#!/usr/bin/env bash
# session_start.sh — hook SessionStart della modalità azienda.
#
# Legge ./.claude/azienda/state.json sulla radice del progetto.
# - Se non esiste o active=false  → exit 0 silenzioso (nessun output).
# - Se active=true                → stampa la persona su stdout. Per l'evento
#   SessionStart, Claude Code aggiunge lo stdout plain-text al contesto della
#   sessione, quindi la persona viene iniettata automaticamente a ogni avvio.

set -uo pipefail

# --- Risoluzione radice progetto (identica a toggle.sh) ---
resolve_project_dir() {
  if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "${CLAUDE_PROJECT_DIR:-}" ]; then
    printf '%s' "$CLAUDE_PROJECT_DIR"
    return
  fi
  # Stato azienda esistente = segnale più specifico: cercalo PRIMA del git
  # toplevel (vedi toggle.sh per il razionale sui repo annidati).
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
STATE_FILE="$PROJECT_DIR/.claude/azienda/state.json"

# Nessuno stato o file assente → silenzio.
[ -f "$STATE_FILE" ] || exit 0

# active != true → silenzio.
# ponytail: python3 parser vero se c'è, grep come fallback (vedi toggle.sh).
if command -v python3 >/dev/null 2>&1; then
  python3 -c 'import json,sys;sys.exit(0 if json.load(open(sys.argv[1])).get("active") is True else 1)' "$STATE_FILE" 2>/dev/null || exit 0
else
  grep -Eq '"active"[[:space:]]*:[[:space:]]*true' "$STATE_FILE" || exit 0
fi

# Attiva: inietta il BRIEF compatto (non l'intera persona). A ogni ripresa di
# sessione bastano poche righe operative + il puntatore al profilo completo;
# la persona intera la carica solo /azienda on (attivazione esplicita).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
BRIEF_FILE="$PLUGIN_ROOT/persona-brief.md"
PERSONA_FILE="$PLUGIN_ROOT/persona.md"
# fallback: se il brief manca, usa la persona completa
[ -f "$BRIEF_FILE" ] || BRIEF_FILE="$PERSONA_FILE"

POLICIES_FILE="$PROJECT_DIR/.claude/azienda/policies.md"

if [ -f "$BRIEF_FILE" ]; then
  # delimitatore | e escape di &,| così un nome con caratteri speciali non rompe
  _f=$(printf '%s' "${AZIENDA_FOUNDER:-Cris}" | sed 's/[&|]/\\&/g')
  sed "s|{{FOUNDER}}|$_f|g" "$BRIEF_FILE"
  echo
  echo ">> Modalità azienda ATTIVA (stato persistente su disco). Assumi il ruolo"
  echo ">> di Leader dall'inizio della sessione. Profilo completo (per orchestrare"
  echo ">> lavori non banali): $PERSONA_FILE"
  echo ">> Gli script del plugin (roster/agents/memory/audit) sono in: $PLUGIN_ROOT"
  echo ">> Quando la persona cita 'scripts/X' o 'roster.md', usa quel percorso."
  if [ -f "$POLICIES_FILE" ]; then
    echo ">> LEGGI le policy del progetto in $POLICIES_FILE e applicale."
  fi
  # Contatore sessioni + nudge periodico di audit conformità (soft, non blocca).
  bash "$SCRIPT_DIR/audit.sh" tick 2>/dev/null || true
fi

exit 0
