# Original PNG generator (Pillow). The live wallpaper's look is rendered by
# tools/render-static.sh now; this one is kept for reference.
#   python3 tools/make_desktop.py [OUTDIR]     default: assets/
import os, random, math, subprocess, sys
from PIL import Image, ImageDraw, ImageFont

W, H = 2560, 1600


def font_file(pattern):
    return subprocess.run(["fc-match", "-f", "%{file}", pattern], capture_output=True, text=True).stdout


B = font_file("DejaVu Sans Mono:bold")
R = font_file("DejaVu Sans Mono")
BLACK = (10, 10, 10); CREAM = (232, 224, 208); DIM = (92, 90, 84)
BEIGE = (214, 205, 188); INK = (22, 22, 20)
STEP = 40


def F(sz, bold=True):
    return ImageFont.truetype(B if bold else R, sz)


def txt(d, xy, s, sz, col, bold=True, sp=0, bg=None):
    f = F(sz, bold); x, y = xy; adv = f.getlength("0") + sp
    if bg is not None:
        d.rectangle((x - 10, y - 4, x + adv * len(s) + 4, y + sz * 1.25), fill=bg)
    for ch in s:
        d.text((x, y), ch, font=f, fill=col); x += adv


def grid(d, col):
    for x in range(0, W, STEP):
        d.line((x, 0, x, H), fill=col)
    for y in range(0, H, STEP):
        d.line((0, y, W, y), fill=col)


def dots(d, col, r=3, x0=80, y0=80, x1=W - 80, y1=H - 120):
    for y in range(y0, y1 + 1, STEP):
        for x in range(x0, x1 + 1, STEP):
            d.ellipse((x - r, y - r, x + r, y + r), fill=col)


def brackets(d, box, col, ln=50, w=3):
    x0, y0, x1, y1 = box
    for x, y, dx, dy in [(x0, y0, 1, 1), (x1, y0, -1, 1), (x0, y1, 1, -1), (x1, y1, -1, -1)]:
        d.line((x, y, x + dx * ln, y), fill=col, width=w)
        d.line((x, y, x, y + dy * ln), fill=col, width=w)


def bars(d, x, y, heights, cell, gap, on, off, rows):
    for c, h in enumerate(heights):
        for r in range(rows):
            px = x + c * (cell + gap); py = y + (rows - 1 - r) * (cell + gap)
            d.rectangle((px, py, px + cell, py + cell), fill=on if r < h else off)


def night():
    random.seed(11)
    im = Image.new("RGB", (W, H), BLACK); d = ImageDraw.Draw(im)
    grid(d, (17, 17, 17))
    dots(d, (58, 56, 52))
    # left column
    txt(d, (120, 100), "ENVIRON CTR | DR-5 |", 64, CREAM, sp=8, bg=BLACK)
    for r in range(4):
        txt(d, (120, 210 + r * 62), "|||||||||||||||", 52, CREAM, bold=False, sp=16, bg=BLACK)
    hs = [int(6 + 4 * math.sin(i / 2.3) + random.randint(-2, 2)) for i in range(26)]
    bars(d, 120, 500, hs, 28, 12, CREAM, (32, 32, 30), 12)
    txt(d, (120, 1030), ".........J.................", 50, CREAM, bold=False, sp=4, bg=BLACK)
    txt(d, (120, 1100), "...........M...............", 50, CREAM, bold=False, sp=4, bg=BLACK)
    txt(d, (120, 1170), ".I.........................", 50, CREAM, bold=False, sp=4, bg=BLACK)
    txt(d, (120, 1270), "16592170 | 60190813", 64, CREAM, sp=8, bg=BLACK)
    # right: galaxy
    cx, cy = 1760, 760
    for _ in range(2600):
        t = random.random() * 2 * math.pi; rr = abs(random.gauss(0, 1)) * 330
        x = cx + rr * math.cos(t); y = cy + rr * math.sin(t) * 0.33 - (x - cx) * 0.38
        s = random.choice([5, 7, 9, 11]) if rr < 140 else random.choice([3, 4, 5])
        c = max(40, int(245 - rr * 0.55))
        d.rectangle((x, y, x + s, y + s), fill=(c, c - 6, c - 18))
    brackets(d, (1180, 260, 2440, 1260), DIM, ln=70)
    txt(d, (1210, 1190), "REDSHIFT Z=0.03  DEC -05  OBJ 22 0A8863", 26, DIM, bold=False, sp=3, bg=BLACK)
    txt(d, (1210, 290), "PHI 096  VEL 228KM/S  SECTOR 1-81", 26, DIM, bold=False, sp=3, bg=BLACK)
    return im


def day():
    random.seed(5)
    im = Image.new("RGB", (W, H), BEIGE); d = ImageDraw.Draw(im)
    grid(d, (205, 196, 179))
    dots(d, INK)
    # no clock here: a static image must not show a frozen time
    txt(d, (1900, 90), "24556 DR 5", 64, INK, sp=8, bg=BEIGE)
    for i in range(12):
        d.rectangle((120 + i * 52, 200, 120 + i * 52 + 46, 246), fill=(160, 152, 138))
    L = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    for r in range(9):
        txt(d, (1760, 300 + r * 76), "".join(random.choice(L) for _ in range(9)), 68, INK, sp=8, bg=BEIGE)
    for _ in range(26):
        gx = 120 + random.randint(0, 40) * STEP; gy = 340 + random.randint(0, 24) * STEP
        if gx > 1700 and gy < 1020:
            continue
        if gx > 1600 and gy > 1000:
            continue
        txt(d, (gx - 12, gy - 28), random.choice(["0", "i", "0", "00"]), 54, INK, bold=False, bg=BEIGE)
    txt(d, (1700, 1030), "00", 300, INK, sp=20, bg=BEIGE)
    txt(d, (1700, 1290), "/0", 300, INK, sp=20, bg=BEIGE) if False else None
    return im


out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "assets")
night().save(os.path.join(out, "night.png"))
day().save(os.path.join(out, "day.png"))
