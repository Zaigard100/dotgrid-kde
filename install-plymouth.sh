#!/usr/bin/env bash
# Загрузочная заставка Plymouth "dotgrid". Запускайте от обычного пользователя: sudo спросит сам.
#   ./install-plymouth.sh              установить и включить (пересобирает initramfs, ~1 мин)
#   ./install-plymouth.sh --uninstall  вернуть прежнюю тему и убрать dotgrid
set -eu
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TH=/usr/share/plymouth/themes/dotgrid
PREV="$HOME/.config/dotgrid/plymouth.prev"
say() { printf '\033[1m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!!\033[0m %s\n' "$*"; }

if ! command -v plymouth-set-default-theme >/dev/null; then
  echo "Plymouth не установлен: sudo pacman -S plymouth, затем добавьте хук plymouth в /etc/mkinitcpio.conf и splash в параметры ядра"
  exit 1
fi

if [ "${1:-}" = "--uninstall" ]; then
  OLD="$(cat "$PREV" 2>/dev/null || echo bgrt)"
  say "Plymouth: возвращаю тему $OLD и пересобираю initramfs"
  sudo plymouth-set-default-theme -R "$OLD"
  sudo rm -rf "$TH"
  rm -f "$PREV"
  say "Готово"
  exit 0
fi

CUR="$(plymouth-set-default-theme)"
mkdir -p "$(dirname "$PREV")"
if [ ! -f "$PREV" ] && [ "$CUR" != dotgrid ]; then
  echo "$CUR" > "$PREV"
  say "Прежняя тема Plymouth запомнена: $CUR"
fi

# without these the theme is installed but never shown
grep -qw splash /proc/cmdline || warn "В параметрах ядра нет 'splash': заставка не появится (добавьте в /etc/default/grub, GRUB_CMDLINE_LINUX_DEFAULT)"
if [ -f /etc/mkinitcpio.conf ] && ! grep -qE '^HOOKS=.*\bplymouth\b' /etc/mkinitcpio.conf; then
  warn "В HOOKS /etc/mkinitcpio.conf нет plymouth: заставка не попадёт в initramfs"
fi

T="$(mktemp -d)"
python3 "$DIR/tools/make_plymouth.py" "$T" "$TH" >/dev/null
say "Копирую тему в $TH (нужен sudo)"
sudo mkdir -p "$TH"
sudo cp "$T"/* "$TH/"
rm -rf "$T"
say "Включаю dotgrid и пересобираю initramfs (mkinitcpio -P)"
sudo plymouth-set-default-theme -R dotgrid
cat <<MSG
Готово: заставка загрузки DotGrid. Видно при следующей загрузке.
Если при загрузке что-то не так: Esc показывает текстовый журнал загрузки.
Вернуть прежнюю ($(cat "$PREV" 2>/dev/null || echo bgrt)): ./install-plymouth.sh --uninstall
MSG
