# azienda — persistent Leader mode for Claude Code

![license: MIT](https://img.shields.io/badge/license-MIT-green)

Plugin for [Claude Code](https://docs.anthropic.com/claude-code) that activates a
persistent, **per-project** **azienda mode**: Claude takes on the persona of the
founder's **Leader/CTO** — it doesn't do everything itself, it **orchestrates
specialized agents**, parallelizes independent work, and coordinates the
outcome. Heavy execution is delegated to subagents with a restricted toolset.
The mode survives across sessions until you turn it off.

Underlying philosophy: **reuse-first**. azienda reuses as much as possible of
what's already installed (graft, mycelium, codedb, skills, commands,
subagents) instead of reinventing it.

## Installation

Requires [Claude Code](https://docs.anthropic.com/claude-code). Everything else
(`myc`, `graft`, memory MCPs…) is **optional**: the plugin degrades gracefully
without it. What each optional dependency unlocks and how to install it is in
[OPTIONALS.md](OPTIONALS.md).

```bash
git clone https://github.com/tcsenpai/azienda.git
cd azienda
./install.sh          # checks the environment and prints the commands to paste
```

`install.sh` can't run the slash commands for you: it prints the two
ready-to-paste commands to run **inside Claude Code**:

```
/plugin marketplace add /absolute/path/to/azienda
/plugin install azienda@azienda-market
```

Verify with `/plugin list`. Then, in any repo: `/azienda on`.

To update later: `git pull` in the folder, then
`/plugin marketplace update azienda-market`.

## How persistence works

State does NOT live in the session (ephemeral). It lives on disk, **per
project**:

```
./.claude/azienda/state.json     →  { "active": true|false, "activated_at": "ISO8601" }
./.claude/azienda/policies.md    →  the project's company policies and workflow (editable)
./.claude/azienda/organigramma.md →  role→agent roster (from bootstrap; editable)
```

The project root is resolved as `$CLAUDE_PROJECT_DIR` → git repo root →
`$PWD`. This way the mode activates **only** in repos where you ran
`/azienda on`, and doesn't follow you elsewhere. A `SessionStart` hook rereads
the state on every startup: if `active:true`, it reinjects the persona.

## Commands

```
/azienda on|off|status            activate / deactivate / status (read from disk)
/azienda-bootstrap                automatic bootstrap: repo scouting + who to hire + org chart
/azienda-onboard                  configure tracking (mycelium|vault) + repo assessment → policy
/azienda-org [init]               role→agent org chart + multi-team management
/azienda-mappa [svg] [--heat]     office view: static office map (Gather.town style)
/azienda-riunione [team=X] <topic>  meeting: sequential debate between agents + minutes
/azienda-audit                    policy compliance audit (on-demand)
/azienda-update                   migrate per-project state to the new schema (idempotent)
```

`on`/`off` act on two fronts: they update the file on disk (for future
sessions, via hook) **and** inject/remove the persona in the current session.
No restart required.

## The typical flow

1. **`/azienda on`** in a repo → Claude becomes the Leader and reads the
   policies. If there's no org chart yet, it suggests the bootstrap.
2. **`/azienda-bootstrap`** → in one shot: stack scouting (using graft/codedb
   if present), an inventory of the agents actually available, and generation
   of the role→agent org chart. **The Leader decides who to hire** and can
   hire/fire whenever it wants: the org chart is its roster, not a constraint.
3. **You work** as usual: the Leader breaks down tasks and delegates to the
   right agents.
4. **`/azienda-riunione <topic>`** when a discussion is needed: a sequential
   debate between agents in role, run by a **Workflow** (self-contained),
   which wraps up with minutes and action items poured into the tracking
   system.

## The subagents

- **`luogotenente`** — confined executor (`Read, Grep, Glob, Bash, Edit, Write,
  TodoWrite`). No web, no spawning. The persona delegates concrete execution
  in the repo to it.
- **`quartiermastro`** — the Leader's right hand: maps the current Claude Code
  config (skills, commands, agents, MCP, CLI) and reports **what to reuse**
  before building from scratch. Read + Bash, no writes.

Neither of them sees session MCPs: only the Leader sees those.

## Office view (office map)

`/azienda-mappa` draws a **static office map** in Gather.town style from
`organigramma.md` and `teams.md`: desks are roles (role→agent), rooms are
teams. Purely graphical, no interactivity.

Each team room shows **its own roster** if the team has its own org chart (in
`teams.md`, section `## Organigramma per team` → `### <team>`); otherwise the
room says `(inherits project roster)`. The "Office · the Roster" room always
shows the project-wide roster.

- Default: **ANSI** scene in the terminal (zero-dep; with `python3` it's the
  pixel-art map, without it's a text-only view).
- `/azienda-mappa svg` → a self-contained pixel-art **SVG** file, openable in
  a browser.
- The **heat thermometer** (90-day git activity on the team's globs) is **ON
  by default in the SVG map** — `--no-heat` to turn it off; in ANSI it stays
  opt-in (`--heat`). `cold/warm/hot` is a raw activity signal, not one of
  importance. Degrades to neutral without git.
- `--open` (with `svg out.svg`) opens the file in the system viewer.
- `--drift` marks ⚠ agents no longer present on disk (opt-in: it doesn't know
  about the harness's built-ins).
- `--highlight=SRE,Review` highlights specific roles (e.g. meeting
  participants).

## Memory (two levels)

- **Local scratchpad** `./.claude/azienda/` — ephemeral: subagents write their
  working files here; operational lessons about the project live in
  `scripts/memory.sh` (`note`/`recall`).
- **Promotion to long-term memory** — only the Leader (the only one who sees
  MCPs): at key moments (meeting minutes, architectural decisions, the
  quartermaster's inventory, a lesson from a bug), it promotes durable
  knowledge to `hindsight` **and** `obsidian-memory` if present, otherwise to
  the local store. The checklist is printed by `scripts/memory.sh promote`.

## Per-project policy & workflow

On the first `/azienda on` in a repo, the plugin creates
`./.claude/azienda/policies.md` from a template: it's the operational source
of truth for **that** project (mission, priorities, rules of engagement,
workflow, prohibitions, definition of "done"). The persona reads it on
activation and at every session. Edit it freely.

## Onboarding and tracking

`/azienda-onboard` configures task tracking: **mycelium** (`myc`) if
installed, otherwise a **vault** (`./.claude/azienda/vault/TASKS.md`). The
choice ends up in `./.claude/azienda/tracking` (versionable, shared with the
team) and survives `off`.

## Configurable founder

The founder's name in the persona is the `{{FOUNDER}}` placeholder, expanded
at runtime with `$AZIENDA_FOUNDER` (default: `Cris`). Export the env var to
change it.

## Language

The plugin's sources are written in English, but the Leader **replies in the
language you normally use** with it (fallback: English) — Claude is already
multilingual, so nothing is translated at build time; the persona simply carries
an output-language directive. Write to it in Italian and it answers in Italian;
in French, French. To pin a language explicitly, set `$AZIENDA_LANG` (e.g. `it`,
`en`, `fr`) as an override. The name `azienda`, the `/azienda*` commands, and the
structural headings the scripts parse stay verbatim in every language — they're
identifiers, not prose.

## Development

The active plugin runs from the cache (`~/.claude/plugins/cache/...`), not
from source. After editing: `./sync-to-cache.sh`, then **restart the
session**. Details and rules in [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE) © 2026 Cris (tcsenpai)
