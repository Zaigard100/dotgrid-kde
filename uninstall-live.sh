#!/usr/bin/env bash
# Удаляет DotGrid Live и возвращает статичные обои DotGrid.
#   ./uninstall-live.sh [--purge]
#     --purge  удалить и настройки ~/.config/dotgrid/live.json
# Остальная тема DotGrid (цвета, Konsole, kitty, таймер день/ночь) остаётся.
set -uo pipefail
PURGE=0
[ "${1:-}" = "--purge" ] && PURGE=1

say() { printf '\033[1m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!!\033[0m %s\n' "$*"; }

BIN="$HOME/.local/bin"
CFG="$HOME/.config/dotgrid"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/dotgrid-theme"
MODE=$(cat "$STATE" 2>/dev/null || echo night)
case "$MODE" in day|night) ;; *) MODE=night ;; esac

say "Останавливаю сервис"
systemctl --user disable --now dotgrid-livectl.service >/dev/null 2>&1
rm -f "$HOME/.config/systemd/user/dotgrid-livectl.service"
systemctl --user daemon-reload

say "Горячая клавиша"
python3 - <<'EOF' 2>/dev/null || warn "kglobalaccel не ответил; клавишу можно убрать в Параметрах"
import dbus
ga = dbus.Interface(dbus.SessionBus().get_object("org.kde.kglobalaccel", "/kglobalaccel"), "org.kde.KGlobalAccel")
ga.unRegister(["dotgrid-live", "toggle-pause", "DotGrid Live", ""])
EOF

say "Статичные обои: $MODE"
rm -f "$CFG/live.enabled"
if command -v plasma-apply-wallpaperimage >/dev/null && [ -f "$HOME/Pictures/DotGrid/$MODE.png" ]; then
  plasma-apply-wallpaperimage "$HOME/Pictures/DotGrid/$MODE.png" >/dev/null
else
  warn "Не смог вернуть обои: plasma-apply-wallpaperimage ~/Pictures/DotGrid/$MODE.png"
fi

say "Удаляю плагин, сервис и CLI"
kpackagetool6 --type Plasma/Wallpaper --remove org.dotgrid.live >/dev/null 2>&1 \
  || rm -rf "$HOME/.local/share/plasma/wallpapers/org.dotgrid.live"
rm -f "$BIN/dotgrid-livectl" "$BIN/dotgrid-live"

# dotgrid-theme: remove only the live wrapper (other edits, e.g. kitty, stay)
TH="$BIN/dotgrid-theme"
if [ -f "$TH" ] && grep -q "# DotGrid live" "$TH"; then
  python3 - "$TH" <<'PY'
import sys
p = sys.argv[1]
lines = open(p).read().split("\n")
out, i = [], 0
while i < len(lines):
    if lines[i].startswith("# DotGrid live") and i + 3 < len(lines) and "live.enabled" in lines[i + 1] \
            and lines[i + 3].strip() == "fi":
        out.append(lines[i + 2].strip())
        i += 4
    else:
        out.append(lines[i])
        i += 1
open(p, "w").write("\n".join(out))
PY
  say "dotgrid-theme: снова меняет картинку обоев"
fi

[ "$PURGE" = 1 ] && rm -f "$CFG/live.json" && say "Настройки live.json удалены"
say "Готово. Бэкапы конфига Plasma: ~/.config/plasma-org.kde.plasma.desktop-appletsrc.bak.dotgrid-live, $CFG/appletsrc.*.bak"
