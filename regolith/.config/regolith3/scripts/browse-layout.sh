#!/usr/bin/env bash
# Workspace 10: Claude Desktop (left 1/3) + general Chrome (right 2/3).
# Called on login via 70-autostart.conf and on demand via $mod+ctrl+b.
#
# append_layout pre-creates two sized placeholder slots, so each app drops into
# the same third/two-thirds split every time instead of an even 50/50. Claude is
# swallowed by class ^Claude$, the general browsing window by class ^Google-chrome$.
set -euo pipefail

i3-msg "workspace 10"
i3-msg "append_layout $HOME/.config/regolith3/layouts/browse.json"

# Claude pins to the left third; general Chrome (Default profile) fills the rest.
# The PWA app windows (Slack/Gather/YouTube Music) are launched by startup-apps.sh
# and self-route to ws7/ws9 — this general window stays on ws10 (class Google-chrome).
claude-desktop &
google-chrome &
