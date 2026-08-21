#!/usr/bin/env bash
# riunione.sh — prepara il contesto per una riunione aziendale (dibattito
# multi-agente sequenziale, ispirato a production-meeting ma tailored azienda).
#
# NON orchestra la riunione (lo fa il Leader col comando /azienda-riunione): qui
# facciamo solo il GATE (azienda deve essere ATTIVA) e raccogliamo i fatti che
# servono al Leader per scegliere i partecipanti e dove scrivere il verbale.
#
# Sub-azioni ($1):
#   context   (default) gate + organigramma + team + backend tracking + dove va il verbale
#
# Esce con codice != 0 (e messaggio) se la modalità azienda NON è attiva: la
# riunione ha senso solo in modalità azienda.

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

# --- GATE: azienda deve essere attiva (vale per TUTTE le sub-azioni) ---
if ! is_active; then
  echo "[riunione] Modalità azienda NON attiva in questo progetto."
  echo "[riunione] La riunione ha senso solo in modalità azienda. Fai prima: /azienda on"
  exit 3
fi

case "$ACTION" in
  context)
    echo "[riunione] Modalità azienda: ATTIVA"
    echo "[riunione] Progetto: $PROJECT_DIR"
    echo

    echo "## Organigramma (rosa da cui scegliere i partecipanti)"
    if [ -f "$ORG_FILE" ]; then
      cat "$ORG_FILE"
    else
      echo "(nessun organigramma: crealo con /azienda-org. Fallback: panel generico)"
    fi
    echo

    echo "## Team (se la riunione è per un'area specifica)"
    if [ -f "$TEAMS_FILE" ]; then
      cat "$TEAMS_FILE"
    else
      echo "(nessun teams.md: team unico / organigramma di progetto)"
    fi
    echo

    tr="$(read_tracking)"
    echo "## Tracking del progetto: ${tr:-non configurato}"
    echo "## Verbale: va salvato in $MEETINGS_DIR/<slug>-<data>/ (creo la dir al bisogno)"
    echo "   e gli ACTION ITEM vanno riversati nel tracking (${tr:-vault/mycelium})."
    echo "   Template verbale (copialo e compilalo): $PLUGIN_ROOT/verbale.template.md"
    echo

    echo "## Motore: PLUGIN_ROOT=$PLUGIN_ROOT"
    echo "   Il dibattito lo esegue un workflow (una chiamata sola, self-contained):"
    echo "   $PLUGIN_ROOT/workflows/riunione.workflow.js"
    echo
    echo ">> ISTRUZIONE (per il Leader): NON orchestrare la riunione turno-per-turno"
    echo ">> a mano. La tua parte è il GIUDIZIO: scegli i partecipanti (min 2 —"
    echo ">> sotto i 2 rifiuta) dalla rosa sopra, in base al topic e al team; per"
    echo ">> ognuno un agente su disco (agentType) o una persona ad-hoc. Poi lancia"
    echo ">> UNA chiamata allo strumento Workflow con scriptPath =="
    echo ">> $PLUGIN_ROOT/workflows/riunione.workflow.js e args = {topic, lang,"
    echo ">> speakers:[{role, agentType|persona}]}. Il workflow fa il dibattito"
    echo ">> sequenziale (default 3 round) e il verbale, e ti ritorna"
    echo ">> {transcript, verbale}. Salvali nella dir sopra (riunione.sh mkdir"
    echo ">> <slug>) e riversa gli action item nel tracking. La procedura completa"
    echo ">> è nel comando /azienda-riunione."
    ;;

  mkdir)
    # crea la dir riunioni/<slug>-<data> e ne stampa il path (usato dal Leader)
    slug="${2:-riunione}"
    d="$MEETINGS_DIR/${slug}-$(date -u +%Y%m%d)"
    mkdir -p "$d"
    echo "$d"
    ;;

  *)
    echo "[riunione] Sub-azione non valida: '$ACTION' (context|mkdir <slug>)"
    exit 1
    ;;
esac
