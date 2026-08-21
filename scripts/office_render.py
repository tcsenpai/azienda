#!/usr/bin/env python3
# office_render.py — renderer della "visione dell'azienda".
# Legge un TSV su stdin (TIPO \t nome \t agente/glob \t heat \t drift) e disegna
# un ufficio top-down statico: la ROSA (ruolo→agente) come scrivanie in una
# stanza, e i TEAM come stanze-area. Due modi: ansi | svg.
#
# argv: mode(ansi|svg)  nocolor(0|1)  project_name
# Zero dipendenze oltre la stdlib. Non fallisce su input parziale.

import sys

def read_model():
    roles, teams = [], []
    for line in sys.stdin:
        parts = line.rstrip("\n").split("\t")
        if len(parts) < 5:
            continue
        typ, name, extra, heat, drift = parts[0], parts[1], parts[2], parts[3], parts[4]
        hl = len(parts) >= 6 and parts[5] == "1"
        if typ == "role":
            roles.append({"role": name, "agent": extra, "drift": drift == "1", "hl": hl})
        elif typ == "team":
            try:
                h = int(heat)
            except ValueError:
                h = 0
            teams.append({"name": name, "globs": extra, "heat": h, "members": []})
        elif typ == "teammember":
            # name = nome team; extra = "ruolo|agente"
            role_agent = extra.split("|", 1)
            r = role_agent[0]
            for t in teams:
                if t["name"] == name:
                    t["members"].append({"role": r, "drift": drift == "1"})
                    break
    return roles, teams

# palette retro (indice ciclato per stanza)
PALETTE = [
    ("#7b6cd9", 141),  # viola
    ("#4a9d6e", 71),   # verde
    ("#c9803a", 173),  # arancio
    ("#3a8cc9", 74),   # azzurro
    ("#b0505a", 131),  # rosso mattone
    ("#5aa0a0", 66),   # teal
    ("#9d6cb0", 139),  # magenta
    ("#8a8a3a", 100),  # oliva
]
HEAT_TINT_ANSI = {0: 238, 1: 179, 2: 208}  # cold grigio / warm giallo / hot arancio

def short(s, n):
    s = s.strip()
    return s if len(s) <= n else s[: n - 1] + "…"

# ---------------------------------------------------------------- ANSI ----
def esc(code):
    return f"\033[{code}m"

def ansi_room(title, subtitle, cells, color256, heat, nocolor, empty_label="(vuota)"):
    # cella = (label, drift). Disegna una stanza box con scrivanie a 2 colonne.
    W = 30
    def c(s, code):
        return s if nocolor else esc(f"38;5;{code}") + s + esc("0")
    top_code = HEAT_TINT_ANSI.get(heat, color256)
    lines = []
    bar = "─" * (W - 2)
    lines.append(c("┌" + bar + "┐", color256))
    # banda titolo colorata
    t = short(title, W - 4).center(W - 2)
    lines.append(c("│", color256) + (t if nocolor else esc(f"48;5;{top_code}") + esc("38;5;16") + t + esc("0")) + c("│", color256))
    if subtitle:
        st = short(subtitle, W - 4).center(W - 2)
        lines.append(c("│" + st + "│", color256))
    lines.append(c("├" + bar + "┤", color256))
    # scrivanie: 2 per riga, avatar half-block + name tag
    i = 0
    while i < len(cells):
        pair = cells[i:i+2]
        # riga avatar
        row_av = ""
        row_tag = ""
        for cell in pair:
            label, drift = cell[0], cell[1]
            hl = cell[2] if len(cell) > 2 else False
            av = "▄▀" if not drift else "⚠▀"
            marker = "*" if hl else " "
            tag = short(label, 11)
            slot_av = (marker + "[" + (av) + "]").ljust(14)
            slot_tag = (("»" if hl else " ") + tag).ljust(14)
            row_av += slot_av
            row_tag += slot_tag
        row_av = row_av.ljust(W - 2)[:W-2]
        row_tag = row_tag.ljust(W - 2)[:W-2]
        lines.append(c("│", color256) + (row_av if nocolor else esc(f"38;5;{color256}") + row_av + esc("0")) + c("│", color256))
        lines.append(c("│", color256) + row_tag + c("│", color256))
        i += 2
    if not cells:
        empty = short(empty_label, W - 2).center(W - 2)
        lines.append(c("│" + empty + "│", color256))
    lines.append(c("└" + bar + "┘", color256))
    return lines, W

def render_ansi(roles, teams, project, nocolor):
    out = []
    title = f"  VISIONE AZIENDA · {project}  "
    if not nocolor:
        title = esc("1;38;5;231") + esc("48;5;240") + title + esc("0")
    out.append(title)
    out.append("")

    rooms = []
    # stanza rosa
    cells = [(f"{short(r['role'],10)}", r["drift"], r.get("hl", False)) for r in roles]
    rooms.append(("Ufficio · la Rosa", "ruolo → agente", cells, PALETTE[0][1], 0, "(nessun ruolo)"))
    # stanze team — con la loro rosa dentro (fallback: eredita rosa progetto)
    for idx, t in enumerate(teams):
        col = PALETTE[(idx + 1) % len(PALETTE)][1]
        sub = short(t["globs"], 26)
        tcells = [(short(m["role"], 10), m["drift"], False) for m in t["members"]]
        rooms.append((t["name"], sub, tcells, col, t["heat"], "(eredita rosa progetto)"))

    # rendi ogni stanza in blocco-righe, poi affianca 2 per riga (il trucco:
    # trasponi gli array di righe). ponytail: 2 stanze per fila, wrap.
    rendered = []
    for (ti, st, ce, co, he, el) in rooms:
        lines, w = ansi_room(ti, st, ce, co, he, nocolor, el)
        rendered.append(lines)

    PERROW = 2
    for i in range(0, len(rendered), PERROW):
        group = rendered[i:i+PERROW]
        h = max(len(b) for b in group)
        for b in group:
            b += [" " * _vis_len(b[0], nocolor)] * (h - len(b))  # pad verticale
        for row in range(h):
            out.append("  ".join(b[row] for b in group))
        out.append("")

    # legenda
    leg = "Legenda: ▄▀ agente · ⚠ drift (agente non su disco)"
    if teams and any(t["heat"] for t in teams):
        leg += " · stanza: cold/warm/hot = attività git 90g"
    out.append(leg if nocolor else esc("2") + leg + esc("0"))
    return "\n".join(out)

def _vis_len(s, nocolor):
    # lunghezza visibile (approssima: se nocolor, len; altrimenti conta box width)
    if nocolor:
        return len(s)
    # rimuovi escape per stimare
    import re
    return len(re.sub(r"\033\[[0-9;]*m", "", s))

# ----------------------------------------------------------------- SVG ----
def render_svg(roles, teams, project):
    TILE = 16
    pad = 20
    room_w, room_h = 240, 150
    per_row = 2
    rooms = []
    cells = [(short(r["role"], 14), r["drift"], r.get("hl", False)) for r in roles]
    rooms.append(("Ufficio · la Rosa", "ruolo → agente", cells, PALETTE[0][0], 0, "(nessun ruolo)"))
    for idx, t in enumerate(teams):
        tcells = [(short(m["role"], 14), m["drift"], False) for m in t["members"]]
        rooms.append((t["name"], short(t["globs"], 30), tcells, PALETTE[(idx+1) % len(PALETTE)][0], t["heat"], "(eredita rosa progetto)"))

    cols = per_row
    rows = (len(rooms) + cols - 1) // cols
    W = pad + cols * (room_w + pad)
    H = pad + 40 + rows * (room_h + pad)
    heat_fill = {0: "#2b2b30", 1: "#5a4a20", 2: "#6a3a18"}

    s = []
    s.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" font-family="monospace">')
    s.append(f'<rect width="{W}" height="{H}" fill="#16161a"/>')
    # pattern floor
    s.append('<defs><pattern id="floor" width="16" height="16" patternUnits="userSpaceOnUse">'
             '<rect width="16" height="16" fill="#1e1e24"/>'
             '<rect width="8" height="8" fill="#22222a"/><rect x="8" y="8" width="8" height="8" fill="#22222a"/></pattern></defs>')
    s.append(f'<text x="{pad}" y="28" fill="#f0f0f5" font-size="20" font-weight="bold">VISIONE AZIENDA · {esc_xml(project)}</text>')

    for i, (title, sub, ce, color, heat, empty_label) in enumerate(rooms):
        rx = pad + (i % cols) * (room_w + pad)
        ry = pad + 40 + (i // cols) * (room_h + pad)
        floor = heat_fill.get(heat, "#1e1e24") if heat else "url(#floor)"
        s.append(f'<rect x="{rx}" y="{ry}" width="{room_w}" height="{room_h}" fill="{floor}" stroke="{color}" stroke-width="3" rx="4"/>')
        s.append(f'<rect x="{rx}" y="{ry}" width="{room_w}" height="24" fill="{color}"/>')
        s.append(f'<text x="{rx+8}" y="{ry+17}" fill="#101014" font-size="13" font-weight="bold">{esc_xml(title)}</text>')
        if sub:
            s.append(f'<text x="{rx+8}" y="{ry+40}" fill="#9a9aa5" font-size="10">{esc_xml(sub)}</text>')
        # scrivanie: griglia
        dx, dy = rx + 14, ry + 52
        for j, cell in enumerate(ce):
            label, drift = cell[0], cell[1]
            hl = cell[2] if len(cell) > 2 else False
            cx = dx + (j % 3) * 74
            cy = dy + (j // 3) * 44
            # highlight: alone dietro l'avatar
            if hl:
                s.append(f'<rect x="{cx+12}" y="{cy-4}" width="28" height="30" fill="none" stroke="#ffd94a" stroke-width="2" rx="4"/>')
            # desk
            s.append(f'<rect x="{cx}" y="{cy+18}" width="52" height="12" fill="#3a3a44" rx="2"/>')
            # avatar (testa+corpo pixel)
            head = "#d9a066" if not drift else "#c0392b"
            s.append(f'<rect x="{cx+18}" y="{cy}" width="16" height="16" fill="{head}"/>')
            s.append(f'<rect x="{cx+16}" y="{cy+14}" width="20" height="8" fill="{color}"/>')
            if drift:
                s.append(f'<text x="{cx+36}" y="{cy+10}" fill="#e74c3c" font-size="12">⚠</text>')
            # name tag
            s.append(f'<text x="{cx+26}" y="{cy+42}" fill="#e0e0e8" font-size="9" text-anchor="middle">{esc_xml(label)}</text>')
        if not ce:
            s.append(f'<text x="{rx+room_w//2}" y="{ry+room_h//2+20}" fill="#55555f" font-size="11" text-anchor="middle">{esc_xml(empty_label)}</text>')

    # legenda
    ly = H - 8
    s.append(f'<text x="{pad}" y="{ly}" fill="#8a8a95" font-size="10">▄ agente  ⚠ drift  ·  stanza tint = attività git 90g (con --heat)</text>')
    s.append('</svg>')
    return "\n".join(s)

def esc_xml(s):
    return (s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
             .replace('"', "&quot;"))

def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "ansi"
    nocolor = (len(sys.argv) > 2 and sys.argv[2] == "1")
    project = sys.argv[3] if len(sys.argv) > 3 else "azienda"
    roles, teams = read_model()
    if mode == "svg":
        sys.stdout.write(render_svg(roles, teams, project) + "\n")
    else:
        sys.stdout.write(render_ansi(roles, teams, project, nocolor) + "\n")

if __name__ == "__main__":
    main()
