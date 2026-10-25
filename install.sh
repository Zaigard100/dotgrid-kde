#!/usr/bin/env bash
# DotGrid для KDE Plasma 6 (Wayland/X11). Ставит шрифты, цветовые схемы, обои,
# профиль Konsole, конфиг fastfetch и команду dotgrid-theme night|day.
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPLY=1; FONTS=1; MODE=""; AUTO=1; SPLASH=1; SCHEDULE=sun; LAT=""; LON=""; DAY_AT=8; NIGHT_AT=20; ICON_NIGHT=DotGrid-Dark; ICON_DAY=DotGrid
LIVE=0; LIVE_ARGS=(); LOOK_ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --live) LIVE=1 ;;
    --live-only) LIVE=2 ;;
    --yes) LIVE_ARGS+=(--yes) ;;
    --no-apply) APPLY=0 ;;
    --no-fonts-download) FONTS=0 ;;
    --day) MODE=day ;;
    --night) MODE=night ;;
    --no-auto) AUTO=0 ;;
    --no-splash) SPLASH=0; LOOK_ARGS+=(--no-splash) ;;
    --no-icons) LOOK_ARGS+=(--no-icons) ;;
    --no-cursor) LOOK_ARGS+=(--no-cursor) ;;
    --no-decoration) LOOK_ARGS+=(--no-decoration) ;;
    --no-monitors) LOOK_ARGS+=(--no-monitors) ;;
    --day-at) shift; DAY_AT="${1:-8}"; SCHEDULE=hours ;;
    --night-at) shift; NIGHT_AT="${1:-20}"; SCHEDULE=hours ;;
    --lat) shift; LAT="${1:-}" ;;
    --lon) shift; LON="${1:-}" ;;
    --icons-night) shift; ICON_NIGHT="${1:-DotGrid-Dark}"; LOOK_ARGS+=(--no-icons) ;;
    --icons-day) shift; ICON_DAY="${1:-DotGrid}"; LOOK_ARGS+=(--no-icons) ;;
    -h|--help)
      echo "Использование: ./install.sh [--day|--night] [--no-apply] [--no-fonts-download] [--no-auto] [--lat ШИРОТА --lon ДОЛГОТА] [--day-at ЧАС] [--night-at ЧАС] [--icons-night ТЕМА] [--icons-day ТЕМА] [--no-splash] [--no-icons] [--no-cursor] [--no-decoration] [--no-monitors] [--live|--live-only] [--yes]"
      echo "Автопереключение по умолчанию: день от восхода до заката (место — по часовому поясу, --lat/--lon уточняют); --day-at/--night-at — по часам."
      echo "--live: ещё и живые обои (плагин, сервис, трей, CLI); --live-only: только живые обои."
      echo "--yes: недостающие пакеты для живых обоев ставить без вопроса."
      echo "Иконки, курсор, рамки окон, вид системных мониторов и заставка DotGrid ставятся по умолчанию; --no-icons, --no-cursor, --no-decoration, --no-monitors, --no-splash их пропускают."; exit 0 ;;
    *) echo "Неизвестный параметр: $1"; exit 1 ;;
  esac
  shift
done
case "$DAY_AT$NIGHT_AT" in *[!0-9]*) echo "Часы должны быть числами 0-23"; exit 1 ;; esac
if [ "$DAY_AT" -ge "$NIGHT_AT" ] || [ "$NIGHT_AT" -gt 23 ]; then echo "Нужно: ДЕНЬ < НОЧЬ, оба в диапазоне 0-23"; exit 1; fi

say() { printf '\033[1m==>\033[0m %s\n' "$*"; }
[ "$APPLY" = 0 ] && LIVE_ARGS+=(--no-apply)
# только живые обои: остальная тема не трогается
[ "$LIVE" = 2 ] && exec "$DIR/install-live.sh" "${LIVE_ARGS[@]}"
warn() { printf '\033[33m!!\033[0m %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

CS="$HOME/.local/share/color-schemes"
FN="$HOME/.local/share/fonts"
WP="$HOME/Pictures/DotGrid"
BIN="$HOME/.local/bin"
KON="$HOME/.local/share/konsole"
FF="$HOME/.config/fastfetch"
mkdir -p "$CS" "$FN" "$WP" "$BIN" "$KON" "$FF"

# --- бэкап ---
for f in kdeglobals konsolerc; do
  [ -f "$HOME/.config/$f" ] && [ ! -f "$HOME/.config/$f.bak.dotgrid" ] && cp "$HOME/.config/$f" "$HOME/.config/$f.bak.dotgrid" && say "Бэкап: ~/.config/$f.bak.dotgrid"
done

# --- цвета и обои ---
say "Цветовые схемы и обои"
cp "$DIR"/assets/DotGridNight.colors "$DIR"/assets/DotGridDay.colors "$CS/"
cp "$DIR/assets/night.png" "$WP/night.png"
cp "$DIR/assets/day.png" "$WP/day.png"

# --- шрифты ---
is_font() { [ -s "$1" ] && case "$(od -An -tx1 -N4 "$1" | tr -d ' \n')" in 00010000|74727565|4f54544f) return 0 ;; esac; return 1; }
if [ "$FONTS" = 1 ]; then
  if ! fc-list | grep -qi "JetBrains Mono"; then
    say "JetBrains Mono не найден, ставлю через pacman (нужен sudo)"
    if have pacman; then sudo pacman -S --needed --noconfirm ttf-jetbrains-mono || warn "Не удалось поставить JetBrains Mono"; else warn "pacman не найден, поставьте шрифт вручную"; fi
  fi
  if ! fc-list | grep -qi "Doto"; then
    say "Скачиваю Doto"
    T="$(mktemp)"
    for u in \
      "https://github.com/google/fonts/raw/main/ofl/doto/Doto%5BROND%2Cwght%5D.ttf" \
      "https://cdn.jsdelivr.net/gh/google/fonts@main/ofl/doto/Doto%5BROND%2Cwght%5D.ttf"; do
      curl -fsSL --max-time 60 -o "$T" "$u" 2>/dev/null && is_font "$T" && { cp "$T" "$FN/Doto[ROND,wght].ttf"; say "Doto установлен"; break; }
    done
    is_font "$FN/Doto[ROND,wght].ttf" || warn "Doto не скачался: скачайте на fonts.google.com/specimen/Doto и положите .ttf в $FN"
    rm -f "$T"
  fi
  fc-cache -f >/dev/null 2>&1 && say "Кеш шрифтов обновлён"
fi

# --- Konsole ---
say "Профиль Konsole"
cat > "$KON/DotGrid.colorscheme" <<'KC'
[Background]
Color=10,10,10
[BackgroundFaint]
Color=10,10,10
[BackgroundIntense]
Color=20,20,19
[Foreground]
Color=232,224,208
[ForegroundFaint]
Color=130,126,116
[ForegroundIntense]
Color=245,238,224
[Color0]
Color=28,28,26
[Color0Intense]
Color=92,90,84
[Color1]
Color=200,90,80
[Color1Intense]
Color=220,120,108
[Color2]
Color=140,180,120
[Color2Intense]
Color=162,200,142
[Color3]
Color=200,170,90
[Color3Intense]
Color=220,192,120
[Color4]
Color=150,160,170
[Color4Intense]
Color=176,186,196
[Color5]
Color=170,140,150
[Color5Intense]
Color=192,164,174
[Color6]
Color=140,170,160
[Color6Intense]
Color=164,194,184
[Color7]
Color=200,192,176
[Color7Intense]
Color=232,224,208
[General]
Description=DotGrid
Opacity=1
KC
cat > "$KON/DotGrid.profile" <<'KP'
[Appearance]
ColorScheme=DotGrid
Font=JetBrains Mono,12,-1,5,400,0,0,0,0,0,0,0,0,0,0,1
[General]
Name=DotGrid
Parent=FALLBACK/
[Scrolling]
ScrollBarPosition=2
KP
if have kwriteconfig6; then kwriteconfig6 --file konsolerc --group "Desktop Entry" --key DefaultProfile DotGrid.profile; fi

cp "$DIR/assets/konsole-day.colorscheme" "$KON/DotGridDay.colorscheme"
cp "$DIR/assets/konsole-day.profile" "$KON/DotGridDay.profile"

# --- kitty ---
say "kitty"
KD="$HOME/.config/kitty"; mkdir -p "$KD/dotgrid"
cp "$DIR/assets/kitty-night.conf" "$KD/dotgrid/night.conf"
cp "$DIR/assets/kitty-day.conf" "$KD/dotgrid/day.conf"
[ -f "$KD/dotgrid-current.conf" ] || cp "$KD/dotgrid/night.conf" "$KD/dotgrid-current.conf"
KC="$KD/kitty.conf"
if [ -f "$KC" ] && [ ! -f "$KC.bak.dotgrid" ]; then cp "$KC" "$KC.bak.dotgrid"; say "Бэкап: $KC.bak.dotgrid"; fi
grep -qs 'dotgrid-current.conf' "$KC" || printf '\n# DotGrid (день/ночь)\ninclude dotgrid-current.conf\n' >> "$KC"

# --- fastfetch ---
say "Конфиг fastfetch"
cat > "$FF/logo.txt" <<'LG'
. . . . . . . . . . .
. ▪ ▪ ▪ ▪ ▪ ▪ ▪ ▪ . .
. ▪ . . . . . . ▪ . .
. ▪ . 0 0 0 0 . ▪ . .
. ▪ . 0 . . 0 . ▪ . .
. ▪ . 0 0 0 0 . ▪ . .
. ▪ . . . . . . ▪ . .
. ▪ ▪ ▪ ▪ ▪ ▪ ▪ ▪ . .
. . . . . . . . . . .
LG
cat > "$FF/config.jsonc" <<'FC'
{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": { "type": "file", "source": "~/.config/fastfetch/logo.txt", "padding": { "right": 3 } },
  "modules": ["title", "separator", "os", "kernel", "uptime", "packages", "shell", "de", "cpu", "gpu", "memory", "disk", "battery"]
}
FC

# --- команда dotgrid-theme ---
say "Команда dotgrid-theme"
cat > "$BIN/dotgrid-theme" <<'TH'
#!/usr/bin/env bash
case "${1:-}" in
  night) S=DotGridNight; I=night.png; K=night; KP=DotGrid ;;
  day)   S=DotGridDay;   I=day.png;   K=day;   KP=DotGridDay ;;
  *) echo "Использование: dotgrid-theme night|day"; exit 1 ;;
esac
ICON_NIGHT=DotGrid-Dark; ICON_DAY=DotGrid
[ -f "$HOME/.config/dotgrid/schedule" ] && . "$HOME/.config/dotgrid/schedule"
if [ "$K" = night ]; then ICON="$ICON_NIGHT"; else ICON="$ICON_DAY"; fi

command -v plasma-apply-colorscheme >/dev/null && plasma-apply-colorscheme "$S"
# DotGrid live: живые обои сами следуют за файлом состояния ниже
if [ ! -f "$HOME/.config/dotgrid/live.enabled" ]; then
  command -v plasma-apply-wallpaperimage >/dev/null && plasma-apply-wallpaperimage "$HOME/Pictures/DotGrid/$I"
fi

if command -v kwriteconfig6 >/dev/null; then
  if [ -d "$HOME/.local/share/icons/$ICON" ] || [ -d "/usr/share/icons/$ICON" ]; then
    kwriteconfig6 --file kdeglobals --group Icons --key Theme "$ICON"
    dbus-send --session --type=signal /KGlobalSettings org.kde.KGlobalSettings.notifyChange int32:4 int32:0 2>/dev/null
  else
    echo "Тема иконок '$ICON' не найдена, пропускаю" >&2
  fi
  kwriteconfig6 --file konsolerc --group "Desktop Entry" --key DefaultProfile "$KP.profile"
fi

if command -v kwriteconfig6 >/dev/null; then
  kwriteconfig6 --file kscreenlockerrc --group Greeter --key WallpaperPlugin org.kde.image
  kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General --key Image "file://$HOME/Pictures/DotGrid/$I"
fi

KD="$HOME/.config/kitty"
if [ -f "$KD/dotgrid/$K.conf" ]; then
  cp "$KD/dotgrid/$K.conf" "$KD/dotgrid-current.conf"
  pkill -USR1 -x kitty 2>/dev/null
fi

# DotGrid look: the splash learns day/night (icons are switched above)
SPLASH_MODE="$HOME/.local/share/plasma/look-and-feel/org.dotgrid.splash/contents/splash/Mode.qml"
if [ -d "$(dirname "$SPLASH_MODE")" ]; then
  [ "$K" = night ] && N=true || N=false
  printf 'import QtQuick 2.15\nQtObject { property bool known: true; property bool night: %s }\n' "$N" > "$SPLASH_MODE"
fi

# DotGrid decoration: the Aurorae title bars of the theme
[ "$K" = night ] && DECO=DotGrid-Dark || DECO=DotGrid
if [ -d "$HOME/.local/share/aurorae/themes/$DECO" ]; then
  kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library org.kde.kwin.aurorae
  kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme "__aurorae__svg__$DECO"
  gdbus call --session -d org.kde.KWin -o /KWin -m org.kde.KWin.reconfigure >/dev/null 2>&1
fi

STATE="${XDG_STATE_HOME:-$HOME/.local/state}/dotgrid-theme"
mkdir -p "$(dirname "$STATE")"; echo "$1" > "$STATE"
TH
chmod +x "$BIN/dotgrid-theme"
case ":$PATH:" in *":$BIN:"*) ;; *) warn "$BIN нет в PATH: добавьте в ~/.bashrc или ~/.zshrc: export PATH=\"\$HOME/.local/bin:\$PATH\"" ;; esac

# --- иконки, курсор, рамки окон, заставка (точечная матрица) ---
[ "$APPLY" = 0 ] && LOOK_ARGS+=(--no-apply)
"$DIR/install-look.sh" "${LOOK_ARGS[@]}"

# --- автопереключение день/ночь ---
mkdir -p "$HOME/.config/dotgrid" "$HOME/.config/systemd/user"
SCHED="$HOME/.config/dotgrid/schedule"
# a place set earlier stays unless --lat/--lon give a new one
if [ -z "$LAT$LON" ] && [ -f "$SCHED" ]; then eval "$(grep -E '^(LAT|LON)=[-+0-9.]*$' "$SCHED")"; fi
{
  echo "# DotGrid: SCHEDULE=sun switches at sunrise/sunset, SCHEDULE=hours at DAY_AT/NIGHT_AT"
  echo "# LAT/LON: the place for the sun (empty: the main city of the time zone)"
  printf 'SCHEDULE=%s\nLAT=%s\nLON=%s\nDAY_AT=%s\nNIGHT_AT=%s\nICON_NIGHT=%s\nICON_DAY=%s\n' \
    "$SCHEDULE" "$LAT" "$LON" "$DAY_AT" "$NIGHT_AT" "$ICON_NIGHT" "$ICON_DAY"
} > "$SCHED"
install -m755 "$DIR/assets/dotgrid-auto" "$BIN/dotgrid-auto"
say "Автопереключение: $("$BIN/dotgrid-auto" --show | head -1)"
if [ "$AUTO" = 1 ]; then
  printf '[Unit]\nDescription=DotGrid day/night switch\n\n[Service]\nType=oneshot\nExecStart=%%h/.local/bin/dotgrid-auto\n' > "$HOME/.config/systemd/user/dotgrid-auto.service"
  printf '[Unit]\nDescription=DotGrid day/night schedule\n\n[Timer]\nOnStartupSec=25\nOnCalendar=*:0/10\nAccuracySec=1min\n\n[Install]\nWantedBy=timers.target\n' > "$HOME/.config/systemd/user/dotgrid-auto.timer"
  if have systemctl && [ "$APPLY" = 1 ]; then
    systemctl --user daemon-reload && systemctl --user enable --now dotgrid-auto.timer && say "Таймер включён" || warn "Не удалось включить таймер: systemctl --user enable --now dotgrid-auto.timer"
  fi
fi

# --- применение ---
if [ "$APPLY" = 1 ]; then
  if have kwriteconfig6; then
    kwriteconfig6 --file kdeglobals --group General --key fixed "JetBrains Mono,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
    say "Моноширинный шрифт системы: JetBrains Mono"
  fi
  if have plasma-apply-colorscheme; then
    if [ -n "$MODE" ]; then "$BIN/dotgrid-theme" "$MODE"; say "Применена тема: $MODE"
    else "$BIN/dotgrid-auto" --force; say "Применена тема по текущему времени"; fi
  else warn "plasma-apply-colorscheme не найден, выберите тему вручную в Настройках"; fi
fi

[ "$LIVE" = 1 ] && "$DIR/install-live.sh" "${LIVE_ARGS[@]}"

say "Готово. Выйдите из сеанса и войдите снова, чтобы всё подхватилось."
echo "Переключение: dotgrid-theme night | dotgrid-theme day"
echo "Отключить авто: systemctl --user disable --now dotgrid-auto.timer"
echo "Восход/закат и место: dotgrid-auto --show; поменять: ~/.config/dotgrid/schedule (LAT, LON, SCHEDULE=hours)"
echo "Иконки и курсор DotGrid; другая тема иконок: ./install.sh --icons-night ИМЯ --icons-day ИМЯ; вернуть прежние: ./uninstall-look.sh"
echo "Экран входа SDDM (нужен sudo, ставится отдельно): ./install-sddm.sh"
echo "Откат: cp ~/.config/kdeglobals.bak.dotgrid ~/.config/kdeglobals"
