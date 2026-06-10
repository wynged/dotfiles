#!/usr/bin/env bash
# Launch Polybar on every connected monitor.
#
# Wired into i3 via `exec_always` (see i3/config.d/70-autostart.conf), so this
# runs on login AND on every `i3 reload` (Super+Shift+c). It kills any running
# instances first, which is what makes a reload bring up a fresh bar cleanly.

# pkill (procps) is more universally present than killall (psmisc).
pkill -x polybar 2>/dev/null || true

# Wait for the old processes to exit before starting new ones — but BOUNDED, so
# a stuck/unkillable instance can never hang login (max ~2.5s).
for _ in $(seq 1 25); do
  pgrep -u "$UID" -x polybar >/dev/null || break
  sleep 0.1
done

# One bar per connected monitor. On a single ultrawide this is just one.
if type polybar >/dev/null 2>&1; then
  for m in $(polybar --list-monitors | cut -d: -f1); do
    MONITOR="$m" polybar --reload main >"/tmp/polybar-${m}.log" 2>&1 &
    disown
  done
fi

# The recording indicator ([module/recording]) is custom/ipc, which resets to
# its blank initial state on every (re)launch. If a gpu-screen-recorder is
# already running (e.g. this is an i3 reload mid-recording), re-show "● REC"
# once the new bar's IPC socket is ready. Bracketed [g] so this never matches
# its own command line.
if pgrep -f '[g]pu-screen-recorder' >/dev/null 2>&1; then
  for _ in $(seq 1 20); do
    polybar-msg action "#recording.hook.1" >/dev/null 2>&1 && break
    sleep 0.1
  done
fi
