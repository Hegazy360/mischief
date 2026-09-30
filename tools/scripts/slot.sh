#!/usr/bin/env bash
# CPU slots for every Godot / Blender process (R3D index §3.2, ruling R11): at most 4 such processes
# run at once in the container, each with ONE render thread.
#
#   tools/scripts/slot.sh <cmd...>
#
# Tries /tmp/mnd_slots/slot{1..MND_SLOTS}.lock with a non-blocking flock; when one is free the command
# runs (exec) holding that lock (the fd is inherited, so the lock lives exactly as long as the command)
# with MND_SLOT_HELD=1, MND_SLOT=<n>, LP_NUM_THREADS=${LP_NUM_THREADS:-1} and GALLIUM_THREAD=0 exported
# (llvmpipe otherwise starts one thread per core per GL context). Else it sleeps 3 s and retries,
# printing "[slot] waiting" once a minute; after MND_SLOT_WAIT seconds (default 1800) it gives up: exit 75.
# MND_SLOT_HELD=1 in the environment (a nested call from a process that already holds a slot): exec at once.
# Env: MND_SLOTS (default 4, never more than 4), MND_SLOT_WAIT (s), MND_SLOT_DIR (default /tmp/mnd_slots).
set -u
[ "$#" -gt 0 ] || { echo "usage: slot.sh <cmd...>" >&2; exit 64; }
if [ "${MND_SLOT_HELD:-}" = 1 ]; then exec "$@"; fi

n="${MND_SLOTS:-4}"
[[ "$n" =~ ^[0-9]+$ ]] || n=4
(( n > 4 )) && n=4
(( n < 1 )) && n=1
wait_s="${MND_SLOT_WAIT:-1800}"
[[ "$wait_s" =~ ^[0-9]+$ ]] || wait_s=1800
dir="${MND_SLOT_DIR:-/tmp/mnd_slots}"
mkdir -p "$dir" 2>/dev/null
chmod 1777 "$dir" 2>/dev/null || true

start=$SECONDS
last_msg=-1000
while :; do
  for ((i = 1; i <= n; i++)); do
    exec {fd}>>"$dir/slot$i.lock" || continue
    if flock -n "$fd"; then
      export MND_SLOT_HELD=1 MND_SLOT="$i" LP_NUM_THREADS="${LP_NUM_THREADS:-1}" GALLIUM_THREAD=0
      exec "$@"
    fi
    exec {fd}>&-
  done
  if (( SECONDS - start >= wait_s )); then
    echo "[slot] no free slot after ${wait_s}s (MND_SLOT_WAIT), giving up: $1" >&2
    exit 75
  fi
  if (( SECONDS - last_msg >= 60 )); then
    echo "[slot] waiting ($n/$n busy, $((SECONDS - start))s): $1" >&2
    last_msg=$SECONDS
  fi
  sleep 3
done
