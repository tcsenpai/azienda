---
description: Audit di conformità del Leader alle policy del progetto (policy-drift, on-demand)
argument-hint: (nessuno)
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/audit.sh *)
---

## Fatti per l'audit

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/audit.sh report`

## Cosa fare adesso

Sopra ci sono i fatti e le istruzioni dell'audit di conformità. Non è
automatico: sei TU (il Leader) a giudicare il tuo operato contro le policy
dichiarate. Procedi così:

1. Leggi `./.claude/azienda/policies.md`.
2. Ripercorri il lavoro recente e confrontalo con quelle regole: divieti
   rispettati, tracking aggiornato, escalation seguite, e soprattutto — hai
   RIUSATO l'esistente (skill/command/agenti/graft/myc/codedb) o costruito da
   zero? Se da zero, era un buco reale non coperto da nulla?
3. Scrivi un blocco datato in `./.claude/azienda/ledger.md` (APPEND, mai
   sovrascrivere): aderenze OK, derive trovate col motivo, override consapevoli.
   Sii onesto — il ledger serve a te, non a fare bella figura.
4. Se una deriva è in realtà un pattern nuovo e valido, PROPONI all'utente di
   emendare `policies.md`; non modificarlo di tua iniziativa.
5. Quando hai scritto il ledger, registra l'audit eseguendo il comando
   `bash …/scripts/audit.sh done` **col percorso ASSOLUTO che lo script ha
   stampato sopra** (la riga `bash /…/audit.sh done`). NON usare
   `${CLAUDE_PLUGIN_ROOT}`: nella shell delle tue Bash è vuoto, quindi
   quel percorso non risolverebbe.
6. Riporta al founder in poche righe: cosa era in linea, cosa è derivato, cosa
   proponi di cambiare.

Nota: l'audit è **on-demand**. Il promemoria periodico ("sono passate N sessioni")
è OPT-IN e disattivo di default. Se il founder lo vuole, attivalo con
`touch ./.claude/azienda/audit-nudge.on` (rimuovi il file per spegnerlo).
