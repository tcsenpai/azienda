#!/usr/bin/env bash
# assess.sh — assessment grezzo del repo per popolare le policies.
# Raccoglie fatti (stack, servizi, test, struttura); NON conclude nulla:
# è il leader (Claude) a interpretarli e a porre le domande all'user.

set -uo pipefail

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

P="$(resolve_project_dir)"
cd "$P" || exit 1

echo "[assess] Progetto: $P"
echo

echo "## Manifest / stack rilevati"
for m in package.json bun.lockb bun.lock pnpm-lock.yaml yarn.lock \
         pyproject.toml requirements.txt uv.lock Pipfile \
         Cargo.toml go.mod pom.xml build.gradle composer.json \
         Gemfile deno.json; do
  [ -f "$P/$m" ] && echo "  - $m"
done
echo

echo "## Servizi / infra"
for s in docker-compose.yml docker-compose.yaml compose.yml Dockerfile \
         Makefile .env.example; do
  [ -f "$P/$s" ] && echo "  - $s"
done
echo

echo "## Test"
# directory e file di test comuni
find "$P" -maxdepth 3 \( -type d -name test -o -type d -name tests \
  -o -type d -name __tests__ -o -type d -name spec \) 2>/dev/null \
  | grep -v node_modules | head -5 | sed 's/^/  - /'
ls "$P"/*.test.* "$P"/*_test.* 2>/dev/null | head -3 | sed 's/^/  - /'
echo

echo "## Struttura di primo livello"
ls -1 "$P" 2>/dev/null | grep -vE '^(node_modules|\.git|target|dist|build|\.venv)$' | head -20 | sed 's/^/  - /'
echo

echo "## README (prime righe, se c'è)"
for r in README.md README readme.md; do
  [ -f "$P/$r" ] && { grep -m5 -v '^[[:space:]]*$' "$P/$r" | sed 's/^/  | /'; break; }
done
echo

echo "## Strumenti di code-intelligence disponibili"
CODE_INTEL=0
if command -v graft >/dev/null 2>&1; then
  if [ -f "$P/graft/INDEX.md" ] || [ -d "$P/graft-out" ] || [ -d "$P/graft" ]; then
    echo "  - graft: PRESENTE e repo INDICIZZATO → usa \`graft ask/map/skeleton\` per l'assessment strutturale"
    CODE_INTEL=1
  else
    echo "  - graft: presente ma repo NON indicizzato (indicizzabile se serve)"
  fi
fi
# codedb è un MCP: la sua presenza si vede dai tool mcp__codedb__* in sessione.
echo "  - codedb: se in sessione vedi tool \`mcp__codedb__*\`, usali (outline/search/context)"
echo "  - semantic-codemapper: skill disponibile come fallback per la mappa semantica"
[ "$CODE_INTEL" = 0 ] && echo "  - (nessun indice graft pronto: assessment best-effort sui fatti sopra)"
echo

echo ">> ISTRUZIONE: questi sono i FATTI grezzi del repo. Se sopra è indicato che"
echo ">> graft (indicizzato) o codedb sono disponibili, USALI come supporto"
echo ">> first-class per un assessment strutturale (architettura, moduli, hub)"
echo ">> più profondo di questa lista; altrimenti best-effort sui fatti sopra."
echo ">> Poi deduci stack, natura del progetto e servizi e proponi all'user"
echo ">> valori concreti per le sezioni delle policies (stack, servizi, test,"
echo ">> ecc.) ponendo domande mirate. Scrivi nelle policies SOLO ciò che l'user"
echo ">> conferma. Non inventare vincoli non supportati dai fatti."
