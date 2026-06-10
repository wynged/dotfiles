#!/usr/bin/env bash
# Workspace 8: localhost browser (left 1/3) + WezTerm (right 2/3).
# Called on login via 70-autostart.conf and on demand via $mod+ctrl+d.
set -euo pipefail

i3-msg "workspace 8"
i3-msg "append_layout $HOME/.config/regolith3/layouts/dev.json"

# Debug browser (DevTools port 9222 for the chrome-devtools MCP). The launch
# flags live in debug-browser.sh, which is idempotent — on login it just launches,
# and Super+Ctrl+Shift+d reuses it to reopen/focus the browser on its own.
"$HOME/.config/regolith3/scripts/debug-browser.sh" &
wezterm &
