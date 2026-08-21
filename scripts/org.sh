#!/usr/bin/env bash
# org.sh — per-project org chart + azienda mode multi-team management.
#
# The org chart maps azienda ROLE → recommended agent, per-project and
# versionable (like policies.md). Teams ("depending on the code") are repo
# areas with a competence path-glob and their own org chart: when the Leader
# works on a file, the glob says WHICH team is responsible.
#
# Deliberately static and declarative: the assessment PROPOSES, the founder
# confirms and edits the files by hand. No auto-inference on every task
# (fragile and costly).
#
# Sub-actions ($1):
#   show               prints org chart + teams (or says they need to be initialized)
#   init               creates organigramma.md and teams.md from templates (no overwrite)
#   which <path>       says which team is responsible for a path (glob match)
#   agents             hands off to agents.sh (real inventory on disk)
#
# Does NOT write anything decided on its own beyond the initial templates:
# the files belong to the founder. Idempotent: init does not touch existing files.

set -uo pipefail

ACTION="${1:-show}"
VALUE="${2:-}"

# Absolute path of THIS script and of the plugin: deferred instructions to the
# Leader must use absolute paths, not ${CLAUDE_PLUGIN_ROOT} (empty in Bash).
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
  echo "[org] azienda mode NOT active in this project."
  echo "[org] org.sh only makes sense in azienda mode. Run first: /azienda on"
  exit 3
fi

# Reads the team lines from teams.md, ONLY from the "## Team" section (not
# from "## Organigramma per team", which has different `:` lines). Line
# format: "- <name> : <glob>[, <glob>...]". Returns "name<TAB>glob" lines
# (one per glob).
parse_teams() {
  [ -f "$TEAMS_FILE" ] || return 0
  # awk: inside the "## Team" section (up to the next ## heading), emits the
  # "- name : glob" lines. Deliberately excludes "## Organigramma per team".
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

# Extracts the ROSTER (org chart) of a specific team from the
# "## Organigramma per team" section → heading "### <team>". Emits the real
# role lines (excluding the "(inherits...)" placeholders). Empty if the team
# has no override → the caller falls back to the project org chart.
team_roster() {
  local team="$1"
  [ -f "$TEAMS_FILE" ] || return 0
  awk -v team="$team" '
    # enters the override section only after "## Organigramma per team"
    /^##[[:space:]]/ {
      insec = ($0 ~ /Organigramma per team/) ? 1 : 0
      inteam = 0
      next
    }
    insec && /^###[[:space:]]/ {
      # team name after "### "
      h = $0; sub(/^###[[:space:]]+/, "", h)
      gsub(/[[:space:]]+$/, "", h)
      inteam = (h == team) ? 1 : 0
      next
    }
    insec && inteam && /^[[:space:]]*-[[:space:]]/ {
      # skip the inheritance placeholders
      if ($0 ~ /eredita/) next
      print
    }
  ' "$TEAMS_FILE" 2>/dev/null
}

# Prints the roster responsible for a team: team override if it exists,
# otherwise the project org chart. $1 = team name.
print_roster_for_team() {
  local team="$1" roster
  roster="$(team_roster "$team")"
  if [ -n "$roster" ]; then
    echo "   Roster of team '$team' (override in teams.md):"
    printf '%s\n' "$roster" | sed 's/^/     /'
  elif [ -f "$ORG_FILE" ]; then
    echo "   Roster: inherited from the project org chart ($ORG_FILE):"
    # only the role lines from the "## Figure e agenti" section (not "## Note" etc.)
    awk '
      /^##[[:space:]]/ { insec = ($0 ~ /Figure e agenti/) ? 1 : 0; next }
      insec && /^[[:space:]]*-[[:space:]]/ { print }
    ' "$ORG_FILE" 2>/dev/null | grep -vi 'aggiungi qui' | sed 's/^/     /'
  else
    echo "   Roster: no override and no organigramma.md — create it with /azienda-org."
  fi
}

# robust glob-vs-path matching in bash. In bash `[[ == ]]` with `*` does NOT
# cross `/`, so we don't rely on a plain case: we treat the `/**` and `/*`
# suffixes as PREFIX matches (the team's area = everything under that folder),
# and patterns like `*.ext` also on the basename (extension at any depth).
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
  # simple glob (e.g. dir/file.txt) — direct match (no crossing /)
  # shellcheck disable=SC2053
  [[ "$path" == $glob ]] && return 0
  # *.ext → matches the extension at any depth (on the basename)
  case "$glob" in
    \*.*) [[ "${path##*/}" == $glob ]] && return 0 ;;
  esac
  return 1
}

case "$ACTION" in
  show)
    echo "[org] Project: $PROJECT_DIR"
    echo
    if [ -f "$ORG_FILE" ]; then
      echo "=== Organigramma ($ORG_FILE) ==="
      cat "$ORG_FILE"
    else
      echo "[org] No org chart: create it with /azienda-org (init)."
    fi
    echo
    if [ -f "$TEAMS_FILE" ]; then
      echo "=== Team ($TEAMS_FILE) ==="
      cat "$TEAMS_FILE"
    else
      echo "[org] No teams file: monorepo/single team. To define multiple teams: /azienda-org."
    fi
    echo
    echo ">> ISTRUZIONE: above is the project's org chart and team map."
    echo ">> Use them to pick agents when orchestrating. The REAL inventory of"
    echo ">> agents on disk (to validate they still exist) is given by:"
    echo ">>   bash $SCRIPT_DIR/agents.sh"
    ;;

  init)
    mkdir -p "$STATE_DIR"
    created=0
    if [ -f "$ORG_FILE" ]; then
      echo "[org] organigramma.md already present: not touching it."
    elif [ -f "$ORG_TEMPLATE" ]; then
      _p=$(basename "$PROJECT_DIR" | sed 's/[&|]/\\&/g')
      sed "s|{{PROGETTO}}|$_p|g" "$ORG_TEMPLATE" > "$ORG_FILE"
      echo "[org] CREATED: $ORG_FILE (from template)"
      created=1
    else
      # missing template (e.g. incomplete plugin cache): do NOT stay silent.
      echo "[org] WARNING: org chart template not found ($ORG_TEMPLATE)."
      echo "[org]   The cached plugin might be incomplete. Update the plugin"
      echo "[org]   (/plugin update azienda) or reinstall. You can create it by hand: see"
      echo "[org]   the format in $PLUGIN_ROOT/organigramma.template.md if present."
    fi
    if [ -f "$TEAMS_FILE" ]; then
      echo "[org] teams.md already present: not touching it."
    elif [ -f "$TEAMS_TEMPLATE" ]; then
      _p=$(basename "$PROJECT_DIR" | sed 's/[&|]/\\&/g')
      sed "s|{{PROGETTO}}|$_p|g" "$TEAMS_TEMPLATE" > "$TEAMS_FILE"
      echo "[org] CREATED: $TEAMS_FILE (from template)"
      created=1
    else
      echo "[org] WARNING: teams template not found ($TEAMS_TEMPLATE)."
      echo "[org]   The cached plugin might be incomplete (update/reinstall)."
    fi
    echo
    if [ "$created" = 1 ]; then
      echo ">> ISTRUZIONE: the files are seeded from templates. Do a stack"
      echo ">> assessment (bash $SCRIPT_DIR/assess.sh) and a real-agents assessment"
      echo ">> (bash $SCRIPT_DIR/agents.sh), then PROPOSE roles→agents and a team"
      echo ">> split based on the repo's paths to the founder. Write in the files"
      echo ">> ONLY what they confirm. Don't invent teams unsupported by the structure."
    else
      echo ">> ISTRUZIONE: the files already existed; show them to the founder"
      echo ">> (/azienda-org show) and propose changes only if requested."
    fi
    ;;

  which)
    [ -n "$VALUE" ] || { echo "[org] usage: org.sh which <path>"; exit 1; }
    if [ ! -f "$TEAMS_FILE" ]; then
      echo "[org] No teams.md: single team. '$VALUE' → single team (project org chart)."
      print_roster_for_team "__nessuno__"   # no override → shows project org chart
      exit 0
    fi
    # Collect the matching teams (dedup: multiple globs of the same team count as 1).
    matched=""
    while IFS=$'\t' read -r tname tglob; do
      [ -n "$tname" ] || continue
      if path_matches_glob "$VALUE" "$tglob"; then
        case " $matched " in
          *" $tname "*) : ;;                       # already seen
          *) matched="$matched $tname"
             echo "[org] '$VALUE' → team: $tname (glob: $tglob)" ;;
        esac
      fi
    done < <(parse_teams)
    matched="$(printf '%s' "$matched" | sed 's/^[[:space:]]*//')"
    if [ -z "$matched" ]; then
      echo "[org] '$VALUE' → no specific team matches; use the project org chart (default)."
      print_roster_for_team "__nessuno__"
    else
      # print the roster of each responsible team
      for t in $matched; do
        echo "[org] --- roster responsible for '$t' ---"
        print_roster_for_team "$t"
      done
    fi
    ;;

  roster)
    # roster by team NAME (direct path for /azienda-riunione team=X).
    [ -n "$VALUE" ] || { echo "[org] usage: org.sh roster <team-name>"; exit 1; }
    echo "[org] Roster responsible for team '$VALUE':"
    print_roster_for_team "$VALUE"
    ;;

  agents)
    exec bash "$SCRIPT_DIR/agents.sh"
    ;;

  office)
    # "azienda view": static office map from org chart/teams.
    # Passes the remaining args (ansi|svg|tsv, --heat, --drift, --no-color).
    shift 2>/dev/null || true
    exec bash "$SCRIPT_DIR/office.sh" "$@"
    ;;

  *)
    echo "[org] Invalid sub-action: '$ACTION' (show|init|which <path>|roster <team>|agents|office)"
    exit 1
    ;;
esac
