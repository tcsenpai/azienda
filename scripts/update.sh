#!/usr/bin/env bash
# update.sh — migrates the per-project state (./.claude/azienda/) to the new schema.
# Idempotent and non-destructive: only creates/adds what's missing, never
# touches policies.md, ledger.md, memory/, vault/.
#
# Does NOT update the plugin: the cache (~/.claude/plugins/cache/...) is
# managed by Claude Code. For that: /plugin update azienda (or reinstall from the marketplace).

set -euo pipefail

# --- Project root resolution (must match toggle.sh/session_start.sh) ---
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

# --- Version we're running (= installed version: we run from the cache) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
RUNNING_VER="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
  "$PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null | head -n1)"

echo "[update] azienda plugin running: v${RUNNING_VER:-unknown} ($PLUGIN_ROOT)"
echo "[update] NOTE: this command does NOT update the plugin itself. If the"
echo "[update] marketplace has a newer version, use: /plugin update azienda"
echo

# --- Per-project state migration ---
if [ ! -f "$STATE_FILE" ]; then
  echo "[update] No azienda state in $PROJECT_DIR — nothing to migrate."
  echo "[update] (To start: /azienda on)"
  echo
  echo ">> ISTRUZIONE: report to the founder that there was nothing to migrate."
  exit 0
fi

echo "[update] Project: $PROJECT_DIR"
CHANGED=0

# 1) tracking: from legacy key in state.json → shared file
if [ ! -f "$TRACKING_FILE" ]; then
  legacy=""
  if command -v python3 >/dev/null 2>&1; then
    legacy="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("tracking") or "")' "$STATE_FILE" 2>/dev/null || true)"
  else
    legacy="$(sed -n 's/.*"tracking"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$STATE_FILE" | head -n1)"
  fi
  if [ -n "$legacy" ]; then
    printf '%s\n' "$legacy" > "$TRACKING_FILE"
    echo "[update] MIGRATED: tracking '$legacy' from state.json → $TRACKING_FILE"
    echo "[update]          (the legacy key in state.json remains: harmless, the file wins)"
    CHANGED=1
  fi
  # no legacy and no file → we don't invent a default: /azienda on does that
fi

# 2) .gitignore: must exclude the personal state.json
GI="$STATE_DIR/.gitignore"
if [ ! -f "$GI" ]; then
  printf 'state.json\n' > "$GI"
  echo "[update] CREATED: $GI (excludes personal state.json)"
  CHANGED=1
elif ! grep -qx 'state.json' "$GI"; then
  printf 'state.json\n' >> "$GI"
  echo "[update] UPDATED: added 'state.json' to $GI"
  CHANGED=1
fi

# 3) audit counters: sessions / last_audit_session (new keys, default 0)
if command -v python3 >/dev/null 2>&1; then
  added="$(python3 - "$STATE_FILE" <<'PY'
import json,sys,os
path=sys.argv[1]
try: d=json.load(open(path))
except Exception: d={}
added=[k for k in ("sessions","last_audit_session") if k not in d]
for k in added: d[k]=0
if added:
    # atomic write (consistent with toggle.sh/audit.sh)
    tmp=path+".tmp"
    with open(tmp,'w') as f: json.dump(d,f,indent=2); f.write("\n")
    os.replace(tmp,path)
print(",".join(added))
PY
)"
  if [ -n "$added" ]; then
    echo "[update] UPDATED: state.json — keys initialized to 0: $added"
    CHANGED=1
  fi
else
  echo "[update] (python3 absent: skipping audit counter init — the scripts treat them as 0 anyway)"
fi

echo
if [ "$CHANGED" = "1" ]; then
  echo "[update] Migration completed. Not touched: policies.md, ledger.md, memory/, vault/."
else
  echo "[update] Already on the new schema: no changes needed."
fi
echo
echo ">> ISTRUZIONE: report to the founder in a few lines what was migrated"
echo ">> (or that everything was already up to date) and remind them that"
echo ">> updating the plugin itself is done with /plugin update azienda."
