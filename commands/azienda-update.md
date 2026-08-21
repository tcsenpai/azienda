---
description: Migra lo stato per-progetto della modalità azienda al nuovo schema (idempotente, non distruttivo)
argument-hint: (nessuno)
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/update.sh *)
---

## Esito della migrazione

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/update.sh`

## Cosa fare adesso

Sopra c'è l'esito della migrazione dello stato per-progetto. Segui l'istruzione
finale dello script: riassumi al founder cosa è cambiato (o che era già tutto
in ordine).

Limiti onesti di questo comando:
- Migra SOLO `./.claude/azienda/` (tracking, .gitignore, contatori audit).
- NON aggiorna il plugin installato: la cache è gestita da Claude Code.
  Per la versione nuova del plugin: `/plugin update azienda` (o reinstall
  da `/plugin` → marketplace azienda-market).
- Non tocca mai `policies.md`, `ledger.md`, `memory/`, `vault/`.
