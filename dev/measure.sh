#!/usr/bin/env bash
# CPU cost of the dev host on the real GPU (Wayland window), per scenario.
#   dev/measure.sh [seconds]
#   dev/measure.sh 20 --mode=night --off=galaxy     one custom scenario
# Prints % of one core used by the whole qml6 process (GUI + render thread).
set -euo pipefail
export LC_ALL=C
cd "$(dirname "$0")/.."
secs=${1:-20}
tck=$(getconf CLK_TCK)
run() {
  local label=$1; shift
  QT_QPA_PLATFORM=wayland qml6 dev/host.qml -- --live=0 --size=1766x1104 "$@" >/dev/null 2>&1 &
  local pid=$!
  sleep 4   # let it settle
  local a b
  a=$(awk '{print $14+$15}' "/proc/$pid/stat")
  sleep "$secs"
  b=$(awk '{print $14+$15}' "/proc/$pid/stat")
  kill "$pid"; wait "$pid" 2>/dev/null || true
  printf '%-28s %6.2f %% of one core\n' "$label" "$(awk -v d=$((b-a)) -v t=$tck -v s=$secs 'BEGIN{print d*100/t/s}')"
}
if [ $# -gt 1 ]; then shift; run "custom: $*" "$@"; exit; fi
run "night, running"       --mode=night
run "night, paused"        --mode=night --paused=1
run "day, running"         --mode=day
run "day, paused"          --mode=day --paused=1
