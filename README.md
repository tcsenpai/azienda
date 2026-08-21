# azienda — modalità Leader persistente per Claude Code

![licenza: MIT](https://img.shields.io/badge/licenza-MIT-green)

Plugin per [Claude Code](https://docs.anthropic.com/claude-code) che attiva una
**azienda mode** persistente e **per-progetto**: Claude assume la persona di
**Leader/CTO** del founder — non fa tutto da solo, ma **orchestra agenti
specializzati**, parallelizza il lavoro indipendente, e coordina il risultato.
L'esecuzione pesante è delegata a subagent a toolset ristretto. La modalità
sopravvive tra le sessioni finché non la disattivi.

Filosofia di fondo: **riuso-first**. L'azienda riusa il più possibile ciò che è
già installato (graft, mycelium, codedb, skill, command, subagent) invece di
reinventare.

## Installazione

Serve [Claude Code](https://docs.anthropic.com/claude-code). Tutto il resto
(`myc`, `graft`, gli MCP di memoria…) è **opzionale**: il plugin degrada senza.
Cosa sblocca ciascuna dep opzionale e come installarla è in
[OPTIONALS.md](OPTIONALS.md).

```bash
git clone https://github.com/tcsenpai/azienda.git
cd azienda
./install.sh          # verifica l'ambiente e stampa i comandi da incollare
```

`install.sh` non può eseguire gli slash command al posto tuo: ti stampa i due
comandi già pronti da incollare **dentro Claude Code**:

```
/plugin marketplace add /percorso/assoluto/di/azienda
/plugin install azienda@azienda-market
```

Verifica con `/plugin list`. Poi, in un repo qualsiasi: `/azienda on`.

Aggiornare in futuro: `git pull` nella cartella, poi
`/plugin marketplace update azienda-market`.

## Come funziona la persistenza

Lo stato NON vive nella sessione (effimera). Vive su disco, **per progetto**:

```
./.claude/azienda/state.json     →  { "active": true|false, "activated_at": "ISO8601" }
./.claude/azienda/policies.md    →  policy e workflow aziendali del progetto (editabile)
./.claude/azienda/organigramma.md →  rosa ruolo→agente (dal bootstrap; editabile)
```

La radice del progetto è risolta come `$CLAUDE_PROJECT_DIR` → root del repo git
→ `$PWD`. Così la modalità si attiva **solo** nei repo dove hai fatto
`/azienda on`, e non ti segue altrove. Un hook `SessionStart` rilegge lo stato a
ogni avvio: se `active:true`, reinietta la persona.

## Comandi

```
/azienda on|off|status            attiva / disattiva / stato (letto da disco)
/azienda-bootstrap                bootstrap automatico: scouting repo + chi assumere + organigramma
/azienda-onboard                  configura il tracking (mycelium|vault) + assessment repo → policy
/azienda-org [init]               organigramma ruolo→agente + gestione multi-team
/azienda-riunione [team=X] <topic>  riunione: dibattito sequenziale tra agenti + verbale
/azienda-audit                    audit di conformità alle policy (on-demand)
/azienda-update                   migra lo stato per-progetto al nuovo schema (idempotente)
```

`on`/`off` agiscono in doppio: aggiornano il file su disco (per le sessioni
future, via hook) **e** iniettano/rimuovono la persona nella sessione corrente.
Nessun restart richiesto.

## Il flusso tipico

1. **`/azienda on`** in un repo → Claude diventa il Leader e legge le policy.
   Se non c'è ancora un organigramma, ti propone il bootstrap.
2. **`/azienda-bootstrap`** → in un colpo: scout dello stack (usando graft/codedb
   se presenti), inventario degli agenti realmente disponibili, e generazione
   dell'organigramma ruolo→agente. **Il Leader decide chi assumere** e può
   assumere/licenziare quando vuole: l'organigramma è la sua rosa, non un vincolo.
3. **Lavori** normalmente: il Leader scompone i task e delega agli agenti giusti.
4. **`/azienda-riunione <topic>`** quando serve un confronto: un dibattito
   sequenziale tra agenti in ruolo, eseguito da un **Workflow** (self-contained),
   che chiude con un verbale e action item riversati nel tracking.

## I subagent

- **`luogotenente`** — esecutore confinato (`Read, Grep, Glob, Bash, Edit, Write,
  TodoWrite`). Niente web, niente spawn. La persona gli delega l'esecuzione
  concreta nel repo.
- **`quartiermastro`** — braccio destro del Leader: mappa la config Claude Code
  corrente (skill, command, agenti, MCP, CLI) e dice **cosa riutilizzare** prima
  di costruire da zero. Read + Bash, nessuna scrittura.

Nessuno dei due vede gli MCP di sessione: quelli li vede solo il Leader.

## Memoria (due livelli)

- **Scratchpad locale** `./.claude/azienda/` — effimero: i subagent scrivono qui
  i file di lavoro; le lezioni operative del progetto stanno in
  `scripts/memory.sh` (`note`/`recall`).
- **Promozione a memoria long-term** — solo il Leader (unico a vedere gli MCP):
  ai momenti chiave (verbale riunione, decisione architetturale, inventario del
  quartiermastro, lezione da un bug) promuove la conoscenza durevole verso
  `hindsight` **e** `obsidian-memory` se presenti, altrimenti nel locale. La
  checklist la stampa `scripts/memory.sh promote`.

## Policy & workflow per-progetto

Al primo `/azienda on` in un repo, il plugin crea `./.claude/azienda/policies.md`
dal template: è la fonte di verità operativa di **quel** progetto (missione,
priorità, regole d'ingaggio, workflow, divieti, definizione di "fatto"). La
persona la legge all'attivazione e a ogni sessione. Editala liberamente.

## Onboarding e tracking

`/azienda-onboard` configura il task tracking: **mycelium** (`myc`) se
installato, altrimenti un **vault** (`./.claude/azienda/vault/TASKS.md`). La
scelta finisce in `./.claude/azienda/tracking` (versionabile, condivisa dal
team) e sopravvive a `off`.

## Founder configurabile

Il nome del founder nella persona è il placeholder `{{FOUNDER}}`, espanso a
runtime con `$AZIENDA_FOUNDER` (default: `Cris`). Esporta la env var per
cambiarlo.

## Sviluppo

Il plugin attivo gira dalla cache (`~/.claude/plugins/cache/...`), non dal
source. Dopo aver editato: `./sync-to-cache.sh`, poi **riavvia la sessione**.
Dettagli e regole in [CONTRIBUTING.md](CONTRIBUTING.md).

## Licenza

[MIT](LICENSE) © 2026 Cris (tcsenpai)
