#!/usr/bin/env bash
# Renders the static fallback wallpapers (lock screen, plugin missing) from
# the live wallpaper's own QML, so both look the same. No clocks in them.
#   tools/render-static.sh [WIDTHxHEIGHT]      default 2560x1600 -> assets/{day,night}.png
set -euo pipefail
cd "$(dirname "$0")/.."
size=${1:-2560x1600}
for mode in day night; do
  QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen timeout 60 \
    qml6 dev/host.qml -- --live=0 --static=1 --paused=1 --mode=$mode --size=$size \
      --delay=2500 --shot="assets/$mode.png" 2>&1 | grep -v '^qml: saved' || true
  echo "assets/$mode.png"
done
