<!-- FORMAT (read by /azienda-mappa): under "## Team" write teams as a LIST
     `- <name> : <glob>[, <glob>]` OR as a TABLE `| Team | Glob |`. To have
     MEMBERS inside the team room in the map, give the team a roster below in
     "## Organigramma per team" → "### <team name>" with lines
     `- <role> → <agent>`. A team without a roster shows "(eredita rosa
     progetto)" in the map, not "(vuota)". -->
# Team — {{PROGETTO}}

> Divides the repo into TEAMs "by area of code": each team has an area of
> competence (path-glob) and — if needed — its own organigramma. When the
> Leader works on a file, the globs say WHICH team is competent.
>
> **Static and declarative**: you edit this file by hand, it's not
> auto-inferred on every task. `/azienda-org`'s assessment can PROPOSE an
> initial division based on the repo's real paths; you confirm. If the
> project is a single block (no separate areas), leave a single entry or
> delete this file: without `teams.md` there's a single team using the
> project's organigramma.

## Team

Format per line (one or more glob separated by comma after the colon):
`- <team name> : <glob>[, <glob>...]`

The globs are relative to the project root. `**` = any depth.
Example (adapt to your repo's REAL paths, these are only illustrative):

- frontend : apps/web/**, packages/ui/**
- backend  : services/**, apps/api/**
- contracts : contracts/**, *.sol

## Organigramma per team (optional)

If a team wants a different agent roster from the project's, declare it below
under a heading `### <team name>` (must match the name used in the Team
section above). Row format IDENTICAL to organigramma.md:
`- <company role> → <recommended agent> [| fallback: <alt>]`

A team WITHOUT a heading here (or with only comment lines) inherits the whole
roster from `organigramma.md`. `scripts/org.sh which <path>` automatically
extracts the competent team's roster (the team's override if present,
otherwise the project's).

### frontend
- (inherits from organigramma.md — delete this line and add real overrides)

### backend
- (inherits from organigramma.md — delete this line and add real overrides)

## Usage note for the Leader

- To find out which team covers a path: `bash scripts/org.sh which <path>`
  (absolute path printed by `/azienda-org`).
- A meeting can be convened for a specific team
  (`/azienda-riunione team=frontend "<topic>"`) or cross-team (default).
- A file that matches no glob → single team / project organigramma.
