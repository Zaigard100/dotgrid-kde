#!/usr/bin/env python3
"""DotGrid cursor theme: dot-matrix cursors in Xcursor format.

  python3 tools/make_cursors.py [OUTDIR]     default: assets/cursors

Every cursor is a 12x12 cell bitmap: cream cells with a dark outline (the
outline is derived from the fill), so it reads on the beige day and the black
night background. Cells become squares; from 4 px per cell on, the fill cells
get a 1 px gap, like the dot grid. Two formats:
- cursors_scalable/: SVG (KDE format), what KWin on Wayland uses; sharp at
  any scale, e.g. 1.45;
- cursors/: Xcursor bitmaps 24..96 px, for X11/XWayland programs (written
  straight, no xcursorgen needed).
Anything not drawn here comes from breeze_cursors.
"""
import json
import math
import os
import struct
import sys

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "assets", "cursors")
THEME = "DotGrid-cursors"
SIZES = (24, 32, 36, 48, 64, 72, 96)
OUTLINE = (0x16, 0x16, 0x14)
FILL = (0xe8, 0xe0, 0xd0)
DIM = (0x5c, 0x5a, 0x54)
N = 12


def mask(art):
    rows = [r.strip() for r in art.strip().splitlines() if r.strip()]
    assert len(rows) == N and all(len(r) == N for r in rows), art
    return {(x, y) for y, r in enumerate(rows) for x, c in enumerate(r) if c == "o"}


def cells(fill, dim=frozenset()):
    """cell -> colour; the outline is every cell touching the shape."""
    shape = set(fill) | set(dim)
    out = {}
    for (x, y) in shape:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                c = (x + dx, y + dy)
                if c not in shape and 0 <= c[0] < N and 0 <= c[1] < N:
                    out[c] = OUTLINE
    for c in fill:
        out[c] = FILL
    for c in dim:
        out[c] = DIM
    return out


ARROW = mask("""
    ............
    .o..........
    .oo.........
    .ooo........
    .oooo.......
    .ooooo......
    .oooooo.....
    .ooooooo....
    .oooo.......
    .o..oo......
    .....oo.....
    ............
""")

HAND = mask("""
    ............
    ...oo.......
    ...oo.......
    ...oo.......
    ...ooooooo..
    ...oooooooo.
    .oooooooooo.
    .oooooooooo.
    ..ooooooooo.
    ...oooooooo.
    ....oooooo..
    ............
""")

OPEN_HAND = mask("""
    ............
    ...o.o.o....
    ...o.o.o.o..
    ...o.o.o.o..
    ...ooooooo..
    .o.oooooooo.
    .oooooooooo.
    .oooooooooo.
    ..ooooooooo.
    ...oooooooo.
    ....oooooo..
    ............
""")

FIST = mask("""
    ............
    ............
    ............
    ............
    ...ooooooo..
    ...oooooooo.
    .oooooooooo.
    .oooooooooo.
    ..ooooooooo.
    ...oooooooo.
    ....oooooo..
    ............
""")

IBEAM = mask("""
    ............
    ...oo.oo....
    .....o......
    .....o......
    .....o......
    .....o......
    .....o......
    .....o......
    .....o......
    .....o......
    ...oo.oo....
    ............
""")

CROSS = mask("""
    ............
    .....o......
    .....o......
    .....o......
    .....o......
    .oooo.oooo..
    .....o......
    .....o......
    .....o......
    .....o......
    ............
    ............
""")

FORBIDDEN = mask("""
    ............
    ....oooo....
    ..oo....oo..
    ..o....ooo..
    .o....ooo.o.
    .o...ooo..o.
    .o..ooo...o.
    .o.ooo....o.
    ..ooo....o..
    ..oo....oo..
    ....oooo....
    ............
""")

HELP = mask("""
    ............
    .o......ooo.
    .oo....o...o
    .ooo.......o
    .oooo.....o.
    .ooooo...o..
    .oooooo..o..
    .ooooooo....
    .oooo....o..
    .o..oo......
    .....oo.....
    ............
""")

H_ARROW = mask("""
    ............
    ............
    ............
    ...o....o...
    ..oo....oo..
    .oooooooooo.
    ..oo....oo..
    ...o....o...
    ............
    ............
    ............
    ............
""")

MOVE = mask("""
    ............
    .....o......
    ....ooo.....
    .....o......
    ..o..o..o...
    .oooooooooo.
    ..o..o..o...
    .....o......
    ....ooo.....
    .....o......
    ............
    ............
""")


def transpose(m):
    return {(y, x) for (x, y) in m}


def diag(flip=False):
    """a double arrow from top-left to bottom-right (or mirrored)."""
    m = set()
    for i in range(2, 10):
        m.add((i, i))
    for c in ((2, 3), (2, 4), (3, 2), (4, 2), (9, 8), (9, 7), (8, 9), (7, 9)):
        m.add(c)
    if flip:
        m = {(N - 1 - x, y) for (x, y) in m}
    return m


V_ARROW = transpose(H_ARROW)


def spinner(frame, centre=(5.5, 5.5), radius=3.6, size=2):
    """8 dots around a ring, the lit one turns with the frame."""
    lit, dim = set(), set()
    for k in range(8):
        a = 2 * math.pi * k / 8 - math.pi / 2
        cx, cy = centre[0] + radius * math.cos(a), centre[1] + radius * math.sin(a)
        block = {(int(round(cx - size / 2 + i)), int(round(cy - size / 2 + j))) for i in range(size) for j in range(size)}
        (lit if (k - frame) % 8 in (0, 1) else dim).update(block)
    return lit, dim - lit


def progress(frame):
    """arrow plus a small turning ring at the bottom right."""
    small = set(list(ARROW))
    small = {(x, y) for (x, y) in small if x < 6 and y < 9}
    lit, dim = set(), set()
    for k in range(4):
        a = 2 * math.pi * k / 4 - math.pi / 2
        c = (int(round(8.5 + 1.6 * math.cos(a))), int(round(8.5 + 1.6 * math.sin(a))))
        (lit if k == frame % 4 else dim).add(c)
    return small | lit, dim


# name -> (frames: list of (fill, dim)), hotspot cell, frame delay ms
SHAPES = {
    "default": ([(ARROW, set())], (1, 1)),
    "pointer": ([(HAND, set())], (3, 1)),
    "text": ([(IBEAM, set())], (5, 6)),
    "crosshair": ([(CROSS, set())], (5, 5)),
    "not-allowed": ([(FORBIDDEN, set())], (5, 5)),
    "help": ([(HELP, set())], (1, 1)),
    "move": ([(MOVE, set())], (5, 5)),
    "grab": ([(OPEN_HAND, set())], (5, 5)),
    "grabbing": ([(FIST, set())], (5, 5)),
    "ew-resize": ([(H_ARROW, set())], (5, 5)),
    "ns-resize": ([(V_ARROW, set())], (5, 5)),
    "nwse-resize": ([(diag(False), set())], (5, 5)),
    "nesw-resize": ([(diag(True), set())], (6, 5)),
    "wait": ([spinner(f) for f in range(8)], (5, 5)),
    "progress": ([progress(f) for f in range(4)], (1, 1)),
}
DELAYS = {"wait": 90, "progress": 140}

# X11 / CSS / Qt names that should show the same picture
ALIASES = {
    "default": ["left_ptr", "arrow", "top_left_arrow", "left-arrow", "right_ptr", "draft"],
    "pointer": ["hand1", "hand2", "pointing_hand", "e29285e634086352946a0e7090d73106", "9d800788f1b08800ae810202380a0822"],
    "text": ["xterm", "ibeam", "vertical-text"],
    "crosshair": ["cross", "tcross", "cross_reverse", "diamond_cross", "cell", "plus"],
    "not-allowed": ["forbidden", "circle", "no-drop", "crossed_circle", "03b6e0fcb3499374a867c041f52298f0"],
    "help": ["question_arrow", "whats_this", "left_ptr_help", "d9ce0ab605698f320427677b458ad60b", "5c6cd98b3f3ebcb1f9c7f1c204630408"],
    "move": ["fleur", "all-scroll", "size_all", "4498f0e0c1937ffe01fd06f973665830", "9081237383d90e509aa00f00170e968f"],
    "grab": ["openhand", "fcf1c3c7cd4491d801f1e1c78f100000", "5aca4d189052212118709018842178c0"],
    "grabbing": ["closedhand", "dnd-move", "dnd-none", "208530c400c041818281048008011002", "fcf21c00b30f7e3f83fe0dfd12e71cff"],
    "ew-resize": ["size_hor", "col-resize", "e-resize", "w-resize", "sb_h_double_arrow", "h_double_arrow",
                  "left_side", "right_side", "split_h", "028006030e0e7ebffc7f7070c0600140", "14fef782d02440884392942c11205230"],
    "ns-resize": ["size_ver", "row-resize", "n-resize", "s-resize", "sb_v_double_arrow", "v_double_arrow",
                  "top_side", "bottom_side", "split_v", "00008160000006810000408080010102", "2870a09082c103050810ffdffffe0204"],
    "nwse-resize": ["size_fdiag", "nw-resize", "se-resize", "bd_double_arrow", "top_left_corner", "bottom_right_corner",
                    "c7088f0f3e6c8088236ef8e1e3e70000", "38c5dff7c7b8962045400281044508d2"],
    "nesw-resize": ["size_bdiag", "ne-resize", "sw-resize", "fd_double_arrow", "top_right_corner", "bottom_left_corner",
                    "fcf1c3c7cd4491d801f1e1c78f100000-ne", "50585d75b494802d0151028115016902"],
    "wait": ["watch", "00000000000000020006000e7e9ffc3f"],
    "progress": ["left_ptr_watch", "half-busy", "3ecb610c1bf2410f44200f48c40d3599", "08e8e1c95fe2fc01f976f1e063a24ccd"],
}


def render(fill, dim, nominal):
    """ARGB (premultiplied, little endian) pixels of one frame."""
    c = max(2, nominal // N)
    px = [[0] * nominal for _ in range(nominal)]
    gap = 1 if c >= 4 else 0
    for (x, y), rgb in cells(fill, dim).items():
        inner = gap if rgb != OUTLINE else 0
        for yy in range(y * c, y * c + c):
            for xx in range(x * c, x * c + c):
                if yy >= nominal or xx >= nominal:
                    continue
                edge = inner and (xx - x * c < inner or yy - y * c < inner)
                col = OUTLINE if edge else rgb
                px[yy][xx] = 0xff000000 | (col[0] << 16) | (col[1] << 8) | col[2]
    return c, b"".join(struct.pack("<I", v) for row in px for v in row)


def svg(fill, dim):
    """One frame as SVG on a 24x24 canvas (2 units per cell)."""
    parts = []
    for (x, y), rgb in sorted(cells(fill, dim).items()):
        hexc = "#%02x%02x%02x" % rgb
        if rgb == OUTLINE:
            parts.append(f'<rect x="{2 * x}" y="{2 * y}" width="2" height="2" fill="{hexc}"/>')
        else:   # dark square with the colour inset: the dot-grid gap
            parts.append(f'<rect x="{2 * x}" y="{2 * y}" width="2" height="2" fill="#%02x%02x%02x"/>' % OUTLINE)
            parts.append(f'<rect x="{2 * x + 0.22}" y="{2 * y + 0.22}" width="1.56" height="1.56" fill="{hexc}"/>')
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" '
            'shape-rendering="crispEdges">' + "".join(parts) + "</svg>\n")


def scalable(root, name, frames, hot, delay):
    d = os.path.join(root, name)
    os.makedirs(d, exist_ok=True)
    meta = []
    for i, (fill, dim) in enumerate(frames):
        fn = f"{name}.svg" if len(frames) == 1 else f"{name}-{i + 1:02d}.svg"
        with open(os.path.join(d, fn), "w") as f:
            f.write(svg(fill, dim))
        entry = {"filename": fn, "hotspot_x": 2 * hot[0] + 1, "hotspot_y": 2 * hot[1] + 1, "nominal_size": 24}
        if len(frames) > 1:
            entry["delay"] = delay
        meta.append(entry)
    with open(os.path.join(d, "metadata.json"), "w") as f:
        json.dump(meta, f, indent=4)


def xcursor(frames, hot, delay):
    """One Xcursor file with every size and frame."""
    images = []
    for nominal in SIZES:
        for fill, dim in frames:
            c, data = render(fill, dim, nominal)
            hx, hy = hot[0] * c + c // 2, hot[1] * c + c // 2
            header = struct.pack("<IIIIIIIII", 36, 0xFFFD0002, nominal, 1, nominal, nominal, hx, hy, delay)
            images.append((nominal, header + data))
    ntoc = len(images)
    pos = 16 + ntoc * 12
    toc, body = b"", b""
    for nominal, chunk in images:
        toc += struct.pack("<III", 0xFFFD0002, nominal, pos + len(body))
        body += chunk
    return b"Xcur" + struct.pack("<III", 16, 0x10000, ntoc) + toc + body


def main():
    d = os.path.join(OUT, THEME, "cursors")
    sd = os.path.join(OUT, THEME, "cursors_scalable")
    os.makedirs(d, exist_ok=True)
    os.makedirs(sd, exist_ok=True)
    for name, (frames, hot) in SHAPES.items():
        with open(os.path.join(d, name), "wb") as f:
            f.write(xcursor(frames, hot, DELAYS.get(name, 0)))
        scalable(sd, name, frames, hot, DELAYS.get(name, 0))
        for alias in ALIASES.get(name, []):
            for base in (d, sd):
                p = os.path.join(base, alias)
                if os.path.lexists(p):
                    os.remove(p)
                os.symlink(name, p)
    with open(os.path.join(OUT, THEME, "index.theme"), "w") as f:
        f.write("[Icon Theme]\nName=DotGrid\nComment=Dot-matrix cursors for DotGrid\nInherits=breeze_cursors\n")
    with open(os.path.join(OUT, THEME, "cursor.theme"), "w") as f:
        f.write(f"[Icon Theme]\nInherits={THEME}\n")
    print(f"{THEME}: {len(SHAPES)} cursors, {sum(len(v) for v in ALIASES.values())} aliases; "
          f"SVG (Wayland) + Xcursor {SIZES}")


if __name__ == "__main__":
    main()
