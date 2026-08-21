#!/usr/bin/env python3
# office_render.py — renderer for the "azienda view".
# Reads a TSV from stdin (TYPE \t name \t agent/glob \t heat \t drift) and draws
# a static top-down office: the ROSTER (role→agent) as desks in a room, and
# TEAMS as area-rooms. Two modes: ansi | svg.
#
# argv: mode(ansi|svg)  nocolor(0|1)  project_name
# Zero dependencies beyond the stdlib. Does not fail on partial input.

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
            # name = team name; extra = "role|agent"
            role_agent = extra.split("|", 1)
            r = role_agent[0]
            for t in teams:
                if t["name"] == name:
                    t["members"].append({"role": r, "drift": drift == "1"})
                    break
    return roles, teams

# retro palette (index cycled per room)
PALETTE = [
    ("#7b6cd9", 141),  # violet
    ("#4a9d6e", 71),   # green
    ("#c9803a", 173),  # orange
    ("#3a8cc9", 74),   # sky blue
    ("#b0505a", 131),  # brick red
    ("#5aa0a0", 66),   # teal
    ("#9d6cb0", 139),  # magenta
    ("#8a8a3a", 100),  # olive
]
HEAT_TINT_ANSI = {0: 238, 1: 179, 2: 208}  # cold gray / warm yellow / hot orange

def short(s, n):
    s = s.strip()
    return s if len(s) <= n else s[: n - 1] + "…"

# ---------------------------------------------------------------- ANSI ----
def esc(code):
    return f"\033[{code}m"

def ansi_room(title, subtitle, cells, color256, heat, nocolor, empty_label="(empty)"):
    # cell = (label, drift). Draws a room box with desks in 2 columns.
    W = 30
    def c(s, code):
        return s if nocolor else esc(f"38;5;{code}") + s + esc("0")
    top_code = HEAT_TINT_ANSI.get(heat, color256)
    lines = []
    bar = "─" * (W - 2)
    lines.append(c("┌" + bar + "┐", color256))
    # colored title band
    t = short(title, W - 4).center(W - 2)
    lines.append(c("│", color256) + (t if nocolor else esc(f"48;5;{top_code}") + esc("38;5;16") + t + esc("0")) + c("│", color256))
    if subtitle:
        st = short(subtitle, W - 4).center(W - 2)
        lines.append(c("│" + st + "│", color256))
    lines.append(c("├" + bar + "┤", color256))
    # desks: 2 per row, half-block avatar + name tag
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
    title = f"  AZIENDA VIEW · {project}  "
    if not nocolor:
        title = esc("1;38;5;231") + esc("48;5;240") + title + esc("0")
    out.append(title)
    out.append("")

    rooms = []
    # roster room
    cells = [(f"{short(r['role'],10)}", r["drift"], r.get("hl", False)) for r in roles]
    rooms.append(("Office · the Roster", "role → agent", cells, PALETTE[0][1], 0, "(no roles)"))
    # team rooms — with their own roster inside (fallback: inherits project roster)
    for idx, t in enumerate(teams):
        col = PALETTE[(idx + 1) % len(PALETTE)][1]
        sub = short(t["globs"], 26)
        tcells = [(short(m["role"], 10), m["drift"], False) for m in t["members"]]
        rooms.append((t["name"], sub, tcells, col, t["heat"], "(inherits project roster)"))

    # render each room (height already adaptive to content via ansi_room), then
    # pack in 2 masonry COLUMNS: each room goes into the shortest column →
    # no gaps under small rooms (layout fix, same as for the SVG).
    ROOM_W = 30
    rendered = []
    for (ti, st, ce, co, he, el) in rooms:
        lines, w = ansi_room(ti, st, ce, co, he, nocolor, el)
        rendered.append(lines)

    NCOL = 2
    columns = [[] for _ in range(NCOL)]   # each column = list of text lines
    col_h = [0] * NCOL
    for lines in rendered:
        c = col_h.index(min(col_h))       # shortest column
        columns[c].extend(lines)
        columns[c].append("")             # spacing between rooms
        col_h[c] += len(lines) + 1

    # lays the columns side by side row by row; pads to fixed width ROOM_W.
    blank = " " * ROOM_W
    maxrows = max((len(c) for c in columns), default=0)
    for r in range(maxrows):
        parts = []
        for c in range(NCOL):
            cell = columns[c][r] if r < len(columns[c]) else ""
            # pad to the room's visible width
            padn = ROOM_W - _vis_len(cell, nocolor)
            parts.append(cell + (" " * padn if padn > 0 else ""))
        out.append("  ".join(parts).rstrip())
    out.append("")

    # legend
    leg = "Legend: ▄▀ agent · ⚠ drift (agent not on disk)"
    if teams and any(t["heat"] for t in teams):
        leg += " · room: cold/warm/hot = git activity 90d"
    out.append(leg if nocolor else esc("2") + leg + esc("0"))
    return "\n".join(out)

def _vis_len(s, nocolor):
    # visible length (approximates: if nocolor, len; otherwise counts box width)
    if nocolor:
        return len(s)
    # strip escapes to estimate
    import re
    return len(re.sub(r"\033\[[0-9;]*m", "", s))

# ----------------------------------------------------------------- SVG ----
def render_svg(roles, teams, project):
    pad = 20
    room_w = 240
    DESK_W, DESK_H = 74, 44   # desk grid pitch
    HEAD_Y = 24               # title band
    BODY_TOP = 52             # offset of the first desk inside the room
    heat_fill = {0: "#2b2b30", 1: "#5a4a20", 2: "#6a3a18"}

    # --- room model ---
    raw = []
    cells = [(short(r["role"], 14), r["drift"], r.get("hl", False)) for r in roles]
    raw.append(("Office · the Roster", "role → agent", cells, PALETTE[0][0], 0, "(no roles)"))
    for idx, t in enumerate(teams):
        tcells = [(short(m["role"], 14), m["drift"], False) for m in t["members"]]
        raw.append((t["name"], short(t["globs"], 30), tcells, PALETTE[(idx+1) % len(PALETTE)][0], t["heat"], "(inherits project roster)"))

    # ADAPTIVE desk columns: 1 desk→1 col, 2→2, 3+→3. room_h = f(n desks).
    def desk_cols(n):
        return 1 if n <= 1 else (2 if n == 2 else 3)
    def room_height(ce):
        n = len(ce)
        if n == 0:
            return BODY_TOP + 30          # area-room/placeholder: short
        dcols = desk_cols(n)
        drows = (n + dcols - 1) // dcols
        return BODY_TOP + drows * DESK_H + 8

    sized = []  # (meta..., room_h, dcols)
    for (title, sub, ce, color, heat, el) in raw:
        sized.append((title, sub, ce, color, heat, el, room_height(ce), desk_cols(len(ce))))

    # --- MASONRY packing over 2 room columns: put each room in the shortest
    # column. Eliminates overflow (real height) and gaps (columns balanced by
    # height, not by row count). ---
    NCOL = 2
    col_x = [pad + c * (room_w + pad) for c in range(NCOL)]
    col_y = [pad + 40] * NCOL   # sotto il titolo pagina
    placed = []
    for room in sized:
        c = col_y.index(min(col_y))   # colonna più corta
        rx, ry = col_x[c], col_y[c]
        placed.append((rx, ry, room))
        col_y[c] += room[6] + pad     # room_h + pad

    W = pad + NCOL * (room_w + pad)
    H = max(col_y) + 12

    s = []
    s.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" font-family="monospace">')
    s.append(f'<rect width="{W}" height="{H}" fill="#16161a"/>')
    s.append('<defs><pattern id="floor" width="16" height="16" patternUnits="userSpaceOnUse">'
             '<rect width="16" height="16" fill="#1e1e24"/>'
             '<rect width="8" height="8" fill="#22222a"/><rect x="8" y="8" width="8" height="8" fill="#22222a"/></pattern></defs>')
    s.append(f'<text x="{pad}" y="28" fill="#f0f0f5" font-size="20" font-weight="bold">AZIENDA VIEW · {esc_xml(project)}</text>')

    for rx, ry, (title, sub, ce, color, heat, empty_label, rh, dcols) in placed:
        floor = heat_fill.get(heat, "#1e1e24") if heat else "url(#floor)"
        s.append(f'<rect x="{rx}" y="{ry}" width="{room_w}" height="{rh}" fill="{floor}" stroke="{color}" stroke-width="3" rx="4"/>')
        s.append(f'<rect x="{rx}" y="{ry}" width="{room_w}" height="{HEAD_Y}" fill="{color}"/>')
        s.append(f'<text x="{rx+8}" y="{ry+17}" fill="#101014" font-size="13" font-weight="bold">{esc_xml(title)}</text>')
        if sub:
            s.append(f'<text x="{rx+8}" y="{ry+40}" fill="#9a9aa5" font-size="10">{esc_xml(sub)}</text>')
        dx, dy = rx + 14, ry + BODY_TOP
        for j, cell in enumerate(ce):
            label, drift = cell[0], cell[1]
            hl = cell[2] if len(cell) > 2 else False
            cx = dx + (j % dcols) * DESK_W
            cy = dy + (j // dcols) * DESK_H
            if hl:
                s.append(f'<rect x="{cx+12}" y="{cy-4}" width="28" height="30" fill="none" stroke="#ffd94a" stroke-width="2" rx="4"/>')
            s.append(f'<rect x="{cx}" y="{cy+18}" width="52" height="12" fill="#3a3a44" rx="2"/>')
            head = "#d9a066" if not drift else "#c0392b"
            s.append(f'<rect x="{cx+18}" y="{cy}" width="16" height="16" fill="{head}"/>')
            s.append(f'<rect x="{cx+16}" y="{cy+14}" width="20" height="8" fill="{color}"/>')
            if drift:
                s.append(f'<text x="{cx+36}" y="{cy+10}" fill="#e74c3c" font-size="12">⚠</text>')
            s.append(f'<text x="{cx+26}" y="{cy+42}" fill="#e0e0e8" font-size="9" text-anchor="middle">{esc_xml(label)}</text>')
        if not ce:
            s.append(f'<text x="{rx+room_w//2}" y="{ry+rh//2+8}" fill="#55555f" font-size="11" text-anchor="middle">{esc_xml(empty_label)}</text>')

    s.append(f'<text x="{pad}" y="{H-8}" fill="#8a8a95" font-size="10">▄ agent  ⚠ drift  ·  room tint = git activity 90d (with --heat)</text>')
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
