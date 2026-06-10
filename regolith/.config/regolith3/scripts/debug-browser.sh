#!/usr/bin/env bash
# Reopen (or focus) the workspace-8 debug Chrome that exposes DevTools port 9222
# so the chrome-devtools MCP can attach (--browserUrl http://127.0.0.1:9222).
#
# Idempotent: if the debug port is already live, just focus the existing window
# instead of spawning a duplicate (a second --remote-debugging-port=9222 instance
# can't bind the port anyway, and re-launching with the same --user-data-dir would
# only hand off a new tab to the running instance without reopening the port).
#
# Bound to Super+Ctrl+Shift+d. Also called by dev-layout.sh so the launch flags
# live in exactly one place.
set -euo pipefail

PORT=9222
URL="${1:-http://localhost:3000}"

# Already running? Switch to ws8 and focus it; don't launch another.
if curl -sf "http://127.0.0.1:${PORT}/json/version" >/dev/null 2>&1; then
  i3-msg '[class="chrome-dev"] focus' >/dev/null
  exit 0
fi

# Not running — launch it. --class=chrome-dev routes the window to ws8 via
# 50-assignments.conf. The dedicated --user-data-dir is mandatory: since Chrome
# 136 the remote-debugging port is refused on the default profile, and it also
# keeps the debug pane clean/isolated from the main browser + PWAs.
google-chrome --class=chrome-dev \
  --user-data-dir="$HOME/.config/chrome-dev-profile" \
  --remote-debugging-port="$PORT" \
  --new-window "$URL" &
