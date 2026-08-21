---
description: Automatic bootstrap of the azienda — repo scouting, hiring decisions, org chart generation. Only with azienda mode ACTIVE.
argument-hint: (none)
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/toggle.sh *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/bootstrap.sh *)
---

## Gate modalità azienda

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/toggle.sh status | grep -E 'ATTIVA|DISATTIVA' | head -1`

## Bootstrap

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/bootstrap.sh`

## What to do now

**First check the gate above.** If it says `DISATTIVA`, azienda mode is
NOT active: stop and tell the founder to run `/azienda on` first. Do not proceed.

If it's `ATTIVA`, above you have in one shot the repo scouting, the real agent
inventory, and the seeded org chart files, followed by an
`>> ISTRUZIONE AL LEADER (bootstrap):` block. **Execute it now:**

1. If the scouting flags graft (indexed) or codedb in session, USE THEM for a
   deeper structural assessment than a plain file list.
2. Work out which roles this repo REALLY needs (only the relevant ones) and
   map them onto the REAL agents from the inventory, with cost-aware routing.
3. Write the role→agent roster to `./.claude/azienda/organigramma.md` and, if
   the repo has separate areas in its real paths, the team split in `teams.md`.
   Populate them from the scouting — no placeholders. The founder edits them later.
4. Report the proposed roster and team map to the founder, in a few lines.

You're in charge of hiring: you can **hire and fire** as you see fit. The org
is your roster, not a constraint — change it whenever the work requires it.
Re-run `/azienda-bootstrap` if the stack changes substantially.
