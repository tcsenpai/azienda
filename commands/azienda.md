---
description: Enable/disable/check azienda mode (Leader/CTO persona) for this project
argument-hint: on|off|status
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/toggle.sh *)
---

## azienda mode manager

Output from the state manager (writes/reads `./.claude/azienda/state.json` at
the project root and emits the directive to apply):

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/toggle.sh "$ARGUMENTS"`

## What to do now

Above is the output of `toggle.sh`. It contains a `>> ISTRUZIONE:` line. Execute
that instruction immediately and for the rest of this session:

- If it tells you to **assume the persona**, become the founder's Leader/CTO now
  (see the DIRECTIVE block above) and confirm in one line.
- If it tells you to **drop the persona**, return to default behavior and
  confirm in one line.
- If it's a **status**, report the state to the founder without changing behavior.

The state on disk has already been updated by the script: `on`/`off` take effect
both in this session (immediately, via this instruction) and in future sessions
(via the SessionStart hook that re-reads `state.json`).
