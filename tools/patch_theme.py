#!/usr/bin/env python3
"""Adds or removes a marked block in ~/.local/bin/dotgrid-theme.

  patch_theme.py decoration FILE      add the window-decoration block
  patch_theme.py remove MARK FILE     drop the block starting with "# DotGrid MARK"

Blocks go right before the line that writes the state file, so they run on
every switch; each starts with a "# DotGrid <name>" marker line.
"""
import sys

BLOCKS = {
    "decoration": '''# DotGrid decoration: the Aurorae title bars of the theme
[ "$1" = night ] && DECO=DotGrid-Dark || DECO=DotGrid
if [ -d "$HOME/.local/share/aurorae/themes/$DECO" ]; then
  kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library org.kde.kwin.aurorae
  kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme "__aurorae__svg__$DECO"
  gdbus call --session -d org.kde.KWin -o /KWin -m org.kde.KWin.reconfigure >/dev/null 2>&1
fi
''',
}
ANCHOR = 'STATE="${XDG_STATE_HOME'


def add(name, path):
    t = open(path).read()
    marker = BLOCKS[name].splitlines()[0].split(":")[0]
    if marker in t:
        return
    i = t.index(ANCHOR)
    open(path, "w").write(t[:i] + BLOCKS[name] + t[i:])


def remove(mark, path):
    t = open(path).read()
    marker = "# DotGrid " + mark
    a = t.find(marker)
    if a == -1:
        return
    # the block ends where the next marked block or the state line starts
    ends = [i for i in (t.find("\n# DotGrid ", a + 1), t.find(ANCHOR, a)) if i != -1]
    b = min(ends)
    if t[b] == "\n":
        b += 1
    open(path, "w").write(t[:a] + t[b:])


if __name__ == "__main__":
    if sys.argv[1] == "remove":
        remove(sys.argv[2], sys.argv[3])
    else:
        add(sys.argv[1], sys.argv[2])
