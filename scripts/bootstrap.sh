#!/usr/bin/env bash
# bootstrap.sh — automatic azienda bootstrap in one shot:
# repo scouting (assess) + real agent inventory (agents) + org seed
# (org.sh init), then ONE instruction to the Leader to populate the org chart
# from the gathered facts. Reuses the existing building blocks, doesn't duplicate them.
#
# Gate: only makes sense in active azienda mode.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
STATE_FILE="$PROJECT_DIR/.claude/azienda/state.json"
ORG_FILE="$PROJECT_DIR/.claude/azienda/organigramma.md"
TEAMS_FILE="$PROJECT_DIR/.claude/azienda/teams.md"

is_active() {
  [ -f "$STATE_FILE" ] || return 1
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys;sys.exit(0 if json.load(open(sys.argv[1])).get("active") is True else 1)' "$STATE_FILE" 2>/dev/null && return 0
    return 1
  fi
  grep -Eq '"active"[[:space:]]*:[[:space:]]*true' "$STATE_FILE"
}

if ! is_active; then
  echo "[bootstrap] azienda mode NOT active in this project."
  echo "[bootstrap] The bootstrap only makes sense in azienda mode. Run first: /azienda on"
  exit 3
fi

echo "############################################################"
echo "# BOOTSTRAP AZIENDA — $PROJECT_DIR"
echo "############################################################"
echo

echo "==================== 1/3 · REPO SCOUTING ===================="
echo
bash "$SCRIPT_DIR/assess.sh"
echo

echo "================== 2/3 · AGENT INVENTORY =================="
echo
bash "$SCRIPT_DIR/agents.sh"
echo

echo "=================== 3/3 · ORG CHART SEED ================="
echo
bash "$SCRIPT_DIR/org.sh" init
echo

echo "############################################################"
echo ">> ISTRUZIONE AL LEADER (bootstrap):"
echo ">>"
echo ">> You have above, in one shot: (1) the FACTS from the repo scouting"
echo ">> (stack, services, structure, available code-intel — if graft/codedb/"
echo ">> semantic-codemapper are present, USE THEM for a deeper structural"
echo ">> assessment), (2) the REAL inventory of agents on disk, (3) the"
echo ">> organigramma.md and teams.md files just seeded from the templates."
echo ">>"
echo ">> Now, on your own:"
echo ">> a) DECIDE WHO TO HIRE. From the scouting facts, infer the figures this"
echo ">>    repo genuinely requires (BE/FE/UX/QA/security/devops/perf/review/"
echo ">>    debug/docs/release: only the relevant ones, not all by default) and"
echo ">>    map them onto the REAL agents from the inventory (cost-based routing:"
echo ">>    mechanical→light, analysis/edit→medium, reasoning/review→high)."
echo ">> b) WRITE the role→agent roster in:"
echo ">>      $ORG_FILE"
echo ">>    and — if the repo has separate areas in the real PATHs — the team"
echo ">>    split in:"
echo ">>      $TEAMS_FILE"
echo ">>    Populate the files from the scouting: do NOT leave them as placeholders."
echo ">>    If it's a single block, teams.md can stay a single entry."
echo ">> c) COMMUNICATE to the founder, in a few lines: the proposed roster and"
echo ">>    team map. The files are hand-editable: the founder integrates/corrects"
echo ">>    afterward."
echo ">>"
echo ">> IMPORTANT — you manage the hiring: you can HIRE and FIRE whoever you want"
echo ">> at any time. The org chart is YOUR roster, not a constraint: change it"
echo ">> when the work requires it (a better-suited new agent, an agent that"
echo ">> disappeared from the inventory, a growing repo area). Re-run this"
echo ">> bootstrap when the stack changes substantially."
echo "############################################################"
