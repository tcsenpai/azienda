<!-- FORMAT (read by /azienda-mappa): under "## Figure e agenti" write roles as
     a LIST `- <role> → <agent> [| fallback: <alt>]` OR as a TABLE
     `| Ruolo | Agente |`. Both work. Outside these two formats, the map
     doesn't see the rows (and /azienda-mappa warns if the section is empty). -->
# Organigramma — {{PROGETTO}}

> Map of company ROLE → recommended agent for this project. Versionable
> (shared with the team via git), editable by hand. It's the ROSTER the
> Leader draws from when orchestrating: it's not a rigid constraint — if the
> ideal agent no longer exists (check with `agents.sh`), fall back.
>
> The REAL inventory of on-disk agents is given by the plugin's
> `scripts/agents.sh`. Here you only write the intent MAP: which figure this
> repo needs and which agent covers it best RIGHT NOW.

## Figure e agenti

Fill in with the roles this project actually uses. Format per line:
`- <company role> → <recommended agent> [| fallback: <alt>]`

- Technical Leader / orchestrator → (you, the main session)
- Confined execution (edit/refactor in the repo) → luogotenente | fallback: general-purpose
- On-disk tooling inventory → quartiermastro
- …add here the project's figures (backend, frontend, UX, QA, security,
  devops, performance, review, debug, docs, release) → chosen agent | fallback

## Note

- A role without a dedicated agent uses the fallback (`luogotenente` or
  `general-purpose`), it's not a gap that must be forcibly filled.
- Cost routing: mechanical → light agents; analysis/edit → mid tier;
  reasoning/synthesis/adversarial review → top tier. Never the premium tier
  on mechanical work.
