#!/usr/bin/env bash
# Workspace 10: Claude Desktop + Obsidian (tabbed, left 1/3) + general Chrome
# (right 2/3). Called on login via 70-autostart.conf and on demand via $mod+ctrl+b.
#
# append_layout pre-creates the sized placeholder slots, so each app drops into
# the same third/two-thirds split every time instead of an even 50/50. The left
# third is a tabbed container: Claude (^Claude$) and Obsidian (^obsidian$) stack
# as tabs — Super+Left/Right flips between them. The general browsing window
# (^Google-chrome$) fills the right two-thirds.
set -euo pipefail

i3-msg "workspace 10"
i3-msg "append_layout $HOME/.config/regolith3/layouts/browse.json"

# Claude + Obsidian pin to the tabbed left third; general Chrome (Default profile)
# fills the rest. The PWA app windows (Slack/Gather/YouTube Music) are launched by
# startup-apps.sh and self-route to ws7/ws9 — this general window stays on ws10
# (class Google-chrome).
claude-desktop &
obsidian &
google-chrome &
