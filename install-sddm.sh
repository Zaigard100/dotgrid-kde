#!/usr/bin/env bash
# Тема входа SDDM "dotgrid". Запускайте от обычного пользователя: sudo спросит сам.
#   ./install-sddm.sh              установить и включить
#   ./install-sddm.sh --uninstall  убрать и вернуть прежнюю тему
set -eu
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TH=/usr/share/sddm/themes/dotgrid
CONF=/etc/sddm.conf.d/10-dotgrid.conf

if [ "${1:-}" = "--uninstall" ]; then
  sudo rm -rf "$TH" "$CONF"
  echo "Тема SDDM удалена. Вход вернётся к теме по умолчанию."
  exit 0
fi

DAY_AT=8; NIGHT_AT=20; SCHEDULE=sun
[ -f "$HOME/.config/dotgrid/schedule" ] && . "$HOME/.config/dotgrid/schedule"
# the place for the sun, baked into the theme (the greeter cannot read ~/.config)
LAT=NaN; LON=NaN
if [ "$SCHEDULE" != hours ]; then
  AUTO="$(command -v dotgrid-auto || echo "$DIR/assets/dotgrid-auto")"
  read -r LAT LON < <("$AUTO" --coords 2>/dev/null || echo NaN NaN)
fi

T="$(mktemp -d)"
cp "$DIR"/assets/sddm/metadata.desktop "$T/"
# the user running the installer is filled in when SDDM remembers nobody
SDDM_USER="${DOTGRID_SDDM_USER:-$USER}"
printf '[General]\ndefaultUser=%s\n' "$SDDM_USER" > "$T/theme.conf"
sed "s/@DAY_AT@/$DAY_AT/g; s/@NIGHT_AT@/$NIGHT_AT/g; s/@LAT@/$LAT/; s/@LON@/$LON/" "$DIR/assets/sddm/Main.qml.in" > "$T/Main.qml"
[ -f "$DIR/assets/sddm/preview.png" ] && cp "$DIR/assets/sddm/preview.png" "$T/preview.png"
# background: the static DotGrid composition (same pictures as the lock screen, no clocks)
cp "$DIR/assets/day.png" "$DIR/assets/night.png" "$T/"

echo "Копирую тему в $TH (нужен sudo)"
sudo rm -rf "$TH"
sudo mkdir -p "$TH" /etc/sddm.conf.d
sudo cp -r "$T"/. "$TH/"
printf '[Theme]\nCurrent=dotgrid\n' | sudo tee "$CONF" >/dev/null
rm -rf "$T"
[ "$LAT" = NaN ] && WHEN="день с $DAY_AT:00, ночь с $NIGHT_AT:00" || WHEN="день от восхода до заката ($LAT, $LON)"

cat <<MSG
Готово. Тема включена, пользователь по умолчанию: $SDDM_USER; $WHEN (экран входа не видит тему пользователя, поэтому выбирает сам).

ПРОВЕРЬТЕ ДО ВЫХОДА ИЗ СЕАНСА (откроется окно с экраном входа, закрыть: Ctrl+C в терминале):
  sddm-greeter-qt6 --test-mode --theme $TH

Если после перезагрузки экран входа чёрный или пустой: Ctrl+Alt+F3, войдите в консоль и выполните
  sudo rm -f $CONF && sudo systemctl restart sddm
или запустите ./install-sddm.sh --uninstall
MSG
