#!/usr/bin/env bash
# check-docs.sh — coerenza della documentazione al commit.
#
# NON blocca il commit (exit 0 sempre): è un REMINDER + un rilevatore di
# incoerenze meccaniche. Un hook è bash, non un umano: non può riscrivere la
# prosa di README/OPTIONALS in modo sensato. Quello che fa:
#   1. DERIVA dal codice i tool opzionali wirati (non una lista a mano);
#   2. verifica che ciascuno sia documentato in OPTIONALS.md (match robusto,
#      a confine di parola — niente falsi positivi su token corti come `bw`);
#   3. verifica che README.md linki OPTIONALS.md;
#   4. ti RICORDA di controllare che la PROSA sia aggiornata (questo non lo può
#      giudicare uno script).
# Il "renderli coerenti" davvero (scrivere la voce giusta) lo fai tu (o Claude):
# lo script ti dice ESATTAMENTE cosa manca.
#
# Uso: bash scripts/check-docs.sh   (o richiamato da .git/hooks/pre-commit)

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
README="$ROOT/README.md"
OPT="$ROOT/OPTIONALS.md"
SCAN_DIRS=("$ROOT/scripts" "$ROOT/agents")
SCAN_FILES=("$ROOT/persona.md")

y() { printf '\033[33m%s\033[0m\n' "$*"; }   # giallo = attenzione
g() { printf '\033[32m%s\033[0m\n' "$*"; }   # verde = ok

# --- 1. DERIVA i tool opzionali wirati dal codice --------------------------
# Pattern riconosciuti (ognuno rende il NOME del tool):
#   command -v <tool>          → CLI opzionale
#   has_<tool>()               → helper di rilevamento (es. has_obsidian, has_myc)
#   mcp__<server>__            → server MCP di sessione
# Normalizziamo alias noti (bw→bw ma documentato come Bitwarden; l'helper
# has_obsidian → obsidian-memory; myc → mycelium ma il token cercato è `myc`).
#
# NB: cerchiamo i NOMI così come DEVONO apparire (anche solo come substring
# riconoscibile) in OPTIONALS.md, con match a confine di parola.
derive_tools() {
  {
    # command -v <tool>
    grep -rhoE "command -v [a-zA-Z0-9_-]+" "${SCAN_DIRS[@]}" "${SCAN_FILES[@]}" 2>/dev/null \
      | sed 's/command -v //'
    # has_<tool>  → prende <tool>
    grep -rhoE "has_[a-zA-Z0-9]+\(\)" "${SCAN_DIRS[@]}" "${SCAN_FILES[@]}" 2>/dev/null \
      | sed -E 's/has_([a-zA-Z0-9]+)\(\)/\1/'
    # mcp__<server>__  → prende <server>
    grep -rhoE "mcp__[a-zA-Z0-9]+" "${SCAN_DIRS[@]}" "${SCAN_FILES[@]}" 2>/dev/null \
      | sed 's/mcp__//'
    # Dep note ma cablate solo in PROSA (non come `command -v`/`has_`/`mcp__`):
    # la derivazione automatica non le vede, le dichiariamo qui. Tienila corta —
    # ogni voce è un'eccezione, non la regola.
    printf '%s\n' "bw"
  } | sort -u
}

# Mappa gli alias del codice al TOKEN che ci si aspetta in OPTIONALS.md.
# (chiave codice → token doc). Ciò che non è in mappa resta invariato.
canon_token() {
  case "$1" in
    obsidian)   echo "obsidian-memory" ;;   # has_obsidian → skill obsidian-memory
    myc)        echo "myc" ;;               # documentato come "mycelium (myc)"
    python3)    echo "python3" ;;
    *)          echo "$1" ;;
  esac
}

# Rumore da ignorare (non sono dep opzionali da documentare).
is_noise() {
  case "$1" in
    python3) return 1 ;;   # python3 SÌ è documentato → non è rumore
    git|bash|sed|grep|awk|cat|find|date|mkdir|printf|echo|head|tail|tr|sort|python) return 0 ;;
    *) return 1 ;;
  esac
}

# match a CONFINE DI PAROLA: il token deve comparire come parola isolata, non
# come substring dentro un'altra (robusto per token corti tipo `bw`).
doc_has() {
  local tok="$1" file="$2"
  # -w = word boundary; -F = literal; -i = case-insensitive. Backtick/parentesi
  # attorno al token in OPTIONALS contano come confine, quindi `bw` matcha.
  grep -qiwF -- "$tok" "$file" 2>/dev/null && return 0
  # fallback: token che contiene '-' (es. obsidian-memory) — -w non sempre
  # tratta '-' come confine uniforme tra le implementazioni di grep: prova anche
  # un match literal semplice, che per un token lungo e specifico è sicuro.
  case "$tok" in
    *-*) grep -qiF -- "$tok" "$file" 2>/dev/null && return 0 ;;
  esac
  return 1
}

echo "── check-docs: coerenza README ↔ OPTIONALS ──"
echo

if [ ! -f "$OPT" ]; then
  y "OPTIONALS.md non trovato ($OPT) — creane uno che documenti le dep opzionali."
  echo; exit 0
fi

missing=""
seen=""
while IFS= read -r raw; do
  [ -n "$raw" ] || continue
  is_noise "$raw" && continue
  tok="$(canon_token "$raw")"
  # dedup
  case " $seen " in *" $tok "*) continue ;; esac
  seen="$seen $tok"
  doc_has "$tok" "$OPT" || missing="$missing $tok"
done < <(derive_tools)

if [ -n "$missing" ]; then
  y "Tool opzionali cablati nel codice ma ASSENTI da OPTIONALS.md:"
  for t in $missing; do echo "    - $t"; done
  y "→ aggiungili a OPTIONALS.md (cosa sblocca / come si installa / senza →)."
else
  g "OK: ogni tool opzionale wirato nel codice è documentato in OPTIONALS.md."
  [ -n "$seen" ] && echo "   (verificati:$seen )"
fi

# --- 3. link README → OPTIONALS --------------------------------------------
if [ -f "$README" ]; then
  if grep -qF "OPTIONALS.md" "$README"; then
    g "OK: README.md linka OPTIONALS.md."
  else
    y "README.md NON linka OPTIONALS.md → aggiungi un rimando."
  fi
else
  y "README.md non trovato."
fi

echo
y "PROMEMORIA: hai toccato comandi, script o dep? Verifica che README.md e"
y "OPTIONALS.md siano AGGIORNATI e CORRETTI prima di pushare. Questo check"
y "coglie solo le incoerenze meccaniche, non se la prosa è giusta."
echo

exit 0
