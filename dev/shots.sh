#!/usr/bin/env bash
# Renders the wallpaper offscreen into docs/shots/ (no plasmashell needed).
#   dev/shots.sh              this laptop (1766x1104 @1.45) and 1920x1080
#   dev/shots.sh 2560x1600:1  custom list of SIZE:SCALE
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p docs/shots
targets=("${@:-1766x1104:1.45 1920x1080:1}")
for t in ${targets[@]}; do
  size=${t%%:*}; scale=${t##*:}
  for mode in night day; do
    out="docs/shots/$mode-$size@$scale.png"
    QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen QT_SCALE_FACTOR=$scale timeout 30 \
      qml6 dev/host.qml -- --live=0 --mode=$mode --size=$size --inset=44 --shot="$out" 2>&1 | grep -v '^qml: saved' || true
    echo "$out"
  done
done
