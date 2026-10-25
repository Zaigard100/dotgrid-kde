#!/usr/bin/env bash
# DotGrid Live: живые обои для KDE Plasma 6. Без sudo, всё в ~/.local и ~/.config.
# Обычно вызывается как ./install.sh --live (вся тема + живые обои)
# или ./install.sh --live-only (только живые обои, тема не трогается).
#   ./install-live.sh [--yes] [--no-apply]
#     --yes       ставить недостающие пакеты без вопроса (sudo pacman)
#     --no-apply  разложить файлы, но не включать обои на рабочем столе
# Повторный запуск безопасен: обновляет плагин, сервис и CLI.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
YES=0; APPLY=1
for a in "$@"; do
  case "$a" in
    --yes) YES=1 ;;
    --no-apply) APPLY=0 ;;
    -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Неизвестный параметр: $a"; exit 1 ;;
  esac
done

say() { printf '\033[1m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!!\033[0m %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }
pymod() { python3 -c "import $1" >/dev/null 2>&1; }

BIN="$HOME/.local/bin"
CFG="$HOME/.config/dotgrid"
UNIT_DIR="$HOME/.config/systemd/user"
WP_DIR="$HOME/.local/share/plasma/wallpapers/org.dotgrid.live"
APPLETS="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
STAMP="$(date +%Y%m%d-%H%M%S)"

# --- зависимости ---
say "Проверяю зависимости"
need=()     # обязательные: без них не собрать или не запустить
opt=()      # для звука
have cmake || need+=(cmake)
have g++ || need+=(gcc)
have ninja || need+=(ninja)
[ -f /usr/lib/cmake/Qt6Quick/Qt6QuickConfig.cmake ] || need+=(qt6-declarative)
[ -f /usr/lib/cmake/Qt6DBus/Qt6DBusConfig.cmake ] || need+=(qt6-base)
have kpackagetool6 || need+=(kpackage)
pymod PySide6 || need+=(pyside6)
pymod dbus || need+=(python-dbus)
pymod numpy || opt+=(python-numpy)
have pw-record || opt+=(pipewire)
have pactl || opt+=(libpulse)
if [ ${#need[@]} -gt 0 ] || [ ${#opt[@]} -gt 0 ]; then
  echo "Нужны пакеты:      ${need[*]:-нет}"
  echo "Для звука (опц.):  ${opt[*]:-нет}"
  pkgs=("${need[@]}" "${opt[@]}")
  if [ "$YES" = 1 ]; then ans=y
  elif [ -t 0 ]; then read -r -p "Поставить через sudo pacman -S --needed ${pkgs[*]}? [y/N] " ans
  else ans=n; fi
  if [ "$ans" = y ] || [ "$ans" = Y ]; then
    sudo pacman -S --needed "${pkgs[@]}"
  elif [ ${#need[@]} -gt 0 ]; then
    echo "Без обязательных пакетов продолжить нельзя."; exit 1
  else
    warn "Без них столбики не будут реагировать на звук (останутся генеративными)"
  fi
fi

# --- сборка C++-модуля (галактика, батарея, связь с сервисом) ---
say "Собираю модуль обоев"
"$DIR/backend/build.sh" >/dev/null

# --- бэкапы ---
mkdir -p "$CFG"
for f in "$APPLETS" "$HOME/.config/kdeglobals"; do
  if [ -f "$f" ] && [ ! -f "$f.bak.dotgrid-live" ]; then
    cp "$f" "$f.bak.dotgrid-live"; say "Бэкап: ${f/#$HOME/~}.bak.dotgrid-live"
  fi
done
[ -f "$APPLETS" ] && cp "$APPLETS" "$CFG/appletsrc.$STAMP.bak"   # каждая установка: снимок до изменений

# --- плагин обоев ---
say "Плагин обоев org.dotgrid.live"
if [ -d "$WP_DIR" ]; then
  kpackagetool6 --type Plasma/Wallpaper --upgrade "$DIR/plugin/org.dotgrid.live" >/dev/null
else
  kpackagetool6 --type Plasma/Wallpaper --install "$DIR/plugin/org.dotgrid.live" >/dev/null
fi
[ -f "$WP_DIR/contents/backend/libdotgridlivebackend.so" ] || { warn "Модуль не попал в пакет обоев"; exit 1; }

# --- статичные обои (экран блокировки и запасной вариант), без часов ---
mkdir -p "$HOME/Pictures/DotGrid"
for m in day night; do
  dst="$HOME/Pictures/DotGrid/$m.png"
  # only the pictures that were there before the first live install
  if [ -f "$dst" ] && [ ! -f "$CFG/live.enabled" ] && [ ! -f "$dst.bak.dotgrid-live" ]; then
    cp "$dst" "$dst.bak.dotgrid-live"
  fi
  cp "$DIR/assets/$m.png" "$dst"
done

# --- сервис и CLI ---
say "Сервис dotgrid-livectl и команда dotgrid-live"
mkdir -p "$BIN" "$UNIT_DIR"
install -m755 "$DIR/live/dotgrid-livectl" "$DIR/live/dotgrid-live" "$BIN/"
install -m644 "$DIR/live/dotgrid-livectl.service" "$UNIT_DIR/"
systemctl --user daemon-reload
systemctl --user enable dotgrid-livectl.service >/dev/null 2>&1
systemctl --user restart dotgrid-livectl.service   # новая версия, если уже работал
case ":$PATH:" in *":$BIN:"*) ;; *) warn "$BIN нет в PATH" ;; esac

# --- dotgrid-theme: в live-режиме обои не меняются картинкой ---
TH="$BIN/dotgrid-theme"
if [ -f "$TH" ] && ! grep -q "# DotGrid live" "$TH"; then
  cp "$TH" "$TH.bak.dotgrid-live"
  python3 - "$TH" <<'EOF'
import sys
p = sys.argv[1]
lines = open(p).read().split("\n")
out = []
for l in lines:
    if "plasma-apply-wallpaperimage" in l and not l.lstrip().startswith("#"):
        out += ["# DotGrid live: живые обои сами следуют за файлом состояния ниже",
                'if [ ! -f "$HOME/.config/dotgrid/live.enabled" ]; then',
                "  " + l,
                "fi"]
    else:
        out.append(l)
open(p, "w").write("\n".join(out))
EOF
  say "dotgrid-theme: в live-режиме не трогает обои (бэкап: dotgrid-theme.bak.dotgrid-live)"
fi
# kitty in day/night colours: older dotgrid-theme versions did not switch it
if have kitty && [ -f "$TH" ] && ! grep -q 'dotgrid-current.conf' "$TH"; then
  KD="$HOME/.config/kitty"
  mkdir -p "$KD/dotgrid"
  cp "$DIR/assets/kitty-day.conf" "$KD/dotgrid/day.conf"
  cp "$DIR/assets/kitty-night.conf" "$KD/dotgrid/night.conf"
  cur=$(cat "${XDG_STATE_HOME:-$HOME/.local/state}/dotgrid-theme" 2>/dev/null || echo night)
  [ -f "$KD/dotgrid/$cur.conf" ] || cur=night
  cp "$KD/dotgrid/$cur.conf" "$KD/dotgrid-current.conf"
  [ -f "$KD/kitty.conf" ] && [ ! -f "$KD/kitty.conf.bak.dotgrid" ] && cp "$KD/kitty.conf" "$KD/kitty.conf.bak.dotgrid"
  grep -qs 'dotgrid-current.conf' "$KD/kitty.conf" || printf '\n# DotGrid (день/ночь)\ninclude dotgrid-current.conf\n' >> "$KD/kitty.conf"
  python3 - "$TH" <<'EOF2'
import sys
p = sys.argv[1]
t = open(p).read()
block = """# DotGrid kitty: day/night colours; running kitty windows reload on SIGUSR1
KD="$HOME/.config/kitty"
if [ -f "$KD/dotgrid/$1.conf" ]; then
  cp "$KD/dotgrid/$1.conf" "$KD/dotgrid-current.conf"
  pkill -USR1 -x kitty 2>/dev/null
fi
"""
i = t.index('STATE="${XDG_STATE_HOME')
open(p, "w").write(t[:i] + block + t[i:])
EOF2
  pkill -USR1 -x kitty 2>/dev/null || true
  say "kitty: цвета DotGrid день/ночь (~/.config/kitty/dotgrid/)"
fi
# lock screen (Meta+L): older dotgrid-theme versions did not set it
if [ -f "$TH" ] && ! grep -q 'kscreenlockerrc' "$TH"; then
  python3 - "$TH" <<'EOF2'
import sys
p = sys.argv[1]
t = open(p).read()
block = """# DotGrid lock screen: the static picture of the current theme (no clocks in it)
if command -v kwriteconfig6 >/dev/null; then
  kwriteconfig6 --file kscreenlockerrc --group Greeter --key WallpaperPlugin org.kde.image
  kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General --key Image "file://$HOME/Pictures/DotGrid/$I"
fi
"""
i = t.index('STATE="${XDG_STATE_HOME')
open(p, "w").write(t[:i] + block + t[i:])
EOF2
  cur=$(cat "${XDG_STATE_HOME:-$HOME/.local/state}/dotgrid-theme" 2>/dev/null || echo night)
  case "$cur" in day|night) ;; *) cur=night ;; esac
  kwriteconfig6 --file kscreenlockerrc --group Greeter --key WallpaperPlugin org.kde.image
  kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General --key Image "file://$HOME/Pictures/DotGrid/$cur.png"
  say "Экран блокировки: картинка DotGrid по теме"
fi
touch "$CFG/live.enabled"

# --- включить на рабочем столе ---
if [ "$APPLY" = 1 ]; then
  say "Включаю живые обои на всех экранах"
  res=$(python3 - <<'EOF'
import dbus
ps = dbus.Interface(dbus.SessionBus().get_object("org.kde.plasmashell", "/PlasmaShell"), "org.kde.PlasmaShell")
print(ps.evaluateScript("""
if (knownWallpaperPlugins()["DotGrid Live"] === undefined) {
    print("missing");
} else {
    var ds = desktops();
    for (var i = 0; i < ds.length; i++) {
        ds[i].wallpaperPlugin = "org.dotgrid.live";
        ds[i].currentConfigGroup = ["Wallpaper", "org.dotgrid.live", "General"];
        ds[i].writeConfig("Mode", "auto");
        ds[i].reloadConfig();
    }
    print("ok " + ds.length);
}
"""))
EOF
  ) || res="error"
  case "$res" in
    ok*) say "Готово: ${res#ok } рабочих стола" ;;
    *) warn "plasmashell не принял плагин ($res); статичные обои остались. Откат не нужен." ;;
  esac
fi

say "DotGrid Live установлен"
echo "Состояние:   dotgrid-live status"
echo "Пауза:       dotgrid-live toggle   (или Meta+Shift+P, или иконка в трее)"
echo "Удаление:    $DIR/uninstall-live.sh"
