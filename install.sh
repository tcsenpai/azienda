#!/usr/bin/env bash
# install.sh — helper d'installazione del plugin "azienda" per Claude Code.
#
# Claude Code installa i plugin da un "marketplace" e i comandi d'installazione
# sono SLASH COMMAND che girano DENTRO Claude Code (/plugin ...): uno script di
# shell non può eseguirli al posto tuo. Quello che questo script fa:
#   1. verifica i prerequisiti (git; e avvisa sui tool opzionali);
#   2. risolve il path assoluto di questo repo (serve al marketplace);
#   3. STAMPA i due comandi /plugin da incollare in Claude Code, già pronti.
#
# Uso:
#   ./install.sh            # da dentro il repo clonato
#   bash install.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

say()  { printf '%s\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }

say "== Installazione plugin 'azienda' =="
say

# --- 1. prerequisiti ---------------------------------------------------------
say "Prerequisiti:"
if command -v git >/dev/null 2>&1; then ok "git presente"; else
  warn "git non trovato — serve per clonare/aggiornare il repo."
fi

# Il marketplace.json deve esistere: senza, /plugin non trova il plugin.
if [ -f "$ROOT/.claude-plugin/marketplace.json" ]; then
  ok "marketplace.json presente"
else
  warn "manca .claude-plugin/marketplace.json — repo incompleto?"
fi
if [ -f "$ROOT/.claude-plugin/plugin.json" ]; then
  ok "plugin.json presente"
else
  warn "manca .claude-plugin/plugin.json — repo incompleto?"
fi

say
say "Tool OPZIONALI (il plugin degrada senza, ma con questi rende di più):"
for t in myc graft; do
  if command -v "$t" >/dev/null 2>&1; then ok "$t presente"; else warn "$t assente (opzionale)"; fi
done
say "  ! mycelium/hindsight/obsidian-memory/codedb: rilevati a runtime in sessione."
say "  → cosa sblocca ciascuna dep opzionale e come installarla: OPTIONALS.md"

# --- 2. path del marketplace -------------------------------------------------
say
say "Repo risolto in:"
say "  $ROOT"

# --- 3. comandi da incollare in Claude Code ----------------------------------
say
say "== Ora, DENTRO Claude Code, incolla questi due comandi: =="
say
printf '  \033[1m/plugin marketplace add %s\033[0m\n' "$ROOT"
printf '  \033[1m/plugin install azienda@azienda-market\033[0m\n'
say
say "Verifica con:  /plugin list"
say "Poi, in un repo qualsiasi:  /azienda on"
say
say "(Aggiornamento futuro: git pull qui, poi /plugin marketplace update azienda-market)"
