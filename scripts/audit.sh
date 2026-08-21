#!/usr/bin/env bash
# audit.sh — Leader's compliance with the project's policy (policy-drift).
#
# Sub-actions ($1):
#   tick    increments the session counter and, if it exceeds the threshold
#           since the last audit, emits a soft NUDGE (no blocking). Called by session_start.
#   report  gathers the facts for a compliance audit and instructs the Leader
#           to compare their own work against policies.md. Called by /azienda audit.
#   done    records that an audit has just been done (resets the since-audit counter).
#
# Fully file-based: counters in state.json, append-only ledger in ledger.md.
# No runtime, no inference from logs: the Leader supplies the intent in the report.

set -uo pipefail

ACTION="${1:-report}"

# Absolute path of this script: deferred instructions to the Leader must use
# THIS, not ${CLAUDE_PLUGIN_ROOT} (which is empty in the model's Bash shell —
# it's expanded only in frontmatter/hooks, not at runtime).
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

# Session threshold above which the nudge suggests an audit (override via env).
AUDIT_EVERY="${AZIENDA_AUDIT_EVERY:-5}"

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
POLICIES_FILE="$STATE_DIR/policies.md"
LEDGER_FILE="$STATE_DIR/ledger.md"

# Reads an integer from state.json (default 0). $1 = key.
read_int() {
  [ -f "$STATE_FILE" ] || { echo 0; return; }
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys;print(int(json.load(open(sys.argv[1])).get(sys.argv[2]) or 0))' "$STATE_FILE" "$1" 2>/dev/null && return
  fi
  echo 0
}

# Writes/updates an integer key in state.json preserving the rest.
write_int() {
  [ -f "$STATE_FILE" ] || return 0
  command -v python3 >/dev/null 2>&1 || return 0
  python3 - "$STATE_FILE" "$1" "$2" <<'PY'
import json,sys,os
path,key,val=sys.argv[1],sys.argv[2],int(sys.argv[3])
try: d=json.load(open(path))
except Exception: d={}
d[key]=val
# atomic write: a concurrent reader (session_start/toggle) must never see
# truncated JSON during the counter's write.
tmp=path+".tmp"
with open(tmp,'w') as f: json.dump(d,f,indent=2); f.write("\n")
os.replace(tmp,path)
PY
}

case "$ACTION" in
  tick)
    # only if the mode is active (state.json exists with active:true)
    [ -f "$STATE_FILE" ] || exit 0
    grep -Eq '"active"[[:space:]]*:[[:space:]]*true' "$STATE_FILE" || exit 0
    # The counter ALWAYS advances (used by /azienda-audit to know how long
    # since the last audit). But the unsolicited NUDGE is OPT-IN: it appears
    # only if the user has enabled it — a plugin that reminds itself to audit
    # itself is intrusive. Enable with: touch .claude/azienda/audit-nudge.on
    # (or AZIENDA_AUDIT_NUDGE=on).
    n=$(( $(read_int sessions) + 1 ))
    write_int sessions "$n"
    last=$(read_int last_audit_session)
    nudge_on=0
    [ -f "$STATE_DIR/audit-nudge.on" ] && nudge_on=1
    [ "${AZIENDA_AUDIT_NUDGE:-}" = "on" ] && nudge_on=1
    if [ "$nudge_on" = "1" ] && [ $(( n - last )) -ge "$AUDIT_EVERY" ]; then
      echo ">> [azienda] $(( n - last )) sessions have passed since the last policy"
      echo ">> compliance audit. Whenever convenient, run /azienda-audit."
    fi
    ;;

  report)
    echo "[audit] Project: $PROJECT_DIR"
    if [ ! -f "$POLICIES_FILE" ]; then
      echo "[audit] No policies.md: run /azienda on first (creates the file from the template)."
      exit 0
    fi
    echo "[audit] Project policy: $POLICIES_FILE"
    echo "[audit] Compliance ledger: $LEDGER_FILE $( [ -f "$LEDGER_FILE" ] && echo '(existing)' || echo '(new)')"
    echo "[audit] Total sessions: $(read_int sessions) | last audit at session: $(read_int last_audit_session)"
    echo
    echo ">> ISTRUZIONE (compliance audit, NOT automatic):"
    echo ">> 1. Read policies.md (the project's declared rules)."
    echo ">> 2. Retrace the recent work and compare it against those rules:"
    echo ">>    - prohibitions respected? tracking updated? escalations followed?"
    echo ">>    - did you REUSE what already existed (skill/command/agents/graft/myc/codedb)"
    echo ">>      or build from scratch? if from scratch, was it a real gap?"
    echo ">> 3. Write a dated block in $LEDGER_FILE (append, don't overwrite):"
    echo ">>    date, OK compliances, DRIFTS found (with reason), conscious OVERRIDES."
    echo ">> 4. If a drift is actually a new, valid pattern, PROPOSE to the user"
    echo ">>    amending policies.md — don't do it on your own initiative."
    echo ">> 5. Once you've written the ledger, run:"
    echo ">>    bash $SELF done"
    ;;

  done)
    n=$(read_int sessions)
    write_int last_audit_session "$n"
    echo "[audit] Audit recorded at session $n → counter reset."
    ;;

  *)
    echo "[audit] Invalid sub-action: '$ACTION' (tick|report|done)"
    exit 1
    ;;
esac
