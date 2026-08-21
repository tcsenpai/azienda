#!/usr/bin/env bash
# stop-check-docs.sh — hook CLAUDE su Stop: a fine turno, SE nel working tree ci
# sono modifiche non committate a file "documentabili" (comandi, script, agenti,
# persona, o i doc stessi), inietta un REMINDER a Claude di rileggere README.md e
# OPTIONALS.md e verificarne la coerenza PRIMA di committare.
#
# Perché Stop e non un git hook: un git hook è bash cieco (non rilegge la prosa).
# Questo hook parla a CLAUDE, che PUÒ usare il giudizio sulla coerenza dei doc —
# esattamente il pezzo che un check meccanico non copre.
#
# Scatta in QUALSIASI repo dove il plugin è attivo, quindi è progettato per essere
# INNOCUO fuori dal repo del plugin: se non esistono sia README.md sia OPTIONALS.md,
# non dice nulla. L'output su stdout viene iniettato nel contesto di Claude.

set -uo pipefail

# Root del repo corrente (dove Claude sta lavorando).
ROOT="$(git -C "${CLAUDE_PROJECT_DIR:-$PWD}" rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -n "$ROOT" ] || exit 0

# Innocuo fuori da un repo che ha QUESTA struttura di doc.
[ -f "$ROOT/README.md" ] || exit 0
[ -f "$ROOT/OPTIONALS.md" ] || exit 0

# Ci sono modifiche non committate a file documentabili? (staged o unstaged)
# Pattern: commands/, scripts/, agents/, persona*.md, README.md, OPTIONALS.md.
changed="$(git -C "$ROOT" status --porcelain 2>/dev/null \
  | grep -E '(^| )(commands/|scripts/|agents/|persona.*\.md|README\.md|OPTIONALS\.md)' \
  | grep -vE 'stop-check-docs\.sh' \
  || true)"

[ -n "$changed" ] || exit 0   # niente di rilevante toccato → silenzio

# Reminder iniettato nel contesto di Claude.
cat <<'EOF'
>> PROMEMORIA COERENZA DOC (hook Stop del plugin azienda):
>> Hai modifiche non committate a comandi/script/agenti/persona o ai doc. Prima
>> di committare, RILEGGI README.md e OPTIONALS.md e verifica che siano coerenti
>> con le modifiche: ogni tool opzionale wirato nel codice va documentato in
>> OPTIONALS.md, e i comandi/flussi nuovi vanno riflessi nel README. Se serve,
>> aggiornali ORA. (Questo controllo guarda la coerenza della PROSA, non solo la
>> presenza meccanica di un riferimento.)
EOF
exit 0
