#!/usr/bin/env bash
# DotGrid в Zen Browser и Firefox: цвета темы, точечная сетка за вкладками,
# JetBrains Mono. День/ночь браузер берёт из системной схемы сам.
#   ./install-browser.sh              во все найденные профили
#   ./install-browser.sh --uninstall  убрать
# Свои userChrome.css / userContent.css не перезаписываются: в начало
# добавляется строка @import с пометкой DotGrid. Нужен перезапуск браузера.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
say() { printf '\033[1m==>\033[0m %s\n' "$*"; }
MARK="/* DotGrid */"
PREF='user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true); // DotGrid'

profiles() {
  for root in "$HOME/.config/zen" "$HOME/.zen" "$HOME/.mozilla/firefox" "$HOME/.config/mozilla/firefox"; do
    [ -f "$root/profiles.ini" ] || continue
    grep '^Path=' "$root/profiles.ini" | cut -d= -f2- | while read -r p; do
      case "$p" in /*) d="$p" ;; *) d="$root/$p" ;; esac
      [ -f "$d/prefs.js" ] && echo "$d"
    done
  done
}

# adds or removes the @import line at the top of a chrome css file
link() {   # link FILE IMPORT add|remove
  local f="$1" line="@import url(\"$2\"); $MARK"
  if [ "$3" = add ]; then
    [ -f "$f" ] && grep -qF "$MARK" "$f" && return
    { echo "$line"; [ -f "$f" ] && cat "$f"; } > "$f.dotgrid-new"
    mv "$f.dotgrid-new" "$f"
  elif [ -f "$f" ]; then
    grep -vF "$MARK" "$f" > "$f.dotgrid-new" || true
    if [ -s "$f.dotgrid-new" ]; then mv "$f.dotgrid-new" "$f"; else rm -f "$f.dotgrid-new" "$f"; fi
  fi
}

mapfile -t PROFILES < <(profiles)
[ ${#PROFILES[@]} -gt 0 ] || { echo "Профили Zen/Firefox не найдены"; exit 0; }

for d in "${PROFILES[@]}"; do
  if [ "${1:-}" = "--uninstall" ]; then
    link "$d/chrome/userChrome.css" dotgrid.css remove
    link "$d/chrome/userContent.css" dotgrid-content.css remove
    rm -f "$d/chrome/dotgrid.css" "$d/chrome/dotgrid-content.css"
    if [ -f "$d/user.js" ]; then
      grep -vF "// DotGrid" "$d/user.js" > "$d/user.js.dotgrid-new" || true
      if [ -s "$d/user.js.dotgrid-new" ]; then mv "$d/user.js.dotgrid-new" "$d/user.js"; else rm -f "$d/user.js.dotgrid-new" "$d/user.js"; fi
    fi
    say "Убрано: ${d/#$HOME/~}"
    continue
  fi
  mkdir -p "$d/chrome"
  cp "$DIR/assets/browser/dotgrid.css" "$DIR/assets/browser/dotgrid-content.css" "$d/chrome/"
  link "$d/chrome/userChrome.css" dotgrid.css add
  link "$d/chrome/userContent.css" dotgrid-content.css add
  # browsers read userChrome.css only with this pref
  grep -qF "// DotGrid" "$d/user.js" 2>/dev/null || echo "$PREF" >> "$d/user.js"
  say "DotGrid: ${d/#$HOME/~}"
done
echo "Перезапустите браузер. Вернуть как было: $0 --uninstall"
