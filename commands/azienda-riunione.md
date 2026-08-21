---
description: Convoca una riunione aziendale — dibattito sequenziale tra subagent in ruolo, verbale finale. Solo con modalità azienda ATTIVA.
argument-hint: [team=<nome>] <topic>
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/riunione.sh *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/org.sh *)
---

## Contesto riunione (gate + rosa + tracking)

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/riunione.sh context`

## Procedura

**GATE — controlla l'output sopra.** Se dice "Modalità azienda NON attiva"
(exit 3), FERMATI: di' al founder di fare `/azienda on`. Se è ATTIVA, procedi.

La riunione NON la orchestri più a mano turno-per-turno: la **esegue un
workflow** in una chiamata sola (dibattito sequenziale, N round, verbale del
moderatore, self-contained). Tu fai la parte di GIUDIZIO — scegliere chi
partecipa — poi lanci il workflow e salvi ciò che ti torna.

### 1. Parsing della richiesta
Da `$ARGUMENTS`: il **topic** (se troppo vago per un dibattito utile, fai UNA
domanda di chiarimento prima — le riunioni costano) e un eventuale **`team=<nome>`**
(riunione per quell'area; senza, è cross-team).

### 2. Scegli i partecipanti (min 2 — VINCOLANTE)
Scegli TU i ruoli dalla rosa sopra, in base al topic. **Minimo 2**: sotto non è
una riunione — o ne aggiungi, o rispondi diretto senza convocare.
- Se `team=X`: pesca dalla rosa ristretta con `bash …/scripts/org.sh roster X`
  (percorso assoluto stampato sopra). Cross-team: usa l'organigramma di progetto.
- Per ogni ruolo: se esiste un **agente su disco** con quel nome (li vedi da
  `org.sh agents`), passalo come `agentType` (senza persona, rispetta la sua).
  Altrimenti scrivi una **persona** di 3-4 frasi (priorità, bias, cosa contesta).
- Routing per costo: dibattenti in fascia media; alza solo se il ruolo richiede
  reasoning pesante. L'ORDINE della lista = ordine di parola.
- Scala: il workflow gira `speaker × round (+1 moderatore)` agenti in totale
  (5 speaker × 3 round = 16). Tienilo sotto ~15: se serve un panel grande,
  riduci gli speaker o i round, non gonfiare la riunione.

### 3. Esegui il workflow (UNA chiamata)
Chiama lo strumento **Workflow** con `scriptPath` puntato allo script versionato
del plugin e `args` coi partecipanti che hai scelto:

- `scriptPath`: `${CLAUDE_PLUGIN_ROOT}/workflows/riunione.workflow.js`
  (usa il percorso ASSOLUTO stampato dal contesto sopra come `PLUGIN_ROOT`, non
  la variabile: nelle tue chiamate `${CLAUDE_PLUGIN_ROOT}` è vuota.)
- `args`:
  ```json
  {
    "topic": "<il topic>",
    "lang": "<lingua del topic, es. it>",
    "speakers": [
      { "role": "SRE",        "agentType": "devops-architect" },
      { "role": "Root-cause", "agentType": "root-cause-analyst" },
      { "role": "Backend",    "persona": "Owner del codice reale. Prioritizza il costo d'implementazione concreto; contesta le soluzioni eleganti ma costose; parla per file e funzioni." }
    ]
  }
  ```
  Ogni speaker: `role` (obbligatorio), poi `agentType` (agente su disco) **oppure**
  `persona` (testo). Opzionale `model` per-speaker. Default 3 round
  (Apertura/Replica/Posizione finale) con early-exit implicito nel comportamento
  degli agenti; per round custom passa `rounds: [{title, instruction}, …]`.

Il workflow gira in background e ti notifica alla fine. Ti ritorna
`{ topic, transcript, verbale }`. **Non fabbricare il risultato: aspetta la
notifica** e leggi il valore di ritorno (se serve, dal journal del run).

### 4. Consegna
- Crea la cartella: `bash …/scripts/riunione.sh mkdir <slug>` → stampa
  `riunioni/<slug>-<data>/`.
- Scrivi `transcript.md` (= campo `transcript`) e `verbale.md` (= campo `verbale`).
- **Riversa gli action item del verbale nel tracking del progetto** (backend
  indicato nel contesto: `myc task create …` o `./.claude/azienda/vault/TASKS.md`).
  MANDATORIO: una riunione che non lascia task tracciati è cerimonia sprecata.
- Presenta al founder il verbale + i path, denso. Il transcript vale la lettura.
