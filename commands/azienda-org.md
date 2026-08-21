---
description: Project org chart (role→agent) and multi-team management (code areas). Only with azienda mode ACTIVE.
argument-hint: (none) | init
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/toggle.sh *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/org.sh *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/agents.sh *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/assess.sh *)
---

## Gate modalità azienda

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/toggle.sh status | grep -E 'ATTIVA|DISATTIVA' | head -1`

## Org chart and teams

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/org.sh ${ARGUMENTS:-show}`

## What to do now

**First check the gate above.** If the line says `DISATTIVA`, azienda mode is
NOT active in this project: stop and tell the founder to run `/azienda on`
first. Do not proceed further.

If it's `ATTIVA`, above is the org chart (role→agent) and the project's team
map, or the outcome of `init`.

- **View (`show`, default):** report to the founder the roster of roles/agents
  and the team split, in a few lines. This is the ROSTER to draw from when you
  orchestrate — not a constraint: if an agent no longer exists (verify with
  `agents.sh`, absolute path printed above), use the fallback.

- **`init`:** created `organigramma.md` and `teams.md` from templates (without
  overwriting existing ones). Now, if you have the founder's consent:
  1. Gather facts about the stack and the real agents by running, with the
     ABSOLUTE path printed by the outputs above (NOT `${CLAUDE_PLUGIN_ROOT}`,
     empty in your Bash): `bash …/scripts/assess.sh` and `bash …/scripts/agents.sh`.
  2. From those facts PROPOSE to the founder: (a) a realistic role→agent map
     for this repo, (b) a team split based on the real PATHs (e.g.
     `frontend : apps/web/**`). Ask targeted questions.
  3. Write to `./.claude/azienda/organigramma.md` and `./.claude/azienda/teams.md`
     ONLY what the founder confirms. Do not invent teams unsupported by the
     repo's structure. The files are hand-editable: integrate, don't overwrite
     wholesale.

Multi-team note: when you work on a file, `bash …/scripts/org.sh which <path>`
tells you which team is responsible **and extracts its ROSTER** (the team's
org chart override if present, otherwise the project one). For a team's roster
by NAME (e.g. before a team meeting): `bash …/scripts/org.sh roster <team>`. If
the project is a single block, `teams.md` can stay with just one entry (or not
exist at all: then there's a single team using the project org chart).
