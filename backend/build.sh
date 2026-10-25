#!/usr/bin/env bash
# Builds the QML backend and copies it into the wallpaper package, where the
# wallpaper imports it as a plain directory ("../backend"). No QML_IMPORT_PATH,
# no relogin. Without it the wallpaper still runs (static galaxy, no battery).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
dest="$here/../plugin/org.dotgrid.live/contents/backend"
cmake -S "$here" -B "$here/build" -G Ninja -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build "$here/build"
mkdir -p "$dest"
mod="$here/build/qml/org/dotgrid/live/backend"
cp "$mod/qmldir" "$mod/libdotgridlivebackend.so" "$mod/dotgridlivebackend.qmltypes" "$dest/"
echo "backend -> $dest"
