# Contributing to azienda

Thanks for your interest. This plugin comes from real-world use and stays
deliberately **lean**: before adding something, ask yourself if it's really
needed (see _Philosophy_).

## How to propose a change

1. **Open an issue first** if the change isn't trivial: describe the concrete
   problem (not the abstract solution). A real use case is worth more than a
   hypothetical feature.
2. **Fork + dedicated branch** (`fix/...`, `feat/...`).
3. **Edit the source**, not the cache. The active plugin runs from
   `~/.claude/plugins/cache/...`: while developing, after editing, sync with
   `./sync-to-cache.sh` and **restart** the Claude Code session to reload
   hooks and commands.
4. **Test** whatever you touch (see below).
5. **Open the PR**, explaining the _why_ as well as the _what_.

## Structure (what lives where)

| Folder / file             | What it contains                                          |
|----------------------------|------------------------------------------------------------|
| `.claude-plugin/`          | `plugin.json` (manifest) + `marketplace.json`               |
| `commands/`                | the `/azienda*` slash commands                              |
| `agents/`                  | the subagents (`luogotenente`, `quartiermastro`)             |
| `hooks/`                   | `hooks.json` (registers `SessionStart`)                     |
| `scripts/`                 | the bash logic (state, onboard, org, meeting, memory…)      |
| `workflows/`               | Workflow scripts (e.g. the meeting)                          |
| `*.template.md`            | templates copied into projects at runtime                    |
| `persona*.md`, `roster.md` | the Leader's persona and the agent-selection method          |

## Style rules

- **Bash**: `set -uo pipefail` (or `-euo` where it makes sense), no mandatory
  external dependencies. Every external tool (`myc`, `graft`, MCP…) is
  **optional**: the script must degrade without it, never fail because it's
  missing.
- **Paths**: scripts resolve the project root with the same
  `resolve_project_dir` function (`$CLAUDE_PROJECT_DIR` → walking up to
  `state.json` → git root → `$PWD`). Reuse it, don't reinvent it.
- **Gating**: commands that only make sense with azienda mode active must gate
  and exit with a non-zero code + a clear message if it's OFF.
- **Idempotence**: `init`/`update` must not overwrite user files. They add,
  never destroy.
- **No secrets** committed: point to where they live (env, Bitwarden), never
  the value.

## Tests

There's no framework: tests are targeted **runnable checks**.

- Syntax of every touched script: `bash -n scripts/<file>.sh`.
- For a script with an azienda gate: verify it's **OFF** (must exit non-zero
  with a message) as well as **ON** (create a fake `state.json`
  `{"active":true}` in a temp dir with `CLAUDE_PROJECT_DIR` pointed there).
- For Workflows: `node --check workflows/<file>.workflow.js`.

A green test only counts if it actually **executed** the code: make sure the
ON case really reaches the branch you're checking, not just stopping at the
gate.

## Doc-consistency hook (dev-tool, optional)

`dev/stop-check-docs.sh` is a **dev-tool** (not part of the distributed
plugin): a Claude **Stop** hook that, at the end of a turn — **only if you're
developing this repo** (identity verified against the `tcsenpai/azienda`
remote) and you have uncommitted changes to commands/scripts/agents/workflows/
persona or docs — **reminds Claude** to reread `README.md` and
`OPTIONALS.md` and check their **prose** for consistency before committing.

The script is versioned (in the repo); the **wiring** is local to your clone
(`.claude/settings.json`, not versioned). To enable it, add a Stop block to
your `.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [
      { "hooks": [ { "type": "command",
        "command": "bash \"${CLAUDE_PROJECT_DIR:-.}/dev/stop-check-docs.sh\"" } ] }
    ]
  }
}
```

(If you already have other Stop hooks, just add the object inside the array,
don't overwrite.) The remote gate makes sure it never fires in any other
repo, even one that happens to have `README.md` + `OPTIONALS.md`.

## Versioning

Functional change → bump `version` in **both** `plugin.json` and
`marketplace.json` (they must match). Semantics: patch for fixes, minor for
backward-compatible features.

## Philosophy (why the plugin stays lean)

The guiding principle is **reuse-first**: before building, check what's
already installed (skill, command, subagent, CLI). New features are the
_glue_ between existing pieces, not re-implementations. If a PR adds a lot of
code to do what an already-installed tool does, it will be asked to be
trimmed down.
