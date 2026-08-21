---
description: Attiva/disattiva/controlla la modalità azienda (persona Leader/CTO) per questo progetto
argument-hint: on|off|status
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/toggle.sh *)
---

## Gestore modalità azienda

Output del gestore di stato (scrive/legge `./.claude/azienda/state.json` sulla
radice del progetto ed emette la direttiva da applicare):

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/toggle.sh "$ARGUMENTS"`

## Cosa fare adesso

Sopra c'è l'output di `toggle.sh`. Contiene una riga `>> ISTRUZIONE:`. Esegui
quell'istruzione immediatamente e per il resto di questa sessione:

- Se ti dice di **assumere la persona**, diventa il Leader/CTO del founder ora
  (vedi il blocco DIRETTIVA sopra) e conferma in una riga.
- Se ti dice di **deporre la persona**, torna al comportamento di default e
  conferma in una riga.
- Se è uno **status**, riporta lo stato al founder senza cambiare comportamento.

Lo stato su disco è già stato aggiornato dallo script: `on`/`off` hanno effetto
sia in questa sessione (subito, via questa istruzione) sia nelle sessioni future
(via l'hook SessionStart che rilegge `state.json`).
