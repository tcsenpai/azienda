#!/usr/bin/env bash
# agents.sh — inventory of the agents available RIGHT NOW for orchestration.
#
# The agent pool changes (plugins, agents added/removed). This gives the leader
# an up-to-date overview: name + first line of description, by source. It is
# not exhaustive of the harness's built-in subagents (you know those from the
# session context) — it covers agents on disk, which are the most volatile.

set -uo pipefail

print_dir() {
  local label="$1" dir="$2"
  [ -d "$dir" ] || return 0
  local found=0
  for f in "$dir"/*.md; do
    [ -f "$f" ] || continue
    found=1
    local name desc
    name="$(basename "$f" .md)"
    # description from the YAML frontmatter, otherwise first non-empty line
    desc="$(sed -n 's/^description:[[:space:]]*//p' "$f" | head -n1)"
    [ -n "$desc" ] || desc="$(grep -m1 -v '^[[:space:]]*$' "$f" 2>/dev/null)"
    printf '  %-28s %s\n' "$name" "${desc:0:90}"
  done
  [ "$found" = 1 ] && echo "  (source: $label — $dir)" && echo
}

echo "=== Agents available on disk (overview) ==="
echo

print_dir "user" "$HOME/.claude/agents"

# Agents from installed plugins (cache)
if [ -d "$HOME/.claude/plugins/cache" ]; then
  while IFS= read -r d; do
    print_dir "plugin" "$d"
  done < <(find "$HOME/.claude/plugins/cache" -type d -name agents 2>/dev/null)
fi

# Project-level agents
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "$CLAUDE_PROJECT_DIR/.claude/agents" ]; then
  print_dir "project" "$CLAUDE_PROJECT_DIR/.claude/agents"
elif top="$(git rev-parse --show-toplevel 2>/dev/null)" && [ -d "$top/.claude/agents" ]; then
  print_dir "project" "$top/.claude/agents"
fi

echo ">> NB: besides these, the harness exposes built-in subagents (you see them"
echo ">> in the session context). Pick the agent from the REAL pool right now;"
echo ">> the plugin's roster (roster.md) is just a starting guide."
