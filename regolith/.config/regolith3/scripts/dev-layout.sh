#!/usr/bin/env bash
# Workspace 8: localhost browser (left 1/3) + WezTerm (right 2/3).
# Called on login via 70-autostart.conf and on demand via $mod+ctrl+d.
set -euo pipefail

i3-msg "workspace 8"
i3-msg "append_layout $HOME/.config/regolith3/layouts/dev.json"
google-chrome --class=chrome-dev --new-window http://localhost:3000 &
wezterm &
