---
description: Audit of the Leader's compliance with the project's policies (policy-drift, on-demand)
argument-hint: (none)
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/audit.sh *)
---

## Facts for the audit

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/audit.sh report`

## What to do now

Above are the facts and instructions for the compliance audit. It's not
automatic: it's YOU (the Leader) who judges your own work against the stated
policies. Proceed as follows:

1. Read `./.claude/azienda/policies.md`.
2. Go back over recent work and compare it against those rules: bans
   respected, tracking updated, escalations followed, and above all — did you
   REUSE what already exists (skill/command/agents/graft/myc/codedb) or built
   from scratch? If from scratch, was it a real gap not covered by anything?
3. Write a dated block to `./.claude/azienda/ledger.md` (APPEND, never
   overwrite): OK adherences, drift found with the reason, conscious overrides.
   Be honest — the ledger is for you, not for looking good.
4. If a drift is actually a new, valid pattern, PROPOSE to the user that they
   amend `policies.md`; don't modify it on your own initiative.
5. Once you've written the ledger, record the audit by running the command
   `bash …/scripts/audit.sh done` **with the ABSOLUTE path the script
   printed above** (the `bash /…/audit.sh done` line). Do NOT use
   `${CLAUDE_PLUGIN_ROOT}`: in the shell of your Bash calls it's empty, so
   that path wouldn't resolve.
6. Report to the founder in a few lines: what was aligned, what drifted, what
   you propose to change.

Note: the audit is **on-demand**. The periodic reminder ("N sessions have passed")
is OPT-IN and off by default. If the founder wants it, enable it with
`touch ./.claude/azienda/audit-nudge.on` (remove the file to turn it off).
