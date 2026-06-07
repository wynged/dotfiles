#!/usr/bin/env bash
# Toggle the floating ScratchPad notes browser on any workspace (i3 scratchpad).
# Bound to $mod+n in 60-keybindings.conf.
#
# First press launches a small WezTerm running nvim's file browser over the
# vault's ScratchPad/ folder; the for_window rule in 50-assignments.conf floats,
# centers, marks, and stashes it. Subsequent presses show/hide that one window.
set -euo pipefail

MARK=scratchnotes

# If the marked window already exists, toggle its visibility and we're done.
if i3-msg -t get_marks | grep -q "\"$MARK\""; then
  i3-msg "[con_mark=$MARK] scratchpad show" >/dev/null
  exit 0
fi

# Otherwise create it — the for_window rule handles float/center/mark/show.
exec wezterm start --class "$MARK" -- \
  nvim -u "$HOME/.config/scratchnotes/init.lua" "$HOME/source/VaultWassail/ScratchPad"
