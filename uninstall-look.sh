#!/usr/bin/env bash
# Removes the DotGrid icons, cursor, window decorations and splash and puts back what was there
# before ./install-look.sh (remembered in ~/.config/dotgrid/look.prev).
set -uo pipefail
say() { printf '\033[1m==>\033[0m %s\n' "$*"; }

CFG="$HOME/.config/dotgrid"
PREV="$CFG/look.prev"
ICONS=breeze-dark; CURSOR=breeze_cursors; SPLASH_THEME=org.kde.breeze.desktop; SPLASH_ENGINE=KSplashQML; PLASMA_STYLE=default
DECO_LIBRARY=org.kde.breeze; DECO_THEME=Breeze
[ -f "$PREV" ] && . "$PREV"

say "Рамки окон: ${DECO_THEME:-Breeze}"
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library "${DECO_LIBRARY:-org.kde.breeze}"
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme "${DECO_THEME:-Breeze}"
gdbus call --session -d org.kde.KWin -o /KWin -m org.kde.KWin.reconfigure >/dev/null 2>&1

say "Иконки: ${ICONS:-breeze-dark}"
/usr/lib/plasma-changeicons "${ICONS:-breeze-dark}" >/dev/null 2>&1 \
  || kwriteconfig6 --file kdeglobals --group Icons --key Theme "${ICONS:-breeze-dark}"
say "Стиль Plasma: ${PLASMA_STYLE:-default}"
plasma-apply-desktoptheme "${PLASMA_STYLE:-default}" >/dev/null 2>&1 \
  || kwriteconfig6 --file plasmarc --group Theme --key name "${PLASMA_STYLE:-default}"
say "Курсор: ${CURSOR:-breeze_cursors}"
XCURSOR_PATH="$HOME/.local/share/icons:$HOME/.icons:/usr/share/icons:/usr/share/pixmaps" \
  plasma-apply-cursortheme "${CURSOR:-breeze_cursors}" >/dev/null 2>&1 \
  || kwriteconfig6 --file kcminputrc --group Mouse --key cursorTheme "${CURSOR:-breeze_cursors}"
say "Заставка: ${SPLASH_THEME:-org.kde.breeze.desktop}"
kwriteconfig6 --file ksplashrc --group KSplash --key Engine "${SPLASH_ENGINE:-KSplashQML}"
kwriteconfig6 --file ksplashrc --group KSplash --key Theme "${SPLASH_THEME:-org.kde.breeze.desktop}"

# System Monitor widgets: the faces they had before
if [ -f "$CFG/monitors.prev" ]; then
  say "Системные мониторы: прежний вид"
  JS="var prev = {};"
  while IFS='=' read -r id face; do [ -n "$id" ] && JS="$JS prev[$id] = '$face';"; done < "$CFG/monitors.prev"
  gdbus call --session -d org.kde.plasmashell -o /PlasmaShell -m org.kde.PlasmaShell.evaluateScript "$JS
    panels().concat(desktops()).forEach(function (c) { c.widgets().forEach(function (w) {
      if (prev[w.id] === undefined) return;
      w.currentConfigGroup = ['Appearance'];
      w.writeConfig('chartFace', prev[w.id]);
    }); });" >/dev/null 2>&1
  rm -f "$CFG/monitors.prev"
fi
rm -rf "$HOME/.local/share/ksysguard/sensorfaces/org.dotgrid.dotmatrix"

rm -rf "$HOME/.local/share/icons/DotGrid" "$HOME/.local/share/icons/DotGrid-Dark" "$HOME/.local/share/icons/DotGrid-Auto" \
       "$HOME/.local/share/icons/DotGrid-cursors" "$HOME/.local/share/plasma/look-and-feel/org.dotgrid.splash" \
       "$HOME/.local/share/plasma/desktoptheme/dotgrid" \
       "$HOME/.local/share/aurorae/themes/DotGrid" "$HOME/.local/share/aurorae/themes/DotGrid-Dark"

# dotgrid-theme: drop only the look block
TH="$HOME/.local/bin/dotgrid-theme"
if [ -f "$TH" ] && grep -q "# DotGrid look" "$TH"; then
  python3 - "$TH" <<'EOF'
import sys
p = sys.argv[1]
t = open(p).read()
a = t.index("# DotGrid look")
b = t.index('STATE="${XDG_STATE_HOME', a)
open(p, "w").write(t[:a] + t[b:])
EOF
  say "dotgrid-theme: блок иконок и заставки убран"
fi
if [ -f "$TH" ] && grep -q "# DotGrid decoration" "$TH"; then
  python3 "$(dirname "$0")/tools/patch_theme.py" remove decoration "$TH"
  say "dotgrid-theme: блок рамок окон убран"
fi
rm -f "$PREV"
say "Готово"
