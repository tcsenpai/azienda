# Requirements — `azienda` plugin

Living document. Updated as the plugin evolves. `[x]` done, `[ ]` planned,
`(opt)` optional/nice-to-have.

## Core — company mode

- [x] Persistent, **per-project** "azienda mode" (state on disk, not session).
- [x] State file `./.claude/azienda/state.json` (`active`, `activated_at`) —
      personal, gitignored. Tracking backend lives in a separate shared file
      `./.claude/azienda/tracking` (see Onboarding).
- [x] `SessionStart` hook re-injects the persona when `active:true`.
- [x] `/azienda on|off|status` — dual effect (current session + future ones).
- [x] `on`/`off` preserve extra keys (e.g. `tracking`) — `off` never wipes config.
- [x] Project-root resolution: `$CLAUDE_PROJECT_DIR` → upward search for an
      existing `state.json` → git toplevel → `$PWD`.
- [x] Robust JSON parsing (python3 primary, grep/sed fallback).

## Persona — the Leader

- [x] Persona is a **leader/orchestrator**, not a lone executor: assembles and
      coordinates specialized agents, harmonizes results.
- [x] Founder name is configurable via `{{FOUNDER}}` + `$AZIENDA_FOUNDER`
      (default `Cris`).
- [x] Cost-based routing (mechanical→light, reasoning→premium).
- [x] Write-conflict handling via **git worktrees** (parallel writers isolated).
- [x] Awareness that the agent roster **changes over time**; take a live
      overview before orchestrating.

## Reuse-first principle

- [x] Standing rule: reuse existing tooling (graft, mycelium, codedb, skills,
      commands, subagents) before building anything new.
- [x] `quartiermastro` subagent — right hand that knows the current Claude Code
      config and advises what to reuse; consulted at task start and per feature.
- [x] `roster.md` — company-figure → recommended system agent map (+ fallbacks).
- [x] `scripts/agents.sh` — live on-disk agent inventory.

## Policies

- [x] Per-project `./.claude/azienda/policies.md` seeded from a template at first
      `/azienda on`; read by the persona every session.
- [x] Policies are a plain editable Markdown file — user may hand-edit anytime;
      the plugin never overwrites an existing one.
- [x] `.gitignore` in the state dir excludes `state.json` (personal), keeps
      `policies.md` / `vault/` shareable.

## Onboarding

- [x] `/azienda-onboard` — configures tracking backend.
- [x] Tracking: **mycelium** (`myc init` + `prime-agents`) if `myc` present,
      else **vault** (`./.claude/azienda/vault/TASKS.md`). Default follows env.
- [x] (opt) Repo **assessment** → policy population via targeted questions;
      writes only what the user confirms.
- [x] Assessment uses **graft/codedb** first-class when available, best-effort
      otherwise.
- [x] (opt) Offer to hand-refine policies at end of onboarding; never forced.

## Distribution / ops

- [x] Local marketplace (`azienda-market`), version bumped to `0.2.0`.
- [x] Active install runs from cache; source→cache sync documented.
- [ ] (opt) `myc`/graft version pinning or capability checks surfaced to user.
- [ ] (opt) `git init` offer when onboarding a non-git repo.

## Fable review fixes (2026-08-20)

- [x] `assess.sh` no longer runs via `!`-injection (was firing even on refusal);
      run via Bash only after consent.
- [x] `{{PROGETTO}}` expanded (basename) when seeding policies — was literal.
- [x] "Cris" no longer hardcoded in toggle.sh/azienda.md instructions.
- [x] Name collision resolved: persona is **Leader/CTO**, `luogotenente` names
      ONLY the executor subagent (README/toggle/command/plugin.json aligned).
- [x] `quartiermastro` no longer inventories MCP (it can't see session tools) —
      MCP is the Leader's job; subagent is `model: haiku`, disk-only.
- [x] Anti-ceremony threshold in persona: trivial tasks executed directly.
- [x] Reuse check made a verifiable report item, not just an exhortation.
- [x] Doctrine de-duplicated: template holds only project-specific slots.
- [x] `roster.md` slimmed to a selection method (no stale name list).
- [x] `tracking` moved to a shared `./.claude/azienda/tracking` file (team-shared
      via git); `state.json` stays personal (on/off only).
- [x] Root resolution: existing-state upward search now beats git toplevel
      (nested repo/submodule no longer hijacks the project root).

## Post-ADHD features (2026-08-20)

- [x] **Policy-drift audit** (`/azienda-audit`, on-demand): Leader compares its
      work against `policies.md`, writes a dated block to `ledger.md` (append),
      records reuse vs build-from-scratch. `scripts/audit.sh` (report/done/tick).
- [x] Periodic **nudge**: `session_start.sh` increments a `sessions` counter and
      can softly suggest an audit every N sessions (`AZIENDA_AUDIT_EVERY`, default 5).
      Never blocks. (Chosen over per-Stop hook to avoid the "stillicidio".)
      **Superseded below (Paperclip-reduction): the nudge is now OPT-IN, OFF by
      default; only the counter always advances.**
- [x] **Operational memory** (`scripts/memory.sh` recall/note): per-project
      lessons in `./.claude/azienda/memory/lessons.md` (local file, versionable)
      giving ephemeral subagents continuity. Suggests obsidian-memory as an
      optional cross-project search channel if installed. NOT hindsight.
- [x] **Bitwarden** (`bw`) as the preferred secret-read channel when installed
      (via `/bitwarden-cli` skill); always optional, degrades to env/other.
      quartiermastro detects `bw`; persona + policies template reference it.

### Rejected (ADHD)
- Context warehouse — redundant, codedb/graft already cover it.
- Process-level mechanisms (heartbeat/PID/quota) — the harness manages agents.

## Frictionless fixes (2026-08-20, post-scouting)

- [x] **Compact injection**: SessionStart injects `persona-brief.md` (~20 lines)
      instead of the full `persona.md` (~115). Full profile loaded only on
      explicit `/azienda on`, or read on-demand for real orchestration work.
      Cuts per-session context ~80%.
- [x] **Statusline indicator**: `~/.claude/statusline-command.sh` shows
      `AZI <tracking>` when azienda mode is active in the current project — so
      the user doesn't forget after the initial banner. Silent when off.
- [x] **Auto-tracking**: `/azienda on` sets a default tracking backend (mycelium
      if `myc` present, else vault) in the shared file WITHOUT invasive init —
      no second command needed. Explicit `/azienda-onboard` still does full init.

## Paperclip-reduction fixes (2026-08-20, post-scouting)

Design lens: "the Leader works in their office and knocks before interrupting
the user" — proactive at its own work, never invasive toward the user.

- [x] **Audit nudge → opt-in**: the periodic "N sessions since last audit"
      reminder is OFF by default. Counter still advances (so `/azienda-audit`
      knows the gap). Enable per-project with `touch .claude/azienda/audit-nudge.on`
      or `AZIENDA_AUDIT_NUDGE=on`.
- [x] **Anti-ceremony GATE** made structural, not a side note: persona (and
      brief) open with a binding gate — question / localized fix / single-file
      edit → execute directly, NO agents/worktree/recall/decomposition; orchestrate
      ONLY for large, multi-file, or multi-skill work. Concrete examples included.
      "When in doubt, execute directly."
- [x] **quartiermastro / memory recall subordinated to the gate**: consulted only
      when already orchestrating a task the gate classed as large — not "every
      non-trivial feature" judged by the model. For a direct fix, the Leader
      checks tool availability itself (`command -v`) without spawning a subagent.

## Update command (2026-08-20)

- [x] `/azienda-update` (`scripts/update.sh`): migrates OLD per-project state to
      the current schema — idempotent, non-destructive. Migrates legacy
      `tracking` (from state.json) to the shared file, creates the `.gitignore`,
      initializes `sessions`/`last_audit_session` counters. Never touches
      `policies.md`, `ledger.md`, `memory/`, `vault/`. Prints the running plugin
      version and is honest that the plugin binary itself updates via
      `/plugin update azienda`, not this command.

## Organigramma, multi-team & riunioni (2026-08-20, v0.3.0)

- [x] **Organigramma per-progetto** (`./.claude/azienda/organigramma.md`, seeded
      from `organigramma.template.md`): rosa ruolo→agente del progetto,
      versionabile e a mano. È la ROSA da cui il Leader pesca; non un vincolo.
      `roster.md` resta il METODO generico, l'organigramma è la mappa concreta.
- [x] **Multi-team "a seconda del codice"** (`./.claude/azienda/teams.md`, seeded
      from `teams.template.md`): aree del repo con path-glob di competenza + (opt)
      organigramma per team. **Statico/dichiarativo**: assessment PROPONE, founder
      conferma; nessuna auto-inferenza per task. `scripts/org.sh which <path>`
      dice quale team è competente per un file. Assente `teams.md` → team unico.
- [x] `scripts/org.sh` (show/init/which/roster/agents) + `/azienda-org [init]`.
      init non sovrascrive file esistenti (idempotente). Gate: script rifiuta
      (exit 3) se azienda OFF.
- [x] **Estrazione rosa per team**: `org.sh which <path>` e `org.sh roster <team>`
      estraggono l'organigramma competente — override del team dalla sezione
      "### <team>" di teams.md se presente, altrimenti fallback all'organigramma
      di progetto (sezione "## Figure e agenti"). Parsing section-aware (awk):
      i glob-team si leggono solo da "## Team", gli override solo da "## Organigramma
      per team"; i placeholder "(eredita…)" sono scartati; team multi-glob dedup.
- [x] **Riunione** (`/azienda-riunione [team=X] <topic>`, `scripts/riunione.sh`):
      dibattito SEQUENZIALE tra subagent in ruolo (pattern da production-meeting,
      tailored). **Solo se azienda ATTIVA** (gate hard, exit 3 se OFF). Partecipanti
      **scelti dal Leader** dalla rosa, **minimo 2** (sotto = rifiuto). 3 round
      (apertura/replica/finale) + early-exit; verbale via moderatore (opus) da
      `verbale.template.md`. Verbale in `./.claude/azienda/riunioni/<slug>-<data>/`;
      **action item riversati nel tracking** del progetto (mandatorio).
- [x] Nessun file agente temporaneo: personae in-memory (o `subagent_type` reale
      se l'agente esiste su disco). Zero cleanup, zero residui nel repo.
- [x] Wiring persona: sezione "Organigramma, team e riunioni" subordinata al GATE
      (valgono solo quando già si orchestra, non per un fix diretto).

## Open / ideas

- [ ] (opt) `quartiermastro` could emit a machine-readable capability map cached
      per session to avoid re-scanning.
- [ ] (opt) Migration helper: vault → mycelium once `myc` gets installed later.
- [ ] (opt) Team presets (named squads of agents) selectable per project.
