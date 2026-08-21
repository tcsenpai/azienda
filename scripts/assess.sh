#!/usr/bin/env bash
# assess.sh — raw repo assessment to populate the policies.
# Gathers facts (stack, services, tests, structure); draws NO conclusions:
# it's the leader (Claude) who interprets them and asks the user questions.

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

echo "[assess] Project: $P"
echo

echo "## Detected manifests / stack"
for m in package.json bun.lockb bun.lock pnpm-lock.yaml yarn.lock \
         pyproject.toml requirements.txt uv.lock Pipfile \
         Cargo.toml go.mod pom.xml build.gradle composer.json \
         Gemfile deno.json; do
  [ -f "$P/$m" ] && echo "  - $m"
done
echo

echo "## Services / infra"
for s in docker-compose.yml docker-compose.yaml compose.yml Dockerfile \
         Makefile .env.example; do
  [ -f "$P/$s" ] && echo "  - $s"
done
echo

echo "## Tests"
# common test directories and files
find "$P" -maxdepth 3 \( -type d -name test -o -type d -name tests \
  -o -type d -name __tests__ -o -type d -name spec \) 2>/dev/null \
  | grep -v node_modules | head -5 | sed 's/^/  - /'
ls "$P"/*.test.* "$P"/*_test.* 2>/dev/null | head -3 | sed 's/^/  - /'
echo

echo "## Top-level structure"
ls -1 "$P" 2>/dev/null | grep -vE '^(node_modules|\.git|target|dist|build|\.venv)$' | head -20 | sed 's/^/  - /'
echo

echo "## README (first lines, if present)"
for r in README.md README readme.md; do
  [ -f "$P/$r" ] && { grep -m5 -v '^[[:space:]]*$' "$P/$r" | sed 's/^/  | /'; break; }
done
echo

echo "## Available code-intelligence tools"
CODE_INTEL=0
if command -v graft >/dev/null 2>&1; then
  if [ -f "$P/graft/INDEX.md" ] || [ -d "$P/graft-out" ] || [ -d "$P/graft" ]; then
    echo "  - graft: PRESENT and repo INDEXED → use \`graft ask/map/skeleton\` for the structural assessment"
    CODE_INTEL=1
  else
    echo "  - graft: present but repo NOT indexed (indexable if needed)"
  fi
fi
# codedb is an MCP: its presence shows up via mcp__codedb__* tools in session.
echo "  - codedb: if you see \`mcp__codedb__*\` tools in session, use them (outline/search/context)"
echo "  - semantic-codemapper: skill available as fallback for the semantic map"
[ "$CODE_INTEL" = 0 ] && echo "  - (no graft index ready: best-effort assessment on the facts above)"
echo

echo ">> ISTRUZIONE: these are the repo's raw FACTS. If it's indicated above that"
echo ">> graft (indexed) or codedb are available, USE THEM as first-class support"
echo ">> for a structural assessment (architecture, modules, hubs) deeper than"
echo ">> this list; otherwise best-effort on the facts above."
echo ">> Then infer the stack, the project's nature and its services, and propose"
echo ">> concrete values to the user for the policies sections (stack, services,"
echo ">> tests, etc.) by asking targeted questions. Write in the policies ONLY"
echo ">> what the user confirms. Don't invent constraints unsupported by the facts."
