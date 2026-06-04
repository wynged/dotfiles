# Migration: WSL → native Ubuntu

The intent, the work done, and what to double-check on the new machine. Written
2026-06-03 while still on the source box (WSL), so everything below is built but
**not yet verified on native Ubuntu** — that's what the checklist is for.

## Intention

Moving from a WSL setup (the `Ubuntu-Dev` distro running under Windows) to a pure
native Ubuntu install. Goals:

1. Consolidate every meaningful config into one Stow-managed dotfiles repo
   (`~/source/dotfiles`) so a fresh machine is a `git clone` + `./install.sh`.
2. Strip everything WSL-specific (WSLg display plumbing, `wsl.exe` wrappers,
   `wslview`, Windows-PATH interop, the `Zed.exe` alias) and replace it with the
   native-Linux equivalent.
3. Make Claude config sync ongoing via git (not a one-off tarball), while keeping
   accumulated per-project memories machine-local.

## Where we came from (and what changed)

| Area | On WSL | Native Ubuntu (this repo) |
|---|---|---|
| Display/clipboard | `DISPLAY=:0`, `WAYLAND_DISPLAY`, `XDG_RUNTIME_DIR` exported in `.zshrc` (WSLg) | Removed — the desktop session provides these |
| PATH | "strip Windows `(x86)` parens" guard | Removed — no Windows PATH interop |
| Browser | `BROWSER=wslview` | Removed — `xdg-open` is the default |
| Editor alias | `zed → /mnt/c/.../Zed.exe` | Removed — native `zed` on PATH |
| Homebrew/dotnet/jdk | unconditional `brew shellenv` + opt paths | Guarded behind `[ -x .../brew ]` so a brew-less box doesn't error |
| WezTerm panes | every pane = `wsl.exe -d Ubuntu-Dev -- bash -lc '…'` | plain `bash -lc '…'` + `cwd` on each spawn |
| WezTerm hall-switch fallback | `wsl.exe -d Ubuntu-Dev -- lookout hall-switch …` | direct `lookout hall-switch …` |
| Claude memory | manual tarball | config in the `claude` stow package; memories machine-local |

The WezTerm city orchestration (mayor / lookout / hall-shim layout, the
`/run/user/1000/*.sock` paths, all `Alt+<slot>` and `Ctrl+Shift+*` bindings) is
otherwise unchanged — only the process-spawn wrapper differed between WSL and native.

## Setup sequence on the new machine

`bootstrap.sh` does steps 1–4 (provision the toolchain + stow the dotfiles). It's
idempotent and follows the best-install-source priority; Gas City tooling is left
to its own bootstrap.

```bash
# 1. Clone + provision everything, then stow
git clone https://github.com/wynged/dotfiles ~/source/dotfiles
cd ~/source/dotfiles
./bootstrap.sh
#   (a fresh Ubuntu has no ~/.zshrc, so stow lands clean. If a package collides
#    with a real file, remove/back it up or use `stow --adopt <pkg>`, then re-run.)

# 2. Restore Claude memories from the transfer branch (exclude CLAUDE.md — stow owns it)
git checkout transfer
tar xzf claude-memory-transfer.tar.gz --exclude='.claude/CLAUDE.md' -C ~
git checkout main

# 3. Re-auth the things that DON'T travel in dotfiles (see "Not carried over")
gh auth login        # etc.

# 4. Open a new terminal (zsh is now the login shell); log out/in once for docker group.
```

What `bootstrap.sh` installs (best-source-first; **no snap, no Flatpak**): apt
base + CLI utils; vendor repos/PPAs for **gh, wezterm, docker, git-core, chrome,
tailscale, handbrake, makemkv**; install scripts for **Homebrew, oh-my-zsh,
oh-my-posh, zed, bun, rustup, dolt, pyenv**; **nvm**+Node and **pyenv**+Python
(3.13); brew **dotnet@8 / openjdk@21** (required by `.zshrc`) + go/deno/yt-dlp/
glow + modern CLI (fzf/fd/bat/eza/zoxide/yazi/neovim, wired into `.zshrc`);
version-pinned **aws cli v2 / sam**; and desktop apps via apt/PPA/vendor-`.deb`
(Chrome, Steam, VLC, Flameshot, guvcview, Dropbox, Discord, Parsec, Obsidian,
LocalSend — Slack as a Chrome PWA). `--skip-apps` skips the desktop tier.

Prompt: **oh-my-posh draws the prompt** (the `half-life` theme, stowed to
`~/.config/oh-my-posh/`), with oh-my-zsh kept for plugins/completions; falls back
to the oh-my-zsh `robbyrussell` theme if oh-my-posh isn't installed. Bootstrap
also installs a FiraCode Nerd Font for the glyphs — set it as your terminal font.

**Intentionally not installed** (per the migration plan): **VS Code, Cursor**
(editors are now Zed + Neovim), Firefox/Edge, Zoom, OBS (camera zoom → guvcview).

### Windows-only / deferred — plan around these (from the migration plan)

- **Autodesk / AEC stack** (Revit 2023–27, AutoCAD, pyRevit, RevitLookup, DIALux):
  no Linux version, no real equivalent → **dual-boot Windows or a Windows VM with
  GPU passthrough** (KVM/QEMU + VFIO). This is the biggest blocker.
- **League of Legends**: Riot Vanguard blocks Linux/Wine → unplayable. Battle.net/
  EA via Lutris/Bottles, per-title.
- **No native Linux app → use web/PWA**: Notion, MS Teams (client discontinued),
  Granola (Mac/Win only), Office 365. Re-add Chrome PWAs (Pomofocus, YouTube Music…).
- **Deferred (learn first)**: **rclone + Google Drive** (no official GDrive client;
  `apt install rclone` then `rclone config` — practice in WSL first); **Conky**
  (Rainmeter replacement; `apt install conky-all`, run from i3).
- **Hardware utils**: AMD GPU = Mesa (built in, nothing to install); sensors via
  `lm-sensors`+`psensor`, GPU/CPU tuning via **CoreCtrl**; Brother printer/scanner
  = Brother's Linux drivers; SafeNet/Vanta/Krisp publish native Linux agents.
- **i3** is assumed already set up (the WM); `sudo apt install i3` if not.

## Apps & tooling to install (distilled from the old Windows `install.ps1`)

The Windows box was provisioned via Chocolatey (`install.ps1` in `G:\My Drive\EW
Machine Setup`). Here's the Linux-relevant subset to reinstall — these are *apps*,
not dotfiles, so they're not in this repo, just listed so nothing is forgotten.

**Dev tooling:** `git` · `gh` · `neovim` · .NET SDK (`dotnet`) · `awscli` ·
`nvm` + Node 18 & 20 · VS Code · Cursor · Docker (+ post-install group setup) ·
AWS SAM (via Homebrew) · Python + `ipykernel` (for Jupyter) · oh-my-zsh.

**GUI apps:** Slack · Notion · Gather · YouTube Music · a screenshot tool
(ShareX on Windows → `flameshot`/`spectacle` on Linux) · Firefox/Chrome · Spotify.

**Hypar dev env vars** (were Windows env vars; not currently in the shell rc — set
them in `zsh/.zshrc` if you still do local Hypar work, pointing at the Linux paths):
```sh
export HYPAR_ELEMENTS="$HOME/source/Elements/Elements/src"
export HYPAR_FUNCTIONS="$HOME/source/Hypar/Hypar.Functions"
```

**Skipped (Windows-only):** PowerToys, Inno Setup, ShareX, Revit + RevitLookup
addin, AutoHotkey (`GranolaAutoStop.ahk`), Oh My Posh theme (`half-life.omp.json`
— superseded by oh-my-zsh here).

## Verification checklist — double-check these actually work

- [ ] **New shell is clean.** Open a fresh terminal: `.zshrc` loads with no errors,
      even before brew/nvm/etc. are installed (the brew block is guarded). The disk-usage
      warning fires only above 85%.
- [ ] **`oh-my-zsh` present.** `echo $ZSH` resolves and the prompt theme loads. If
      `~/.oh-my-zsh` is missing, the `source $ZSH/oh-my-zsh.sh` line errors — install it (step 2).
- [ ] **tmux clipboard.** Select text with the mouse → it lands in the system clipboard.
      `.tmux.conf` uses `xclip` (X11). **Ubuntu 24.04 defaults to Wayland (GNOME)**, where
      `xclip` only works via XWayland and is flaky. If copy doesn't reach the clipboard,
      install `wl-clipboard` and swap `xclip -selection clipboard -i` → `wl-copy` in
      `tmux/.tmux.conf` (2 lines). Verify before assuming it works.
- [ ] **WezTerm launches the city layout.** On a fresh boot with the city *down*, every
      pane should fall back to a usable shell (not a dead/closed tab). Requires `socat`
      and the `lookout` binary present.
- [ ] **`lookout` binary exists at the hardcoded path.** `.wezterm.lua` and the Claude
      hooks call `/home/sirwassail/source/city_hy/lookout/lookout`. Confirm `city_hy` is
      cloned/built there, or update the path in both files.
- [ ] **Hall switching works.** With a city up, `Alt+1..9` / `Alt+<letter>` switch the
      viewer; `Ctrl+Shift+M` → mayor, `Ctrl+Shift+L` → toggle lookout. The shim tab named
      `shim` should appear once.
- [ ] **Claude status line renders.** Open Claude Code in a git repo — dir, branch, model,
      ctx%, and the 5h/7d rate-limit bars show. The bars need
      `~/.claude/.usage-tracking/usage.json`, populated by `usage-probe.sh`. **Verify how
      that probe is scheduled** (cron? a launch hook?) — it isn't set up by `stow` alone, so
      the bars may be blank until you wire the probe to run periodically.
- [ ] **Claude hooks fire.** `settings.json` runs lookout `signal-active`/`signal-waiting`
      on prompt/stop. With no city, these just no-op; confirm they don't error loudly.
- [ ] **Memories attached.** In a restored project dir, Claude recalls prior memories.
      Folder names encode `-home-sirwassail-source-…` — only valid if username (`sirwassail`)
      and `~/source/...` layout match. If not, rename the encoded folders.
- [ ] **Global CLAUDE.md is the symlink, not the tarball copy.** `ls -l ~/.claude/CLAUDE.md`
      should point into `~/source/dotfiles/claude/...`. If it's a real file, the tarball
      restore included it — delete it and re-run `./install.sh`.

## Not carried over (re-do manually — never in dotfiles)

- **Secrets / keys:** `~/.ssh/`, `~/.aws/`, `~/.gnupg/` — copy securely, out of band.
- **Auth tokens:** `gh` (`~/.config/gh/hosts.yml`), `~/.claude/.credentials.json`,
  cloud CLIs — re-login on the new box.
- **Installed (not config) state:** `~/.claude/plugins/`, nvm-installed node versions,
  brew packages, cargo crates — reinstall.
- **Windows-only leftovers (intentionally dropped):** the Drive `clipboard-server.ps1`
  (native Linux has `xclip`/`wl-clipboard`), `AGENTS.md`, the Cursor beadwork system.

## Open items to revisit

- `usage-probe.sh` scheduling mechanism (see checklist) — confirm and document it here.
- Decide Wayland vs X11 for the session, then lock in the tmux clipboard tool to match.
- Wallpapers live in `wallpapers/` (storage only) — set them via GNOME settings manually.
