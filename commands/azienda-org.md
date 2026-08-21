---
description: Organigramma del progetto (ruolo→agente) e gestione multi-team (aree del codice). Solo con modalità azienda ATTIVA.
argument-hint: (nessuno) | init
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/toggle.sh *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/org.sh *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/agents.sh *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/assess.sh *)
---

## Gate modalità azienda

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/toggle.sh status | grep -E 'ATTIVA|DISATTIVA' | head -1`

## Organigramma e team

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/org.sh ${ARGUMENTS:-show}`

## Cosa fare adesso

**Prima controlla il gate qui sopra.** Se la riga dice `DISATTIVA`, la modalità
azienda NON è attiva in questo progetto: fermati e di' al founder di fare prima
`/azienda on`. Non procedere oltre.

Se è `ATTIVA`, sopra c'è l'organigramma (ruolo→agente) e la mappa dei team del
progetto, oppure l'esito dell'`init`.

- **Vista (`show`, default):** riporta al founder la rosa di ruoli/agenti e la
  divisione in team, in poche righe. È la ROSA da cui pescare quando orchestri —
  non un vincolo: se un agente non esiste più (verificalo con `agents.sh`, path
  assoluto stampato sopra), usa il fallback.

- **`init`:** ha creato `organigramma.md` e `teams.md` dai template (senza
  sovrascrivere quelli esistenti). Ora, se hai il consenso del founder:
  1. Raccogli i fatti dello stack e degli agenti reali eseguendo, col percorso
     ASSOLUTO che gli output sopra hanno stampato (NON `${CLAUDE_PLUGIN_ROOT}`,
     vuoto nelle tue Bash): `bash …/scripts/assess.sh` e `bash …/scripts/agents.sh`.
  2. Da quei fatti PROPONI al founder: (a) una mappa ruolo→agente realistica per
     questo repo, (b) una divisione in team basata sui PATH reali (es.
     `frontend : apps/web/**`). Poni domande mirate.
  3. Scrivi in `./.claude/azienda/organigramma.md` e `./.claude/azienda/teams.md`
     SOLO ciò che il founder conferma. Non inventare team non supportati dalla
     struttura del repo. I file sono editabili a mano: integra, non sovrascrivere
     in blocco.

Nota multi-team: quando lavori su un file, `bash …/scripts/org.sh which <path>`
ti dice quale team è competente **e ne estrae la ROSA** (l'organigramma override
del team se c'è, altrimenti quello di progetto). Per la rosa di un team per NOME
(es. prima di una riunione di team): `bash …/scripts/org.sh roster <team>`. Se il
progetto è un blocco unico, `teams.md` può restare con una sola voce (o non
esistere: allora c'è un team unico che usa l'organigramma di progetto).
