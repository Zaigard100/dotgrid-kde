#!/usr/bin/env python3
"""DotGrid boot splash (Plymouth, script module): the night dot grid, the word
DOTGRID in dots and a row of 12 tiles that fill with the boot progress.

  python3 tools/make_plymouth.py OUTDIR [THEMEDIR]

THEMEDIR is where the theme will live (default /usr/share/plymouth/themes/dotgrid);
./install-plymouth.sh copies OUTDIR there. The background is one 32 px tile
repeated by Plymouth itself; the screen redraws 10 times a second, only for the
blinking next tile and the password prompt.
"""
import os
import sys

from PIL import Image

OUT = sys.argv[1]
THEMEDIR = sys.argv[2] if len(sys.argv) > 2 else "/usr/share/plymouth/themes/dotgrid"

BG = (0x14, 0x14, 0x13)
GRID = (0x2a, 0x29, 0x26)
INK = (0xe8, 0xe0, 0xd0)
DIM = (0x3a, 0x39, 0x35)
MUTE = (0x5c, 0x5a, 0x54)
PITCH = 32       # background grid, device pixels
CELL = 12        # one dot of the word
TILES = 12

FONT = {
    "D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
    "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
    "G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".###."],
    "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
    "I": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "#####"],
}


def square(img, x, y, size, color):
    for yy in range(y, y + size):
        for xx in range(x, x + size):
            img.putpixel((xx, yy), color + (255,))


def word(text, cell, gap=1):
    w = (len(text) * (5 + gap) - gap) * cell
    img = Image.new("RGBA", (w, 7 * cell), (0, 0, 0, 0))
    dot = cell - 2
    for i, ch in enumerate(text):
        for y, row in enumerate(FONT[ch]):
            for x, c in enumerate(row):
                square(img, (i * (5 + gap) + x) * cell + 1, y * cell + 1, dot,
                       INK if c == "#" else DIM)
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    tile = Image.new("RGBA", (PITCH, PITCH), BG + (255,))
    square(tile, PITCH // 2 - 1, PITCH // 2 - 1, 3, GRID)
    tile.save(os.path.join(OUT, "grid.png"))
    word("DOTGRID", CELL).save(os.path.join(OUT, "logo.png"))
    for name, color in (("tile-on", INK), ("tile-off", DIM), ("bullet", INK)):
        size = 10 if name == "bullet" else 20
        img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        square(img, 0, 0, size, color)
        img.save(os.path.join(OUT, name + ".png"))
    # the password field: a thin frame, bullets go inside
    w, h = 360, 36
    entry = Image.new("RGBA", (w, h), BG + (255,))
    for x in range(w):
        for y in (0, h - 1):
            entry.putpixel((x, y), MUTE + (255,))
    for y in range(h):
        for x in (0, w - 1):
            entry.putpixel((x, y), MUTE + (255,))
    entry.save(os.path.join(OUT, "entry.png"))

    with open(os.path.join(OUT, "dotgrid.plymouth"), "w") as f:
        f.write(f"[Plymouth Theme]\nName=DotGrid\nDescription=Dot grid with boot progress tiles\nModuleName=script\n\n"
                f"[script]\nImageDir={THEMEDIR}\nScriptFile={THEMEDIR}/dotgrid.script\n")
    with open(os.path.join(OUT, "dotgrid.script"), "w") as f:
        f.write(SCRIPT.replace("@TILES@", str(TILES))
                .replace("@PITCH@", str(PITCH))
                .replace("@BG@", ", ".join(f"{c / 255:.3f}" for c in BG))
                .replace("@MUTE@", ", ".join(f"{c / 255:.3f}" for c in MUTE)))
    print(f"plymouth dotgrid: {OUT}")


SCRIPT = r"""# DotGrid boot splash. Written by tools/make_plymouth.py.
Window.SetBackgroundTopColor(@BG@);
Window.SetBackgroundBottomColor(@BG@);
Plymouth.SetRefreshRate(10);

sw = Window.GetWidth();
sh = Window.GetHeight();
# keep the screen centre on a grid dot, like the wallpaper
pitch = @PITCH@;
ox = Math.Int(sw / 2) % pitch - pitch / 2;
oy = Math.Int(sh / 2) % pitch - pitch / 2;
grid.sprite = Sprite(Image("grid.png").Tile(sw + pitch, sh + pitch));
grid.sprite.SetPosition(ox - pitch, oy - pitch, -10);

logo.image = Image("logo.png");
logo.sprite = Sprite(logo.image);
logo.x = Math.Int((sw - logo.image.GetWidth()) / 2);
logo.y = Math.Int(sh / 2 - logo.image.GetHeight() - 24);
logo.sprite.SetPosition(logo.x, logo.y, 1);

on_image = Image("tile-on.png");
off_image = Image("tile-off.png");
count = @TILES@;
step = 32;
row_x = Math.Int((sw - (count - 1) * step - on_image.GetWidth()) / 2);
row_y = Math.Int(sh / 2 + 40);
for (i = 0; i < count; i++) {
  tiles[i] = Sprite(off_image);
  tiles[i].SetPosition(row_x + i * step, row_y, 1);
}
lit = 0;
ticks = 0;

fun set_lit(n) {
  if (n > count) n = count;
  for (i = lit; i < n; i++) {
    tiles[i].SetImage(on_image);
    tiles[i].SetOpacity(1);
  }
  lit = n;
}

fun progress_callback(duration, progress) {
  set_lit(Math.Int(progress * count));
}
Plymouth.SetBootProgressFunction(progress_callback);

fun refresh_callback() {
  ticks++;
  # the next tile blinks once a second
  if (lit < count) {
    if (ticks % 10 < 5) tiles[lit].SetOpacity(1); else tiles[lit].SetOpacity(0.3);
  }
}
Plymouth.SetRefreshFunction(refresh_callback);

# ---- messages and password prompt ----
message.sprite = Sprite();
message.sprite.SetPosition(0, row_y + 60, 2);
fun message_callback(text) {
  message.image = Image.Text(text, @MUTE@);
  message.sprite.SetImage(message.image);
  message.sprite.SetX(Math.Int((sw - message.image.GetWidth()) / 2));
}
Plymouth.SetMessageFunction(message_callback);

entry.image = Image("entry.png");
bullet_image = Image("bullet.png");
entry.sprite = Sprite();
prompt.sprite = Sprite();
fun hide_dialog() {
  entry.sprite.SetOpacity(0);
  prompt.sprite.SetOpacity(0);
  for (i = 0; bullets[i]; i++) bullets[i].SetOpacity(0);
}

fun password_callback(text, n) {
  ex = Math.Int((sw - entry.image.GetWidth()) / 2);
  ey = row_y + 60;
  entry.sprite.SetImage(entry.image);
  entry.sprite.SetPosition(ex, ey, 3);
  entry.sprite.SetOpacity(1);
  prompt.image = Image.Text(text, @MUTE@);
  prompt.sprite.SetImage(prompt.image);
  prompt.sprite.SetPosition(Math.Int((sw - prompt.image.GetWidth()) / 2), ey - prompt.image.GetHeight() - 10, 3);
  prompt.sprite.SetOpacity(1);
  for (i = 0; bullets[i]; i++) bullets[i].SetOpacity(0);
  shown = n;
  if (shown > 24) shown = 24;
  for (i = 0; i < shown; i++) {
    if (!bullets[i]) bullets[i] = Sprite(bullet_image);
    bullets[i].SetPosition(ex + 13 + i * 14, ey + 13, 4);
    bullets[i].SetOpacity(1);
  }
}
Plymouth.SetDisplayPasswordFunction(password_callback);

fun normal_callback() {
  hide_dialog();
}
Plymouth.SetDisplayNormalFunction(normal_callback);

fun quit_callback() {
  set_lit(count);
}
Plymouth.SetQuitFunction(quit_callback);
"""

if __name__ == "__main__":
    main()
