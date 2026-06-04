-- Wezterm config (native Ubuntu): tmux/city startup (lookout | mayor) + naive
-- tmux + hall shim. Migrated from WSL — every `wsl.exe -d Ubuntu-Dev -- bash -lc`
-- wrapper is now a plain `bash -lc`, since wezterm runs natively in Linux. The
-- lookout/mayor/hall orchestration and the /run/user/1000/*.sock paths are
-- unchanged (same XDG runtime dir on a native session).
local wezterm = require 'wezterm'
local mux = wezterm.mux
local act = wezterm.action

local config = wezterm.config_builder()

-- Default working dir for new tabs/panes and the startup layout.
local SOURCE = '/home/sirwassail/source'

-- Appearance: tab bar on, dark
config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = false
config.use_fancy_tab_bar = false
config.font_size = 12.0
config.color_scheme = 'Tokyo Night'

-- New tabs / panes default to a login zsh in the source dir.
config.default_prog = { 'zsh', '-l' }
config.default_cwd = SOURCE

-- xterm-256color is universally present in terminfo; the native 'wezterm'
-- entry requires installing wezterm's terminfo, so we keep the safe default
-- (also avoids Claude Code's bracketed-paste-end detection dropping pastes).
config.term = 'xterm-256color'

-- Every startup pane runs through `bash -lc` so we can keep it ALIVE in a valid
-- state when the thing it wants to attach to isn't there yet (fresh boot, city
-- not started). Without this a failed `tmux attach` / dead socket exits the
-- pane immediately, leaving useless closed tabs after a computer restart.
local HALL_SOCK = '/run/user/1000/lookout-hall.sock'
-- The crew-viewer (mayor) pane records its Linux tty here on attach so the
-- hall can deterministically retarget *that* pane with switch-client instead
-- of guessing by client activity (and so Ctrl+Shift+L can toggle the viewer
-- in/out of the lookout dashboard reversibly). Must match lookout's
-- viewerTTYPinPath (XDG_RUNTIME_DIR/lookout-hall-viewer.tty).
local VIEWER_TTY = '/run/user/1000/lookout-hall-viewer.tty'
local function sh(script)
  return { 'bash', '-lc', script }
end

-- lookout hall TUI; if it crashes/exits (e.g. city down) drop to a shell so the
-- pane stays usable instead of closing.
local LOOKOUT = sh("/home/sirwassail/source/city_hy/lookout/lookout hall --city /home/sirwassail/source/city_hy || exec zsh -l")

-- mayor tmux session on the city_hy socket — the crew viewer the hall drives.
-- Records its tty to VIEWER_TTY first (the switch-client pin), then attaches.
-- If the city isn't running the session won't exist, so fall back to an
-- interactive shell where you can start it (rather than a dead pane).
local MAYOR   = sh("tty > '" .. VIEWER_TTY .. "' 2>/dev/null; tmux -L city_hy attach -t mayor || { echo '[mayor session not up - city may be down. start the city, then: tmux -L city_hy attach -t mayor]'; exec zsh -l; }")

-- Naive personal tmux on the DEFAULT socket -- your everyday `tmux a`, made
-- restart-safe: attach to the existing default session if one is live, else
-- start a fresh one.
local NAIVE   = sh("tmux attach || tmux new")

-- Hall switch shim: a long-lived `socat` pane piped into the hall TUI's unix
-- socket. Alt+N writes "<slot>\n" to its stdin -> sub-ms switch. Wrapped in a
-- wait+reconnect loop so on a fresh boot it sits quietly until lookout creates
-- the socket, connects, and auto-reconnects if it ever drops.
local SHIM = sh("while true; do while [ ! -S '" .. HALL_SOCK .. "' ]; do sleep 1; done; socat -u - UNIX-CONNECT:'" .. HALL_SOCK .. "'; sleep 1; done")
local hall_shim_pane_id = nil

-- Reuse an existing 'shim' tab if one is already alive. WezTerm re-evaluates
-- this config on file changes / GUI events, which resets hall_shim_pane_id to
-- nil even though the previously-spawned shim tab keeps running — without this
-- guard the next Alt+<slot> keypress spawns a duplicate shim tab.
local function find_existing_shim_pane(mux_window)
  for _, tab in ipairs(mux_window:tabs()) do
    if tab:get_title() == 'shim' then
      for _, p in ipairs(tab:panes()) do
        return p
      end
    end
  end
  return nil
end

local function spawn_hall_shim(mux_window)
  if not mux_window then return end
  local existing = find_existing_shim_pane(mux_window)
  if existing then
    hall_shim_pane_id = existing:pane_id()
    return
  end
  local shim_tab, shim_pane = mux_window:spawn_tab { args = SHIM, cwd = SOURCE }
  shim_tab:set_title('shim')
  hall_shim_pane_id = shim_pane:pane_id()
end

-- Startup: spawn window running mayor (right), split lookout on the left, then
-- a naive personal-tmux tab and the hall shim tab. Activate mayor's tab last so
-- the user lands on it. Every pane is wrapped (see sh) so a cold boot with
-- no city / no tmux server still opens to usable shells, not dead tabs.
wezterm.on('gui-startup', function(cmd)
  -- Spawn already-large so the split fraction applies to ~final dimensions
  -- (maximize is async; splitting against an 80-col default window gives
  -- the lookout pane a tiny absolute size that wezterm later redistributes).
  local tab, mayor_pane, window = mux.spawn_window {
    args = MAYOR,
    cwd = SOURCE,
    width = 200,
    height = 80,
  }
  tab:set_title('city')
  local lookout_pane = mayor_pane:split {
    direction = 'Left',
    size = 0.15,
    args = LOOKOUT,
    cwd = SOURCE,
  }
  local naive_tab = window:spawn_tab { args = NAIVE, cwd = SOURCE }
  naive_tab:set_title('tmux')
  spawn_hall_shim(window)
  tab:activate()
  window:gui_window():maximize()
end)

-- Ctrl+Shift+H toggles focus between the hall (leftmost) pane and the pane to
-- its right (the viewer): if a pane sits to our left we go left, otherwise we
-- go right. In the 2-pane city tab that flips hall <-> viewer; in a single-pane
-- tab it's a harmless no-op.
local toggle_hall_focus = wezterm.action_callback(function(win, pane)
  local tab = win:active_tab()
  if not tab then return end
  local active_left = 0
  for _, p in ipairs(tab:panes_with_info()) do
    if p.is_active then active_left = p.left end
  end
  if active_left > 0 then
    win:perform_action(act.ActivatePaneDirection 'Left', pane)
  else
    win:perform_action(act.ActivatePaneDirection 'Right', pane)
  end
end)

-- Pane focus + zoom keys. Ctrl+Shift+H toggles hall <-> viewer focus (above).
-- Ctrl+Shift+L and Ctrl+Shift+M are added below (after hall_switch is
-- defined) as dedicated viewer switches: M -> mayor, L -> toggle the viewer
-- in/out of the lookout dashboard. (We intentionally drop the old
-- Ctrl+Shift+L focus-right; the switch actions auto-focus the viewer.)
-- These all live in the Ctrl+Shift namespace so they never shadow the
-- Ctrl+<letter> terminal control codes (Ctrl+L=clear, Ctrl+M=Enter) or the
-- tmux Alt+h/Alt+l agent-cycle bindings.
local keys = {
  { key = 'H', mods = 'CTRL|SHIFT', action = toggle_hall_focus },
  { key = 'Z', mods = 'CTRL|SHIFT', action = act.TogglePaneZoomState },
}

-- Alt+1..9 / Alt+<letter> -> switch the right tmux pane's client to the crew
-- in that hall slot. Fast path: write "<slot>\n" to the shim pane's stdin.
-- Fallback: fork-exec lookout's hall-switch subcommand and respawn the shim so
-- the next press is fast again.
local hall_lookout = '/home/sirwassail/source/city_hy/lookout/lookout'
local city_root    = '/home/sirwassail/source/city_hy'

local function hall_switch(slot)
  return wezterm.action_callback(function(win, _pane)
    if hall_shim_pane_id then
      local shim = mux.get_pane(hall_shim_pane_id)
      if shim then
        shim:send_text(slot .. '\n')
        return
      end
    end
    wezterm.background_child_process({
      hall_lookout, 'hall-switch', slot, '--city', city_root,
    })
    if win then
      local mux_win = win:mux_window()
      if mux_win then spawn_hall_shim(mux_win) end
    end
  end)
end

for i = 1, 9 do
  table.insert(keys, { key = tostring(i), mods = 'ALT', action = hall_switch(tostring(i)) })
end
-- Letter slots a-z, skipping h/j/k/l (tmux pane nav) and q/r (hall TUI nav).
-- 'm' is also reserved now — it's the dedicated Ctrl+Shift+M -> mayor switch.
for _, c in ipairs({ 'a','b','c','d','e','f','g','i','n','o','p','s','t','u','v','w','x','y','z' }) do
  table.insert(keys, { key = c, mods = 'ALT', action = hall_switch(c) })
end

-- Dedicated viewer switches (not crew slots). They reuse the hall_switch
-- shim/fallback path with named tokens the lookout binary special-cases:
--   Ctrl+Shift+M -> 'mayor'          : viewer jumps to the mayor session
--   Ctrl+Shift+L -> 'toggle-lookout' : viewer flips in/out of the lookout
--                                      dashboard, remembering where it was
-- Both auto-focus the viewer pane on success (focusCrewPane, hall side).
table.insert(keys, { key = 'M', mods = 'CTRL|SHIFT', action = hall_switch('mayor') })
table.insert(keys, { key = 'L', mods = 'CTRL|SHIFT', action = hall_switch('toggle-lookout') })

config.keys = keys

return config
