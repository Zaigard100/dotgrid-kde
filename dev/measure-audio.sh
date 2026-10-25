#!/usr/bin/env bash
# CPU of dotgrid-livectl's audio path without touching the speakers: a
# temporary null sink gets test audio, the service captures that sink.
#   dev/measure-audio.sh [seconds]
set -euo pipefail
export LC_ALL=C
cd "$(dirname "$0")/.."
secs=${1:-15}
tmp=$(mktemp -d)
trap 'pkill -x pw-play 2>/dev/null || true; [ -n "${D:-}" ] && kill "$D" 2>/dev/null; [ -n "${MOD:-}" ] && pactl unload-module "$MOD"; live/dotgrid-live mode "$OLDMODE" >/dev/null; rm -rf "$tmp"' EXIT

OLDMODE=$(python3 -c "import json,os; print(json.load(open(os.path.expanduser('~/.config/dotgrid/live.json'))).get('mode','auto'))" 2>/dev/null || echo auto)
python3 -I - "$tmp" <<'EOF'
import sys, wave, numpy as np
d = sys.argv[1]; r = 48000; t = np.arange(r * 60) / r
sig = sum(a * np.sin(2 * np.pi * f * t) * (0.6 + 0.4 * np.sin(2 * np.pi * m * t))
          for f, a, m in [(110, .3, .5), (330, .2, .8), (880, .12, 1.3), (2500, .06, 2.1), (5000, .03, .7)])
for name, s in (("music", sig), ("silence", 0 * sig)):
    w = wave.open(f"{d}/{name}.wav", "wb"); w.setnchannels(2); w.setsampwidth(2); w.setframerate(r)
    w.writeframes((np.stack([s, s * .7], 1) * 32767).astype(np.int16).tobytes()); w.close()
EOF

MOD=$(pactl load-module module-null-sink sink_name=dotgrid_test sink_properties=device.description=DotGridTest)
live/dotgrid-live mode night >/dev/null
DOTGRID_AUDIO_TARGET=dotgrid_test live/dotgrid-livectl --no-tray 2>"$tmp/log" &
D=$!
sleep 1.5

meas() {
  local a b
  a=$(awk '{print $14+$15}' /proc/$D/stat); sleep "$secs"; b=$(awk '{print $14+$15}' /proc/$D/stat)
  printf '%-22s service %5.2f %% of one core, pw-record running: %s, autopause: %s\n' "$1" \
    "$(awk -v x=$((b-a)) -v s="$secs" -v t="$(getconf CLK_TCK)" 'BEGIN{print x*100/t/s}')" \
    "$(pgrep -c -x pw-record || true)" \
    "$(live/dotgrid-live status --json | python3 -c 'import json,sys; print(",".join(json.load(sys.stdin)["auto_reasons"]) or "-")')"
}
meas "nothing playing"
pw-play --target dotgrid_test "$tmp/music.wav" & sleep 1
meas "music playing"
pkill -x pw-play; sleep 0.5
pw-play --target dotgrid_test "$tmp/silence.wav" & sleep 4
meas "silent stream open"
pkill -x pw-play
echo "--- service log"; cat "$tmp/log"
