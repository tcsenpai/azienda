#!/usr/bin/env bash
# toggle.sh — gestione stato modalità azienda (per-progetto).
# Uso: toggle.sh on|off|status
#
# Scrive/legge ./.claude/azienda/state.json risolto sulla radice del progetto,
# ed emette su stdout la direttiva da iniettare nella sessione corrente.
# (Chiamato dallo slash command /azienda tramite iniezione `!`.)

set -euo pipefail

ACTION="${1:-status}"

# --- Risoluzione radice progetto (deve combaciare con session_start.sh) ---
resolve_project_dir() {
  if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "${CLAUDE_PROJECT_DIR:-}" ]; then
    printf '%s' "$CLAUDE_PROJECT_DIR"
    return
  fi
  # Uno stato azienda esistente è il segnale PIÙ specifico: risali cercandolo
  # PRIMA del git toplevel, così un repo annidato (submodule) dentro un progetto
  # azienda non fa sparire/sdoppiare la modalità. Nel caso normale (state.json
  # nella root git) la risalita lo trova subito → stesso risultato.
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

# --- Radice plugin / persona (relative a questo script, no dipendenze env) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
PERSONA_FILE="$PLUGIN_ROOT/persona.md"
POLICIES_TEMPLATE="$PLUGIN_ROOT/policies.template.md"

# Crea il file policies del progetto dal template se non esiste ancora,
# più un .gitignore che esclude lo stato personale (non le policy, che
# possono essere condivise col team).
ensure_policies() {
  mkdir -p "$STATE_DIR"
  local gi="$STATE_DIR/.gitignore"
  [ -f "$gi" ] || printf 'state.json\n' > "$gi"
  [ -f "$POLICIES_FILE" ] && return
  if [ -f "$POLICIES_TEMPLATE" ]; then
    # espande {{PROGETTO}} col basename della radice progetto
    _p=$(basename "$PROJECT_DIR" | sed 's/[&|]/\\&/g')
    sed "s|{{PROGETTO}}|$_p|g" "$POLICIES_TEMPLATE" > "$POLICIES_FILE"
    echo "[azienda] Policies inizializzate dal template → $POLICIES_FILE"
  fi
}

# Default tracking senza onboarding esplicito: se non ancora configurato, scrive
# il backend di default (mycelium se `myc` c'è, altrimenti vault) nel file
# condiviso. NON inizializza nulla di invasivo (niente `myc init`): per l'init
# completo resta /azienda-onboard. Così /azienda on non richiede un 2º comando.
auto_tracking() {
  local tf="$STATE_DIR/tracking"
  [ -f "$tf" ] && return  # già configurato (o via onboarding esplicito)
  mkdir -p "$STATE_DIR"
  if command -v myc >/dev/null 2>&1; then
    printf 'mycelium\n' > "$tf"
    echo "[azienda] Tracking default: mycelium (per l'init completo: /azienda-onboard)"
  else
    printf 'vault\n' > "$tf"
    echo "[azienda] Tracking default: vault → ./.claude/azienda/vault/ (crealo con /azienda-onboard)"
  fi
}

now_iso() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# ponytail: python3 è il parser JSON vero (sempre presente su macOS/Linux);
# grep/sed restano come fallback se python3 mancasse, robusti sul JSON che
# scriviamo noi ma fragili su file editati a mano — per quello c'è python3.
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
  # $1 = true|false ; $2 = activated_at (stringa ISO o vuota per null)
  mkdir -p "$STATE_DIR"
  local active="$1" ts="$2"
  # ponytail: python3 preserva chiavi extra (es. "tracking" dall'onboarding)
  # che un off non deve azzerare; il printf resta come fallback.
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
# scrittura atomica: tmp + os.replace. Un session_start.sh concorrente che legge
# "active" durante un write non deve mai vedere JSON troncato (→ except → {} →
# modalità letta come OFF, persona non iniettata).
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
    echo "[azienda] Stato scritto: active=true → $STATE_FILE"
    echo
    if [ -f "$PERSONA_FILE" ]; then
      _f=$(printf '%s' "${AZIENDA_FOUNDER:-Cris}" | sed 's/[&|]/\\&/g')
      sed "s|{{FOUNDER}}|$_f|g" "$PERSONA_FILE"
    fi
    echo
    echo ">> ISTRUZIONE: assumi ORA la persona descritta sopra e mantienila per"
    echo ">> il resto di questa sessione. LEGGI SUBITO le policy e i workflow"
    echo ">> aziendali di questo progetto in $POLICIES_FILE e applicali."
    echo ">> Gli script del plugin (roster/agents/memory/audit) sono in:"
    echo ">> $PLUGIN_ROOT — usa quel percorso quando la persona cita 'scripts/X'."
    echo ">> Conferma al founder in una riga."
    echo ">>"
    echo ">> POI, se NON esiste già $STATE_DIR/organigramma.md, PROPONI al founder"
    echo ">> il bootstrap automatico (scouting repo + decisione su chi assumere +"
    echo ">> generazione organigramma) CHIEDENDO conferma: se accetta, esegui"
    echo ">> \`bash $PLUGIN_ROOT/scripts/bootstrap.sh\` e segui la sua istruzione."
    echo ">> Se rifiuta, resta disponibile via /azienda-bootstrap. Non lanciarlo"
    echo ">> senza il sì del founder."
    ;;

  off)
    write_state "false" ""
    echo "[azienda] Stato scritto: active=false → $STATE_FILE"
    echo
    echo ">> ISTRUZIONE: DEPONI la persona di Leader/CTO. Torna al tuo"
    echo ">> comportamento di default per il resto di questa sessione. Non usare"
    echo ">> più il subagent 'luogotenente' se non esplicitamente richiesto."
    echo ">> Conferma al founder in una riga che la modalità azienda è disattivata."
    ;;

  status)
    active="$(read_active)"
    ts="$(read_activated_at)"
    if [ "$active" = "true" ]; then
      echo "[azienda] Modalità azienda: ATTIVA"
      echo "[azienda] Progetto: $PROJECT_DIR"
      echo "[azienda] Attivata: ${ts:-sconosciuta}"
      echo "[azienda] Stato: $STATE_FILE"
    elif [ -f "$STATE_FILE" ]; then
      echo "[azienda] Modalità azienda: DISATTIVA"
      echo "[azienda] Progetto: $PROJECT_DIR"
      echo "[azienda] Stato: $STATE_FILE"
    else
      echo "[azienda] Modalità azienda: DISATTIVA (nessuno stato per questo progetto)"
      echo "[azienda] Progetto: $PROJECT_DIR"
    fi
    echo
    echo ">> ISTRUZIONE: riporta lo stato qui sopra al founder. Nessun cambio di comportamento."
    ;;

  *)
    echo "[azienda] Argomento non valido: '$ACTION'"
    echo "[azienda] Uso: /azienda on|off|status"
    ;;
esac
