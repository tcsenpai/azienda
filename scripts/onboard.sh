#!/usr/bin/env bash
# onboard.sh — environment detection for azienda mode onboarding.
#
# Does NOT decide on its own: gathers the facts (mycelium present? project
# already initialized? tracking already configured?) and prints them so the
# /azienda-onboard slash command can ask the user the right questions and then act.
#
# Sub-actions (arg $1):
#   detect            (default) prints the environment state and the options
#   set-tracking <v>  writes the backend to the shared tracking file (mycelium|vault)
#   init-mycelium     runs `myc init` (+ prime-agents) in the project
#   init-vault        creates ./.claude/azienda/vault/ with a seed TASKS.md

set -uo pipefail

ACTION="${1:-detect}"
VALUE="${2:-}"

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
VAULT_DIR="$STATE_DIR/vault"

# Absolute path of THIS script: the deferred sub-actions (init-mycelium,
# init-vault, set-tracking) that the model will run later must use THIS,
# not ${CLAUDE_PLUGIN_ROOT} (empty in the model's Bash shell).
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

has_myc() { command -v myc >/dev/null 2>&1; }
myc_project_ready() { [ -d "$PROJECT_DIR/.mycelium" ]; }

# tracking lives in a SHARED file (versionable), not in state.json (personal,
# gitignored). This way in a team the backend choice is shared via git. Legacy:
# if the shared file is missing, read_tracking() falls back to reading the old
# state.json.tracking (read-only: does NOT rewrite the shared file). The real
# migration happens on the first set-tracking, which writes the shared file.
TRACKING_FILE="$STATE_DIR/tracking"

read_tracking() {
  if [ -f "$TRACKING_FILE" ]; then
    head -n1 "$TRACKING_FILE" | tr -d '[:space:]'
    return
  fi
  # legacy fallback: state.json
  [ -f "$STATE_FILE" ] || { echo ""; return; }
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("tracking") or "")' "$STATE_FILE" 2>/dev/null && return
  fi
  sed -n 's/.*"tracking"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$STATE_FILE" | head -n1
}

set_tracking() {
  mkdir -p "$STATE_DIR"
  # If onboarding happens BEFORE /azienda on, the .gitignore that excludes
  # state.json (personal) doesn't exist yet: create it here, so the shared
  # tracking file is versionable without accidentally dragging in the personal state.
  local gi="$STATE_DIR/.gitignore"
  [ -f "$gi" ] || printf 'state.json\n' > "$gi"
  printf '%s\n' "$1" > "$TRACKING_FILE"
}

case "$ACTION" in
  detect)
    echo "[onboard] Project: $PROJECT_DIR"
    if has_myc; then
      echo "[onboard] mycelium (myc): PRESENT ($(myc --version 2>/dev/null))"
      if myc_project_ready; then
        echo "[onboard] mycelium: project ALREADY initialized (.mycelium/ present)"
      else
        echo "[onboard] mycelium: project NOT yet initialized"
      fi
      echo "[onboard] Recommended default: tracking = mycelium"
    else
      echo "[onboard] mycelium (myc): ABSENT from PATH"
      echo "[onboard] Recommended default: tracking = vault (per-project folder)"
    fi
    tr="$(read_tracking)"
    if [ -n "$tr" ]; then
      echo "[onboard] Tracking already configured (shared file): $tr"
    else
      echo "[onboard] Tracking not yet configured."
    fi
    echo
    echo ">> ISTRUZIONE: above are the environment facts. Ask the user the"
    echo ">> onboarding questions (see the command), then run the chosen"
    echo ">> sub-action: init-mycelium OR init-vault, and finally set-tracking."
    echo ">> Use the ABSOLUTE path of this script (NOT \${CLAUDE_PLUGIN_ROOT},"
    echo ">> empty in your Bash):"
    echo ">>   bash $SELF init-mycelium   |   bash $SELF init-vault"
    echo ">>   bash $SELF set-tracking mycelium|vault"
    ;;

  set-tracking)
    case "$VALUE" in
      mycelium|vault) set_tracking "$VALUE"
        echo "[onboard] tracking=$VALUE written to $TRACKING_FILE (shared)" ;;
      *) echo "[onboard] invalid tracking value: '$VALUE' (mycelium|vault)"; exit 1 ;;
    esac
    ;;

  init-mycelium)
    if ! has_myc; then
      echo "[onboard] myc not installed: cannot init-mycelium. Use init-vault."; exit 1
    fi
    ( cd "$PROJECT_DIR" && myc init && myc prime-agents ) 2>&1
    echo "[onboard] mycelium initialized in the project."
    ;;

  init-vault)
    mkdir -p "$VAULT_DIR"
    SEED="$VAULT_DIR/TASKS.md"
    if [ ! -f "$SEED" ]; then
      cat > "$SEED" <<'EOF'
# Task vault — azienda mode

> Per-project tracking without mycelium. Free-form, keep it dense.
> If you later install mycelium, migrate these tasks with `myc task create ...`.

## In progress
- [ ] …

## To do
- [ ] …

## Done
- [x] …
EOF
      echo "[onboard] Vault created → $SEED"
    else
      echo "[onboard] Vault already present → $SEED"
    fi
    ;;

  *)
    echo "[onboard] Invalid sub-action: '$ACTION'"
    echo "[onboard] Usage: onboard.sh detect|set-tracking <v>|init-mycelium|init-vault"
    exit 1
    ;;
esac
