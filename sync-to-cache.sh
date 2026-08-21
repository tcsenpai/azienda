#!/usr/bin/env bash
# sync-to-cache.sh — sincronizza il source del plugin nella cache installata.
#
# Il plugin ATTIVO gira dalla cache (~/.claude/plugins/cache/...), non dal source.
# Dopo aver editato il source, esegui questo per rendere i cambi effettivi senza
# reinstallare. Copia SOLO i file del plugin: mai gli artefatti di sviluppo
# (.git, .mycelium, graft/, .claude/, AGENTS.md, .bank, .mcp.json, ...) che
# sporcherebbero la cache. Serve un restart della sessione per ricaricare hook.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VER="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
  "$SRC/.claude-plugin/plugin.json" | head -n1)"
DEST="$HOME/.claude/plugins/cache/azienda-market/azienda/$VER"

[ -n "$VER" ] || { echo "[sync] versione non trovata in plugin.json"; exit 1; }

echo "[sync] source: $SRC"
echo "[sync] versione: $VER → $DEST"

rm -rf "$DEST"
mkdir -p "$DEST"
# Solo i componenti del plugin (whitelist esplicita: niente artefatti dev).
cp -R "$SRC"/.claude-plugin "$SRC"/commands "$SRC"/agents "$SRC"/hooks "$SRC"/scripts "$DEST"/
# workflows/ (script dei Workflow, letti da PLUGIN_ROOT a runtime): opzionale.
[ -d "$SRC/workflows" ] && cp -R "$SRC/workflows" "$DEST"/
# doc di primo livello + TUTTI i template (*.template.md li leggono gli script a
# runtime da PLUGIN_ROOT: vanno tutti in cache, non solo policies).
for f in README.md REQUIREMENTS.md persona.md persona-brief.md roster.md; do
  [ -f "$SRC/$f" ] && cp "$SRC/$f" "$DEST/"
done
for t in "$SRC"/*.template.md; do
  [ -f "$t" ] && cp "$t" "$DEST/"
done
find "$DEST" -name '.DS_Store' -delete 2>/dev/null || true
find "$DEST" -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true

echo "[sync] fatto. Riavvia Claude Code per ricaricare hook/comandi."
echo "[sync] NB: il registro installed_plugins.json deve puntare a $VER"
echo "[sync]     (se hai bumpato la versione, aggiornalo o reinstalla con /plugin)."
