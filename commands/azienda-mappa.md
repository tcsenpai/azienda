---
description: Visione dell'azienda — mappa-ufficio statica (stile Gather.town) da organigramma e team. Solo con modalità azienda ATTIVA.
argument-hint: (nessuno) | svg | --heat
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/toggle.sh *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/office.sh *)
---

## Gate modalità azienda

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/toggle.sh status | grep -E 'ATTIVA|DISATTIVA' | head -1`

## Mappa dell'azienda

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/office.sh ansi --no-color $ARGUMENTS`

## Cosa fare adesso

**Controlla il gate.** Se `DISATTIVA`, di' al founder di fare `/azienda on` e
fermati. Se `ATTIVA`, sopra c'è la **visione dell'azienda**: una mappa-ufficio
statica (stanze = team, scrivanie = ruolo→agente) generata da `organigramma.md`
e `teams.md`.

Presentala al founder così com'è. Note d'uso:

- **SVG curato** (per condividere/guardare in un browser): `office.sh svg
  ./.claude/azienda/riunioni/azienda.svg` (percorso assoluto del plugin stampato
  sopra). Pixel-art con stanze colorate, avatar, name-tag. Aggiungi `--open` per
  aprirlo subito nel viewer di sistema (macOS `open` / Linux `xdg-open`).
- **heat**: nella mappa SVG il termometro è **ON di default** (colora le stanze
  per attività git recente, commit 90g sulle glob del team) — degrada a neutro
  senza git. `--no-heat` per spegnerlo. `cold/warm/hot` = segnale grezzo di
  attività, **non** di importanza (un team stabile è cold, non morto). In ANSI
  resta opt-in (`--heat`).
- **`--drift`**: marca con ⚠ gli agenti dell'organigramma che non esistono più
  come file su disco. NB: non conosce i subagent built-in dell'harness, quindi
  è opt-in per non dare falsi positivi.

Se l'organigramma non c'è ancora, crealo prima con `/azienda-bootstrap` o
`/azienda-org init`. La mappa è solo grafica: nessuna interattività, nessuno
stato modificato.
