---
description: Migrates the per-project state of azienda mode to the new schema (idempotent, non-destructive)
argument-hint: (none)
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/update.sh *)
---

## Migration outcome

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/update.sh`

## What to do now

Above is the outcome of the per-project state migration. Follow the script's
final instruction: summarize for the founder what changed (or that everything
was already in order).

Honest limits of this command:
- It migrates ONLY `./.claude/azienda/` (tracking, .gitignore, audit counters).
- It does NOT update the installed plugin: the cache is managed by Claude Code.
  For the new plugin version: `/plugin update azienda` (or reinstall
  from `/plugin` → azienda-market marketplace).
- It never touches `policies.md`, `ledger.md`, `memory/`, `vault/`.
