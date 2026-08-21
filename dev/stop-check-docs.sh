#!/usr/bin/env bash
# dev/stop-check-docs.sh — DEV-TOOL, non parte del plugin distribuito.
#
# Hook CLAUDE su Stop, attivo SOLO in questo repo (identità verificata dal remote
# git). A fine turno, se ci sono modifiche non committate a file "documentabili"
# (comandi/script/agenti/persona o i doc), ricorda a Claude di rileggere README.md
# e OPTIONALS.md e verificarne la coerenza della PROSA prima di committare.
#
# NON è in hooks/hooks.json (quello va a tutti gli utenti del plugin): è un tool
# di SVILUPPO, collegato solo dal .claude/settings.json LOCALE di questo clone.
# Attivazione: vedi CONTRIBUTING.md → "Hook di coerenza doc".

set -uo pipefail

ROOT="$(git -C "${CLAUDE_PROJECT_DIR:-$PWD}" rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -n "$ROOT" ] || exit 0

# --- Gate di IDENTITÀ: siamo nel repo tcsenpai/azienda? ---------------------
# Univoco: il remote origin deve puntare al nostro repo. Così l'hook NON scatta
# in un altro plugin che per caso ha README.md + OPTIONALS.md.
remote="$(git -C "$ROOT" remote get-url origin 2>/dev/null || true)"
case "$remote" in
  *tcsenpai/azienda*|*tcsenpai/azienda.git) : ;;   # ok, è il nostro repo
  *) exit 0 ;;                                       # altro repo → silenzio
esac

# --- Modifiche non committate a file documentabili? ------------------------
changed="$(git -C "$ROOT" status --porcelain 2>/dev/null \
  | grep -E '(^| )(commands/|scripts/|agents/|workflows/|persona.*\.md|README\.md|OPTIONALS\.md)' \
  || true)"
[ -n "$changed" ] || exit 0   # niente di rilevante toccato → silenzio

cat <<'EOF'
>> PROMEMORIA COERENZA DOC (dev-hook di tcsenpai/azienda):
>> Hai modifiche non committate a comandi/script/agenti/workflow/persona o ai doc.
>> Prima di committare, RILEGGI README.md e OPTIONALS.md e verifica che siano
>> coerenti con le modifiche: ogni tool opzionale wirato nel codice va documentato
>> in OPTIONALS.md, e i comandi/flussi nuovi vanno riflessi nel README. Aggiornali
>> ORA se serve. (Controlla la coerenza della PROSA, non solo la presenza di un
>> riferimento.)
EOF
exit 0
