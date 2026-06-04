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

**Fresh machine** — `bootstrap.sh` provisions the whole toolchain (apt base,
vendor apt repos for gh/wezterm/vscode/docker, Homebrew, oh-my-zsh, nvm/node,
bun, rust, zed, cursor, aws cli + sam) following a best-source-first priority,
then stows the dotfiles:

```bash
git clone https://github.com/wynged/dotfiles ~/source/dotfiles
cd ~/source/dotfiles
./bootstrap.sh             # full provision + stow  (./bootstrap.sh --no-stow to skip stowing)
```

It's idempotent — safe to re-run; each step skips anything already installed. Gas
City tooling is intentionally excluded (separate bootstrap). See `MIGRATION.md`.

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
