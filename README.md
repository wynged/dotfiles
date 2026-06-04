# dotfiles

Personal dotfiles, managed with [GNU Stow](https://www.gnu.org/software/stow/).
Migrated from a WSL (Ubuntu-Dev) setup to a native Ubuntu install — WSL-specific
bits (WSLg display exports, `wsl.exe` wrappers, `wslview`, Windows-path interop)
have been stripped or rewritten for native Linux.

## Layout

Each top-level directory is a **stow package** whose contents mirror `$HOME`:

```
zsh/      .zshrc  .zshenv
tmux/     .tmux.conf  .tmux/scripts/statusline.sh
git/      .gitconfig  .config/git/ignore
wezterm/  .wezterm.lua
claude/   .claude/settings.json  .claude/statusline-command.sh
wallpapers/   (storage only — not stowed)
```

## Install

**Fresh machine** — `bootstrap.sh` provisions the whole toolchain following a
best-source-first priority (vendor apt repo / PPA → install script → version
manager → apt → vendor `.deb`; **no snap, no Flatpak**), then stows the dotfiles:

```bash
git clone https://github.com/wynged/dotfiles ~/source/dotfiles
cd ~/source/dotfiles
./bootstrap.sh             # CLI/dev + desktop apps + stow
./bootstrap.sh --skip-apps # dev/headless box: skip the desktop GUI apps
./bootstrap.sh --no-stow   # skip the final stow step
```

It installs: apt base + CLI utils (7zip, ffmpeg, imagemagick, poppler, qpdf…);
vendor repos/PPAs for **gh, wezterm, docker, git(-core), chrome, tailscale,
handbrake, makemkv**; install scripts for **Homebrew, oh-my-zsh, oh-my-posh, zed,
bun, rustup, dolt, pyenv**; **nvm**+Node and **pyenv**+Python; brew dotnet@8/
openjdk@21 + go/deno/yt-dlp/glow + modern CLI (fzf/fd/bat/eza/zoxide/yazi/neovim);
version-pinned **aws cli v2 + sam**; and desktop apps (Chrome, Steam, VLC,
Flameshot, guvcview, Dropbox, Discord, Parsec, Obsidian, LocalSend; Slack as a
Chrome PWA). VS Code/Cursor are intentionally **not** installed (editors are Zed +
Neovim). Idempotent — safe to re-run. Gas City tooling is excluded (separate
bootstrap). See `MIGRATION.md`.

**Just the dotfiles** (machine already provisioned):

```bash
sudo apt install stow
./install.sh               # stow every package, or: ./install.sh zsh tmux
```

Stow won't overwrite existing real files. If `~/.zshrc` already exists, remove or
back it up first, or use `stow --adopt <pkg>` to pull the existing file into the
repo (then review the diff before committing).

## Package notes

- **zsh** — oh-my-zsh + nvm + brew + bun + cargo + dotnet. Homebrew and its
  toolchain exports are guarded, so a fresh box without brew won't error on shell
  start. Assumes oh-my-zsh is installed (`sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"`).
- **tmux** — mouse + vi copy (uses `xclip`; install `xclip` or swap for
  `wl-clipboard` under Wayland). Status line reads git branch + Gas Town dev ports.
- **wezterm** — native rewrite of the city orchestration (mayor / lookout / hall
  shim) with every `wsl.exe` wrapper replaced by a plain `bash -lc`. The
  `/run/user/1000/*.sock` paths and all `Alt+<slot>` / `Ctrl+Shift+*` bindings are
  unchanged. Depends on `socat` and the `city_hy/lookout` binary existing.
- **claude** — Claude Code config, version-controlled and synced like any other
  dotfile (the `claude-memory-transfer.tar.gz` is only a one-time bootstrap, not
  the ongoing sync method):
  - `CLAUDE.md` — global agent instructions ("Code Reuse").
  - `settings.json` — Gas Town lookout hooks. The hook commands hardcode
    `/home/sirwassail/source/city_hy/lookout/lookout` — adjust if the city lives
    elsewhere.
  - `statusline-command.sh` + `usage-probe.sh` — the rate-limit-bar status line
    and the probe that feeds it (`~/.claude/.usage-tracking/usage.json`).

  Only these stable config files are stowed. Machine-local Claude state is
  **never** synced: `projects/` (per-project memories), `sessions/`,
  `session-env/`, `history.jsonl`, `file-history/`, `plugins/`, caches,
  `.credentials.json`, and `settings.local.json`.

## Dependencies to install on a fresh box

`zsh` · `oh-my-zsh` · `tmux` · `xclip` (or `wl-clipboard`) · `stow` · `socat`
(for the wezterm hall shim) · `wezterm` · `git` · `gh` · plus your runtimes
(nvm/node, brew, bun, cargo/rust, dotnet) as the zshrc expects them.

## Not managed here

Secrets and machine-local state are intentionally excluded (see `.gitignore`):
`~/.ssh`, `~/.aws`, `~/.gnupg`, `~/.config/gh/hosts.yml`, `~/.claude.json`,
`settings.local.json`.
