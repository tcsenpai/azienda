#!/usr/bin/env bash
# org.sh — organigramma per-progetto + gestione multi-team della modalità azienda.
#
# L'organigramma mappa RUOLO aziendale → agente consigliato, per-progetto e
# versionabile (come policies.md). I team ("a seconda del codice") sono aree del
# repo con un path-glob di competenza e un proprio organigramma: quando il Leader
# lavora su un file, il glob dice QUALE team è competente.
#
# Statico e dichiarativo di proposito: l'assessment PROPONE, il founder conferma
# ed edita i file a mano. Nessuna auto-inferenza a ogni task (fragile e costosa).
#
# Sub-azioni ($1):
#   show               stampa organigramma + team (o dice che vanno inizializzati)
#   init               crea organigramma.md e teams.md dai template (non sovrascrive)
#   which <path>       dice quale team è competente per un path (match sui glob)
#   agents             passa la mano ad agents.sh (inventario reale su disco)
#
# NON scrive nulla di deciso da solo oltre ai template iniziali: i file sono del
# founder. Idempotente: init non tocca file già esistenti.

set -uo pipefail

ACTION="${1:-show}"
VALUE="${2:-}"

# Path assoluto di QUESTO script e del plugin: le istruzioni differite al Leader
# devono usare percorsi assoluti, non ${CLAUDE_PLUGIN_ROOT} (vuoto nelle Bash).
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
ORG_TEMPLATE="$PLUGIN_ROOT/organigramma.template.md"
TEAMS_TEMPLATE="$PLUGIN_ROOT/teams.template.md"

is_active() {
  [ -f "$STATE_FILE" ] || return 1
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys;sys.exit(0 if json.load(open(sys.argv[1])).get("active") is True else 1)' "$STATE_FILE" 2>/dev/null && return 0
    return 1
  fi
  grep -Eq '"active"[[:space:]]*:[[:space:]]*true' "$STATE_FILE"
}

if ! is_active; then
  echo "[org] Modalità azienda NON attiva in questo progetto."
  echo "[org] org.sh ha senso solo in modalità azienda. Fai prima: /azienda on"
  exit 3
fi

# Legge le righe team dal teams.md, SOLO dalla sezione "## Team" (non da
# "## Organigramma per team", che ha righe con `:` diverse). Formato riga:
# "- <nome> : <glob>[, <glob>...]". Ritorna righe "nome<TAB>glob" (una per glob).
parse_teams() {
  [ -f "$TEAMS_FILE" ] || return 0
  # awk: dentro la sezione "## Team" (fino al prossimo heading ##), emette le
  # righe "- nome : glob". Esclude di proposito "## Organigramma per team".
  awk '
    /^##[[:space:]]/ {
      insec = ($0 ~ /^##[[:space:]]+Team([[:space:]]|$)/) ? 1 : 0
      next
    }
    insec && /^[[:space:]]*-[[:space:]]+[^:]+:/ { print }
  ' "$TEAMS_FILE" 2>/dev/null | while IFS= read -r line; do
    body="${line#*- }"
    name="${body%%:*}"
    globs="${body#*:}"
    name="$(printf '%s' "$name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    IFS=',' read -ra arr <<< "$globs"
    for g in "${arr[@]}"; do
      g="$(printf '%s' "$g" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
      [ -n "$g" ] && printf '%s\t%s\n' "$name" "$g"
    done
  done
}

# Estrae la ROSA (organigramma) di uno specifico team dalla sezione
# "## Organigramma per team" → heading "### <team>". Emette le righe-ruolo
# reali (escludendo i placeholder "(eredita...)"). Vuoto se il team non ha
# override → il chiamante fa fallback all'organigramma di progetto.
team_roster() {
  local team="$1"
  [ -f "$TEAMS_FILE" ] || return 0
  awk -v team="$team" '
    # entra nella sezione override solo dopo "## Organigramma per team"
    /^##[[:space:]]/ {
      insec = ($0 ~ /Organigramma per team/) ? 1 : 0
      inteam = 0
      next
    }
    insec && /^###[[:space:]]/ {
      # nome del team dopo "### "
      h = $0; sub(/^###[[:space:]]+/, "", h)
      gsub(/[[:space:]]+$/, "", h)
      inteam = (h == team) ? 1 : 0
      next
    }
    insec && inteam && /^[[:space:]]*-[[:space:]]/ {
      # salta i placeholder di ereditarietà
      if ($0 ~ /eredita/) next
      print
    }
  ' "$TEAMS_FILE" 2>/dev/null
}

# Stampa la rosa competente per un team: override del team se esiste,
# altrimenti l'organigramma di progetto. $1 = nome team.
print_roster_for_team() {
  local team="$1" roster
  roster="$(team_roster "$team")"
  if [ -n "$roster" ]; then
    echo "   Rosa del team '$team' (override in teams.md):"
    printf '%s\n' "$roster" | sed 's/^/     /'
  elif [ -f "$ORG_FILE" ]; then
    echo "   Rosa: eredita dall'organigramma di progetto ($ORG_FILE):"
    # solo le righe-ruolo della sezione "## Figure e agenti" (non "## Note" ecc.)
    awk '
      /^##[[:space:]]/ { insec = ($0 ~ /Figure e agenti/) ? 1 : 0; next }
      insec && /^[[:space:]]*-[[:space:]]/ { print }
    ' "$ORG_FILE" 2>/dev/null | grep -vi 'aggiungi qui' | sed 's/^/     /'
  else
    echo "   Rosa: nessun override e nessun organigramma.md — crealo con /azienda-org."
  fi
}

# match glob-vs-path robusto in bash. In bash `[[ == ]]` con `*` NON attraversa
# i `/`, quindi non ci affidiamo a un semplice case: trattiamo i suffissi `/**`
# e `/*` come match di PREFISSO (l'area del team = tutto sotto quella cartella),
# e i pattern tipo `*.ext` anche sul basename (estensione a qualsiasi profondità).
path_matches_glob() {
  local path="$1" glob="$2"
  case "$glob" in
    */\*\*)
      local pre="${glob%/\*\*}"
      [[ "$path" == "$pre"/* || "$path" == "$pre" ]] && return 0 ;;
    */\*)
      local pre="${glob%/\*}"
      [[ "$path" == "$pre"/* ]] && return 0 ;;
  esac
  # glob semplice (es. dir/file.txt) — match diretto (no attraversamento /)
  # shellcheck disable=SC2053
  [[ "$path" == $glob ]] && return 0
  # *.ext → matcha l'estensione a qualsiasi profondità (sul basename)
  case "$glob" in
    \*.*) [[ "${path##*/}" == $glob ]] && return 0 ;;
  esac
  return 1
}

case "$ACTION" in
  show)
    echo "[org] Progetto: $PROJECT_DIR"
    echo
    if [ -f "$ORG_FILE" ]; then
      echo "=== Organigramma ($ORG_FILE) ==="
      cat "$ORG_FILE"
    else
      echo "[org] Nessun organigramma: crealo con /azienda-org (init)."
    fi
    echo
    if [ -f "$TEAMS_FILE" ]; then
      echo "=== Team ($TEAMS_FILE) ==="
      cat "$TEAMS_FILE"
    else
      echo "[org] Nessun file team: monorepo/team singolo. Per definire più team: /azienda-org."
    fi
    echo
    echo ">> ISTRUZIONE: sopra c'è l'organigramma e la mappa dei team del progetto."
    echo ">> Usali per scegliere gli agenti quando orchestri. L'inventario REALE"
    echo ">> degli agenti su disco (per validare che esistano ancora) è dato da:"
    echo ">>   bash $SCRIPT_DIR/agents.sh"
    ;;

  init)
    mkdir -p "$STATE_DIR"
    created=0
    if [ -f "$ORG_FILE" ]; then
      echo "[org] organigramma.md già presente: non lo tocco."
    elif [ -f "$ORG_TEMPLATE" ]; then
      _p=$(basename "$PROJECT_DIR" | sed 's/[&|]/\\&/g')
      sed "s|{{PROGETTO}}|$_p|g" "$ORG_TEMPLATE" > "$ORG_FILE"
      echo "[org] CREATO: $ORG_FILE (dal template)"
      created=1
    else
      # template mancante (es. cache del plugin incompleta): NON restare muto.
      echo "[org] ATTENZIONE: template organigramma non trovato ($ORG_TEMPLATE)."
      echo "[org]   Il plugin in cache potrebbe essere incompleto. Aggiorna il plugin"
      echo "[org]   (/plugin update azienda) o reinstalla. Puoi crearlo a mano: vedi il"
      echo "[org]   formato in $PLUGIN_ROOT/organigramma.template.md se presente."
    fi
    if [ -f "$TEAMS_FILE" ]; then
      echo "[org] teams.md già presente: non lo tocco."
    elif [ -f "$TEAMS_TEMPLATE" ]; then
      _p=$(basename "$PROJECT_DIR" | sed 's/[&|]/\\&/g')
      sed "s|{{PROGETTO}}|$_p|g" "$TEAMS_TEMPLATE" > "$TEAMS_FILE"
      echo "[org] CREATO: $TEAMS_FILE (dal template)"
      created=1
    else
      echo "[org] ATTENZIONE: template teams non trovato ($TEAMS_TEMPLATE)."
      echo "[org]   Il plugin in cache potrebbe essere incompleto (aggiorna/reinstalla)."
    fi
    echo
    if [ "$created" = 1 ]; then
      echo ">> ISTRUZIONE: i file sono seed da template. Fai un assessment dello"
      echo ">> stack (bash $SCRIPT_DIR/assess.sh) e degli agenti reali"
      echo ">> (bash $SCRIPT_DIR/agents.sh), poi PROPONI al founder ruoli→agenti e"
      echo ">> una divisione in team basata sui path del repo. Scrivi nei file SOLO"
      echo ">> ciò che conferma. Non inventare team non supportati dalla struttura."
    else
      echo ">> ISTRUZIONE: i file esistevano già; mostrali al founder (/azienda-org show)"
      echo ">> e proponi modifiche solo se richiesto."
    fi
    ;;

  which)
    [ -n "$VALUE" ] || { echo "[org] uso: org.sh which <path>"; exit 1; }
    if [ ! -f "$TEAMS_FILE" ]; then
      echo "[org] Nessun teams.md: team singolo. '$VALUE' → team unico (organigramma di progetto)."
      print_roster_for_team "__nessuno__"   # nessun override → mostra organigramma di progetto
      exit 0
    fi
    # Raccogli i team che matchano (dedup: più glob dello stesso team contano 1).
    matched=""
    while IFS=$'\t' read -r tname tglob; do
      [ -n "$tname" ] || continue
      if path_matches_glob "$VALUE" "$tglob"; then
        case " $matched " in
          *" $tname "*) : ;;                       # già visto
          *) matched="$matched $tname"
             echo "[org] '$VALUE' → team: $tname (glob: $tglob)" ;;
        esac
      fi
    done < <(parse_teams)
    matched="$(printf '%s' "$matched" | sed 's/^[[:space:]]*//')"
    if [ -z "$matched" ]; then
      echo "[org] '$VALUE' → nessun team specifico matcha; usa l'organigramma di progetto (default)."
      print_roster_for_team "__nessuno__"
    else
      # stampa la rosa di ciascun team competente
      for t in $matched; do
        echo "[org] --- rosa competente per '$t' ---"
        print_roster_for_team "$t"
      done
    fi
    ;;

  roster)
    # rosa per NOME team (via diretta per /azienda-riunione team=X).
    [ -n "$VALUE" ] || { echo "[org] uso: org.sh roster <nome-team>"; exit 1; }
    echo "[org] Rosa competente per il team '$VALUE':"
    print_roster_for_team "$VALUE"
    ;;

  agents)
    exec bash "$SCRIPT_DIR/agents.sh"
    ;;

  office)
    # "visione dell'azienda": mappa-ufficio statica da organigramma/teams.
    # Passa gli argomenti restanti (ansi|svg|tsv, --heat, --drift, --no-color).
    shift 2>/dev/null || true
    exec bash "$SCRIPT_DIR/office.sh" "$@"
    ;;

  *)
    echo "[org] Sub-azione non valida: '$ACTION' (show|init|which <path>|roster <team>|agents|office)"
    exit 1
    ;;
esac
