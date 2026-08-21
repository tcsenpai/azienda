#!/usr/bin/env bash
# toggle.sh — azienda mode state management (per-project).
# Usage: toggle.sh on|off|status
#
# Writes/reads ./.claude/azienda/state.json resolved against the project root,
# and emits on stdout the directive to inject into the current session.
# (Called by the /azienda slash command via `!` injection.)

set -euo pipefail

ACTION="${1:-status}"

# --- Project root resolution (must match session_start.sh) ---
resolve_project_dir() {
  if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "${CLAUDE_PROJECT_DIR:-}" ]; then
    printf '%s' "$CLAUDE_PROJECT_DIR"
    return
  fi
  # An existing azienda state is the MOST specific signal: walk up looking for
  # it BEFORE the git toplevel, so a nested repo (submodule) inside an azienda
  # project doesn't lose or duplicate the mode. In the normal case (state.json
  # in the git root) the walk-up finds it right away → same result.
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
STATE_DIR="$PROJECT_DIR/.claude/azienda"
STATE_FILE="$STATE_DIR/state.json"
POLICIES_FILE="$STATE_DIR/policies.md"

# --- Plugin / persona root (relative to this script, no env dependencies) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
PERSONA_FILE="$PLUGIN_ROOT/persona.md"
POLICIES_TEMPLATE="$PLUGIN_ROOT/policies.template.md"

# Creates the project's policies file from the template if it doesn't exist
# yet, plus a .gitignore that excludes the personal state (not the policies,
# which can be shared with the team).
ensure_policies() {
  mkdir -p "$STATE_DIR"
  local gi="$STATE_DIR/.gitignore"
  [ -f "$gi" ] || printf 'state.json\n' > "$gi"
  [ -f "$POLICIES_FILE" ] && return
  if [ -f "$POLICIES_TEMPLATE" ]; then
    # expands {{PROGETTO}} with the basename of the project root
    _p=$(basename "$PROJECT_DIR" | sed 's/[&|]/\\&/g')
    sed "s|{{PROGETTO}}|$_p|g" "$POLICIES_TEMPLATE" > "$POLICIES_FILE"
    echo "[azienda] Policies initialized from template → $POLICIES_FILE"
  fi
}

# Default tracking without explicit onboarding: if not configured yet, writes
# the default backend (mycelium if `myc` is present, otherwise vault) to the
# shared file. Does NOT initialize anything invasive (no `myc init`): the full
# init stays at /azienda-onboard. This way /azienda on doesn't need a 2nd command.
auto_tracking() {
  local tf="$STATE_DIR/tracking"
  [ -f "$tf" ] && return  # already configured (or via explicit onboarding)
  mkdir -p "$STATE_DIR"
  if command -v myc >/dev/null 2>&1; then
    printf 'mycelium\n' > "$tf"
    echo "[azienda] Default tracking: mycelium (for full init: /azienda-onboard)"
  else
    printf 'vault\n' > "$tf"
    echo "[azienda] Default tracking: vault → ./.claude/azienda/vault/ (create it with /azienda-onboard)"
  fi
}

now_iso() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# ponytail: python3 is the real JSON parser (always present on macOS/Linux);
# grep/sed remain as fallback if python3 were missing, robust on the JSON we
# write ourselves but fragile on hand-edited files — that's what python3 is for.
read_active() {
  [ -f "$STATE_FILE" ] || { echo "false"; return; }
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys;print("true" if json.load(open(sys.argv[1])).get("active") is True else "false")' "$STATE_FILE" 2>/dev/null && return
  fi
  if grep -Eq '"active"[[:space:]]*:[[:space:]]*true' "$STATE_FILE"; then
    echo "true"
  else
    echo "false"
  fi
}

read_activated_at() {
  [ -f "$STATE_FILE" ] || { echo ""; return; }
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("activated_at") or "")' "$STATE_FILE" 2>/dev/null && return
  fi
  sed -n 's/.*"activated_at"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$STATE_FILE" | head -n1
}

write_state() {
  # $1 = true|false ; $2 = activated_at (ISO string or empty for null)
  mkdir -p "$STATE_DIR"
  local active="$1" ts="$2"
  # ponytail: python3 preserves extra keys (e.g. "tracking" from onboarding)
  # that an off must not reset; the printf remains as fallback.
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$STATE_FILE" "$active" "$ts" <<'PY' && return
import json,sys,os
path,active,ts=sys.argv[1],sys.argv[2],sys.argv[3]
d={}
if os.path.exists(path):
    try: d=json.load(open(path))
    except Exception: d={}
d["active"]= (active=="true")
d["activated_at"]= ts if ts else None
# atomic write: tmp + os.replace. A concurrent session_start.sh reading
# "active" during a write must never see truncated JSON (→ except → {} →
# mode read as OFF, persona not injected).
tmp=path+".tmp"
with open(tmp,'w') as f: json.dump(d,f,indent=2); f.write("\n")
os.replace(tmp,path)
PY
  fi
  local ts_field
  if [ -n "$ts" ]; then ts_field="\"$ts\""; else ts_field="null"; fi
  printf '{\n  "active": %s,\n  "activated_at": %s\n}\n' "$active" "$ts_field" > "$STATE_FILE"
}

case "$ACTION" in
  on)
    write_state "true" "$(now_iso)"
    ensure_policies
    auto_tracking
    echo "[azienda] State written: active=true → $STATE_FILE"
    echo
    if [ -f "$PERSONA_FILE" ]; then
      _f=$(printf '%s' "${AZIENDA_FOUNDER:-Cris}" | sed 's/[&|]/\\&/g')
      sed "s|{{FOUNDER}}|$_f|g" "$PERSONA_FILE"
    fi
    echo
    echo ">> ISTRUZIONE: adopt the persona described above NOW and keep it for"
    echo ">> the rest of this session. READ IMMEDIATELY this project's azienda"
    echo ">> policies and workflows in $POLICIES_FILE and apply them."
    echo ">> The plugin scripts (roster/agents/memory/audit) are in:"
    echo ">> $PLUGIN_ROOT — use that path when the persona mentions 'scripts/X'."
    echo ">> Confirm to the founder in one line."
    echo ">>"
    echo ">> THEN, if $STATE_DIR/organigramma.md does NOT exist yet, PROPOSE to"
    echo ">> the founder the automatic bootstrap (repo scouting + deciding who to"
    echo ">> hire + generating the org chart) ASKING for confirmation: if they"
    echo ">> accept, run \`bash $PLUGIN_ROOT/scripts/bootstrap.sh\` and follow its"
    echo ">> instruction. If they decline, stay available via /azienda-bootstrap."
    echo ">> Do not run it without the founder's yes."
    ;;

  off)
    write_state "false" ""
    echo "[azienda] State written: active=false → $STATE_FILE"
    echo
    echo ">> ISTRUZIONE: SET DOWN the Leader/CTO persona. Return to your default"
    echo ">> behavior for the rest of this session. Do not use the 'luogotenente'"
    echo ">> subagent anymore unless explicitly requested."
    echo ">> Confirm to the founder in one line that azienda mode is disabled."
    ;;

  status)
    active="$(read_active)"
    ts="$(read_activated_at)"
    if [ "$active" = "true" ]; then
      echo "[azienda] azienda mode: ATTIVA"
      echo "[azienda] Project: $PROJECT_DIR"
      echo "[azienda] Activated: ${ts:-unknown}"
      echo "[azienda] State: $STATE_FILE"
    elif [ -f "$STATE_FILE" ]; then
      echo "[azienda] azienda mode: DISATTIVA"
      echo "[azienda] Project: $PROJECT_DIR"
      echo "[azienda] State: $STATE_FILE"
    else
      echo "[azienda] azienda mode: DISATTIVA (no state for this project)"
      echo "[azienda] Project: $PROJECT_DIR"
    fi
    echo
    echo ">> ISTRUZIONE: report the status above to the founder. No behavior change."
    ;;

  *)
    echo "[azienda] Invalid argument: '$ACTION'"
    echo "[azienda] Usage: /azienda on|off|status"
    ;;
esac
