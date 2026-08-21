---
description: View of the azienda — a static office map (Gather.town style) from org chart and teams. Only with azienda mode ACTIVE.
argument-hint: (none) | svg | --heat
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/toggle.sh *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/office.sh *)
---

## Gate modalità azienda

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/toggle.sh status | grep -E 'ATTIVA|DISATTIVA' | head -1`

## azienda map

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/office.sh ansi --no-color $ARGUMENTS`

## What to do now

**Check the gate.** If `DISATTIVA`, tell the founder to run `/azienda on` and
stop. If `ATTIVA`, above is the **view of the azienda**: a static office map
(rooms = teams, desks = role→agent) generated from `organigramma.md`
and `teams.md`.

Present it to the founder as-is. Usage notes:

- **Curated SVG** (to share/view in a browser): `office.sh svg
  ./.claude/azienda/riunioni/azienda.svg` (absolute plugin path printed
  above). Pixel-art with colored rooms, avatars, name-tags. Add `--open` to
  open it right away in the system viewer (macOS `open` / Linux `xdg-open`).
- **heat**: in the SVG map the heat gauge is **ON by default** (colors rooms
  by recent git activity, commits over the last 90 days on the team's globs) —
  degrades to neutral without git. `--no-heat` to turn it off. `cold/warm/hot`
  is a raw activity signal, **not** an importance signal (a stable team is
  cold, not dead). In ANSI it stays opt-in (`--heat`).
- **`--drift`**: marks with ⚠ the org chart's agents that no longer exist as
  files on disk. Note: it doesn't know about the harness's built-in
  subagents, so it's opt-in to avoid false positives.

If the org chart doesn't exist yet, create it first with `/azienda-bootstrap` or
`/azienda-org init`. The map is purely visual: no interactivity, no state
modified.
