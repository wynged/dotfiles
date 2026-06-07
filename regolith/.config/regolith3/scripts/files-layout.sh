#!/usr/bin/env bash
# Workspace 4: Nautilus (left 1/2) + WezTerm running Yazi (right 1/2).
# Invoked on demand via $mod+ctrl+f.
set -euo pipefail

i3-msg "workspace 4"
i3-msg "append_layout $HOME/.config/regolith3/layouts/files.json"
nautilus &
wezterm start -- yazi &
