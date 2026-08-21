---
description: Convene a company meeting — sequential debate between subagents in role, final minutes. Only with azienda mode ACTIVE.
argument-hint: [team=<nome>] <topic>
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/riunione.sh *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/org.sh *)
---

## Meeting context (gate + roster + tracking)

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/riunione.sh context`

## Procedure

**GATE — check the output above.** If it says "azienda mode NOT active"
(exit 3), STOP: tell the founder to run `/azienda on`. If it's ACTIVE, proceed.

The meeting is no longer orchestrated by hand turn-by-turn: a **workflow
executes** it in a single call (sequential debate, N rounds, moderator's
minutes, self-contained). You handle the JUDGMENT part — choosing who
participates — then launch the workflow and save what it returns.

### 1. Parsing the request
From `$ARGUMENTS`: the **topic** (if too vague for a useful debate, ask ONE
clarifying question first — meetings cost) and an optional **`team=<nome>`**
(meeting for that area; without it, it's cross-team).

### 2. Choose the participants (min 2 — BINDING)
YOU choose the roles from the roster above, based on the topic. **Minimum 2**:
below that it's not a meeting — either add more, or answer directly without
convening one.
- If `team=X`: draw from the restricted roster with `bash …/scripts/org.sh roster X`
  (absolute path printed above). Cross-team: use the project's organigramma.
- For each role: if an **agent on disk** exists with that name (visible via
  `org.sh agents`), pass it as `agentType` (no persona, respect its own).
  Otherwise write a 3-4 sentence **persona** (priorities, biases, what it contests).
- Cost routing: debaters in the mid tier; escalate only if the role requires
  heavy reasoning. The list's ORDER = speaking order.
- Scale: the workflow runs `speaker × round (+1 moderator)` agents in total
  (5 speakers × 3 rounds = 16). Keep it under ~15: if a large panel is needed,
  reduce speakers or rounds, don't bloat the meeting.

### 3. Run the workflow (ONE call)
Call the **Workflow** tool with `scriptPath` pointed at the plugin's versioned
script and `args` with the participants you chose:

- `scriptPath`: `${CLAUDE_PLUGIN_ROOT}/workflows/riunione.workflow.js`
  (use the ABSOLUTE path printed by the context above as `PLUGIN_ROOT`, not
  the variable: in your calls `${CLAUDE_PLUGIN_ROOT}` is empty.)
- `args`:
  ```json
  {
    "topic": "<the topic>",
    "lang": "<topic language, e.g. it>",
    "speakers": [
      { "role": "SRE",        "agentType": "devops-architect" },
      { "role": "Root-cause", "agentType": "root-cause-analyst" },
      { "role": "Backend",    "persona": "Owner of the actual code. Prioritizes concrete implementation cost; contests solutions that are elegant but expensive; speaks in terms of files and functions." }
    ]
  }
  ```
  Each speaker: `role` (required), then `agentType` (agent on disk) **or**
  `persona` (text). Optional per-speaker `model`. Default 3 rounds
  (Opening/Rebuttal/Final position) with implicit early-exit in the agents'
  behavior; for custom rounds pass `rounds: [{title, instruction}, …]`.

The workflow runs in the background and notifies you at the end. It returns
`{ topic, transcript, verbale }`. **Don't fabricate the result: wait for the
notification** and read the return value (from the run's journal if needed).

### 4. Delivery
- Create the folder: `bash …/scripts/riunione.sh mkdir <slug>` → prints
  `riunioni/<slug>-<data>/`.
- Write `transcript.md` (= `transcript` field) and `verbale.md` (= `verbale` field).
- **Pour the minutes' action items into the project's tracking** (backend
  indicated in the context: `myc task create …` or `./.claude/azienda/vault/TASKS.md`).
  MANDATORY: a meeting that leaves no tracked tasks is wasted ceremony.
- Present the founder with the minutes + the paths, densely. The transcript is worth reading.
