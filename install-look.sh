#!/usr/bin/env bash
# DotGrid: icons, cursor, window decorations, panel monitors and splash in the dot-matrix style.
# Called by ./install.sh, or alone for an existing DotGrid install.
#   ./install-look.sh [--no-icons] [--no-cursor] [--no-decoration] [--no-monitors] [--no-splash] [--no-apply]
# The previous icons/cursor/splash are remembered on the first run;
# ./uninstall-look.sh puts them back. Without sudo, everything in ~/.local.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ICONS=1; CURSOR=1; DECO=1; MON=1; SPLASH=1; APPLY=1
for a in "$@"; do
  case "$a" in
    --no-icons) ICONS=0 ;;
    --no-cursor) CURSOR=0 ;;
    --no-decoration) DECO=0 ;;
    --no-monitors) MON=0 ;;
    --no-splash) SPLASH=0 ;;
    --no-apply) APPLY=0 ;;
    -h|--help) sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Неизвестный параметр: $a"; exit 1 ;;
  esac
done

say() { printf '\033[1m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!!\033[0m %s\n' "$*"; }

ICON_DIR="$HOME/.local/share/icons"
LNF="$HOME/.local/share/plasma/look-and-feel/org.dotgrid.splash"
CFG="$HOME/.config/dotgrid"
PREV="$CFG/look.prev"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/dotgrid-theme"
TH="$HOME/.local/bin/dotgrid-theme"
MODE=$(cat "$STATE" 2>/dev/null || echo night)
case "$MODE" in day|night) ;; *) MODE=night ;; esac
DAY_AT=8; NIGHT_AT=20
[ -f "$CFG/schedule" ] && . "$CFG/schedule"
mkdir -p "$CFG" "$ICON_DIR"

# what was there before DotGrid, for uninstall-look.sh
if [ ! -f "$PREV" ]; then
  {
    echo "ICONS=$(printf '%q' "$(kreadconfig6 --file kdeglobals --group Icons --key Theme)")"
    echo "CURSOR=$(printf '%q' "$(kreadconfig6 --file kcminputrc --group Mouse --key cursorTheme)")"
    echo "SPLASH_THEME=$(printf '%q' "$(kreadconfig6 --file ksplashrc --group KSplash --key Theme)")"
    echo "SPLASH_ENGINE=$(printf '%q' "$(kreadconfig6 --file ksplashrc --group KSplash --key Engine)")"
  } > "$PREV"
  say "Прежние иконки, курсор и заставка запомнены: ${PREV/#$HOME/~}"
fi
grep -q '^PLASMA_STYLE=' "$PREV" || echo "PLASMA_STYLE=$(printf '%q' "$(kreadconfig6 --file plasmarc --group Theme --key name)")" >> "$PREV"
if ! grep -q '^DECO_LIBRARY=' "$PREV"; then
  echo "DECO_LIBRARY=$(printf '%q' "$(kreadconfig6 --file kwinrc --group org.kde.kdecoration2 --key library)")" >> "$PREV"
  echo "DECO_THEME=$(printf '%q' "$(kreadconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme)")" >> "$PREV"
fi

if [ "$ICONS" = 1 ]; then
  say "Иконки DotGrid (день) и DotGrid-Dark (ночь)"
  T="$(mktemp -d)"
  # every other Breeze and application icon, converted to dots (a few seconds);
  # first, because make_icons.py copies some of them into the two themes
  if command -v rsvg-convert >/dev/null && python3 -c "import PIL" 2>/dev/null; then
    python3 "$DIR/tools/dotify_icons.py" "$T" >/dev/null
  else
    warn "Нет rsvg-convert или python-pillow: остальные значки останутся Breeze (pacman -S librsvg python-pillow)"
  fi
  python3 "$DIR/tools/make_icons.py" "$T" >/dev/null
  for th in DotGrid DotGrid-Dark DotGrid-Auto; do
    rm -rf "$ICON_DIR/$th"
    [ -d "$T/$th" ] && cp -r "$T/$th" "$ICON_DIR/$th"
  done
  # the panel and tray take their icons from the Plasma style first:
  # DotGrid = Breeze with these icon files replaced
  PS="$HOME/.local/share/plasma/desktoptheme/dotgrid"
  rm -rf "$PS"
  mkdir -p "$(dirname "$PS")"
  cp -r "$T/plasma-style/dotgrid" "$PS"
  rm -rf "$T"
fi

if [ "$CURSOR" = 1 ]; then
  say "Курсор DotGrid"
  T="$(mktemp -d)"
  python3 "$DIR/tools/make_cursors.py" "$T" >/dev/null
  rm -rf "$ICON_DIR/DotGrid-cursors"
  cp -a "$T/DotGrid-cursors" "$ICON_DIR/DotGrid-cursors"
  rm -rf "$T"
fi

if [ "$DECO" = 1 ]; then
  say "Рамки окон DotGrid (Aurorae)"
  AUR="$HOME/.local/share/aurorae/themes"
  mkdir -p "$AUR"
  python3 "$DIR/tools/make_aurorae.py" "$AUR" >/dev/null
fi

if [ "$MON" = 1 ]; then
  say "Вид системных мониторов DotGrid (точечная матрица)"
  FACES="$HOME/.local/share/ksysguard/sensorfaces"
  mkdir -p "$FACES"
  rm -rf "$FACES/org.dotgrid.dotmatrix"
  cp -r "$DIR/assets/sensorface/org.dotgrid.dotmatrix" "$FACES/"
fi

if [ "$SPLASH" = 1 ]; then
  say "Заставка входа DotGrid"
  rm -rf "$LNF"
  mkdir -p "$LNF/contents/splash/images"
  sed "s/@DAY_AT@/$DAY_AT/; s/@NIGHT_AT@/$NIGHT_AT/" "$DIR/assets/Splash.qml.in" > "$LNF/contents/splash/Splash.qml"
  cp "$DIR/assets/SplashMode.qml" "$LNF/contents/splash/Mode.qml"
  cp "$DIR/assets/day.png" "$DIR/assets/night.png" "$LNF/contents/splash/images/"
  cat > "$LNF/metadata.json" <<'MJ'
{
    "KPackageStructure": "Plasma/LookAndFeel",
    "KPlugin": {
        "Authors": [{ "Name": "DotGrid" }],
        "Description": "Dot grid splash, day and night",
        "Id": "org.dotgrid.splash",
        "License": "MIT",
        "Name": "DotGrid",
        "Version": "2.0"
    }
}
MJ
fi

# dotgrid-theme: window decorations follow the theme
if [ -f "$TH" ] && ! grep -q "# DotGrid decoration" "$TH"; then
  [ -f "$TH.bak.dotgrid-look" ] || cp "$TH" "$TH.bak.dotgrid-look"
  python3 "$DIR/tools/patch_theme.py" decoration "$TH"
  say "dotgrid-theme: рамки окон переключаются вместе с темой"
fi

# dotgrid-theme: icons and splash follow the theme (older versions did not)
if [ -f "$TH" ] && ! grep -q "# DotGrid look" "$TH"; then
  cp "$TH" "$TH.bak.dotgrid-look"
  python3 - "$TH" <<'EOF'
import sys
p = sys.argv[1]
t = open(p).read()
block = '''# DotGrid look: dot-matrix icons per theme; the splash learns day/night
[ "$1" = night ] && LOOK_ICONS=DotGrid-Dark || LOOK_ICONS=DotGrid
if [ -d "$HOME/.local/share/icons/$LOOK_ICONS" ]; then
  if [ -x /usr/lib/plasma-changeicons ]; then /usr/lib/plasma-changeicons "$LOOK_ICONS" >/dev/null 2>&1
  else kwriteconfig6 --file kdeglobals --group Icons --key Theme "$LOOK_ICONS"; fi
fi
SPLASH_MODE="$HOME/.local/share/plasma/look-and-feel/org.dotgrid.splash/contents/splash/Mode.qml"
if [ -d "$(dirname "$SPLASH_MODE")" ]; then
  [ "$1" = night ] && N=true || N=false
  printf 'import QtQuick 2.15\\nQtObject { property bool known: true; property bool night: %s }\\n' "$N" > "$SPLASH_MODE"
fi
'''
i = t.index('STATE="${XDG_STATE_HOME')
open(p, "w").write(t[:i] + block + t[i:])
EOF
  say "dotgrid-theme: иконки и заставка переключаются вместе с темой (бэкап: dotgrid-theme.bak.dotgrid-look)"
fi

if [ "$APPLY" = 1 ]; then
  if [ "$ICONS" = 1 ]; then
    [ "$MODE" = night ] && I=DotGrid-Dark || I=DotGrid
    /usr/lib/plasma-changeicons "$I" >/dev/null 2>&1 || kwriteconfig6 --file kdeglobals --group Icons --key Theme "$I"
    plasma-apply-desktoptheme dotgrid >/dev/null 2>&1 || kwriteconfig6 --file plasmarc --group Theme --key name dotgrid
  fi
  if [ "$CURSOR" = 1 ]; then
    # libXcursor here reports "~/.local/share/icons" with a literal "~", so KDE's
    # cursor tools cannot see themes in the home directory: give the full path,
    # now and for future sessions
    XCP="$HOME/.local/share/icons:$HOME/.icons:/usr/share/icons:/usr/share/pixmaps"
    mkdir -p "$HOME/.config/plasma-workspace/env"
    printf '# DotGrid: cursor themes in the home directory (the default path has a literal ~)\nexport XCURSOR_PATH="%s"\n' \
      '$HOME/.local/share/icons:$HOME/.icons:/usr/share/icons:/usr/share/pixmaps' > "$HOME/.config/plasma-workspace/env/dotgrid-xcursor.sh"
    # re-applying the same name is a no-op, so go through Breeze once
    if [ "$(kreadconfig6 --file kcminputrc --group Mouse --key cursorTheme)" = DotGrid-cursors ]; then
      XCURSOR_PATH="$XCP" plasma-apply-cursortheme breeze_cursors >/dev/null 2>&1 || true
    fi
    if ! XCURSOR_PATH="$XCP" plasma-apply-cursortheme DotGrid-cursors >/dev/null 2>&1; then
      warn "Курсор не применился сразу; выберите DotGrid в Параметры → Курсоры"
    fi
  fi
  if [ "$DECO" = 1 ]; then
    [ "$MODE" = night ] && D=DotGrid-Dark || D=DotGrid
    kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library org.kde.kwin.aurorae
    kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme "__aurorae__svg__$D"
    gdbus call --session -d org.kde.KWin -o /KWin -m org.kde.KWin.reconfigure >/dev/null 2>&1 || true
  fi
  if [ "$MON" = 1 ]; then
    # every System Monitor widget on the panels and desktop gets the dot face;
    # the previous faces go to monitors.prev for uninstall-look.sh
    R=$(gdbus call --session -d org.kde.plasmashell -o /PlasmaShell -m org.kde.PlasmaShell.evaluateScript '
      var out = [];
      panels().concat(desktops()).forEach(function (c) { c.widgets().forEach(function (w) {
        if (w.type.indexOf("org.kde.plasma.systemmonitor") !== 0) return;
        w.currentConfigGroup = ["Appearance"];
        var f = w.readConfig("chartFace");
        if (f !== "org.dotgrid.dotmatrix") { out.push(w.id + "=" + f); w.writeConfig("chartFace", "org.dotgrid.dotmatrix"); }
      }); });
      print(out.join("\n"));' 2>/dev/null | sed "s/^('//; s/',)$//") || R=""
    if [ -n "$R" ]; then printf '%b\n' "$R" >> "$CFG/monitors.prev"; fi
  fi
  if [ "$SPLASH" = 1 ]; then
    kwriteconfig6 --file ksplashrc --group KSplash --key Engine KSplashQML
    kwriteconfig6 --file ksplashrc --group KSplash --key Theme org.dotgrid.splash
    [ "$MODE" = night ] && N=true || N=false
    printf 'import QtQuick 2.15\nQtObject { property bool known: true; property bool night: %s }\n' "$N" > "$LNF/contents/splash/Mode.qml"
  fi
  say "Применено (тема сейчас: $MODE)"
fi
echo "Вернуть как было: $DIR/uninstall-look.sh"
