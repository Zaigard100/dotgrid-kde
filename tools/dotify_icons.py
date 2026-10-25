#!/usr/bin/env python3
"""DotGrid-Auto: every Breeze icon and every third-party app icon (hicolor),
turned into a dot matrix automatically.

  python3 tools/dotify_icons.py [OUTDIR]       default: assets/icons

Each source icon is rasterised, and each cell of a grid gets its coverage:
small icons (16/22/24 px sources: actions, status, menus) go on an 11x11 grid,
large ones (apps, places, mime types) on 16x16. The outline of a shape and its
dark parts become solid dots, mid tones dimmed dots, light parts (white paper,
a white glyph on a coloured disc) stay empty. Dots use the colour-scheme text
colour, so the result follows day and night like the Breeze symbolic icons. The hand-drawn
DotGrid / DotGrid-Dark icons stay in front (they inherit this theme).
"""
import os
import re
import subprocess
import sys
import tempfile
from concurrent.futures import ProcessPoolExecutor

from PIL import Image

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "assets", "icons")
THEME = "DotGrid-Auto"
BREEZE = "/usr/share/icons/breeze"
HICOLOR = "/usr/share/icons/hicolor"
CONTEXTS = ("actions", "applets", "apps", "categories", "devices", "emblems", "emotes",
            "mimetypes", "places", "preferences", "status")
# Context= values as in Breeze; icon lookups match on them
CONTEXT_NAMES = {"actions": "Actions", "applets": "Status", "apps": "Applications", "categories": "Categories",
                 "devices": "Devices", "emblems": "Emblems", "emotes": "Emotes", "mimetypes": "MimeTypes",
                 "places": "Places", "preferences": "Applications", "status": "Status"}
SMALL_GRID, LARGE_GRID = 11, 16
OVERSAMPLE = 6


def size_of(path):
    """Pixel size from a theme directory like .../actions/22/ or 48x48/apps."""
    for part in reversed(path.split(os.sep)):
        m = re.fullmatch(r"(\d+)(?:x\d+)?(@\dx)?", part)
        if m:
            return int(m.group(1)), bool(m.group(2))
        if part == "scalable":
            return 512, False
    return 0, False


SMALL_CONTEXTS = ("actions", "status", "emblems", "applets", "emotes")


def collect():
    """name -> (context, source path, small?) with the best source for each."""
    found = {}       # name -> list of (size, path, ctx, from_breeze)
    for ctx in CONTEXTS:
        for root, _, files in os.walk(os.path.join(BREEZE, ctx)):
            size, hidpi = size_of(root)
            if hidpi or not size:
                continue
            for f in files:
                if f.endswith(".svg"):
                    found.setdefault(f[:-4], []).append((size, os.path.join(root, f), ctx, True))
    for root, _, files in os.walk(HICOLOR):
        ctx = "apps" if os.sep + "apps" in root else "status" if os.sep + "status" in root else None
        size, hidpi = size_of(root)
        if ctx is None or hidpi or not size:
            continue
        for f in files:
            name, _, ext = f.rpartition(".")
            if ext in ("svg", "png") and not any(s[3] for s in found.get(name, [])):
                found.setdefault(name, []).append((size + (1 if ext == "svg" else 0), os.path.join(root, f), ctx, False))
    out = {}
    for name, srcs in found.items():
        ctx = srcs[0][2]
        small = name.endswith("-symbolic") or (ctx in SMALL_CONTEXTS and any(s[0] <= 24 for s in srcs))
        if small:
            pick = min((s for s in srcs if s[0] <= 24), key=lambda s: abs(s[0] - 22), default=min(srcs))
        else:
            pick = max(srcs)
        out[name] = (pick[2], pick[1], small)
    return out


def raster(path, px):
    if path.endswith(".svg"):
        with tempfile.NamedTemporaryFile(suffix=".png") as tmp:
            r = subprocess.run(["rsvg-convert", "-w", str(px), "-h", str(px), "-o", tmp.name, path],
                               capture_output=True)
            if r.returncode != 0:
                return None
            return Image.open(tmp.name).convert("RGBA")
    try:
        return Image.open(path).convert("RGBA").resize((px, px), Image.LANCZOS)
    except OSError:
        return None


def dotify(job):
    name, (ctx, path, small) = job
    n = SMALL_GRID if small else LARGE_GRID
    im = raster(path, n * OVERSAMPLE)
    if im is None:
        return name, ctx, None
    px = im.load()
    k = OVERSAMPLE
    cov = [[0.0] * n for _ in range(n)]
    lum = [[0.0] * n for _ in range(n)]
    for cy in range(n):
        for cx in range(n):
            a_sum = l_sum = 0.0
            for y in range(cy * k, cy * k + k):
                for x in range(cx * k, cx * k + k):
                    r, g, b, a = px[x, y]
                    a /= 255
                    a_sum += a
                    l_sum += a * (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255
            cov[cy][cx] = a_sum / (k * k)
            lum[cy][cx] = l_sum / a_sum if a_sum else 1.0
    full, dim = [], []
    for cy in range(n):
        for cx in range(n):
            c = cov[cy][cx]
            if c < 0.22:
                continue
            edge = any(not (0 <= cx + dx < n and 0 <= cy + dy < n) or cov[cy + dy][cx + dx] < 0.22
                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if edge:
                # the outline of the shape: always a dot
                (full if c >= 0.4 else dim).append((cx, cy))
            elif lum[cy][cx] < 0.45:
                full.append((cx, cy))          # dark parts: solid
            elif lum[cy][cx] < 0.75:
                dim.append((cx, cy))           # mid tones: dimmed
            # light parts (white paper, the "i" in a blue circle) stay empty
    if not full and not dim:
        return name, ctx, None
    cell = 16 / n
    sq = cell * 0.84
    off = (cell - sq) / 2

    def path_of(cells):
        return "".join(f"M{cx * cell + off:.2f} {cy * cell + off:.2f}h{sq:.2f}v{sq:.2f}h-{sq:.2f}z" for cx, cy in cells)

    body = ""
    if full:
        body += f'<path class="ColorScheme-Text" fill="currentColor" d="{path_of(full)}"/>'
    if dim:
        body += f'<path class="ColorScheme-Text" fill="currentColor" opacity="0.4" d="{path_of(dim)}"/>'
    svg = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16">'
           '<style id="current-color-scheme" type="text/css">.ColorScheme-Text{color:#232629;}</style>'
           + body + "</svg>\n")
    return name, ctx, svg


def main():
    jobs = sorted(collect().items())
    root = os.path.join(OUT, THEME)
    for c in CONTEXTS:
        os.makedirs(os.path.join(root, "scalable", c), exist_ok=True)
    done = skipped = 0
    with ProcessPoolExecutor() as pool:
        for name, ctx, svg in pool.map(dotify, jobs, chunksize=64):
            if svg is None:
                skipped += 1
                continue
            with open(os.path.join(root, "scalable", ctx, name + ".svg"), "w") as f:
                f.write(svg)
            done += 1
    dirs = ",".join(f"scalable/{c}" for c in CONTEXTS)
    sections = "".join(f"\n[scalable/{c}]\nSize=48\nMinSize=8\nMaxSize=512\nType=Scalable\nContext={CONTEXT_NAMES[c]}\n"
                       for c in CONTEXTS)
    with open(os.path.join(root, "index.theme"), "w") as f:
        f.write(f"[Icon Theme]\nName=DotGrid Auto\nComment=Breeze and app icons as a dot matrix\n"
                f"Inherits=hicolor\nHidden=true\nDirectories={dirs}\nFollowsColorScheme=true\n{sections}")
    print(f"{THEME}: {done} icons ({skipped} sources could not be read)")


if __name__ == "__main__":
    main()
