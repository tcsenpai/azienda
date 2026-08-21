#!/usr/bin/env bash
# update.sh — migra lo stato per-progetto (./.claude/azienda/) al nuovo schema.
# Idempotente e non distruttivo: crea/aggiunge solo ciò che manca, non tocca
# mai policies.md, ledger.md, memory/, vault/.
#
# NON aggiorna il plugin: la cache (~/.claude/plugins/cache/...) è gestita da
# Claude Code. Per quello: /plugin update azienda (o reinstall dal marketplace).

set -euo pipefail

# --- Risoluzione radice progetto (deve combaciare con toggle.sh/session_start.sh) ---
resolve_project_dir() {
  if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "${CLAUDE_PROJECT_DIR:-}" ]; then
    printf '%s' "$CLAUDE_PROJECT_DIR"
    return
  fi
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
STATE_DIR="$PROJECT_DIR/.claude/azienda"
STATE_FILE="$STATE_DIR/state.json"
TRACKING_FILE="$STATE_DIR/tracking"

# --- Versione con cui stiamo girando (= versione installata: giriamo dalla cache) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
RUNNING_VER="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
  "$PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null | head -n1)"

echo "[update] Plugin azienda in esecuzione: v${RUNNING_VER:-sconosciuta} ($PLUGIN_ROOT)"
echo "[update] NOTA: questo comando NON aggiorna il plugin stesso. Se il"
echo "[update] marketplace ha una versione più nuova, usa: /plugin update azienda"
echo

# --- Migrazione stato per-progetto ---
if [ ! -f "$STATE_FILE" ]; then
  echo "[update] Nessuno stato azienda in $PROJECT_DIR — niente da migrare."
  echo "[update] (Per iniziare: /azienda on)"
  echo
  echo ">> ISTRUZIONE: riporta al founder che non c'era nulla da migrare."
  exit 0
fi

echo "[update] Progetto: $PROJECT_DIR"
CHANGED=0

# 1) tracking: da chiave legacy in state.json → file condiviso
if [ ! -f "$TRACKING_FILE" ]; then
  legacy=""
  if command -v python3 >/dev/null 2>&1; then
    legacy="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("tracking") or "")' "$STATE_FILE" 2>/dev/null || true)"
  else
    legacy="$(sed -n 's/.*"tracking"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$STATE_FILE" | head -n1)"
  fi
  if [ -n "$legacy" ]; then
    printf '%s\n' "$legacy" > "$TRACKING_FILE"
    echo "[update] MIGRATO: tracking '$legacy' da state.json → $TRACKING_FILE"
    echo "[update]          (la chiave legacy in state.json resta: innocua, il file vince)"
    CHANGED=1
  fi
  # nessun legacy e nessun file → non inventiamo un default: lo fa /azienda on
fi

# 2) .gitignore: deve escludere lo state.json personale
GI="$STATE_DIR/.gitignore"
if [ ! -f "$GI" ]; then
  printf 'state.json\n' > "$GI"
  echo "[update] CREATO: $GI (esclude state.json personale)"
  CHANGED=1
elif ! grep -qx 'state.json' "$GI"; then
  printf 'state.json\n' >> "$GI"
  echo "[update] AGGIORNATO: aggiunta 'state.json' a $GI"
  CHANGED=1
fi

# 3) contatori audit: sessions / last_audit_session (nuove chiavi, default 0)
if command -v python3 >/dev/null 2>&1; then
  added="$(python3 - "$STATE_FILE" <<'PY'
import json,sys,os
path=sys.argv[1]
try: d=json.load(open(path))
except Exception: d={}
added=[k for k in ("sessions","last_audit_session") if k not in d]
for k in added: d[k]=0
if added:
    # scrittura atomica (coerente con toggle.sh/audit.sh)
    tmp=path+".tmp"
    with open(tmp,'w') as f: json.dump(d,f,indent=2); f.write("\n")
    os.replace(tmp,path)
print(",".join(added))
PY
)"
  if [ -n "$added" ]; then
    echo "[update] AGGIORNATO: state.json — chiavi inizializzate a 0: $added"
    CHANGED=1
  fi
else
  echo "[update] (python3 assente: salto l'init dei contatori audit — gli script li trattano comunque come 0)"
fi

echo
if [ "$CHANGED" = "1" ]; then
  echo "[update] Migrazione completata. Non toccati: policies.md, ledger.md, memory/, vault/."
else
  echo "[update] Già al nuovo schema: nessuna modifica necessaria."
fi
echo
echo ">> ISTRUZIONE: riporta al founder in poche righe cosa è stato migrato"
echo ">> (o che era già tutto aggiornato) e ricordagli che l'update del plugin"
echo ">> stesso si fa con /plugin update azienda."
