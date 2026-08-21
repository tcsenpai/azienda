#!/usr/bin/env bash
# agents.sh — inventario degli agenti disponibili ORA per l'orchestrazione.
#
# Il parco agenti cambia (plugin, agenti aggiunti/rimossi). Questo dà al leader
# una visione d'insieme aggiornata: nome + prima riga di description, per fonte.
# Non è esaustivo dei subagent built-in dell'harness (quelli li conosci dal
# contesto di sessione) — copre gli agenti su disco, che sono i più volatili.

set -uo pipefail

print_dir() {
  local label="$1" dir="$2"
  [ -d "$dir" ] || return 0
  local found=0
  for f in "$dir"/*.md; do
    [ -f "$f" ] || continue
    found=1
    local name desc
    name="$(basename "$f" .md)"
    # description dalla frontmatter YAML, altrimenti prima riga non vuota
    desc="$(sed -n 's/^description:[[:space:]]*//p' "$f" | head -n1)"
    [ -n "$desc" ] || desc="$(grep -m1 -v '^[[:space:]]*$' "$f" 2>/dev/null)"
    printf '  %-28s %s\n' "$name" "${desc:0:90}"
  done
  [ "$found" = 1 ] && echo "  (fonte: $label — $dir)" && echo
}

echo "=== Agenti disponibili su disco (visione d'insieme) ==="
echo

print_dir "utente" "$HOME/.claude/agents"

# Agenti dai plugin installati (cache)
if [ -d "$HOME/.claude/plugins/cache" ]; then
  while IFS= read -r d; do
    print_dir "plugin" "$d"
  done < <(find "$HOME/.claude/plugins/cache" -type d -name agents 2>/dev/null)
fi

# Agenti a livello progetto
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "$CLAUDE_PROJECT_DIR/.claude/agents" ]; then
  print_dir "progetto" "$CLAUDE_PROJECT_DIR/.claude/agents"
elif top="$(git rev-parse --show-toplevel 2>/dev/null)" && [ -d "$top/.claude/agents" ]; then
  print_dir "progetto" "$top/.claude/agents"
fi

echo ">> NB: oltre a questi, l'harness espone subagent built-in (li vedi nel"
echo ">> contesto di sessione). Scegli l'agente sul parco REALE di adesso; il"
echo ">> roster del plugin (roster.md) è solo una guida di partenza."
