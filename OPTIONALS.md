# Dipendenze opzionali

Il plugin `azienda` funziona **senza nessuna** di queste: ogni integrazione è
rilevata a runtime e **degrada in silenzio** se il tool manca (mai un errore).
Ma se le installi, il plugin le usa automaticamente — sono già cablate nel
codice. Qui trovi cosa sblocca ciascuna e come installarla.

Come il plugin le rileva:
- **CLI su disco** (`myc`, `graft`, `bw`, `python3`): via `command -v`.
- **Skill utente** (`obsidian-memory`): via file in `~/.claude/skills/...`.
- **MCP di sessione** (`hindsight`, `codedb`, `graft`): visibili solo al Leader
  in sessione (i tool `mcp__*`), non agli script.

---

## mycelium (`myc`) — task tracking

**Cosa sblocca:** `/azienda-onboard` usa mycelium come backend di tracking dei
task se `myc` è installato (altrimenti crea un vault Markdown locale). Gli action
item delle riunioni ci finiscono dentro.

**Installa:** è un CLI Rust single-binary.

```bash
# serve una toolchain Rust (rustup)
cargo install --git https://github.com/tcsenpai/mycelium
# verifica
myc --version
```

Senza `myc`: il tracking usa `./.claude/azienda/vault/TASKS.md`. Nessuna perdita
di funzione, solo un backend diverso.

---

## graft — code intelligence (assessment strutturale)

**Cosa sblocca:** `/azienda-bootstrap` e `/azienda-onboard` fanno un assessment
del repo più profondo (architettura, moduli, hub) usando graft se il repo è
**indicizzato**, invece della semplice lista di file.

**Installa** (CLI + indicizzazione del repo):

```bash
# installa il CLI graft (vedi il suo repo per il metodo aggiornato)
# poi, nella root del progetto dove userai azienda:
graft build          # costruisce il grafo (cartella graft/, git-ignorata)
```

graft espone anche tool MCP (`mcp__graft__*`): se configuri il server MCP in
Claude Code, il Leader li usa direttamente. Senza graft: assessment best-effort
sui fatti grezzi del repo.

---

## codedb — code intelligence (MCP)

**Cosa sblocca:** assessment strutturale alternativo/complementare a graft
(`outline`, `search`, `context`). È un **server MCP**: il Leader lo usa se in
sessione vede i tool `mcp__codedb__*`.

**Installa:** configura il server MCP codedb in Claude Code (vedi la doc di
codedb). Non è un pacchetto da `command -v`: la sua presenza è solo di sessione.
Senza: usa graft, o l'assessment best-effort.

---

## Memoria long-term: hindsight + obsidian-memory

**Cosa sblocca:** la **promozione** della conoscenza durevole (decisioni,
inventario del quartiermastro, lezioni) a memoria persistente cross-sessione.
Vedi la sezione _Memoria (due livelli)_ del README. Il plugin scrive su
**entrambi** i canali se presenti; se manca uno usa l'altro; se mancano
entrambi, resta la memoria locale (`scripts/memory.sh note`).

**hindsight** — è un **server MCP**. Il Leader lo usa se in sessione vede i tool
`mcp__hindsight__*` (retain nel bank `coding-<repo>`). Configura il server MCP
hindsight in Claude Code.

**obsidian-memory** — è una **skill utente**. Il plugin la rileva se esiste
`~/.claude/skills/obsidian-memory/scripts/recall.sh`. Installa la skill nel tuo
`~/.claude/skills/`.

Senza né l'uno né l'altro: la memoria resta locale al progetto
(`./.claude/azienda/memory/`), versionabile ma non cross-progetto.

---

## Bitwarden CLI (`bw`) — segreti

**Cosa sblocca:** quando la persona deve **leggere** un segreto al volo, se `bw`
è installato è il canale preferito (via la skill `/bitwarden-cli`), invece di
env var o del gestore indicato nelle policy.

**Installa:**

```bash
# npm
npm install -g @bitwarden/cli
# oppure Homebrew
brew install bitwarden-cli
# verifica
bw --version
```

Senza `bw`: si usano env var o il gestore che le policy del progetto indicano.
Il plugin non scrive mai segreti in chiaro, con o senza Bitwarden.

---

## python3 — parsing robusto dello stato + mappa-ufficio

**Cosa sblocca:** (1) gli script leggono `state.json` con `python3` quando c'è
(parse JSON affidabile), senza cadono su `grep`; (2) `/azienda-mappa` usa
`python3` per il rendering pixel-art (ANSI e SVG) — senza, la mappa degrada a una
vista testuale semplice (l'SVG richiede `python3`). È quasi sempre già presente
sui sistemi di sviluppo — non serve installarlo apposta.

---

## Riepilogo

| Dep              | Tipo         | Sblocca                                  | Senza →                          |
|------------------|--------------|------------------------------------------|----------------------------------|
| `myc` (mycelium) | CLI          | tracking task via mycelium               | vault Markdown locale            |
| graft            | CLI + MCP    | assessment strutturale del repo          | assessment best-effort           |
| codedb           | MCP          | assessment strutturale (alt.)            | graft / best-effort              |
| hindsight        | MCP          | memoria long-term (canale 1)             | obsidian / locale                |
| obsidian-memory  | skill utente | memoria long-term (canale 2)             | hindsight / locale               |
| `bw` (Bitwarden) | CLI          | lettura segreti al volo                  | env var / gestore da policy      |
| `python3`        | CLI          | parse JSON robusto dello stato           | fallback grep                    |
