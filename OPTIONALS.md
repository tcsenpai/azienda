# Optional dependencies

The `azienda` plugin works **without any** of these: every integration is
detected at runtime and **degrades silently** if the tool is missing (never an
error). But if you install them, the plugin uses them automatically — they're
already wired into the code. Here's what each one unlocks and how to install
it.

How the plugin detects them:
- **CLI on disk** (`myc`, `graft`, `bw`, `python3`): via `command -v`.
- **User skill** (`obsidian-memory`): via a file in `~/.claude/skills/...`.
- **Session MCP** (`hindsight`, `codedb`, `graft`): visible only to the Leader
  in-session (the `mcp__*` tools), not to the scripts.

---

## mycelium (`myc`) — task tracking

**What it unlocks:** `/azienda-onboard` uses mycelium as the task-tracking
backend if `myc` is installed (otherwise it creates a local Markdown vault).
Meeting action items end up there.

**Install:** it's a single-binary Rust CLI.

```bash
# needs a Rust toolchain (rustup)
cargo install --git https://github.com/tcsenpai/mycelium
# verify
myc --version
```

Without `myc`: tracking uses `./.claude/azienda/vault/TASKS.md`. No loss of
functionality, just a different backend.

---

## graft — code intelligence (structural assessment)

**What it unlocks:** `/azienda-bootstrap` and `/azienda-onboard` run a deeper
repo assessment (architecture, modules, hubs) using graft if the repo is
**indexed**, instead of a plain file listing.

**Install** (CLI + repo indexing):

```bash
# install the graft CLI (see its repo for the current method)
# then, in the project root where you'll use azienda:
graft build          # builds the graph (graft/ folder, git-ignored)
```

graft also exposes MCP tools (`mcp__graft__*`): if you configure the MCP
server in Claude Code, the Leader uses them directly. Without graft:
best-effort assessment on raw repo facts.

---

## codedb — code intelligence (MCP)

**What it unlocks:** an alternative/complementary structural assessment to
graft (`outline`, `search`, `context`). It's an **MCP server**: the Leader
uses it if it sees the `mcp__codedb__*` tools in session.

**Install:** configure the codedb MCP server in Claude Code (see codedb's
docs). It's not a package detectable via `command -v`: its presence is
session-only. Without it: falls back to graft, or best-effort assessment.

---

## Long-term memory: hindsight + obsidian-memory

**What it unlocks:** the **promotion** of durable knowledge (decisions, the
quartermaster's inventory, lessons) to persistent cross-session memory. See
the _Memory (two levels)_ section of the README. The plugin writes to
**both** channels if present; if one is missing it uses the other; if both
are missing, it stays with local memory (`scripts/memory.sh note`).

**hindsight** — it's an **MCP server**. The Leader uses it if it sees the
`mcp__hindsight__*` tools in session (retain into the `coding-<repo>` bank).
Configure the hindsight MCP server in Claude Code.

**obsidian-memory** — it's a **user skill**. The plugin detects it if
`~/.claude/skills/obsidian-memory/scripts/recall.sh` exists. Install the
skill in your `~/.claude/skills/`.

Without either: memory stays local to the project
(`./.claude/azienda/memory/`), versionable but not cross-project.

---

## Bitwarden CLI (`bw`) — secrets

**What it unlocks:** when the persona needs to **read** a secret on the fly,
if `bw` is installed it's the preferred channel (via the `/bitwarden-cli`
skill), instead of env vars or the manager indicated in the policies.

**Install:**

```bash
# npm
npm install -g @bitwarden/cli
# or Homebrew
brew install bitwarden-cli
# verify
bw --version
```

Without `bw`: env vars or the manager indicated by the project's policies are
used instead. The plugin never writes secrets in plaintext, with or without
Bitwarden.

---

## python3 — robust state parsing + office map

**What it unlocks:** (1) scripts read `state.json` with `python3` when
available (reliable JSON parsing), falling back to `grep` otherwise; (2)
`/azienda-mappa` uses `python3` for pixel-art rendering (ANSI and SVG) —
without it, the map degrades to a simple text view (the SVG requires
`python3`). It's almost always already present on development systems — no
need to install it specifically.

---

## Summary

| Dep               | Type          | Unlocks                                  | Without →                         |
|--------------------|---------------|--------------------------------------------|--------------------------------------|
| `myc` (mycelium)   | CLI           | task tracking via mycelium                 | local Markdown vault                 |
| graft              | CLI + MCP     | structural repo assessment                 | best-effort assessment               |
| codedb             | MCP           | structural assessment (alt.)               | graft / best-effort                  |
| hindsight          | MCP           | long-term memory (channel 1)               | obsidian / local                     |
| obsidian-memory    | user skill    | long-term memory (channel 2)               | hindsight / local                    |
| `bw` (Bitwarden)   | CLI           | on-the-fly secret reading                  | env var / policy-defined manager     |
| `python3`          | CLI           | robust JSON parsing of state               | grep fallback                        |
