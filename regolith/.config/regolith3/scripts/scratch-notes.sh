#!/usr/bin/env bash
# Toggle the floating ScratchPad notes browser on any workspace (i3 scratchpad).
# Bound to Super+Ctrl+n in 60-keybindings.conf.
#
# First press launches a small WezTerm running nvim's file browser over the
# vault's ScratchPad/ folder; the for_window rule in 50-assignments.conf floats,
# centers, marks, and stashes it. Subsequent presses show/hide that one window.
#
# --config-file loads a minimal isolated WezTerm config so the popup bypasses
# ~/.wezterm.lua (whose gui-startup handler would otherwise spawn the "city"
# tmux tabs). nvim is given by absolute path since i3 launches with a bare PATH.
set -euo pipefail

MARK=scratchnotes
NVIM=/home/linuxbrew/.linuxbrew/bin/nvim

# If the marked window already exists, toggle its visibility and we're done.
if i3-msg -t get_marks | grep -q "\"$MARK\""; then
  i3-msg "[con_mark=$MARK] scratchpad show" >/dev/null
  exit 0
fi

# Otherwise create it — the for_window rule handles float/center/mark/show.
exec wezterm --config-file "$HOME/.config/scratchnotes/wezterm.lua" \
  start --class "$MARK" -- \
  "$NVIM" -u "$HOME/.config/scratchnotes/init.lua" "$HOME/source/VaultWassail/ScratchPad"
