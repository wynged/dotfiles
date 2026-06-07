#!/usr/bin/env bash
# bootstrap.sh — provision a fresh native Ubuntu box (24.04 LTS or 25.10) to match
# this environment, then stow the dotfiles. Re-runnable / idempotent: every step
# checks whether the thing is already present before installing.
#
# Install-source priority (best → worst for staying in sync with the OS):
#   1. vendor apt repo / PPA   2. official install script   3. version manager
#   4. apt   5. vendor .deb (flag: won't auto-update unless the app self-updates)
# No snap, no Flatpak (by request) — desktop apps use apt-repo/PPA/vendor .deb.
#
# Gas City / Gas Town tooling (gascity, gastown, gc, gt, lookout, city_hy, beads,
# bv) is intentionally NOT installed here — that belongs in a separate bootstrap.
#
# Usage:  ./bootstrap.sh              # full run (CLI/dev + desktop apps + stow)
#         ./bootstrap.sh --skip-apps  # skip the desktop GUI apps (dev/headless box)
#         ./bootstrap.sh --no-stow    # skip the final stow step
#   (flags combine: ./bootstrap.sh --skip-apps --no-stow)
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCH="$(dpkg --print-architecture)"        # amd64 / arm64
CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"
NVM_VERSION="v0.40.1"                        # bump to the latest nvm release tag
AWSCLI_VERSION="2.27.48"                     # pinned to exactly match the source box
SAM_VERSION="1.142.1"                        # pinned to exactly match the source box
PYENV_PYTHON="3.13"                          # python version pyenv installs + globals
REGOLITH_RELEASE="v3.4"                      # bump when Regolith cuts a new release

DO_STOW=1; DO_APPS=1
for a in "$@"; do
  case "$a" in
    --no-stow)   DO_STOW=0 ;;
    --skip-apps) DO_APPS=0 ;;
    *) echo "unknown flag: $a" >&2; exit 2 ;;
  esac
done

c()    { printf '\033[1;36m\n==> %s\033[0m\n' "$*"; }   # section header
note() { printf '\033[1;33m    %s\033[0m\n' "$*"; }     # advisory
have() { command -v "$1" >/dev/null 2>&1; }

# Install a vendor .deb from a URL (apt resolves its deps). $1=label $2=url
install_deb() {
  local label="$1" url="$2" tmp; tmp="$(mktemp --suffix=.deb)"
  if curl -fsSL "$url" -o "$tmp"; then
    sudo apt-get install -y "$tmp" || note "$label: apt install failed — try manually"
  else
    note "$label: download failed ($url) — install manually"
  fi
  rm -f "$tmp"
}
# Resolve a GitHub 'latest' release .deb asset URL. $1=owner/repo $2=asset regex
gh_latest_deb() {
  curl -fsSL "https://api.github.com/repos/$1/releases/latest" \
    | jq -r '.assets[].browser_download_url' | grep -E "$2" | head -1
}

c "Requesting sudo up front"
sudo -v
while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done 2>/dev/null &

# ─────────────────────────────────────────────────────────────────────────────
c "1. apt base — system foundation + CLI utilities"
sudo apt-get update -y
sudo apt-get install -y \
  build-essential procps file ca-certificates curl wget gnupg lsb-release \
  apt-transport-https software-properties-common pkg-config \
  zsh tmux stow \
  xclip wl-clipboard socat \
  jq unzip zip ncdu ripgrep fontconfig \
  7zip ffmpeg imagemagick poppler-utils qpdf \
  python3 python3-pip python3-venv pipx
pipx ensurepath >/dev/null 2>&1 || true
# Build deps so pyenv can compile CPython
sudo apt-get install -y \
  make libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
  libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev

# ─────────────────────────────────────────────────────────────────────────────
c "2. Vendor apt repos & PPAs (priority 1 — stay in sync with apt upgrade)"
sudo install -m 0755 -d /etc/apt/keyrings

# git — git-core PPA (stock apt git lags)
have git || true
sudo add-apt-repository -y ppa:git-core/ppa || note "git-core PPA add failed (interim release?)"

# GitHub CLI
if ! have gh; then
  wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
  sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
fi

# WezTerm (terminal — its city-orchestration config is stowed in wezterm/)
if ! have wezterm; then
  curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /etc/apt/keyrings/wezterm-fury.gpg
  sudo chmod 644 /etc/apt/keyrings/wezterm-fury.gpg
  echo "deb [signed-by=/etc/apt/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *" \
    | sudo tee /etc/apt/sources.list.d/wezterm.list >/dev/null
fi

# Docker Engine (official) — replaces Docker Desktop
if ! have docker; then
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $CODENAME stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
fi

# Regolith Desktop (i3/X11 session — the WM; replaces bare i3)
if ! dpkg -l regolith-desktop 2>/dev/null | grep -q '^ii'; then
  wget -qO - https://archive.regolith-desktop.com/regolith.key \
    | gpg --dearmor | sudo tee /usr/share/keyrings/regolith-archive-keyring.gpg >/dev/null
  echo "deb [arch=$ARCH signed-by=/usr/share/keyrings/regolith-archive-keyring.gpg] https://archive.regolith-desktop.com/ubuntu/stable ${CODENAME} ${REGOLITH_RELEASE}" \
    | sudo tee /etc/apt/sources.list.d/regolith.list >/dev/null
fi

sudo apt-get update -y
sudo apt-get install --only-upgrade -y git || sudo apt-get install -y git
have gh      || sudo apt-get install -y gh
have wezterm || sudo apt-get install -y wezterm
if ! have docker; then
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo usermod -aG docker "$USER"
  note "Added $USER to 'docker' group — log out/in (or 'newgrp docker') to use docker without sudo."
fi
dpkg -l regolith-desktop 2>/dev/null | grep -q '^ii' \
  || sudo apt-get install -y regolith-desktop regolith-session-flashback regolith-look-lascaille xdg-desktop-portal-regolith

# ─────────────────────────────────────────────────────────────────────────────
c "3. Official install scripts (priority 2 — self-updating)"

# Homebrew (linuxbrew) — the stowed .zshrc expects dotnet@8 / openjdk@21 here
if ! have brew && [ ! -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# oh-my-zsh — KEEP_ZSHRC so it never clobbers our stowed ~/.zshrc
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Oh My Posh — draws the prompt (half-life theme is stowed to ~/.config/oh-my-posh).
# oh-my-zsh stays for plugins/completions; .zshrc sets ZSH_THEME="" and inits omp.
have oh-my-posh || curl -s https://ohmyposh.dev/install.sh | bash -s
# Nerd Font so the half-life glyphs render (also set this font in your terminal)
if ! fc-list 2>/dev/null | grep -qi "FiraCode Nerd"; then
  mkdir -p "$HOME/.local/share/fonts"
  if curl -fsSL -o /tmp/FiraCode.zip https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip; then
    unzip -oq /tmp/FiraCode.zip -d "$HOME/.local/share/fonts" && fc-cache -f >/dev/null && rm -f /tmp/FiraCode.zip
  fi
fi

# Zed editor (native)
have zed || curl -fsSL https://zed.dev/install.sh | sh

# Bun
if ! have bun && [ ! -x "$HOME/.bun/bin/bun" ]; then
  curl -fsSL https://bun.sh/install | bash
fi

# Rust (rustup)
if ! have cargo && [ ! -x "$HOME/.cargo/bin/cargo" ]; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi

# Dolt (official self-updating installer)
have dolt || curl -L https://github.com/dolthub/dolt/releases/latest/download/install.sh | sudo bash

# pyenv (Python version manager). .zshrc wires up `pyenv init`.
if ! have pyenv && [ ! -d "$HOME/.pyenv" ]; then
  curl -fsSL https://pyenv.run | bash
fi

# Tailscale (official script — adds its apt repo, then syncs via apt upgrade)
have tailscale || curl -fsSL https://tailscale.com/install.sh | sh

# ─────────────────────────────────────────────────────────────────────────────
c "4. Version managers — Node (nvm) + Python (pyenv)"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] || curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh" | bash
# shellcheck disable=SC1091
. "$NVM_DIR/nvm.sh"
nvm install --lts
nvm install node
nvm alias default node

export PYENV_ROOT="$HOME/.pyenv"; export PATH="$PYENV_ROOT/bin:$PATH"
if have pyenv; then
  eval "$(pyenv init - 2>/dev/null)" || true
  pyenv install -s "$PYENV_PYTHON"
  pyenv global "$PYENV_PYTHON"
fi

# ─────────────────────────────────────────────────────────────────────────────
c "5. Brew formulae — dev runtimes + modern CLI tools"
# dotnet@8 + openjdk@21 are REQUIRED — the stowed .zshrc PATHs point at these.
brew list dotnet@8   >/dev/null 2>&1 || brew install dotnet@8
brew list openjdk@21 >/dev/null 2>&1 || brew install openjdk@21
# General tools you also had (not gas-city):
for f in go deno yt-dlp glow; do
  brew list "$f" >/dev/null 2>&1 || brew install "$f"
done
# Modern CLI tools — brew gives latest + real binary names (fd/bat, not fdfind/
# batcat) with no snap. Shell wiring (fzf/zoxide/eza/yazi) lives in zsh/.zshrc.
for f in fzf fd bat eza zoxide yazi neovim; do
  brew list "$f" >/dev/null 2>&1 || brew install "$f"
done

# ─────────────────────────────────────────────────────────────────────────────
c "6. AWS tooling (pinned to the exact versions on the source box)"
# AWS CLI v2 — official VERSIONED installer so it matches $AWSCLI_VERSION exactly.
if ! have aws || [ "$(aws --version 2>&1 | grep -oP 'aws-cli/\K[0-9.]+')" != "$AWSCLI_VERSION" ]; then
  tmp="$(mktemp -d)"
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m)-${AWSCLI_VERSION}.zip" -o "$tmp/awscliv2.zip"
  unzip -q "$tmp/awscliv2.zip" -d "$tmp"
  sudo "$tmp/aws/install" --update
  rm -rf "$tmp"
fi
# AWS SAM CLI — pinned via pipx so it matches $SAM_VERSION exactly.
if ! have sam || [ "$(sam --version 2>&1 | grep -oP 'version \K[0-9.]+')" != "$SAM_VERSION" ]; then
  pipx install --force "aws-sam-cli==${SAM_VERSION}"
fi

# ─────────────────────────────────────────────────────────────────────────────
if [ "$DO_APPS" -eq 1 ]; then
c "7. Desktop apps (apt-repo / PPA / vendor .deb — no snap, no Flatpak)"

# Google Chrome — vendor apt repo (auto-updates via apt)
if ! have google-chrome; then
  wget -qO- https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /etc/apt/keyrings/google-chrome.gpg
  sudo chmod go+r /etc/apt/keyrings/google-chrome.gpg
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" \
    | sudo tee /etc/apt/sources.list.d/google-chrome.list >/dev/null
  sudo apt-get update -y && sudo apt-get install -y google-chrome-stable
fi

# Steam needs 32-bit + multiverse
sudo dpkg --add-architecture i386
sudo add-apt-repository -y multiverse || true
sudo apt-get update -y
# apt desktop apps (auto-update via apt)
sudo apt-get install -y vlc flameshot guvcview steam-installer || note "one of vlc/flameshot/guvcview/steam failed"

# HandBrake (official PPA) + MakeMKV (community PPA) — may lag on interim releases
sudo add-apt-repository -y ppa:stebbins/handbrake-releases || note "HandBrake PPA unavailable for $CODENAME"
sudo add-apt-repository -y ppa:heyarje/makemkv-beta       || note "MakeMKV PPA unavailable for $CODENAME"
sudo apt-get update -y
sudo apt-get install -y handbrake-gtk handbrake-cli || note "HandBrake install skipped"
sudo apt-get install -y makemkv-bin makemkv-oss     || note "MakeMKV install skipped"

# Dropbox — official headless daemon (self-updates itself in place)
if [ ! -d "$HOME/.dropbox-dist" ]; then
  ( cd "$HOME" && curl -fsSL "https://www.dropbox.com/download?plat=lnx.$(uname -m)" | tar xzf - ) \
    && note "Dropbox: run '~/.dropbox-dist/dropboxd' once to link the account (then autostart it)." \
    || note "Dropbox: download failed — get it from dropbox.com/install-linux"
fi

# Vendor .debs with their OWN updaters (so a one-time install stays current):
have discord || install_deb "Discord" "https://discord.com/api/download?platform=linux&format=deb"
have parsecd || install_deb "Parsec"  "https://builds.parsec.app/package/parsec-linux.deb"
have obsidian || install_deb "Obsidian" "$(gh_latest_deb obsidianmd/obsidian-releases 'amd64\.deb$')"
have localsend || install_deb "LocalSend" "$(gh_latest_deb localsend/localsend 'linux-x86-64\.deb$')"

# Slack — runs as a Chrome PWA (always current, no packaging). Can't be scripted;
# do it once from the browser:
note "Slack: open https://app.slack.com in Chrome, sign in, then install it as an"
note "       app — address-bar install icon, or Chrome menu ▸ Cast, save & share ▸ Install."

note "guvcview camera zoom: verify your webcam exposes it →  v4l2-ctl -d /dev/video0 --list-ctrls  (look for zoom_absolute)"
fi  # DO_APPS

# ─────────────────────────────────────────────────────────────────────────────
c "8. Shell + dotfiles"
if [ "${SHELL:-}" != "$(command -v zsh)" ]; then
  note "Setting zsh as your login shell (may prompt for your password)…"
  chsh -s "$(command -v zsh)" "$USER" || note "chsh failed — run it manually: chsh -s $(command -v zsh)"
fi
if [ "$DO_STOW" -eq 1 ] && [ -x "$DOTFILES_DIR/install.sh" ]; then
  note "Stowing dotfiles…"
  "$DOTFILES_DIR/install.sh" || note "stow conflicts — back up/remove the clashing real file or use 'stow --adopt <pkg>', then re-run ./install.sh"
fi

c "Bootstrap complete"
note "Next: open a NEW terminal (or 'exec zsh'), then:"
note "  • restore Claude memories — see CLAUDE.md (git checkout transfer …)"
note "  • run the verification checklist in MIGRATION.md"
note "  • docker group: log out/in before 'docker' works without sudo"
note "  • Tailscale: 'sudo tailscale up' to authenticate"
note "  • Gas City stack: install with its own (separate) bootstrap"

# ─────────────────────────────────────────────────────────────────────────────
# DEFERRED (per the migration plan — not installed here):
#   • rclone + Google Drive — `sudo apt install rclone` then `rclone config`;
#     treat as a learning task (no official GDrive client on Linux).
#   • Conky (Rainmeter replacement) — `sudo apt install conky-all`; desktop overlay,
#     configured from your Regolith/i3 config.
#
# WINDOWS-ONLY / no Linux equivalent (plan around — see MIGRATION.md):
#   Autodesk/AEC stack (Revit, AutoCAD, pyRevit, RevitLookup, DIALux) → dual-boot
#   or a Windows VM with GPU passthrough.  League of Legends (Vanguard) → unplayable.
#   Granola / Notion / Teams / Office → web/PWA.
#
# DEFERRED — Gas City / Gas Town stack (separate bootstrap):
#   brew: gascity gastown beads bv   (gc, gt, lookout live under these; the stowed
#   wezterm.lua expects lookout at ~/source/city_hy/lookout/lookout, uses socat).
