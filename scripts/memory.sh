#!/usr/bin/env bash
# memory.sh — memoria operativa per-progetto della modalità azienda.
#
# Dà ai subagent (effimeri) continuità: lezioni, gotcha, "l'ultima volta X è
# fallito". File-based e locale (./.claude/azienda/memory/lessons.md), zero
# dipendenze. Se la skill obsidian-memory è presente, la segnala come canale
# di ricerca ibrida opzionale — MAI obbligatorio, degrada senza.
#
# Sub-azioni ($1):
#   recall [query]   stampa le lezioni (o quelle che matchano query) a inizio task
#   note <testo>     appende una lezione datata (scratchpad locale del progetto)
#   where            stampa il percorso del file memoria
#   promote          checklist per il Leader: promuovi la conoscenza durevole a
#                    memoria long-term (hindsight + obsidian se presenti)

set -uo pipefail

ACTION="${1:-recall}"
shift 2>/dev/null || true
ARG="$*"

resolve_project_dir() {
  if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "${CLAUDE_PROJECT_DIR:-}" ]; then
    printf '%s' "$CLAUDE_PROJECT_DIR"; return
  fi
  local d="$PWD"
  while [ "$d" != "/" ]; do
    [ -f "$d/.claude/azienda/state.json" ] && { printf '%s' "$d"; return; }
    d="$(dirname "$d")"
  done
  local top
  if top="$(git rev-parse --show-toplevel 2>/dev/null)" && [ -n "$top" ]; then
    printf '%s' "$top"; return
  fi
  printf '%s' "$PWD"
}

PROJECT_DIR="$(resolve_project_dir)"
MEM_DIR="$PROJECT_DIR/.claude/azienda/memory"
MEM_FILE="$MEM_DIR/lessons.md"

# obsidian-memory presente? (skill utente). Solo per suggerimento, non richiesto.
has_obsidian() { [ -x "$HOME/.claude/skills/obsidian-memory/scripts/recall.sh" ]; }

case "$ACTION" in
  where)
    echo "$MEM_FILE"
    ;;

  note)
    [ -n "$ARG" ] || { echo "[memory] uso: memory.sh note <testo lezione>"; exit 1; }
    mkdir -p "$MEM_DIR"
    [ -f "$MEM_FILE" ] || printf '# Lezioni operative — memoria azienda del progetto\n\n> Continuità per i subagent effimeri: gotcha, cosa ha funzionato/fallito.\n> Append-only. Denso.\n\n' > "$MEM_FILE"
    printf -- '- [%s] %s\n' "$(date -u +%Y-%m-%d)" "$ARG" >> "$MEM_FILE"
    echo "[memory] Lezione registrata → $MEM_FILE"
    if has_obsidian; then
      echo "[memory] (obsidian-memory presente: valuta di ritenerla anche lì per la"
      echo "[memory]  ricerca ibrida cross-progetto — opzionale, vedi /obsidian-memory.)"
    fi
    ;;

  recall)
    if [ ! -f "$MEM_FILE" ]; then
      echo "[memory] Nessuna lezione registrata per questo progetto."
      has_obsidian && echo "[memory] (obsidian-memory presente: puoi cercare lì lezioni cross-progetto.)"
      exit 0
    fi
    if [ -n "$ARG" ]; then
      echo "[memory] Lezioni che matchano '$ARG':"
      grep -i -- "$ARG" "$MEM_FILE" || echo "[memory] (nessun match diretto; leggi il file intero se serve.)"
    else
      echo "[memory] Lezioni operative del progetto ($MEM_FILE):"
      cat "$MEM_FILE"
    fi
    has_obsidian && echo "[memory] (per ricerca ibrida cross-progetto: /obsidian-memory recall '<query>')"
    ;;

  promote)
    # Checklist di PROMOZIONE a memoria long-term. La esegue il LEADER (unico a
    # vedere gli MCP di sessione). Lo script rileva obsidian su disco; hindsight
    # è un MCP → non visibile qui, lo verifica il Leader in sessione.
    repo="$(basename "$PROJECT_DIR")"
    echo "[memory] PROMOZIONE a memoria long-term — repo: $repo"
    echo
    echo "Promuovi SOLO conoscenza durevole, ai momenti chiave (verbale riunione,"
    echo "decisione architetturale, assessment/inventario quartiermastro, lezione"
    echo "da un bug). NON lo scratchpad grezzo. Scrivi su ENTRAMBI i canali se ci"
    echo "sono; se ne manca uno usa l'altro; se mancano entrambi, il locale."
    echo
    echo "Canali long-term:"
    echo "  - hindsight (MCP): se in sessione vedi tool mcp__hindsight__* → retain"
    echo "    nel bank 'coding-$repo' (mcp__hindsight__retain / sync_retain)."
    if has_obsidian; then
      echo "  - obsidian-memory: PRESENTE su disco → /obsidian-memory retain"
      echo "    (o scripts/retain.sh) con type decision|lesson|project|entity."
    else
      echo "  - obsidian-memory: NON presente su disco."
    fi
    echo "  - fallback locale (sempre): scripts/memory.sh note \"<lezione>\""
    echo
    echo ">> ISTRUZIONE (Leader): decidi cosa è durevole, poi scrivi sui canali"
    echo ">> disponibili. Se aggiorni una decisione già in memoria, aggiornala su"
    echo ">> ENTRAMBI (o supersede coerente) — i due canali non devono divergere."
    ;;

  *)
    echo "[memory] Sub-azione non valida: '$ACTION' (recall|note|where|promote)"
    exit 1
    ;;
esac
