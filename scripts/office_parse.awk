# office_parse.awk — parser condiviso per organigramma.md e teams.md.
# Accetta LISTA e TABELLA markdown. Emette righe "campo1<TAB>campo2" su stdout;
# se la sezione esiste ma 0 righe sono parsabili, un warning su stderr (diag).
#
# Variabili (passate con -v):
#   section   regex del titolo di sezione (es. "Figure e agenti" | "^Team$")
#   sep       separatore ruolo/agente per la LISTA: "arrow" (→/->) o "colon" (:)
#   label     nome umano della sezione, per il warning
#
# Uso:
#   awk -v section="Figure e agenti" -v sep="arrow" -v label="Figure e agenti" \
#       -f office_parse.awk file.md
#
# Regole comuni: dentro la sezione (fino al prossimo "## "), salta placeholder
# del template; per le tabelle salta header (|---|) e la riga intestazione.

BEGIN { insec=0; seen=0; parsed=0 }

/^##[[:space:]]/ {
  title = $0
  sub(/^##[[:space:]]+/, "", title)     # titolo dopo "## "
  insec = (title ~ section) ? 1 : 0
  if (insec) seen=1
  next
}
!insec { next }

# placeholder del template da ignorare sempre
/aggiungi qui/ { next }
/\(sei tu/     { next }
/eredita da/   { next }

# ---- riga LISTA: "- A <sep> B" ----
/^[[:space:]]*-[[:space:]]/ {
  line = $0
  sub(/^[[:space:]]*-[[:space:]]*/, "", line)
  emit_pair(line)
  next
}

# ---- riga TABELLA: "| A | B |" ----
/^[[:space:]]*\|/ {
  line = $0
  # separatore header |---|:--|
  if (line ~ /^[[:space:]]*\|[[:space:]]*:?-+/) next
  n = split(line, c, "|")   # c[1] vuoto; celle da c[2]
  a = (n>=2)? c[2] : ""
  b = (n>=3)? c[3] : ""
  # header di tabella: salta se la cella contiene la parola-chiave della sezione
  low = tolower(a)
  if (low ~ /^[[:space:]]*(ruolo|team|nome|role)[[:space:]]*$/) next
  emit_cells(a, b)
  next
}

END {
  if (seen && parsed==0)
    printf "[office] AVVISO: sezione trovata (%s) ma 0 righe parsabili. Formato: lista o tabella markdown.\n", label > "/dev/stderr"
}

# --- helper ---------------------------------------------------------------
# emit_pair: una riga-lista già senza "- ". Splitta secondo sep.
function emit_pair(s,   a, b, p) {
  if (sep == "colon") {
    if (s ~ /:/) { idx=index(s,":"); a=substr(s,1,idx-1); b=substr(s,idx+1) }
    else { a=s; b="" }
  } else {  # arrow
    if (s ~ /→/)       { split(s, p, "→");  a=p[1]; b=p[2] }
    else if (s ~ /->/)  { split(s, p, "->"); a=p[1]; b=p[2] }
    else { a=s; b="" }
  }
  emit_cells(a, b)
}

# emit_cells: pulisce e stampa i due campi. Per sep=arrow toglie "| fallback".
function emit_cells(a, b) {
  if (sep != "colon") sub(/\|.*$/, "", b)   # taglia "| fallback: ..." (solo arrow)
  gsub(/^[[:space:]]+|[[:space:]]+$/, "", a)
  gsub(/^[[:space:]]+|[[:space:]]+$/, "", b)
  if (b ~ /^\(/) b=""                        # "(sei tu)" ecc. = descrittivo
  if (a != "") { printf "%s\t%s\n", a, b; parsed++ }
}
