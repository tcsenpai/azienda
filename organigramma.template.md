# Organigramma — {{PROGETTO}}

> Mappa RUOLO aziendale → agente consigliato per questo progetto. Versionabile
> (condiviso col team via git), editabile a mano. È la ROSA da cui il Leader
> pesca quando orchestra: non è un vincolo rigido — se l'agente ideale non
> esiste più (verifica con `agents.sh`), scendi al fallback.
>
> L'inventario REALE degli agenti su disco lo dà `scripts/agents.sh` del plugin.
> Qui scrivi solo la MAPPA di intenti: quale figura ti serve per questo repo e
> quale agente la copre meglio ORA.

## Figure e agenti

Compila con i ruoli che questo progetto usa davvero. Formato per riga:
`- <ruolo aziendale> → <agente consigliato> [| fallback: <alt>]`

- Leader tecnico / orchestratore → (sei tu, la sessione principale)
- Esecuzione confinata (edit/refactor nel repo) → luogotenente | fallback: general-purpose
- Inventario tooling su disco → quartiermastro
- …aggiungi qui le figure del progetto (BE, FE, UX, QA, security, devops,
  performance, review, debug, docs, release) → agente scelto | fallback

## Note

- Un ruolo senza un agente dedicato usa il fallback (`luogotenente` o
  `general-purpose`), non è un buco da riempire a forza.
- Routing per costo: meccanico → agenti leggeri; analisi/edit → fascia media;
  reasoning/sintesi/review adversariale → fascia alta. Mai la premium sul
  meccanico.
