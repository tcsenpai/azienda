<!-- FORMATO (letto da /azienda-mappa): sotto "## Team" scrivi i team come LISTA
     `- <nome> : <glob>[, <glob>]` OPPURE come TABELLA `| Team | Glob |`. Per
     avere i MEMBRI dentro la stanza-team nella mappa, dai al team una rosa qui
     sotto in "## Organigramma per team" → "### <nome team>" con righe
     `- <ruolo> → <agente>`. Un team senza rosa mostra "(eredita rosa progetto)"
     nella mappa, non "(vuota)". -->
# Team — {{PROGETTO}}

> Divisione del repo in TEAM "a seconda del codice": ogni team ha un'area di
> competenza (path-glob) e — se serve — un proprio organigramma. Quando il
> Leader lavora su un file, i glob dicono QUALE team è competente.
>
> **Statico e dichiarativo**: editi questo file a mano, non viene auto-inferito
> a ogni task. L'assessment di `/azienda-org` può PROPORTI una divisione
> iniziale sui path reali del repo; tu confermi. Se il progetto è un blocco
> unico (nessuna area separata), lascia una sola voce o cancella questo file:
> senza `teams.md` c'è un team unico che usa l'organigramma di progetto.

## Team

Formato per riga (una o più glob separate da virgola dopo i due punti):
`- <nome team> : <glob>[, <glob>...]`

I glob sono relativi alla radice del progetto. `**` = qualsiasi profondità.
Esempio (adatta ai path REALI del tuo repo, questi sono solo illustrativi):

- frontend : apps/web/**, packages/ui/**
- backend  : services/**, apps/api/**
- contracts : contracts/**, *.sol

## Organigramma per team (opzionale)

Se un team vuole una rosa di agenti diversa da quella di progetto, dichiarala
qui sotto sotto un heading `### <nome team>` (deve combaciare col nome usato
nella sezione Team sopra). Formato riga IDENTICO a organigramma.md:
`- <ruolo aziendale> → <agente consigliato> [| fallback: <alt>]`

Un team SENZA heading qui (o con righe solo di commento) eredita interamente la
rosa da `organigramma.md`. `scripts/org.sh which <path>` estrae automaticamente
la rosa del team competente (override del team se c'è, altrimenti quella di
progetto).

### frontend
- (eredita da organigramma.md — cancella questa riga e aggiungi override reali)

### backend
- (eredita da organigramma.md — cancella questa riga e aggiungi override reali)

## Nota d'uso per il Leader

- Per sapere quale team copre un path: `bash scripts/org.sh which <path>`
  (percorso assoluto stampato da `/azienda-org`).
- Una riunione può essere convocata per un team specifico
  (`/azienda-riunione team=frontend "<topic>"`) o cross-team (default).
- Un file che non matcha nessun glob → team unico / organigramma di progetto.
