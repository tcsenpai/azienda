#!/usr/bin/env bash
# riunione.sh — prepares the context for a company meeting (sequential
# multi-agent debate, inspired by production-meeting but tailored to azienda).
#
# Does NOT orchestrate the meeting (the Leader does that with the
# /azienda-riunione command): here we only do the GATE (azienda must be ACTIVE)
# and gather the facts the Leader needs to pick the participants and where to
# write the minutes.
#
# Sub-actions ($1):
#   context   (default) gate + org chart + team + tracking backend + where the minutes go
#
# Exits with code != 0 (and a message) if azienda mode is NOT active: the
# meeting only makes sense in azienda mode.

set -uo pipefail

ACTION="${1:-context}"

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

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
STATE_DIR="$PROJECT_DIR/.claude/azienda"
STATE_FILE="$STATE_DIR/state.json"
ORG_FILE="$STATE_DIR/organigramma.md"
TEAMS_FILE="$STATE_DIR/teams.md"
TRACKING_FILE="$STATE_DIR/tracking"
MEETINGS_DIR="$STATE_DIR/riunioni"

is_active() {
  [ -f "$STATE_FILE" ] || return 1
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys;sys.exit(0 if json.load(open(sys.argv[1])).get("active") is True else 1)' "$STATE_FILE" 2>/dev/null && return 0
    return 1
  fi
  grep -Eq '"active"[[:space:]]*:[[:space:]]*true' "$STATE_FILE"
}

read_tracking() {
  if [ -f "$TRACKING_FILE" ]; then head -n1 "$TRACKING_FILE" | tr -d '[:space:]'; return; fi
  echo ""
}

# --- GATE: azienda must be active (applies to ALL sub-actions) ---
if ! is_active; then
  echo "[riunione] azienda mode NOT active in this project."
  echo "[riunione] The meeting only makes sense in azienda mode. Run first: /azienda on"
  exit 3
fi

case "$ACTION" in
  context)
    echo "[riunione] azienda mode: ATTIVA"
    echo "[riunione] Project: $PROJECT_DIR"
    echo

    echo "## Org chart (roster to choose participants from)"
    if [ -f "$ORG_FILE" ]; then
      cat "$ORG_FILE"
    else
      echo "(no org chart: create it with /azienda-org. Fallback: generic panel)"
    fi
    echo

    echo "## Team (if the meeting is for a specific area)"
    if [ -f "$TEAMS_FILE" ]; then
      cat "$TEAMS_FILE"
    else
      echo "(no teams.md: single team / project org chart)"
    fi
    echo

    tr="$(read_tracking)"
    echo "## Project tracking: ${tr:-not configured}"
    echo "## Minutes: to be saved in $MEETINGS_DIR/<slug>-<date>/ (creates the dir if needed)"
    echo "   and the ACTION ITEMs go into the tracking (${tr:-vault/mycelium})."
    echo "   Minutes template (copy and fill it in): $PLUGIN_ROOT/verbale.template.md"
    echo

    echo "## Engine: PLUGIN_ROOT=$PLUGIN_ROOT"
    echo "   The debate is run by a workflow (a single, self-contained call):"
    echo "   $PLUGIN_ROOT/workflows/riunione.workflow.js"
    echo
    echo ">> ISTRUZIONE (for the Leader): do NOT orchestrate the meeting turn-by-turn"
    echo ">> by hand. Your part is the JUDGMENT: choose the participants (min 2 —"
    echo ">> below 2 it's refused) from the roster above, based on the topic and the"
    echo ">> team; for each one an agent on disk (agentType) or an ad-hoc persona."
    echo ">> Then make ONE call to the Workflow tool with scriptPath =="
    echo ">> $PLUGIN_ROOT/workflows/riunione.workflow.js and args = {topic, lang,"
    echo ">> speakers:[{role, agentType|persona}]}. The workflow runs the sequential"
    echo ">> debate (default 3 rounds) and the minutes, and returns to you"
    echo ">> {transcript, verbale}. Save them in the dir above (riunione.sh mkdir"
    echo ">> <slug>) and pour the action items into the tracking. The full"
    echo ">> procedure is in the /azienda-riunione command."
    ;;

  mkdir)
    # creates the riunioni/<slug>-<date> dir and prints its path (used by the Leader)
    slug="${2:-riunione}"
    d="$MEETINGS_DIR/${slug}-$(date -u +%Y%m%d)"
    mkdir -p "$d"
    echo "$d"
    ;;

  *)
    echo "[riunione] Invalid sub-action: '$ACTION' (context|mkdir <slug>)"
    exit 1
    ;;
esac
