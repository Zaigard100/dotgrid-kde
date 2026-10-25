#!/usr/bin/env python3
"""DotGrid icon themes: every icon is a dot matrix, like the wallpaper.

  python3 tools/make_icons.py [OUTDIR]      default: assets/icons

Writes two themes, DotGrid (day) and DotGrid-Dark (night):
- symbolic icons (tray, menus): 8x8 cells, drawn in the colour-scheme
  text colour (KDE recolours them, the same file serves day and night).
  For every family the names are taken from Breeze, so all levels and
  variants (battery-040-charging-profile-powersave-symbolic, ...) exist.
- application / place icons: a tile in the theme colours with the dot grid
  and a 12x12 glyph.
Anything not drawn here comes from Breeze / Breeze Dark (Inherits).
"""
import os
import re
import sys

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "assets", "icons")
BREEZE = "/usr/share/icons/breeze"

THEMES = {
    # DotGrid-Auto (tools/dotify_icons.py) covers everything else as a dot matrix
    "DotGrid": dict(name="DotGrid", inherits="DotGrid-Auto,breeze,hicolor", tile="#d6cdbc", ink="#161614",
                    grid="#a89f8c", edge="#161614", text="#161614"),
    "DotGrid-Dark": dict(name="DotGrid Dark", inherits="DotGrid-Auto,breeze-dark,hicolor", tile="#161614", ink="#e8e0d0",
                         grid="#3a3935", edge="#5c5a54", text="#e8e0d0"),
}


def bitmap(art):
    rows = [r.strip() for r in art.strip().splitlines() if r.strip()]
    return [[c for c in r] for r in rows]


# ---------------------------------------------------------------------------
# 8x8 symbolic glyphs. '#' full, '+' dim (40%), '.' empty.
# ---------------------------------------------------------------------------

def battery(level, charging):
    # body 7x5 (rows 2..6), cap at column 7; inside 5x3 filled by level
    g = [list("........") for _ in range(8)]
    for x in range(7):
        g[2][x] = g[6][x] = "#"
    for y in range(2, 7):
        g[y][0] = g[y][6] = "#"
    g[3][7] = g[4][7] = g[5][7] = "#"
    cols = round(level / 100 * 5)
    for y in (3, 4, 5):
        for i in range(5):
            g[y][1 + i] = "#" if i < cols else "."
    if level <= 10 and not charging:
        g[4][3] = "#"                       # an alarm dot in the empty body
    if charging:                            # bolt above the body
        g[0][4] = g[1][3] = g[0][3] = "#"
    return g


def wifi(strength, mark=""):
    """4 rising bars; strength 0..4 lit, the rest dim. mark: limited/locked/off."""
    g = [list("........") for _ in range(8)]
    heights = (2, 4, 6, 8)
    for i, h in enumerate(heights):
        x = i * 2
        for y in range(8 - h, 8):
            g[y][x] = "#" if i < strength else "+"
    if mark == "limited":
        g[0][1] = g[1][1] = g[3][1] = "#"
    elif mark == "locked":
        for y, x in ((0, 0), (0, 1), (0, 2), (1, 0), (1, 2), (2, 0), (2, 1), (2, 2)):
            g[y][x] = "#"
    elif mark == "off":
        for i in range(4):
            g[i][i] = g[i][3 - i] = "#"
    return g


def volume(level, muted=False, mark=""):
    g = bitmap("""
        ..#.....
        .##.....
        ###.....
        ###.....
        ###.....
        ###.....
        .##.....
        ..#.....
    """)
    if muted:
        for i in range(4):
            g[2 + i][4 + i] = g[5 - i][4 + i] = "#"
        return g
    waves = [(4, (3, 4)), (5, (2, 5)), (6, (1, 6)), (7, (0, 7))]
    lit = {0: 0, 1: 1, 2: 2, 3: 4}[level]
    for i, (x, (a, b)) in enumerate(waves):
        for y in range(a, b + 1):
            g[y][x] = "#" if i < lit else "+"
    if mark:
        g[0][6] = g[1][6] = g[2][6] = "#"
        g[4][6] = "#"
    return g


GLYPHS = {
    "logo": bitmap("""
        ########
        #......#
        #.####.#
        #.#..#.#
        #.#..#.#
        #.####.#
        #......#
        ########
    """),
    "wired": bitmap("""
        ..#..#..
        ..#..#..
        .######.
        .######.
        .######.
        ..####..
        ...##...
        ...##...
    """),
    "wired-off": bitmap("""
        ..#..#..
        ..#..#..
        .##+###.
        .#+#+##.
        .##+###.
        ..####..
        ...##...
        ...##...
    """),
    "offline": bitmap("""
        #......#
        .#....#.
        ..#..#..
        ...##...
        ...##...
        ..#..#..
        .#....#.
        #......#
    """),
    "flightmode": bitmap("""
        ...##...
        ...##...
        ..####..
        ########
        ...##...
        ...##...
        ..####..
        .######.
    """),
    "bell": bitmap("""
        ...##...
        ..####..
        .######.
        .######.
        .######.
        ########
        ........
        ...##...
    """),
    "bell-active": bitmap("""
        ...##.##
        ..####.#
        .######.
        .######.
        .######.
        ########
        ........
        ...##...
    """),
    "bell-off": bitmap("""
        #..##...
        .#####..
        .##.###.
        .###.##.
        .####.#.
        ######.#
        ........
        ...##...
    """),
    "bell-empty": bitmap("""
        ...##...
        ..#..#..
        .#....#.
        .#....#.
        .#....#.
        ########
        ........
        ...##...
    """),
    "sun": bitmap("""
        #..#..#.
        .#.#.#..
        ..###...
        ###.###.
        ..###...
        .#.#.#..
        #..#..#.
        ........
    """),
    "sun-low": bitmap("""
        ........
        ...#....
        ..###...
        .##.##..
        ..###...
        ...#....
        ........
        ........
    """),
    "bluetooth": bitmap("""
        ...#....
        ...##...
        .#.#.#..
        ..###...
        ..###...
        .#.#.#..
        ...##...
        ...#....
    """),
    "bluetooth-off": bitmap("""
        ...+....
        ...++...
        .+.+.+..
        ..+++...
        ..+++...
        .+.+.+..
        ...++...
        ...+....
    """),
    "keyboard": bitmap("""
        ........
        ########
        #.#.#.##
        ########
        ##.#.#.#
        ########
        #......#
        ########
    """),
    "mouse": bitmap("""
        ..####..
        .##.###.
        .##.###.
        .######.
        .#....#.
        .#....#.
        .#....#.
        ..####..
    """),
    "clipboard": bitmap("""
        ..####..
        ##.##.##
        #......#
        #.####.#
        #......#
        #.###..#
        #......#
        ########
    """),
    "drive": bitmap("""
        ..####..
        ..#..#..
        .######.
        .#....#.
        .#.##.#.
        .#.##.#.
        .#....#.
        .######.
    """),
    "eject": bitmap("""
        ...##...
        ..####..
        .######.
        ########
        ........
        ########
        ########
        ........
    """),
    "phone": bitmap("""
        .######.
        .#....#.
        .#....#.
        .#....#.
        .#....#.
        .#....#.
        .######.
        .##..##.
    """),
    "play": bitmap("""
        .#......
        .##.....
        .###....
        .####...
        .####...
        .###....
        .##.....
        .#......
    """),
    "pause": bitmap("""
        ........
        .##..##.
        .##..##.
        .##..##.
        .##..##.
        .##..##.
        .##..##.
        ........
    """),
    "stop": bitmap("""
        ........
        .######.
        .######.
        .######.
        .######.
        .######.
        .######.
        ........
    """),
    "moon": bitmap("""
        ..####..
        .###....
        ###.....
        ###.....
        ###.....
        ###.....
        .###....
        ..####..
    """),
    "moon-off": bitmap("""
        ..++++..
        .+++....
        +++.....
        +++.....
        +++.....
        +++.....
        .+++....
        ..++++..
    """),
    "display": bitmap("""
        ########
        #......#
        #......#
        #......#
        ########
        ...##...
        ..####..
        ........
    """),
}


def symbolic_svg(g):
    n = len(g)
    cell = 16 / n
    sq = cell * 0.84
    off = (cell - sq) / 2
    parts = []
    for y, row in enumerate(g):
        for x, c in enumerate(row):
            if c == ".":
                continue
            op = "" if c == "#" else ' opacity="0.4"'
            parts.append(f'<rect x="{x * cell + off:.2f}" y="{y * cell + off:.2f}" width="{sq:.2f}" height="{sq:.2f}" rx="{sq * 0.18:.2f}"{op}/>')
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16">'
            '<style id="current-color-scheme" type="text/css">.ColorScheme-Text{color:#232629;}</style>'
            '<g class="ColorScheme-Text" fill="currentColor">' + "".join(parts) + "</g></svg>\n")


def breeze_names(pattern):
    names = set()
    for root, _, files in os.walk(BREEZE):
        for f in files:
            if f.endswith(".svg") and re.match(pattern, f[:-4]):
                names.add(f[:-4])
    return sorted(names)


def glyph_for(n):
    """The dot-matrix glyph for an icon name, or None if DotGrid has none."""
    n = re.sub(r"-symbolic(-rtl)?$|-rtl$", "", n)
    if re.match(r"^battery-\d{3}", n):
        m = re.match(r"battery-(\d{3})(-charging)?", n)
        return battery(int(m.group(1)), bool(m.group(2)))
    if re.match(r"^battery-(missing|empty|caution|low|full|good|ac-adapter|ups)", n):
        return battery(100 if any(w in n for w in ("full", "good", "ac", "ups")) else 0, "ac" in n)
    if n.startswith("network-wireless"):
        m = re.search(r"-(\d+)(?:-|$)", n)
        level = None
        if m and "connected" in n:
            level = {"00": 0, "25": 1, "50": 2, "75": 3, "100": 4}.get(m.group(1))
        elif m:
            level = {"0": 0, "20": 1, "40": 2, "60": 3, "80": 4, "100": 4}.get(m.group(1))
        for word, lv in (("none", 0), ("weak", 1), ("ok", 2), ("good", 3), ("excellent", 4)):
            if f"signal-{word}" in n:
                level = lv
        mark = "limited" if "limited" in n else "locked" if "locked" in n else ""
        if any(w in n for w in ("disconnected", "offline", "unavailable", "deactivated")):
            level, mark = 0, "off"
        if level is None:
            level = 4 if "acquiring" not in n else 2
        return wifi(level, mark)
    if n.startswith("network-wired"):
        return GLYPHS["wired-off"] if any(w in n for w in ("disconnected", "unavailable")) else GLYPHS["wired"]
    if re.match(r"^network-(offline|disconnect)", n):
        return GLYPHS["offline"]
    if re.match(r"^(network-)?flightmode", n):
        return GLYPHS["flightmode"]
    if n.startswith("audio-volume"):
        muted = "muted" in n
        level = 0 if muted else 1 if "low" in n else 2 if "medium" in n else 3
        return volume(level, muted, "!" if ("danger" in n or "warning" in n) else "")
    if n.startswith("notification"):
        if "disabled" in n:
            return GLYPHS["bell-off"]
        if "active" in n and "inactive" not in n:
            return GLYPHS["bell-active"]
        return GLYPHS["bell-empty"] if "empty" in n else GLYPHS["bell"]
    if re.match(r"^(brightness|high-brightness|low-brightness)", n):
        return GLYPHS["sun-low"] if "low" in n else GLYPHS["sun"]
    if n.startswith("preferences-system-bluetooth") or n == "network-bluetooth":
        return GLYPHS["bluetooth-off"] if "inactive" in n else GLYPHS["bluetooth"]
    if re.match(r"^(input-keyboard|preferences-desktop-keyboard|keyboard-layout|input-(caps|num|combo)-on)", n):
        return GLYPHS["keyboard"]
    if n.startswith("input-mouse"):
        return GLYPHS["mouse"]
    if re.match(r"^(klipper|edit-paste)", n):
        return GLYPHS["clipboard"]
    if re.match(r"^(device-notifier|drive-removable-media|drive$)", n):
        return GLYPHS["drive"]
    if n.startswith("media-eject"):
        return GLYPHS["eject"]
    if n.startswith("kdeconnect"):
        return GLYPHS["phone"]
    if re.match(r"^media-playback-(start|playing)", n):
        return GLYPHS["play"]
    if n.startswith("media-playback-paus"):
        return GLYPHS["pause"]
    if n.startswith("media-playback-stop"):
        return GLYPHS["stop"]
    if n.startswith("preferences-desktop-display"):
        return GLYPHS["display"]
    if n.startswith("redshift-status"):
        return GLYPHS["sun"] if n.endswith("day") else GLYPHS["moon-off"] if n.endswith("off") else GLYPHS["moon"]
    if n in ("start-here-kde", "start-here-kde-plasma", "start-here"):
        return GLYPHS["logo"]
    return None


FAMILIES = (r"^battery-", r"^network-(wireless|wired|offline|disconnect|flightmode)", r"^audio-volume",
            r"^notification", r"^(brightness|high-brightness|low-brightness)", r"^preferences-system-bluetooth",
            r"^(input-keyboard|preferences-desktop-keyboard|input-mouse)", r"^(klipper|edit-paste)",
            r"^(device-notifier|drive-removable-media|media-eject)", r"^kdeconnect",
            r"^media-playback-(start|playing|paus|stop)", r"^preferences-desktop-display", r"^redshift-status")


def symbolic_icons():
    """name -> glyph, for every Breeze name of each family."""
    out = {}
    for fam in FAMILIES:
        for n in breeze_names(fam):
            g = glyph_for(n)
            if g is not None:
                out[n] = g
    for n in ("start-here-kde-symbolic", "start-here-kde-plasma-symbolic", "start-here-symbolic"):
        out[n] = GLYPHS["logo"]
    return out


# ---------------------------------------------------------------------------
# Plasma style: the panel and tray take many icons from the Plasma style's
# own icons/*.svgz before the icon theme; DotGrid replaces those files.
# ---------------------------------------------------------------------------

PLASMA_DEFAULT = "/usr/share/plasma/desktoptheme/default/icons"


def glyph_group(g, box, dx):
    """<g> of one glyph scaled into a box x box square at x offset dx."""
    n = len(g)
    cell = box / n
    sq = cell * 0.84
    off = (cell - sq) / 2
    parts = [f'<rect x="{dx}" y="0" width="{box}" height="{box}" fill="#000" fill-opacity="0"/>']
    for y, row in enumerate(g):
        for x, c in enumerate(row):
            if c != ".":
                op = "" if c == "#" else ' opacity="0.4"'
                parts.append(f'<rect class="ColorScheme-Text" fill="currentColor" x="{dx + x * cell + off:.2f}" '
                             f'y="{y * cell + off:.2f}" width="{sq:.2f}" height="{sq:.2f}" rx="{sq * 0.18:.2f}"{op}/>')
    return "".join(parts)


def plasma_style(out):
    import gzip
    root = os.path.join(out, "plasma-style", "dotgrid")
    os.makedirs(os.path.join(root, "icons"), exist_ok=True)
    files = 0
    for f in sorted(os.listdir(PLASMA_DEFAULT)):
        if not f.endswith(".svgz"):
            continue
        with gzip.open(os.path.join(PLASMA_DEFAULT, f)) as fh:
            ids = set(re.findall(r'id="([a-zA-Z0-9_.-]+)"', fh.read().decode("utf-8", "replace")))
        elements, x = [], 0
        for i in sorted(ids):
            m = re.match(r"^(\d+)-\1-(.+)$", i)
            box, base = (int(m.group(1)), m.group(2)) if m else (16, i)
            g = glyph_for(base)
            if g is None:
                continue
            elements.append(f'<g id="{i}">{glyph_group(g, box, x)}</g>')
            x += box + 4
        if not elements:
            continue
        svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{x}" height="32" viewBox="0 0 {x} 32">'
               '<style id="current-color-scheme" type="text/css">.ColorScheme-Text{color:#232629;}</style>'
               + "".join(elements) + "</svg>\n")
        with gzip.open(os.path.join(root, "icons", f), "wb") as fh:
            fh.write(svg.encode())
        files += 1
    with open(os.path.join(root, "metadata.json"), "w") as fh:
        fh.write("""{
    "KPlugin": {
        "Authors": [{ "Name": "DotGrid" }],
        "Description": "Breeze with DotGrid dot-matrix tray icons; colours follow the colour scheme",
        "Id": "dotgrid",
        "License": "LGPL-2.1+",
        "Name": "DotGrid",
        "Version": "1.0"
    },
    "X-Plasma-API-Minimum-Version": "6.0"
}
""")
    return files


# ---------------------------------------------------------------------------
# 12x12 glyphs for the tiles (apps, places, devices)
# ---------------------------------------------------------------------------

TILE_GLYPHS = {
    "logo": """
        ############
        #..........#
        #..........#
        #...####...#
        #...#..#...#
        #...#..#...#
        #...#..#...#
        #...#..#...#
        #...####...#
        #..........#
        #..........#
        ############
    """,
    "folder": """
        ............
        ####........
        #..#........
        #..#########
        #..........#
        #..........#
        #..........#
        #..........#
        #..........#
        #..........#
        ############
        ............
    """,
    "home": """
        ............
        .....##.....
        ....####....
        ...######...
        ..########..
        .##########.
        ..##....##..
        ..##....##..
        ..##.##.##..
        ..##.##.##..
        ..########..
        ............
    """,
    "desktop": """
        ............
        ############
        #..........#
        #.#.#.#.#..#
        #..........#
        #.#.#.#.#..#
        #..........#
        ############
        .....##.....
        ....####....
        ...######...
        ............
    """,
    "documents": """
        ..#######...
        ..#.....##..
        ..#.....###.
        ..#.......#.
        ..#.#####.#.
        ..#.......#.
        ..#.#####.#.
        ..#.......#.
        ..#.####..#.
        ..#.......#.
        ..#########.
        ............
    """,
    "download": """
        ............
        .....##.....
        .....##.....
        .....##.....
        .....##.....
        ..########..
        ...######...
        ....####....
        .....##.....
        ............
        .##########.
        ............
    """,
    "music": """
        ............
        ......######
        ......######
        ......#....#
        ......#....#
        ......#....#
        ......#....#
        ...####.####
        ..#####.####
        ..#####.###.
        ...###......
        ............
    """,
    "pictures": """
        ............
        ############
        #..........#
        #.......##.#
        #.......##.#
        #...#......#
        #..###.....#
        #.#####.#..#
        ##########.#
        ############
        ............
        ............
    """,
    "videos": """
        ............
        ############
        #.#.#.#.#.##
        ############
        #...##.....#
        #...###....#
        #...####...#
        #...###....#
        #...##.....#
        ############
        #.#.#.#.#.##
        ############
    """,
    "templates": """
        ............
        ##.##.##.##.
        #..........#
        ............
        #..........#
        #..........#
        ............
        #..........#
        #..........#
        ............
        ##.##.##.##.
        ............
    """,
    "share": """
        ............
        .........##.
        ........####
        .......#.##.
        ......#.....
        .##..#......
        ####........
        .##..#......
        ......#.....
        .......#.##.
        ........####
        .........##.
    """,
    "trash": """
        ....####....
        ############
        ............
        .##########.
        .#.#..#..#..
        .#.#..#..#..
        .#.#..#..#..
        .#.#..#..#..
        .#.#..#..#..
        .#.#..#..#..
        .##########.
        ............
    """,
    "trash-full": """
        ....####....
        ############
        ..#.##.#.#..
        .##########.
        .##########.
        .#.#..#..#..
        .#.#..#..#..
        .#.#..#..#..
        .#.#..#..#..
        .#.#..#..#..
        .##########.
        ............
    """,
    "harddisk": """
        ............
        ............
        ############
        #..........#
        #..........#
        ############
        #..........#
        #.######.#.#
        #..........#
        ############
        ............
        ............
    """,
    "filemanager": """
        ............
        ####........
        #..#........
        #..#########
        #..........#
        #.#.#.#.#..#
        #..........#
        #.#.#.#.#..#
        #..........#
        #.#.#.#.#..#
        ############
        ............
    """,
    "browser": """
        ....####....
        ..##.##.##..
        .#...##...#.
        .#..#..#..#.
        #...#..#...#
        ############
        #...#..#...#
        .#..#..#..#.
        .#...##...#.
        ..##.##.##..
        ....####....
        ............
    """,
    "settings": """
        .....##.....
        ..#..##..#..
        ...######...
        ..##....##..
        .##..##..##.
        ####.##.####
        ####.##.####
        .##..##..##.
        ..##....##..
        ...######...
        ..#..##..#..
        .....##.....
    """,
    "terminal": """
        ............
        ############
        #..........#
        #.#........#
        #..#.......#
        #...#......#
        #..#.......#
        #.#..####..#
        #..........#
        ############
        ............
        ............
    """,
}

TILE_ICONS = {
    # launcher (non-symbolic names) and DotGrid apps
    "start-here-kde": "logo", "start-here-kde-plasma": "logo", "start-here": "logo",
    # places
    "folder": "folder", "inode-directory": "folder", "folder-open": "folder",
    "user-home": "home", "folder-home": "home",
    "user-desktop": "desktop", "folder-desktop": "desktop",
    "folder-documents": "documents", "folder-download": "download", "folder-downloads": "download",
    "folder-music": "music", "folder-pictures": "pictures", "folder-images": "pictures",
    "folder-videos": "videos", "folder-video": "videos", "folder-templates": "templates",
    "folder-publicshare": "share", "folder-public": "share",
    "user-trash": "trash", "user-trash-full": "trash-full", "trash-empty": "trash",
    "drive-harddisk": "harddisk", "drive-harddisk-root": "harddisk", "drive-harddisk-solidstate": "harddisk",
    # the pinned apps and terminals
    "system-file-manager": "filemanager", "org.kde.dolphin": "filemanager",
    "zen-browser": "browser", "web-browser": "browser", "internet-web-browser": "browser",
    "firefox": "browser", "chromium": "browser",
    "preferences-system": "settings", "systemsettings": "settings",
    "utilities-terminal": "terminal", "org.kde.konsole": "terminal", "kitty": "terminal",
    "terminal": "terminal",
}


def tile_svg(glyph, t):
    g = bitmap(TILE_GLYPHS[glyph])
    S, pad = 48, 6
    cell = (S - 2 * pad) / len(g)
    sq = cell * 0.82
    off = (cell - sq) / 2
    parts = [f'<rect x="1" y="1" width="46" height="46" rx="5" fill="{t["tile"]}" stroke="{t["edge"]}" stroke-width="1.5"/>']
    # the DotGrid dot grid in the background
    for y in range(len(g)):
        for x in range(len(g)):
            if g[y][x] != "#":
                cx, cy = pad + (x + 0.5) * cell, pad + (y + 0.5) * cell
                parts.append(f'<circle cx="{cx:.2f}" cy="{cy:.2f}" r="{cell * 0.12:.2f}" fill="{t["grid"]}"/>')
    for y, row in enumerate(g):
        for x, c in enumerate(row):
            if c == "#":
                parts.append(f'<rect x="{pad + x * cell + off:.2f}" y="{pad + y * cell + off:.2f}" '
                             f'width="{sq:.2f}" height="{sq:.2f}" rx="{sq * 0.15:.2f}" fill="{t["ink"]}"/>')
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">{"".join(parts)}</svg>\n'


DIRS = {"apps": "Applications", "places": "Places", "status": "Status", "devices": "Devices", "actions": "Actions"}
# Context= values as in Breeze (icon lookups match on them), for every directory
CONTEXT_NAMES = dict(DIRS, applets="Status", categories="Categories", emblems="Emblems", emotes="Emotes",
                     mimetypes="MimeTypes", preferences="Applications")


def write_index(root, t):
    dirs = sorted(d for d in os.listdir(os.path.join(root, "scalable")) if d in CONTEXT_NAMES)
    sections = "".join(f"\n[scalable/{d}]\nSize=48\nMinSize=8\nMaxSize=512\nType=Scalable\nContext={CONTEXT_NAMES[d]}\n"
                       for d in dirs)
    with open(os.path.join(root, "index.theme"), "w") as f:
        f.write(f"[Icon Theme]\nName={t['name']}\nComment=Dot-matrix icons for DotGrid\n"
                f"Inherits={t['inherits']}\nDirectories={','.join('scalable/' + d for d in dirs)}\n"
                f"FollowsColorScheme=true\n{sections}")


def context_dir(name):
    if name.startswith(("folder", "user-", "inode", "start-here", "trash")):
        return "places"
    if name.startswith(("drive", "device", "input-", "kdeconnect", "phone")):
        return "devices"
    if name.startswith(("media-", "edit-", "klipper")):
        return "actions"
    if name.startswith(("battery", "network", "audio", "notification", "brightness", "high-", "low-",
                        "preferences-system-bluetooth", "preferences-desktop-display", "redshift")):
        return "status"
    return "apps"


def write_theme(key, t, symbolic):
    root = os.path.join(OUT, key)
    for d in DIRS:
        os.makedirs(os.path.join(root, "scalable", d), exist_ok=True)
    count = 0
    for name, g in symbolic.items():
        with open(os.path.join(root, "scalable", context_dir(name), name + ".svg"), "w") as f:
            f.write(symbolic_svg(g))
        count += 1
    for name, glyph in TILE_ICONS.items():
        with open(os.path.join(root, "scalable", context_dir(name), name + ".svg"), "w") as f:
            f.write(tile_svg(glyph, t))
        count += 1
    write_index(root, t)
    return count


def check():
    for name, g in GLYPHS.items():
        assert len(g) == 8 and all(len(r) == 8 for r in g), f"8x8 glyph {name}"
    for name, art in TILE_GLYPHS.items():
        g = bitmap(art)
        assert len(g) == 12 and all(len(r) == 12 for r in g), f"12x12 glyph {name}"


def copy_shadowed(root, auto_root, own):
    """KDE tries shorter names (folder-git -> folder) inside a theme before it
    moves on to the inherited one, so a hand-drawn "folder" here would hide
    the dotted "folder-git" of DotGrid-Auto. Copy those longer names in."""
    import glob
    import shutil
    prefixes = tuple(n + "-" for n in own)
    copied = 0
    for path in glob.glob(os.path.join(auto_root, "scalable", "*", "*.svg")):
        name = os.path.basename(path)[:-4]
        if name in own or not name.startswith(prefixes):
            continue
        ctx = os.path.basename(os.path.dirname(path))
        os.makedirs(os.path.join(root, "scalable", ctx), exist_ok=True)
        shutil.copyfile(path, os.path.join(root, "scalable", ctx, name + ".svg"))
        copied += 1
    return copied


def main():
    check()
    symbolic = symbolic_icons()
    auto_root = os.path.join(OUT, "DotGrid-Auto")       # tools/dotify_icons.py, run first
    for key, t in THEMES.items():
        n = write_theme(key, t, symbolic)
        extra = ""
        if os.path.isdir(auto_root):
            extra = f", {copy_shadowed(os.path.join(OUT, key), auto_root, set(symbolic) | set(TILE_ICONS))} from DotGrid-Auto"
            write_index(os.path.join(OUT, key), t)      # the copies may add directories
        print(f"{key}: {n} icons{extra}")
    print(f"plasma style dotgrid: {plasma_style(OUT)} icon files")


if __name__ == "__main__":
    main()
