#!/usr/bin/env bash
# bootstrap.sh — bootstrap automatico dell'azienda in un colpo:
# scouting del repo (assess) + inventario agenti reali (agents) + seed org
# (org.sh init), poi UNA istruzione al Leader per popolare l'organigramma dai
# fatti raccolti. Riusa i mattoni esistenti, non li duplica.
#
# Gate: ha senso solo in modalità azienda attiva.

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
  echo "[bootstrap] Modalità azienda NON attiva in questo progetto."
  echo "[bootstrap] Il bootstrap ha senso solo in modalità azienda. Fai prima: /azienda on"
  exit 3
fi

echo "############################################################"
echo "# BOOTSTRAP AZIENDA — $PROJECT_DIR"
echo "############################################################"
echo

echo "==================== 1/3 · SCOUTING REPO ===================="
echo
bash "$SCRIPT_DIR/assess.sh"
echo

echo "================== 2/3 · INVENTARIO AGENTI =================="
echo
bash "$SCRIPT_DIR/agents.sh"
echo

echo "=================== 3/3 · SEED ORGANIGRAMMA ================="
echo
bash "$SCRIPT_DIR/org.sh" init
echo

echo "############################################################"
echo ">> ISTRUZIONE AL LEADER (bootstrap):"
echo ">>"
echo ">> Hai sopra, in un colpo: (1) i FATTI dello scouting del repo (stack,"
echo ">> servizi, struttura, code-intel disponibile — se c'è graft/codedb/"
echo ">> semantic-codemapper USALI per un assessment strutturale più profondo),"
echo ">> (2) l'INVENTARIO REALE degli agenti su disco, (3) i file organigramma.md"
echo ">> e teams.md appena seedati dai template."
echo ">>"
echo ">> Ora, in autonomia:"
echo ">> a) DECIDI CHI ASSUMERE. Dai fatti dello scouting deduci le figure che"
echo ">>    questo repo richiede davvero (BE/FE/UX/QA/security/devops/perf/review/"
echo ">>    debug/docs/release: solo quelle pertinenti, non tutte per default) e"
echo ">>    mappale sugli agenti REALI dell'inventario (routing per costo:"
echo ">>    meccanico→leggeri, analisi/edit→media, reasoning/review→alta)."
echo ">> b) SCRIVI la rosa ruolo→agente in:"
echo ">>      $ORG_FILE"
echo ">>    e — se il repo ha aree separate nei PATH reali — la divisione team in:"
echo ">>      $TEAMS_FILE"
echo ">>    Popola i file dallo scouting: NON lasciarli ai placeholder. Se è un"
echo ">>    blocco unico, teams.md può restare a una sola voce."
echo ">> c) COMUNICA al founder, in poche righe: la rosa proposta e la mappa team."
echo ">>    I file sono editabili a mano: il founder integra/corregge dopo."
echo ">>"
echo ">> IMPORTANTE — sei tu a gestire le assunzioni: puoi ASSUMERE e LICENZIARE"
echo ">> chi vuoi in qualsiasi momento. L'organigramma è la TUA rosa, non un"
echo ">> vincolo: cambiala quando il lavoro lo richiede (nuovo agente più adatto,"
echo ">> agente sparito dall'inventario, area del repo che cresce). Ri-lancia"
echo ">> questo bootstrap quando lo stack cambia in modo sostanziale."
echo "############################################################"
