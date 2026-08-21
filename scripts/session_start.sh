#!/usr/bin/env bash
# session_start.sh — SessionStart hook for azienda mode.
#
# Reads ./.claude/azienda/state.json resolved against the project root.
# - If it doesn't exist or active=false → silent exit 0 (no output).
# - If active=true                      → prints the persona on stdout. For the
#   SessionStart event, Claude Code adds the plain-text stdout to the session's
#   context, so the persona gets injected automatically on every startup.

set -uo pipefail

# --- Project root resolution (identical to toggle.sh) ---
resolve_project_dir() {
  if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "${CLAUDE_PROJECT_DIR:-}" ]; then
    printf '%s' "$CLAUDE_PROJECT_DIR"
    return
  fi
  # An existing azienda state = the most specific signal: look for it BEFORE
  # the git toplevel (see toggle.sh for the rationale on nested repos).
  local d="$PWD"
  while [ "$d" != "/" ]; do
    [ -f "$d/.claude/azienda/state.json" ] && { printf '%s' "$d"; return; }
    d="$(dirname "$d")"
  done
  local top
  if top="$(git rev-parse --show-toplevel 2>/dev/null)" && [ -n "$top" ]; then
    printf '%s' "$top"
    return
  fi
  printf '%s' "$PWD"
}

PROJECT_DIR="$(resolve_project_dir)"
STATE_FILE="$PROJECT_DIR/.claude/azienda/state.json"

# No state or missing file → silence.
[ -f "$STATE_FILE" ] || exit 0

# active != true → silence.
# ponytail: real python3 parser if present, grep as fallback (see toggle.sh).
if command -v python3 >/dev/null 2>&1; then
  python3 -c 'import json,sys;sys.exit(0 if json.load(open(sys.argv[1])).get("active") is True else 1)' "$STATE_FILE" 2>/dev/null || exit 0
else
  grep -Eq '"active"[[:space:]]*:[[:space:]]*true' "$STATE_FILE" || exit 0
fi

# Active: injects the compact BRIEF (not the whole persona). On every session
# resume, a few operational lines plus the pointer to the full profile are
# enough; the full persona is loaded only by /azienda on (explicit activation).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
BRIEF_FILE="$PLUGIN_ROOT/persona-brief.md"
PERSONA_FILE="$PLUGIN_ROOT/persona.md"
# fallback: if the brief is missing, use the full persona
[ -f "$BRIEF_FILE" ] || BRIEF_FILE="$PERSONA_FILE"

POLICIES_FILE="$PROJECT_DIR/.claude/azienda/policies.md"

if [ -f "$BRIEF_FILE" ]; then
  # | delimiter and &,| escaping so a name with special chars doesn't break it
  _f=$(printf '%s' "${AZIENDA_FOUNDER:-Cris}" | sed 's/[&|]/\\&/g')
  sed "s|{{FOUNDER}}|$_f|g" "$BRIEF_FILE"
  echo
  echo ">> azienda mode ACTIVE (state persisted on disk). Adopt the Leader role"
  echo ">> from the start of the session. Full profile (for orchestrating"
  echo ">> non-trivial work): $PERSONA_FILE"
  echo ">> The plugin scripts (roster/agents/memory/audit) are in: $PLUGIN_ROOT"
  echo ">> When the persona mentions 'scripts/X' or 'roster.md', use that path."
  if [ -f "$POLICIES_FILE" ]; then
    echo ">> READ the project's policies in $POLICIES_FILE and apply them."
  fi
  # Session counter + periodic compliance-audit nudge (soft, non-blocking).
  bash "$SCRIPT_DIR/audit.sh" tick 2>/dev/null || true
fi

exit 0
