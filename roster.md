# Roster — how to choose an agent

Choice guide (METHOD) for the Leader. The real agent pool changes per
machine/plugin, so there's NO name list here (it would go stale immediately):
the real inventory is dynamic.

> Note: this is the generic *method*. The concrete role→agent roster for a
> project lives in `./.claude/azienda/organigramma.md` (create/view it with
> `/azienda-org`), and code areas → teams in `./.claude/azienda/teams.md`.

## How to choose
1. **Real inventory, right now:** run `agents.sh` (in the azienda plugin's
   PLUGIN_ROOT, the absolute path the hook/`/azienda on` printed for you)
   (name + description of on-disk agents, by source). Or delegate the mapping
   to the `quartiermastro` subagent.
2. **Match on the need:** pick the agent whose description covers the
   workstream. Serious installations expose figures for backend, frontend,
   fullstack, UX, QA/test, security, devops, performance, refactoring, review,
   debug, research, docs, release — search by those competencies, not by a
   fixed name.
3. **Cost routing:** mechanical/data-gathering → light agents; analysis/edit
   → mid tier; complex reasoning/synthesis/adversarial review → top tier
   (never the premium tier on mechanical work).
4. **Fallback:** if the ideal agent is missing, use the closest one, or the
   confined subagent `luogotenente`, or `general-purpose`.

## Write-also conflicts → worktree (mandatory)
If two or more agents modify potentially conflicting files, assign them to
separate git worktrees (`git worktree add`), have each work in its own, then
you harmonize. Never two concurrent writes to the same file without isolation.
