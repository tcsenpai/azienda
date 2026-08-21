#!/usr/bin/env bash
# onboard.sh — rilevamento ambiente per l'onboarding della modalità azienda.
#
# NON decide da solo: raccoglie i fatti (mycelium presente? progetto già
# inizializzato? tracking già configurato?) e li stampa in modo che lo slash
# command /azienda-onboard possa porre le domande giuste all'user e poi agire.
#
# Sub-azioni (arg $1):
#   detect            (default) stampa lo stato dell'ambiente e le opzioni
#   set-tracking <v>  scrive il backend nel file condiviso tracking (mycelium|vault)
#   init-mycelium     esegue `myc init` (+ prime-agents) nel progetto
#   init-vault        crea ./.claude/azienda/vault/ con un TASKS.md seed

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

# Path assoluto di QUESTO script: le sub-azioni differite (init-mycelium,
# init-vault, set-tracking) che il modello eseguirà più tardi devono usare
# QUESTO, non ${CLAUDE_PLUGIN_ROOT} (vuoto nella shell delle Bash del modello).
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

has_myc() { command -v myc >/dev/null 2>&1; }
myc_project_ready() { [ -d "$PROJECT_DIR/.mycelium" ]; }

# tracking vive in un file CONDIVISO (versionabile), non in state.json (personale,
# gitignorato). Così in team la scelta del backend è condivisa via git. Legacy:
# se il file condiviso manca, read_tracking() legge come fallback il vecchio
# state.json.tracking (sola lettura: NON riscrive il file condiviso). La
# migrazione vera avviene al primo set-tracking, che scrive il file condiviso.
TRACKING_FILE="$STATE_DIR/tracking"

read_tracking() {
  if [ -f "$TRACKING_FILE" ]; then
    head -n1 "$TRACKING_FILE" | tr -d '[:space:]'
    return
  fi
  # fallback legacy: state.json
  [ -f "$STATE_FILE" ] || { echo ""; return; }
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("tracking") or "")' "$STATE_FILE" 2>/dev/null && return
  fi
  sed -n 's/.*"tracking"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$STATE_FILE" | head -n1
}

set_tracking() {
  mkdir -p "$STATE_DIR"
  # Se l'onboarding avviene PRIMA di /azienda on, il .gitignore che esclude lo
  # state.json (personale) non esiste ancora: crealo qui, così il file tracking
  # condiviso è versionabile senza trascinare per errore lo stato personale.
  local gi="$STATE_DIR/.gitignore"
  [ -f "$gi" ] || printf 'state.json\n' > "$gi"
  printf '%s\n' "$1" > "$TRACKING_FILE"
}

case "$ACTION" in
  detect)
    echo "[onboard] Progetto: $PROJECT_DIR"
    if has_myc; then
      echo "[onboard] mycelium (myc): PRESENTE ($(myc --version 2>/dev/null))"
      if myc_project_ready; then
        echo "[onboard] mycelium: progetto GIÀ inizializzato (.mycelium/ presente)"
      else
        echo "[onboard] mycelium: progetto NON ancora inizializzato"
      fi
      echo "[onboard] Default consigliato: tracking = mycelium"
    else
      echo "[onboard] mycelium (myc): ASSENTE nel PATH"
      echo "[onboard] Default consigliato: tracking = vault (cartella per-progetto)"
    fi
    tr="$(read_tracking)"
    if [ -n "$tr" ]; then
      echo "[onboard] Tracking già configurato (file condiviso): $tr"
    else
      echo "[onboard] Tracking non ancora configurato."
    fi
    echo
    echo ">> ISTRUZIONE: sopra ci sono i fatti dell'ambiente. Poni all'user le"
    echo ">> domande di onboarding (vedi il comando), poi esegui la sub-azione"
    echo ">> scelta: init-mycelium OPPURE init-vault, e infine set-tracking."
    echo ">> Usa il percorso ASSOLUTO di questo script (NON \${CLAUDE_PLUGIN_ROOT},"
    echo ">> vuoto nelle tue Bash):"
    echo ">>   bash $SELF init-mycelium   |   bash $SELF init-vault"
    echo ">>   bash $SELF set-tracking mycelium|vault"
    ;;

  set-tracking)
    case "$VALUE" in
      mycelium|vault) set_tracking "$VALUE"
        echo "[onboard] tracking=$VALUE scritto in $TRACKING_FILE (condiviso)" ;;
      *) echo "[onboard] valore tracking non valido: '$VALUE' (mycelium|vault)"; exit 1 ;;
    esac
    ;;

  init-mycelium)
    if ! has_myc; then
      echo "[onboard] myc non installato: impossibile init-mycelium. Usa init-vault."; exit 1
    fi
    ( cd "$PROJECT_DIR" && myc init && myc prime-agents ) 2>&1
    echo "[onboard] mycelium inizializzato nel progetto."
    ;;

  init-vault)
    mkdir -p "$VAULT_DIR"
    SEED="$VAULT_DIR/TASKS.md"
    if [ ! -f "$SEED" ]; then
      cat > "$SEED" <<'EOF'
# Task vault — modalità azienda

> Tracking per-progetto senza mycelium. Formato libero, tienilo denso.
> Se poi installi mycelium, migra questi task con `myc task create ...`.

## In corso
- [ ] …

## Da fare
- [ ] …

## Fatto
- [x] …
EOF
      echo "[onboard] Vault creato → $SEED"
    else
      echo "[onboard] Vault già presente → $SEED"
    fi
    ;;

  *)
    echo "[onboard] Sub-azione non valida: '$ACTION'"
    echo "[onboard] Uso: onboard.sh detect|set-tracking <v>|init-mycelium|init-vault"
    exit 1
    ;;
esac
