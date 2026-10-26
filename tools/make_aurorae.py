#!/usr/bin/env python3
"""DotGrid window decorations (Aurorae): a flat title bar in the theme colours,
a thin frame and dot-matrix buttons.

  python3 tools/make_aurorae.py [OUTDIR]      default: assets/aurorae

Writes DotGrid (day) and DotGrid-Dark (night); dotgrid-theme switches between
them. Buttons are 7x7 dot glyphs; hover inverts the button, pressed dims it,
the close button turns red on hover.
"""
import os
import sys

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "assets", "aurorae")

THEMES = {
    "DotGrid": dict(title="#d6cdbc", title_inactive="#cdc4b3", ink="#161614", ink_inactive="#8a8272",
                    border="#a89f8c", border_inactive="#c0b7a6", red="#c85a50"),
    "DotGrid-Dark": dict(title="#141413", title_inactive="#0e0e0d", ink="#e8e0d0", ink_inactive="#5c5a54",
                         border="#3a3935", border_inactive="#242321", red="#c85a50"),
}

B = 2            # frame width
T = 30           # title area height (TitleEdgeTop + TitleHeight + TitleEdgeBottom)
BTN = 22         # button box

GLYPHS = {
    "close": """
        #.....#
        .#...#.
        ..#.#..
        ...#...
        ..#.#..
        .#...#.
        #.....#
    """,
    "maximize": """
        #######
        #.....#
        #.....#
        #.....#
        #.....#
        #.....#
        #######
    """,
    "restore": """
        ..#####
        ..#...#
        #####.#
        #...#.#
        #...###
        #...#..
        #####..
    """,
    "minimize": """
        .......
        .......
        .......
        .......
        .......
        .......
        #######
    """,
    "alldesktops": """
        #.#.#.#
        .......
        #.#.#.#
        .......
        #.#.#.#
        .......
        #.#.#.#
    """,
    "keepabove": """
        ...#...
        ..###..
        .#.#.#.
        #..#..#
        ...#...
        ...#...
        ...#...
    """,
    "keepbelow": """
        ...#...
        ...#...
        ...#...
        #..#..#
        .#.#.#.
        ..###..
        ...#...
    """,
    "shade": """
        #######
        .......
        ...#...
        ..###..
        .#####.
        .......
        .......
    """,
    "help": """
        .#####.
        #.....#
        ......#
        ...###.
        ...#...
        .......
        ...#...
    """,
}


def cells(art):
    rows = [r.strip() for r in art.strip().splitlines() if r.strip()]
    assert len(rows) == 7 and all(len(r) == 7 for r in rows), art
    return [(x, y) for y, r in enumerate(rows) for x, c in enumerate(r) if c == "#"]


def glyph_rects(glyph, x0, color, box=BTN):
    pitch = 2
    size = 7 * pitch
    off = (box - size) / 2
    return "".join(f'<rect x="{x0 + off + x * pitch + 0.15:.2f}" y="{off + y * pitch + 0.15:.2f}" width="1.7" height="1.7" fill="{color}"/>'
                   for x, y in cells(glyph))


def button_svg(name, t):
    """five states side by side, each a BTN x BTN element."""
    g = GLYPHS[name]
    states = []
    hover_bg = t["red"] if name == "close" else t["ink"]
    hover_fg = "#e8e0d0" if name == "close" else t["title"]
    variants = (
        ("active", None, t["ink"]),
        ("inactive", None, t["ink_inactive"]),
        ("hover", hover_bg, hover_fg),
        ("pressed", t["border"], t["ink"]),
        ("deactivated", None, t["ink_inactive"]),
    )
    for i, (state, bg, fg) in enumerate(variants):
        x0 = i * (BTN + 4)
        body = f'<rect x="{x0}" y="0" width="{BTN}" height="{BTN}" fill="{bg or "#000"}" fill-opacity="{1 if bg else 0}"/>'
        body += glyph_rects(g, x0, fg)
        states.append(f'<g id="{state}-center">{body}</g>')
    w = 5 * (BTN + 4)
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{BTN}" viewBox="0 0 {w} {BTN}">{"".join(states)}</svg>\n'


def frame_svg(t):
    """9-slice frame for active, inactive and maximized windows."""
    parts = []
    y_rows = 0

    def slice_set(prefix, title, border, frame):
        nonlocal y_rows
        y = y_rows
        w = 10
        pieces = {
            "topleft": (0, y, B, T), "top": (B, y, w, T), "topright": (B + w, y, B, T),
            "left": (0, y + T, B, w), "center": (B, y + T, w, w), "right": (B + w, y + T, B, w),
            "bottomleft": (0, y + T + w, B, B), "bottom": (B, y + T + w, w, B), "bottomright": (B + w, y + T + w, B, B),
        }
        for key, (x, yy, ww, hh) in pieces.items():
            fill = title if key in ("topleft", "top", "topright") else border
            if key == "center":
                # a framed window covers the centre with its content, so it stays
                # empty; a maximized title bar is drawn from the centre alone
                # (no borders), so there it is the title bar
                fill, op = title, (0 if frame else 1)
            else:
                op = 1
            inner = f'<rect x="{x}" y="{yy}" width="{ww}" height="{hh}" fill="{fill}" fill-opacity="{op}"/>'
            if frame and key in ("topleft", "top", "topright"):
                # a 1 px outline on the outer edge and a separator under the title
                inner += f'<rect x="{x}" y="{yy}" width="{ww}" height="1" fill="{border}"/>'
                inner += f'<rect x="{x}" y="{yy + hh - 1}" width="{ww}" height="1" fill="{border}"/>'
                if key == "topleft":
                    inner += f'<rect x="{x}" y="{yy}" width="1" height="{hh}" fill="{border}"/>'
                if key == "topright":
                    inner += f'<rect x="{x + ww - 1}" y="{yy}" width="1" height="{hh}" fill="{border}"/>'
            parts.append(f'<g id="{prefix}-{key}">{inner}</g>')
        y_rows += T + w + B + 6

    slice_set("decoration", t["title"], t["border"], True)
    slice_set("decoration-inactive", t["title_inactive"], t["border_inactive"], True)
    slice_set("decoration-maximized", t["title"], t["border"], False)
    slice_set("decoration-maximized-inactive", t["title_inactive"], t["border_inactive"], False)
    w = 2 * B + 10
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{y_rows}" viewBox="0 0 {w} {y_rows}" shape-rendering="crispEdges">{"".join(parts)}</svg>\n'


def rc(t):
    return f"""[General]
ActiveTextColor={t['ink']}
InactiveTextColor={t['ink_inactive']}
TitleAlignment=Center
TitleVerticalAlignment=Center
Animation=0
Shadow=false
DecorationPosition=0

[Layout]
BorderLeft={B}
BorderRight={B}
BorderBottom={B}
TitleEdgeTop=4
TitleEdgeBottom=4
TitleEdgeLeft=6
TitleEdgeRight=6
TitleEdgeTopMaximized=4
TitleEdgeBottomMaximized=4
TitleEdgeLeftMaximized=6
TitleEdgeRightMaximized=6
TitleBorderLeft=8
TitleBorderRight=8
TitleHeight={T - 8}
ButtonWidth={BTN}
ButtonHeight={BTN}
ButtonSpacing=4
ButtonMarginTop=0
ExplicitButtonSpacer=10
PaddingTop=0
PaddingBottom=0
PaddingLeft=0
PaddingRight=0
"""


def main():
    for name, t in THEMES.items():
        d = os.path.join(OUT, name)
        os.makedirs(d, exist_ok=True)
        with open(os.path.join(d, "decoration.svg"), "w") as f:
            f.write(frame_svg(t))
        for b in GLYPHS:
            with open(os.path.join(d, f"{b}.svg"), "w") as f:
                f.write(button_svg(b, t))
        with open(os.path.join(d, f"{name}rc"), "w") as f:
            f.write(rc(t))
        with open(os.path.join(d, "metadata.desktop"), "w") as f:
            f.write(f"[Desktop Entry]\nName={name.replace('-', ' ')}\nComment=Flat title bar with dot-matrix buttons\n"
                    f"X-KDE-PluginInfo-Name={name}\nX-KDE-PluginInfo-Author=DotGrid\nX-KDE-PluginInfo-Version=1.0\n"
                    f"X-KDE-PluginInfo-License=GPL\nX-Plasma-API=javascript\nX-KDE-ServiceTypes=KWin/Decoration\n")
        print(f"aurorae {name}: decoration + {len(GLYPHS)} buttons")


if __name__ == "__main__":
    main()
