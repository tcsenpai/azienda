#!/usr/bin/env bash
# audit.sh — conformità del Leader alle policy del progetto (policy-drift).
#
# Sub-azioni ($1):
#   tick    incrementa il contatore sessioni e, se supera la soglia dall'ultimo
#           audit, emette un NUDGE soft (nessun blocco). Chiamato da session_start.
#   report  raccoglie i fatti per un audit di conformità e istruisce il Leader
#           a confrontare il proprio operato con policies.md. Chiamato da /azienda audit.
#   done    registra che un audit è stato fatto ora (azzera il contatore-da-audit).
#
# Tutto file-based: contatori in state.json, ledger append-only in ledger.md.
# Nessun runtime, nessuna inferenza dai log: l'intento lo dà il Leader nel report.

set -uo pipefail

ACTION="${1:-report}"

# Path assoluto di questo script: le istruzioni differite al Leader devono usare
# QUESTO, non ${CLAUDE_PLUGIN_ROOT} (che è vuoto nella shell delle Bash del
# modello — è espanso solo in frontmatter/hook, non a runtime).
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

# Soglia sessioni oltre la quale il nudge suggerisce un audit (override via env).
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

# Legge un intero da state.json (default 0). $1 = chiave.
read_int() {
  [ -f "$STATE_FILE" ] || { echo 0; return; }
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys;print(int(json.load(open(sys.argv[1])).get(sys.argv[2]) or 0))' "$STATE_FILE" "$1" 2>/dev/null && return
  fi
  echo 0
}

# Scrive/aggiorna una chiave intera in state.json preservando il resto.
write_int() {
  [ -f "$STATE_FILE" ] || return 0
  command -v python3 >/dev/null 2>&1 || return 0
  python3 - "$STATE_FILE" "$1" "$2" <<'PY'
import json,sys,os
path,key,val=sys.argv[1],sys.argv[2],int(sys.argv[3])
try: d=json.load(open(path))
except Exception: d={}
d[key]=val
# scrittura atomica: un lettore concorrente (session_start/toggle) non deve mai
# vedere JSON troncato durante il write del contatore.
tmp=path+".tmp"
with open(tmp,'w') as f: json.dump(d,f,indent=2); f.write("\n")
os.replace(tmp,path)
PY
}

case "$ACTION" in
  tick)
    # solo se la modalità è attiva (state.json esiste con active:true)
    [ -f "$STATE_FILE" ] || exit 0
    grep -Eq '"active"[[:space:]]*:[[:space:]]*true' "$STATE_FILE" || exit 0
    # Il contatore avanza SEMPRE (serve a /azienda-audit per sapere da quanto
    # non si audita). Ma il NUDGE non richiesto è OPT-IN: appare solo se
    # l'utente lo ha attivato — un plugin che ti ricorda da solo di auditare se
    # stesso è invadente. Attiva con: touch .claude/azienda/audit-nudge.on
    # (o AZIENDA_AUDIT_NUDGE=on).
    n=$(( $(read_int sessions) + 1 ))
    write_int sessions "$n"
    last=$(read_int last_audit_session)
    nudge_on=0
    [ -f "$STATE_DIR/audit-nudge.on" ] && nudge_on=1
    [ "${AZIENDA_AUDIT_NUDGE:-}" = "on" ] && nudge_on=1
    if [ "$nudge_on" = "1" ] && [ $(( n - last )) -ge "$AUDIT_EVERY" ]; then
      echo ">> [azienda] Sono passate $(( n - last )) sessioni dall'ultimo audit di"
      echo ">> conformità alle policy. Quando ti fa comodo, lancia /azienda-audit."
    fi
    ;;

  report)
    echo "[audit] Progetto: $PROJECT_DIR"
    if [ ! -f "$POLICIES_FILE" ]; then
      echo "[audit] Nessun policies.md: fai prima /azienda on (crea il file dal template)."
      exit 0
    fi
    echo "[audit] Policy del progetto: $POLICIES_FILE"
    echo "[audit] Ledger conformità: $LEDGER_FILE $( [ -f "$LEDGER_FILE" ] && echo '(esistente)' || echo '(nuovo)')"
    echo "[audit] Sessioni totali: $(read_int sessions) | ultimo audit alla sessione: $(read_int last_audit_session)"
    echo
    echo ">> ISTRUZIONE (audit di conformità, NON automatico):"
    echo ">> 1. Leggi policies.md (le regole dichiarate del progetto)."
    echo ">> 2. Ripercorri il lavoro recente e confrontalo con quelle regole:"
    echo ">>    - divieti rispettati? tracking aggiornato? escalation seguite?"
    echo ">>    - hai RIUSATO l'esistente (skill/command/agenti/graft/myc/codedb)"
    echo ">>      o costruito da zero? se da zero, era un buco reale?"
    echo ">> 3. Scrivi un blocco datato in $LEDGER_FILE (append, non sovrascrivere):"
    echo ">>    data, aderenze OK, DERIVE trovate (con motivo), OVERRIDE consapevoli."
    echo ">> 4. Se una deriva è in realtà un pattern nuovo e valido, PROPONI"
    echo ">>    all'utente di emendare policies.md — non farlo di tua iniziativa."
    echo ">> 5. Quando hai scritto il ledger, esegui:"
    echo ">>    bash $SELF done"
    ;;

  done)
    n=$(read_int sessions)
    write_int last_audit_session "$n"
    echo "[audit] Audit registrato alla sessione $n → contatore azzerato."
    ;;

  *)
    echo "[audit] Sub-azione non valida: '$ACTION' (tick|report|done)"
    exit 1
    ;;
esac
