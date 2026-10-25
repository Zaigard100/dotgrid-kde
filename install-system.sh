#!/usr/bin/env bash
# Всё, что требует sudo, одним запуском: экран входа SDDM и загрузочная заставка Plymouth.
# Запускайте от обычного пользователя; пароль спросят один раз.
#   ./install-system.sh              установить оба
#   ./install-system.sh --uninstall  убрать оба
set -eu
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sudo -v
"$DIR/install-sddm.sh" "$@"
echo
if command -v plymouth-set-default-theme >/dev/null; then
  "$DIR/install-plymouth.sh" "$@"
else
  echo "Plymouth не установлен, загрузочную заставку пропускаю"
fi
