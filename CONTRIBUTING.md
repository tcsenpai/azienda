# Contribuire ad azienda

Grazie per l'interesse. Questo plugin nasce da un uso reale e resta volutamente
**snello**: prima di aggiungere, chiediti se serve davvero (vedi _Filosofia_).

## Come proporre una modifica

1. **Apri prima una issue** se il cambiamento non è banale: descrivi il problema
   concreto (non la soluzione astratta). Un caso d'uso reale vale più di una
   feature ipotetica.
2. **Fork + branch** dedicato (`fix/...`, `feat/...`).
3. **Modifica il source**, non la cache. Il plugin attivo gira da
   `~/.claude/plugins/cache/...`: durante lo sviluppo, dopo aver editato,
   sincronizza con `./sync-to-cache.sh` e **riavvia la sessione** di Claude Code
   per ricaricare hook e comandi.
4. **Testa** ciò che tocchi (vedi sotto).
5. **Apri la PR** in italiano, spiegando il _perché_ oltre al _cosa_.

## Struttura (cosa vive dove)

| Cartella / file          | Cosa contiene                                            |
|--------------------------|----------------------------------------------------------|
| `.claude-plugin/`        | `plugin.json` (manifest) + `marketplace.json`            |
| `commands/`              | gli slash command `/azienda*`                            |
| `agents/`                | i subagent (`luogotenente`, `quartiermastro`)            |
| `hooks/`                 | `hooks.json` (registra `SessionStart`)                   |
| `scripts/`               | la logica bash (stato, onboard, org, riunione, memory…)  |
| `workflows/`             | script dei Workflow (es. la riunione)                    |
| `*.template.md`          | template copiati nei progetti a runtime                  |
| `persona*.md`, `roster.md` | la persona del Leader e il metodo di scelta agente     |

## Regole di stile

- **Bash**: `set -uo pipefail` (o `-euo` dove ha senso), niente dipendenze
  esterne obbligatorie. Ogni tool esterno (`myc`, `graft`, MCP…) è **opzionale**:
  lo script deve degradare senza, mai fallire perché manca.
- **Percorsi**: gli script risolvono la root del progetto con la stessa funzione
  `resolve_project_dir` (`$CLAUDE_PROJECT_DIR` → `state.json` risalendo → root
  git → `$PWD`). Riusala, non reinventarla.
- **Gate**: i comandi che hanno senso solo in modalità azienda attiva devono
  fare il gate e uscire con codice ≠ 0 + messaggio chiaro se è OFF.
- **Idempotenza**: `init`/`update` non devono sovrascrivere file dell'utente.
  Aggiungono, non distruggono.
- **Niente segreti** committati: punta a dove vivono (env, Bitwarden), mai il
  valore.
- **Lingua**: codice e commenti in italiano (coerente col resto del repo).

## Test

Non c'è un framework: i test sono **check runnable** mirati.

- Sintassi di ogni script toccato: `bash -n scripts/<file>.sh`.
- Per uno script con gate azienda: verificalo sia **OFF** (deve uscire ≠ 0 con
  messaggio) sia **ON** (crea uno `state.json` fittizio `{"active":true}` in una
  dir temporanea con `CLAUDE_PROJECT_DIR` puntato lì).
- Per i Workflow: `node --check workflows/<file>.workflow.js`.

Un test verde vale solo se ha **eseguito** il codice: assicurati che il caso ON
raggiunga davvero il ramo che stai verificando, non che si fermi al gate.

## Versioning

Modifica funzionale → bump di `version` in **entrambi** `plugin.json` e
`marketplace.json` (devono combaciare). Semantica: patch per fix, minor per
feature retro-compatibili.

## Filosofia (perché il plugin è snello)

Il principio guida è **riuso-first**: prima di costruire, si controlla cosa è già
installato (skill, command, subagent, CLI). Le feature nuove sono la _colla_ tra
pezzi esistenti, non re-implementazioni. Se una PR aggiunge molto codice per fare
ciò che un tool già installato fa, verrà chiesto di ridurla.
