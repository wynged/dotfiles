-- Minimal, isolated WezTerm config for the i3 ScratchPad notes popup.
-- Loaded via `wezterm --config-file` so it bypasses ~/.wezterm.lua entirely —
-- no gui-startup handler, no "city" tmux tabs. Just a bare window running nvim's
-- file browser (the actual program is passed on the CLI by scratch-notes.sh).
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

local home = os.getenv('HOME')
-- Fallback program if launched without an explicit CLI command.
config.default_prog = {
  '/home/linuxbrew/.linuxbrew/bin/nvim',
  '-u', home .. '/.config/scratchnotes/init.lua',
  home .. '/source/VaultWassail/ScratchPad',
}

config.enable_tab_bar = false
config.window_padding = { left = 6, right = 6, top = 6, bottom = 6 }
config.window_close_confirmation = 'NeverPrompt'

return config
