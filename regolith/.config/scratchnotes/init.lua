-- Dedicated nvim config for the i3 ScratchPad notes popup ($mod+Ctrl+n).
-- Launched via: nvim -u ~/.config/scratchnotes/init.lua ~/source/VaultWassail/ScratchPad
--
-- A GUI-style notes editor: a docked left-hand sidebar lists the vault's
-- ScratchPad/ notes (newest first); click one (single click) or press <CR> to
-- open it in the main pane on the right. Markdown buffers autosave, so toggling
-- the popup away never loses work. These edit the same .md files Obsidian reads.
--
--   sidebar:  click / <CR> open · n new note · D delete · r refresh · q close popup
--   note:     q  save + back to the sidebar  ·  edits autosave
--
-- A hand-rolled sidebar (not netrw) so the layout is stable: opening and
-- deleting notes never reshuffles the windows. Dependency-free, instant.

local scratch_dir = vim.fn.expand("~/source/VaultWassail/ScratchPad")

-- Sensible, fast, dependency-free -------------------------------------------
vim.g.mapleader = " "
vim.opt.mouse = "a"            -- click in the sidebar to switch between notes
vim.opt.number = false
vim.opt.swapfile = false
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.conceallevel = 0      -- show raw markdown while editing
vim.opt.equalalways = false   -- don't rebalance the sidebar when panes split
vim.opt.laststatus = 2

local SIDEBAR_WIDTH = 28
local PLACEHOLDER = "  (no notes yet — press n)"

local sidebar_win, sidebar_buf, editor_win

-- The notes, newest first, as display names (".md" stripped) ----------------
local function list_notes()
  local files = vim.fn.glob(scratch_dir .. "/*.md", false, true)
  table.sort(files, function(a, b) return vim.fn.getftime(a) > vim.fn.getftime(b) end)
  local names = {}
  for _, f in ipairs(files) do
    names[#names + 1] = vim.fn.fnamemodify(f, ":t:r")
  end
  return names
end

-- Resolve the note on the cursor's line to a full path (nil if none) --------
local function path_under_cursor()
  if vim.api.nvim_get_current_win() ~= sidebar_win then return nil end
  local name = vim.trim(vim.api.nvim_get_current_line())
  if name == "" or name:sub(1, 1) == "(" then return nil end
  local path = scratch_dir .. "/" .. name .. ".md"
  if vim.fn.filereadable(path) == 0 then return nil end
  return path
end

local function render_sidebar()
  if not (sidebar_buf and vim.api.nvim_buf_is_valid(sidebar_buf)) then return end
  local names = list_notes()
  if #names == 0 then names = { PLACEHOLDER } end
  vim.bo[sidebar_buf].modifiable = true
  vim.api.nvim_buf_set_lines(sidebar_buf, 0, -1, false, names)
  vim.bo[sidebar_buf].modifiable = false
end

-- Make sure there is an editor pane to the right of the sidebar -------------
local function ensure_editor()
  if editor_win and vim.api.nvim_win_is_valid(editor_win) then return end
  vim.api.nvim_set_current_win(sidebar_win)
  vim.cmd("rightbelow vsplit")        -- new pane to the right of the sidebar
  editor_win = vim.api.nvim_get_current_win()
end

local function open_note(path)
  ensure_editor()
  vim.api.nvim_set_current_win(editor_win)
  vim.cmd("edit " .. vim.fn.fnameescape(path))
end

local function open_under_cursor()
  local path = path_under_cursor()
  if path then open_note(path) end
end

-- Create a new note: prompt for a title, slug it, seed an H1, open it -------
local function new_note()
  local title = vim.fn.input("New note: ")
  if title == nil or title == "" then return end
  local slug = title:gsub("%s+", "-"):gsub("[^%w%-_]", ""):lower()
  if slug == "" then slug = "note" end
  local path = scratch_dir .. "/" .. slug .. ".md"
  local is_new = vim.fn.filereadable(path) == 0
  open_note(path)
  if is_new then
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "# " .. title, "" })
    vim.cmd("normal! G")
    vim.cmd("startinsert")
  end
  render_sidebar()
end

local function delete_under_cursor()
  local path = path_under_cursor()
  if not path then return end
  local name = vim.fn.fnamemodify(path, ":t")
  if vim.fn.confirm("Delete " .. name .. "?", "&Yes\n&No", 2) ~= 1 then return end
  -- If the doomed note is open in the editor, clear that pane first.
  if editor_win and vim.api.nvim_win_is_valid(editor_win) then
    local eb = vim.api.nvim_win_get_buf(editor_win)
    if vim.api.nvim_buf_get_name(eb) == vim.fn.fnamemodify(path, ":p") then
      vim.bo[eb].modified = false
      vim.api.nvim_set_current_win(editor_win)
      vim.cmd("enew")
    end
  end
  vim.fn.delete(path)
  vim.api.nvim_set_current_win(sidebar_win)
  render_sidebar()
end

-- Build the docked sidebar + editor layout, discarding nvim's folder view ----
local function setup_layout()
  vim.cmd("enew")
  vim.cmd("silent! only")
  vim.cmd("topleft vsplit")           -- new window on the far left = sidebar
  sidebar_win = vim.api.nvim_get_current_win()
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if w ~= sidebar_win then editor_win = w end
  end

  sidebar_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(sidebar_buf, "scratchpad://notes")
  vim.bo[sidebar_buf].buftype = "nofile"
  vim.bo[sidebar_buf].swapfile = false
  vim.bo[sidebar_buf].filetype = "scratchnotes"
  vim.api.nvim_win_set_buf(sidebar_win, sidebar_buf)
  vim.api.nvim_win_set_width(sidebar_win, SIDEBAR_WIDTH)

  vim.wo[sidebar_win].winfixwidth = true
  vim.wo[sidebar_win].number = false
  vim.wo[sidebar_win].relativenumber = false
  vim.wo[sidebar_win].signcolumn = "no"
  vim.wo[sidebar_win].cursorline = true
  vim.wo[sidebar_win].wrap = false

  -- Sidebar keymaps (buffer-local) ------------------------------------------
  local map = function(lhs, rhs)
    vim.keymap.set("n", lhs, rhs, { buffer = sidebar_buf, silent = true })
  end
  map("<CR>", open_under_cursor)
  map("<LeftRelease>", open_under_cursor)  -- single click opens the note
  map("<2-LeftMouse>", open_under_cursor)  -- ...and so does a double click
  map("n", new_note)
  map("D", delete_under_cursor)
  map("r", render_sidebar)
  map("R", render_sidebar)
  map("q", "<cmd>qa<cr>")                  -- close the popup

  render_sidebar()
  vim.api.nvim_set_current_win(sidebar_win)
end

vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    vim.schedule(function() pcall(setup_layout) end)
  end,
})

-- Autosave markdown so toggling the popup away never loses edits ------------
vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave", "BufLeave", "FocusLost" }, {
  pattern = "*.md",
  callback = function()
    if vim.bo.modified and vim.bo.buftype == "" and vim.fn.expand("%") ~= "" then
      vim.cmd("silent! write")
    end
  end,
})

-- Keep the sidebar's newest-first order fresh after each save ---------------
vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = "*.md",
  callback = function() pcall(render_sidebar) end,
})

-- In a note: q saves and jumps back to the sidebar to pick another note -----
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.keymap.set("n", "q", function()
      vim.cmd("silent! write")
      if sidebar_win and vim.api.nvim_win_is_valid(sidebar_win) then
        vim.api.nvim_set_current_win(sidebar_win)
      end
    end, { buffer = true, silent = true })
  end,
})
