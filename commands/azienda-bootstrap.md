---
description: Bootstrap automatico dell'azienda — scouting del repo, decisione su chi assumere, generazione organigramma. Solo con modalità azienda ATTIVA.
argument-hint: (nessuno)
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/toggle.sh *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/bootstrap.sh *)
---

## Gate modalità azienda

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/toggle.sh status | grep -E 'ATTIVA|DISATTIVA' | head -1`

## Bootstrap

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/bootstrap.sh`

## Cosa fare adesso

**Prima controlla il gate qui sopra.** Se dice `DISATTIVA`, la modalità azienda
NON è attiva: fermati e di' al founder di fare prima `/azienda on`. Non procedere.

Se è `ATTIVA`, sopra hai in un colpo lo scouting del repo, l'inventario reale
degli agenti e i file organigramma seedati, seguiti da un blocco
`>> ISTRUZIONE AL LEADER (bootstrap):`. **Eseguila ora:**

1. Se lo scouting segnala graft (indicizzato) o codedb in sessione, USALI per un
   assessment strutturale più profondo della semplice lista di file.
2. Deduci le figure che questo repo richiede DAVVERO (solo le pertinenti) e
   mappale sugli agenti REALI dell'inventario, con routing per costo.
3. Scrivi la rosa ruolo→agente in `./.claude/azienda/organigramma.md` e, se il
   repo ha aree separate nei path reali, la divisione team in `teams.md`.
   Popolali dallo scouting — niente placeholder. Il founder li edita dopo.
4. Comunica al founder la rosa proposta e la mappa team, in poche righe.

Sei tu a gestire le assunzioni: puoi **assumere e licenziare** chi vuoi. L'org
è la tua rosa, non un vincolo — cambiala quando il lavoro lo richiede. Ri-lancia
`/azienda-bootstrap` se lo stack cambia in modo sostanziale.
