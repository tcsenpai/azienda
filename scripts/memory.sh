#!/usr/bin/env bash
# memory.sh — per-project operational memory for azienda mode.
#
# Gives (ephemeral) subagents continuity: lessons, gotchas, "last time X
# failed". File-based and local (./.claude/azienda/memory/lessons.md), zero
# dependencies. If the obsidian-memory skill is present, flags it as an
# optional hybrid-search channel — NEVER mandatory, degrades without it.
#
# Sub-actions ($1):
#   recall [query]   prints the lessons (or those matching query) at task start
#   note <text>      appends a dated lesson (project's local scratchpad)
#   where            prints the memory file's path
#   promote          checklist for the Leader: promote durable knowledge to
#                    long-term memory (hindsight + obsidian if present)

set -uo pipefail

ACTION="${1:-recall}"
shift 2>/dev/null || true
ARG="$*"

resolve_project_dir() {
  if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "${CLAUDE_PROJECT_DIR:-}" ]; then
    printf '%s' "$CLAUDE_PROJECT_DIR"; return
  fi
  local d="$PWD"
  while [ "$d" != "/" ]; do
    [ -f "$d/.claude/azienda/state.json" ] && { printf '%s' "$d"; return; }
    d="$(dirname "$d")"
  done
  local top
  if top="$(git rev-parse --show-toplevel 2>/dev/null)" && [ -n "$top" ]; then
    printf '%s' "$top"; return
  fi
  printf '%s' "$PWD"
}

PROJECT_DIR="$(resolve_project_dir)"
MEM_DIR="$PROJECT_DIR/.claude/azienda/memory"
MEM_FILE="$MEM_DIR/lessons.md"

# obsidian-memory present? (user skill). Suggestion only, never required.
has_obsidian() { [ -x "$HOME/.claude/skills/obsidian-memory/scripts/recall.sh" ]; }

case "$ACTION" in
  where)
    echo "$MEM_FILE"
    ;;

  note)
    [ -n "$ARG" ] || { echo "[memory] usage: memory.sh note <lesson text>"; exit 1; }
    mkdir -p "$MEM_DIR"
    [ -f "$MEM_FILE" ] || printf '# Operational lessons — project azienda memory\n\n> Continuity for ephemeral subagents: gotchas, what worked/failed.\n> Append-only. Dense.\n\n' > "$MEM_FILE"
    printf -- '- [%s] %s\n' "$(date -u +%Y-%m-%d)" "$ARG" >> "$MEM_FILE"
    echo "[memory] Lesson recorded → $MEM_FILE"
    if has_obsidian; then
      echo "[memory] (obsidian-memory present: consider retaining it there too for"
      echo "[memory]  cross-project hybrid search — optional, see /obsidian-memory.)"
    fi
    ;;

  recall)
    if [ ! -f "$MEM_FILE" ]; then
      echo "[memory] No lessons recorded for this project."
      has_obsidian && echo "[memory] (obsidian-memory present: you can search cross-project lessons there.)"
      exit 0
    fi
    if [ -n "$ARG" ]; then
      echo "[memory] Lessons matching '$ARG':"
      grep -i -- "$ARG" "$MEM_FILE" || echo "[memory] (no direct match; read the whole file if needed.)"
    else
      echo "[memory] Project operational lessons ($MEM_FILE):"
      cat "$MEM_FILE"
    fi
    has_obsidian && echo "[memory] (for cross-project hybrid search: /obsidian-memory recall '<query>')"
    ;;

  promote)
    # PROMOTION checklist to long-term memory. Run by the LEADER (the only one
    # who sees the session's MCPs). The script detects obsidian on disk; hindsight
    # is an MCP → not visible here, the Leader verifies it in session.
    repo="$(basename "$PROJECT_DIR")"
    echo "[memory] PROMOTION to long-term memory — repo: $repo"
    echo
    echo "Promote ONLY durable knowledge, at key moments (meeting minutes,"
    echo "architectural decision, quartiermastro assessment/inventory, lesson"
    echo "from a bug). NOT the raw scratchpad. Write to BOTH channels if both"
    echo "exist; if one is missing use the other; if both are missing, the local one."
    echo
    echo "Long-term channels:"
    echo "  - hindsight (MCP): if you see mcp__hindsight__* tools in session → retain"
    echo "    in the 'coding-$repo' bank (mcp__hindsight__retain / sync_retain)."
    if has_obsidian; then
      echo "  - obsidian-memory: PRESENT on disk → /obsidian-memory retain"
      echo "    (or scripts/retain.sh) with type decision|lesson|project|entity."
    else
      echo "  - obsidian-memory: NOT present on disk."
    fi
    echo "  - local fallback (always): scripts/memory.sh note \"<lesson>\""
    echo
    echo ">> ISTRUZIONE (Leader): decide what's durable, then write to the"
    echo ">> available channels. If you update a decision already in memory,"
    echo ">> update it on BOTH (or a coherent supersede) — the two channels must not diverge."
    ;;

  *)
    echo "[memory] Invalid sub-action: '$ACTION' (recall|note|where|promote)"
    exit 1
    ;;
esac
