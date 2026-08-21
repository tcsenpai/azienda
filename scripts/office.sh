#!/usr/bin/env bash
# office.sh — "visione dell'azienda": una mappa-ufficio (stile Gather.town, ma
# STATICA) generata da organigramma.md (ruolo→agente) e teams.md (aree→stanze).
#
# Un solo PARSER → due RENDERER → un LAYER opzionale:
#   parse    organigramma.md + teams.md  →  TSV (team \t ruolo \t agente)
#   ansi     scena ANSI nel terminale (default, zero-dep bash; Python se c'è)
#   svg      file .svg self-contained (zero-dep: SVG è testo)
#   layer    (opt-in) heat-stanza da git + badge drift agente non su disco
#
# Gate: ha senso solo in modalità azienda attiva. Degrada SEMPRE: senza git il
# layer è neutro; senza python3 l'ANSI usa un fallback testuale semplice.
#
# Sub-azioni ($1):
#   ansi | svg [out.svg] | tsv          (default: ansi)
# Flag:
#   --heat        colora le stanze per attività git recente (opt-in)
#   --no-color    ANSI senza colori (o rispetta NO_COLOR / pipe non-tty)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

# --- args -----------------------------------------------------------------
ACTION="ansi"
OUT=""
HEAT=0
NOCOLOR=0
DRIFT=0
HIGHLIGHT=""
for a in "$@"; do
  case "$a" in
    ansi|svg|tsv) ACTION="$a" ;;
    --heat) HEAT=1 ;;
    --drift) DRIFT=1 ;;
    --no-color) NOCOLOR=1 ;;
    --highlight=*) HIGHLIGHT="${a#--highlight=}" ;;
    *.svg) OUT="$a" ;;
    *) : ;;
  esac
done
[ -n "${NO_COLOR:-}" ] && NOCOLOR=1
[ -t 1 ] || NOCOLOR=1   # pipe / file → niente ANSI

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

is_active() {
  [ -f "$STATE_FILE" ] || return 1
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys;sys.exit(0 if json.load(open(sys.argv[1])).get("active") is True else 1)' "$STATE_FILE" 2>/dev/null && return 0
    return 1
  fi
  grep -Eq '"active"[[:space:]]*:[[:space:]]*true' "$STATE_FILE"
}

if ! is_active; then
  echo "[office] Modalità azienda NON attiva in questo progetto."
  echo "[office] La visione dell'azienda ha senso solo in modalità azienda. Fai prima: /azienda on"
  exit 3
fi

# ==========================================================================
# PARSER — organigramma.md + teams.md → TSV (team \t ruolo \t agente \t glob)
# Lenient: ignora righe malformate/placeholder invece di rompere. È qui che
# vive la correttezza (rischio portante dall'assessment).
# ==========================================================================

# Ruoli dall'organigramma di progetto. Accetta DUE formati sotto la sezione
# "## Figure e agenti":
#   LISTA:    - <ruolo> → <agente> [| fallback: <alt>]   (→ o ->)
#   TABELLA:  | <ruolo> | <agente> |                       (salta header e ---)
# Esclude placeholder del template ("(sei tu", "aggiungi qui", "…").
# Se la sezione esiste ma nessuna riga è parsabile → warning su stderr (diag).
parse_roles() {
  [ -f "$ORG_FILE" ] || return 0
  awk -v section="Figure e agenti" -v sep="arrow" -v label="Figure e agenti" \
      -f "$SCRIPT_DIR/office_parse.awk" "$ORG_FILE"
}

# Team dalla sezione "## Team" (una riga per team, glob accorpate). Riusa la
# logica di org.sh. Ritorna "team \t glob1,glob2".
parse_teams() {
  [ -f "$TEAMS_FILE" ] || return 0
  # section regex: "Team" ma NON "Organigramma per team" (il parser matcha il
  # titolo dopo "## "; passiamo un pattern ancorato).
  awk -v section="^Team([[:space:]]|$)" -v sep="colon" -v label="Team" \
      -f "$SCRIPT_DIR/office_parse.awk" "$TEAMS_FILE"
}

# heat di un team: commit recenti (90g) sulle sue glob. 0 se git assente o
# nessuna glob. Bucket 0/1/2 (cold/warm/hot). MAI fallisce.
team_heat() {
  local globs="$1"
  [ "$HEAT" = 1 ] || { echo 0; return; }
  command -v git >/dev/null 2>&1 || { echo 0; return; }
  git -C "$PROJECT_DIR" rev-parse --git-dir >/dev/null 2>&1 || { echo 0; return; }
  [ -n "$globs" ] || { echo 0; return; }
  # split glob su virgola, passa come pathspec
  local IFS=','; local arr=($globs); local n
  n="$(git -C "$PROJECT_DIR" log --since=90.days --oneline -- "${arr[@]}" 2>/dev/null | wc -l | tr -d ' ')"
  n="${n:-0}"
  if   [ "$n" -ge 6 ]; then echo 2
  elif [ "$n" -ge 1 ]; then echo 1
  else echo 0; fi
}

# drift: l'agente esiste come file su disco? (utente ~/.claude/agents, plugin
# cache, progetto). Vuoto/descrittivo → non è drift. Ritorna 1 se DRIFT.
# ATTENZIONE: rileva solo agenti-SU-DISCO mancanti; NON conosce i subagent
# built-in dell'harness (non sono file) → per non dare falsi positivi, il drift
# è OPT-IN (--drift). Senza flag, non si segnala mai drift.
agent_missing() {
  [ "$DRIFT" = 1 ] || return 1             # drift disattivato → mai drift
  local ag="$1"
  [ -n "$ag" ] || return 1                 # nessun agente nominato → non drift
  case "$ag" in general-purpose|Task|"") return 1 ;; esac  # built-in noti
  # cerca <ag>.md nelle sedi note
  local hit=0
  for d in "$HOME/.claude/agents" "$PROJECT_DIR/.claude/agents"; do
    [ -f "$d/$ag.md" ] && hit=1
  done
  if [ "$hit" = 0 ] && [ -d "$HOME/.claude/plugins/cache" ]; then
    find "$HOME/.claude/plugins/cache" -name "$ag.md" -path '*/agents/*' 2>/dev/null | grep -q . && hit=1
  fi
  [ "$hit" = 0 ]   # true (0) = missing
}

# Costruisce il modello: per ogni team, le sue righe-ruolo. Semplificazione
# lazy: TUTTI i ruoli dell'organigramma di progetto stanno in OGNI stanza-team?
# No — sarebbe rumore. Modello: una stanza "Azienda" con la rosa di progetto +
# una stanza per ogni team di teams.md (etichettata con le sue glob). Le persone
# vivono nella rosa di progetto; i team sono le AREE. Così la mappa mostra: la
# rosa (chi c'è) e le aree (i team) come stanze separate.
# ponytail: modello volutamente semplice; se servisse rosa-per-team, si legge
# l'override da teams.md come fa org.sh — deferred finché non serve.

emit_tsv() {
  # righe: TIPO \t nome \t agente|glob \t heat \t drift \t hl
  # TIPO=role → riga persona (agente, drift, hl); TIPO=team → stanza (heat)
  # hl=1 se il ruolo è in --highlight (match case-insensitive su substring).
  while IFS=$'\t' read -r role agent; do
    [ -n "$role" ] || continue
    local drift=0
    agent_missing "$agent" && drift=1
    local hl=0
    if [ -n "$HIGHLIGHT" ]; then
      local lc_role; lc_role="$(printf '%s' "$role" | tr '[:upper:]' '[:lower:]')"
      local IFS=','; for want in $HIGHLIGHT; do
        want="$(printf '%s' "$want" | tr '[:upper:]' '[:lower:]' | sed 's/^ *//;s/ *$//')"
        [ -n "$want" ] || continue
        case "$lc_role" in *"$want"*) hl=1 ;; esac
      done
    fi
    printf 'role\t%s\t%s\t0\t%s\t%s\n' "$role" "$agent" "$drift" "$hl"
  done < <(parse_roles)
  while IFS=$'\t' read -r tname globs; do
    [ -n "$tname" ] || continue
    local h; h="$(team_heat "$globs")"
    printf 'team\t%s\t%s\t%s\t0\t0\n' "$tname" "$globs" "$h"
  done < <(parse_teams)
}

# ==========================================================================
# RENDER — deleghiamo a Python3 (parsing/layout robusto). Se manca, fallback
# testuale semplice in bash. Il TSV è passato su stdin al renderer.
# ==========================================================================

render_python() {
  local mode="$1"   # ansi | svg
  emit_tsv | python3 "$SCRIPT_DIR/office_render.py" "$mode" "$NOCOLOR" "$(basename "$PROJECT_DIR")"
}

render_fallback_ansi() {
  # Nessun python: elenco raggruppato, comunque leggibile. Mai un errore.
  echo "== VISIONE AZIENDA: $(basename "$PROJECT_DIR") =="
  echo
  echo "-- Rosa (ruolo → agente) --"
  emit_tsv | awk -F'\t' '$1=="role"{ d=($5=="1")?"  [!drift]":""; printf "  • %s → %s%s\n", $2, ($3==""?"(fallback)":$3), d }'
  echo
  echo "-- Team / aree --"
  emit_tsv | awk -F'\t' '$1=="team"{ h=($4=="2")?"hot":($4=="1")?"warm":"cold"; printf "  ▢ %-16s %s  [%s]\n", $2, $3, h }'
  echo
  echo "(python3 assente: vista testuale. Con python3 avresti la mappa ANSI.)"
}

case "$ACTION" in
  tsv)
    emit_tsv
    ;;
  ansi)
    if command -v python3 >/dev/null 2>&1 && [ -f "$SCRIPT_DIR/office_render.py" ]; then
      render_python ansi
    else
      render_fallback_ansi
    fi
    ;;
  svg)
    command -v python3 >/dev/null 2>&1 && [ -f "$SCRIPT_DIR/office_render.py" ] || {
      echo "[office] SVG richiede python3 (assente). Usa: office.sh ansi"; exit 1; }
    if [ -n "$OUT" ]; then
      emit_tsv | python3 "$SCRIPT_DIR/office_render.py" svg 1 "$(basename "$PROJECT_DIR")" > "$OUT"
      echo "[office] SVG scritto in: $OUT"
    else
      emit_tsv | python3 "$SCRIPT_DIR/office_render.py" svg 1 "$(basename "$PROJECT_DIR")"
    fi
    ;;
  *)
    echo "[office] uso: office.sh ansi|svg [out.svg]|tsv  [--heat] [--no-color]"; exit 1
    ;;
esac
