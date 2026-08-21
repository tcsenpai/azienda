---
description: Onboarding modalità azienda — configura il task tracking del progetto (mycelium o vault)
argument-hint: (nessuno)
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/onboard.sh *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/assess.sh *)
---

## Rilevamento ambiente

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/onboard.sh detect`

## Cosa fare adesso

Sopra c'è lo stato reale dell'ambiente (mycelium presente o no, progetto già
inizializzato o no, tracking già configurato o no). Conduci l'onboarding del
**task tracking** per questo progetto:

1. **Se il tracking è già configurato** (lo dice l'output sopra): riportalo al
   founder in una riga e chiedi se vuole ri-configurarlo. Se no, fermati qui.

2. **Poni le domande** al founder con lo strumento di domanda interattiva.
   La scelta principale è il backend di tracking, con questo default:
   - **mycelium** se `myc` è PRESENTE (raccomandato: è il supporto first-class,
     vedi `myc --help` / l'AGENTS.md generato da `myc prime-agents`);
   - **vault** (cartella `./.claude/azienda/vault/` con `TASKS.md`) se `myc` è
     ASSENTE, o se il founder preferisce esplicitamente un tracking leggero
     senza dipendenze.
   Presenta il default già evidenziato in base all'ambiente. Non forzare
   mycelium se non è installato — offri il vault come alternativa naturale.

3. **Esegui la scelta** (una sola delle due). Usa il percorso ASSOLUTO dello
   script che l'output `detect` sopra ha stampato (le righe `bash /…/onboard.sh
   …`). NON usare `${CLAUDE_PLUGIN_ROOT}`: nelle tue Bash è vuoto e il percorso
   non risolverebbe.
   - mycelium → `bash …/onboard.sh init-mycelium` (esegue `myc init` +
     `myc prime-agents` nel progetto), poi `bash …/onboard.sh set-tracking mycelium`.
   - vault → `bash …/onboard.sh init-vault`, poi `bash …/onboard.sh set-tracking vault`.

4. **Registra nelle policy**: apri `./.claude/azienda/policies.md` (creato da
   `/azienda on`) e annota nella sezione workflow QUALE tracking usa il progetto
   e come (es. "task via `myc task create ...`" oppure "task in
   `./.claude/azienda/vault/TASKS.md`"). Se le policy non esistono ancora,
   ricorda al founder di fare prima `/azienda on`.

5. **Conferma** al founder in poche righe: backend scelto, cosa è stato
   inizializzato, dove vivono i task d'ora in poi. Da qui in avanti, in modalità
   azienda, traccia il lavoro con il backend configurato nel file condiviso
   `./.claude/azienda/tracking`.

## (Opzionale) Assessment del repo → policies

Dopo aver configurato il tracking, CHIEDI al founder se vuole che tu faccia un
assessment del repository per popolare le policy di questo progetto. È
**opzionale**: se dice di no, salta del tutto e non toccare `policies.md`.

Se dice di sì (e SOLO se ha acconsentito):

1. Raccogli i fatti del repo eseguendo ORA, via Bash, `assess.sh` dalla STESSA
   cartella `scripts/` di `onboard.sh` (usa il percorso ASSOLUTO stampato
   dall'output `detect` sopra e sostituisci `onboard.sh`→`assess.sh`; NON usare
   `${CLAUDE_PLUGIN_ROOT}`, vuoto nelle tue Bash).
   Non eseguirlo prima del consenso: l'assessment è opzionale e non deve girare
   se il founder ha detto di no.
2. Da quei fatti deduci stack, natura del progetto e servizi. Poi **poni domande
   mirate** al founder per le sezioni delle policy che l'assessment tocca: stack
   e package manager, servizi/infra, come girano i test e cosa deve essere verde
   per dire "fatto", eventuali vincoli (DB prod, segreti), divieti specifici.
3. Scrivi in `./.claude/azienda/policies.md` **solo** i valori che il founder
   conferma. Non inventare vincoli non supportati dai fatti. Preserva il resto
   del file (è editabile a mano dal founder: non sovrascriverlo in blocco,
   integra le sezioni pertinenti).

## (Opzionale) Editing manuale delle policy

Le policy sono un file Markdown normale in `./.claude/azienda/policies.md`: il
founder può editarle a mano quando vuole, tu le rileggi a ogni sessione. Alla
fine dell'onboarding, offri — **senza forzare** — di aprirle e rifinirle insieme
ora. Se il founder preferisce editarle da solo più tardi, indicagli solo il
percorso e fermati.
