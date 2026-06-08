#!/usr/bin/env bash
# Workspace 8: localhost browser (left 1/3) + WezTerm (right 2/3).
# Called on login via 70-autostart.conf and on demand via $mod+ctrl+d.
set -euo pipefail

i3-msg "workspace 8"
i3-msg "append_layout $HOME/.config/regolith3/layouts/dev.json"

# Debug browser: opens a DevTools Protocol port so chrome-devtools MCP can attach
# (connect with `--browserUrl http://127.0.0.1:9222`). Since Chrome 136, the port
# is REFUSED on the default profile, so this must run in its own --user-data-dir —
# which also keeps the debug pane clean (no extensions/logins) and isolated from
# the main browser + PWAs. --class=chrome-dev routes it to ws8 (50-assignments).
google-chrome --class=chrome-dev \
  --user-data-dir="$HOME/.config/chrome-dev-profile" \
  --remote-debugging-port=9222 \
  --new-window http://localhost:3000 &
wezterm &
