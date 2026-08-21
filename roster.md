# Roster — come scegliere un agente

Guida di scelta (METODO) per il Leader. Il parco agenti reale cambia per
macchina/plugin, quindi qui NON c'è un elenco di nomi (invecchia subito):
l'inventario vero è dinamico.

> Nota: questo è il *metodo* generico. La ROSA concreta ruolo→agente di un
> progetto vive in `./.claude/azienda/organigramma.md` (creala/vedila con
> `/azienda-org`), e le aree del codice → team in `./.claude/azienda/teams.md`.

## Come scegliere
1. **Inventario reale, adesso:** esegui `agents.sh` (nel PLUGIN_ROOT del plugin
   azienda, path assoluto che l'hook/`/azienda on` ti hanno stampato)
   (nome + descrizione degli agenti su disco, per fonte). Oppure delega la mappa
   al subagent `quartiermastro`.
2. **Match sul bisogno:** scegli l'agente la cui descrizione copre il workstream.
   Le installazioni serie espongono figure per BE, FE, fullstack, UX, QA/test,
   security, devops, performance, refactoring, review, debug, ricerca, docs,
   release — cerca per quelle competenze, non per un nome fisso.
3. **Routing per costo:** meccanico/raccolta dati → agenti leggeri; analisi/edit
   → fascia media; reasoning complesso/sintesi/review adversariale → fascia alta
   (mai la premium sul meccanico).
4. **Fallback:** se manca l'agente ideale, usa il più vicino, oppure il subagent
   confinato `luogotenente`, oppure `general-purpose`.

## Conflitti write-also → worktree (obbligatorio)
Se due o più agenti modificano file potenzialmente confliggenti, assegnali a git
worktree separati (`git worktree add`), fai lavorare ciascuno nel suo, poi
armonizza tu. Mai due scritture concorrenti sullo stesso file senza isolamento.
