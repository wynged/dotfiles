#!/usr/bin/env bash
# ShareX-style screen recorder toggle, backed by gpu-screen-recorder (AMD VAAPI).
# Bound to Super+Shift+v (window) and Super+Ctrl+Shift+v (whole screen) in
# 60-keybindings.conf — the screenshot/flameshot of video.
#
# First press: pick a target and start a hardware-encoded recording.
#   - "window" (default): the cursor becomes a crosshair — click the window to
#     capture. gpu-screen-recorder follows that window as it moves/resizes.
#   - "screen": records the whole screen, no prompt.
# Second press of the same key: SIGINT tells gpu-screen-recorder to finalize the
# file and exit, so the toggle just stops + saves.
#
# Feedback: gsr draws no on-screen indicator and rofication doesn't toast
# notifications, so we drive a polybar "● REC" indicator over IPC — hook.1 on
# start, hook.0 on stop (see [module/recording] in polybar/config.ini). This is
# also what the indicator's own click-to-stop runs.
#
# Output lands in ~/Videos/rec-<timestamp>.mkv. mkv (not mp4) because Ubuntu's
# FFmpeg 7 has a buggy mp4 muxer that gsr warns can stutter, and mkv stays playable
# even if the recorder is killed without a clean stop. To share as mp4, remux
# losslessly:  ffmpeg -i rec-….mkv -c copy rec-….mp4
# Desktop audio is captured by default; to also record the mic, change
# "default_output" below to "default_output|default_input" (gsr merges sources
# joined by |).
#
# i3 launches scripts with a bare PATH, so set it explicitly for gpu-screen-recorder
# (/usr/bin, meson prefix=/usr), xdotool, pkill/pgrep, notify-send and date.
set -euo pipefail
export PATH=/usr/local/bin:/usr/bin:/bin

OUTDIR="$HOME/Videos"
# Match the full command line, not the comm name: Linux truncates /proc/comm to
# 15 chars so `pgrep -x gpu-screen-recorder` would never match.
MATCH='gpu-screen-recorder'

# Flip the polybar indicator. Guarded so a missing/not-yet-ready polybar never
# aborts the recording (set -e would otherwise kill us on a failed send).
bar() { polybar-msg action "#recording.hook.$1" >/dev/null 2>&1 || true; }

# Already recording? Stop and save.
if pgrep -f "$MATCH" >/dev/null; then
  pkill -SIGINT -f "$MATCH"
  bar 0
  notify-send -i media-record-symbolic "Screen recording" "Stopped — saved to $OUTDIR"
  exit 0
fi

mkdir -p "$OUTDIR"
out="$OUTDIR/rec-$(date +%Y%m%d-%H%M%S).mkv"

case "${1:-window}" in
  screen) target="screen" ;;
  window)
    notify-send -i media-record-symbolic "Screen recording" "Click the window to record…"
    target="$(xdotool selectwindow)" || exit 1
    ;;
  *) target="$1" ;;
esac

bar 1
notify-send -i media-record-symbolic "Screen recording" "Recording — press the hotkey again to stop"
exec gpu-screen-recorder -w "$target" -f 60 -a default_output -o "$out"
