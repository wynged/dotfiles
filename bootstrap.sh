#!/usr/bin/env bash
# bootstrap.sh — provision a fresh native Ubuntu (24.04 LTS) box to match this
# dev environment, then stow the dotfiles. Re-runnable / idempotent: every step
# checks whether the tool is already present before installing.
#
# Install-source priority (best → worst for staying in sync with the OS):
#   1. vendor apt repo   2. official install script   3. version manager
#   4. apt               5. flatpak   6. snap   7. AppImage   8. manual .deb
#
# Gas City / Gas Town tooling (gascity, gastown, gc, gt, lookout, city_hy, beads,
# dolt, bv) is intentionally NOT installed here — see the DEFERRED block at the
# bottom; that belongs in a separate gas-city bootstrap.
#
# Usage:  ./bootstrap.sh           # full run
#         ./bootstrap.sh --no-stow # skip the final `./install.sh` stow step
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCH="$(dpkg --print-architecture)"      # amd64 / arm64
NVM_VERSION="v0.40.1"                     # bump to the latest nvm release tag
DO_STOW=1; [ "${1:-}" = "--no-stow" ] && DO_STOW=0

c()    { printf '\033[1;36m\n==> %s\033[0m\n' "$*"; }   # section header
note() { printf '\033[1;33m    %s\033[0m\n' "$*"; }     # advisory
have() { command -v "$1" >/dev/null 2>&1; }

# Keep sudo alive for the whole run so install scripts don't stall on a prompt.
c "Requesting sudo up front"
sudo -v
while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done 2>/dev/null &

# ─────────────────────────────────────────────────────────────────────────────
c "1. apt base — system foundation"
sudo apt-get update -y
sudo apt-get install -y \
  build-essential procps file ca-certificates curl wget gnupg lsb-release \
  apt-transport-https software-properties-common pkg-config \
  git zsh tmux vim stow \
  xclip wl-clipboard socat \
  jq unzip zip ncdu ripgrep fontconfig \
  python3 python3-pip python3-venv pipx
pipx ensurepath >/dev/null 2>&1 || true

# ─────────────────────────────────────────────────────────────────────────────
c "2. Vendor apt repos (priority 1 — stay in sync with apt upgrade)"
sudo install -m 0755 -d /etc/apt/keyrings

# GitHub CLI
if ! have gh; then
  wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
  sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
fi

# WezTerm (the terminal — its city-orchestration config is stowed in wezterm/)
if ! have wezterm; then
  curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /etc/apt/keyrings/wezterm-fury.gpg
  sudo chmod 644 /etc/apt/keyrings/wezterm-fury.gpg
  echo "deb [signed-by=/etc/apt/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *" \
    | sudo tee /etc/apt/sources.list.d/wezterm.list >/dev/null
fi

# VS Code (Microsoft)
if ! have code; then
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor \
    | sudo tee /etc/apt/keyrings/packages.microsoft.gpg >/dev/null
  sudo chmod go+r /etc/apt/keyrings/packages.microsoft.gpg
  echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
    | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
fi

# Docker Engine (official) — replaces Docker Desktop from the Windows box
if ! have docker; then
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
fi

sudo apt-get update -y
have gh      || sudo apt-get install -y gh
have wezterm || sudo apt-get install -y wezterm
have code    || sudo apt-get install -y code
if ! have docker; then
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo usermod -aG docker "$USER"
  note "Added $USER to the 'docker' group — log out/in (or 'newgrp docker') for it to take effect."
fi

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

# Zed editor (native — replaces the Windows Zed.exe alias)
have zed || curl -fsSL https://zed.dev/install.sh | sh

# Cursor CLI agent (the `cursor`/`agent` shim in ~/.local/bin)
have cursor || curl -fsS https://cursor.com/install | bash

# Bun
if ! have bun && [ ! -x "$HOME/.bun/bin/bun" ]; then
  curl -fsSL https://bun.sh/install | bash
fi

# Rust (rustup)
if ! have cargo && [ ! -x "$HOME/.cargo/bin/cargo" ]; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi

# ─────────────────────────────────────────────────────────────────────────────
c "4. Version managers — Node via nvm (priority 3)"
export NVM_DIR="$HOME/.nvm"
if [ ! -s "$NVM_DIR/nvm.sh" ]; then
  curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh" | bash
fi
# shellcheck disable=SC1091
. "$NVM_DIR/nvm.sh"
nvm install --lts          # current LTS
nvm install node           # latest (this box defaulted to latest)
nvm alias default node

# ─────────────────────────────────────────────────────────────────────────────
c "5. Brew formulae the dotfiles/dev env rely on"
# dotnet@8 + openjdk@21 are REQUIRED — the stowed .zshrc PATHs point at these.
brew list dotnet@8   >/dev/null 2>&1 || brew install dotnet@8
brew list openjdk@21 >/dev/null 2>&1 || brew install openjdk@21
# General tools you also had (not gas-city). Comment any you don't want:
brew list go     >/dev/null 2>&1 || brew install go
brew list deno   >/dev/null 2>&1 || brew install deno
brew list yt-dlp >/dev/null 2>&1 || brew install yt-dlp

# ─────────────────────────────────────────────────────────────────────────────
c "6. AWS tooling"
# AWS CLI v2 — official bundled installer (AWS has no apt repo)
if ! have aws; then
  tmp="$(mktemp -d)"
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o "$tmp/awscliv2.zip"
  unzip -q "$tmp/awscliv2.zip" -d "$tmp"
  sudo "$tmp/aws/install" --update
  rm -rf "$tmp"
fi
# AWS SAM CLI — via pipx (clean, user-level, self-updating)
have sam || pipx install aws-sam-cli

# ─────────────────────────────────────────────────────────────────────────────
c "7. Shell + dotfiles"
# Make zsh the login shell
if [ "${SHELL:-}" != "$(command -v zsh)" ]; then
  note "Setting zsh as your login shell (may prompt for your password)…"
  chsh -s "$(command -v zsh)" "$USER" || note "chsh failed — run it manually: chsh -s $(command -v zsh)"
fi
# Stow the dotfiles (zsh, tmux, git, wezterm, claude)
if [ "$DO_STOW" -eq 1 ] && [ -x "$DOTFILES_DIR/install.sh" ]; then
  note "Stowing dotfiles…"
  "$DOTFILES_DIR/install.sh" || note "stow reported conflicts — resolve (remove/back up the clashing real file or use 'stow --adopt <pkg>') then re-run ./install.sh"
fi

c "Bootstrap complete"
note "Next: open a NEW terminal (or 'exec zsh'), then:"
note "  • restore Claude memories — see CLAUDE.md (git checkout transfer …)"
note "  • run the verification checklist in MIGRATION.md"
note "  • docker group: log out/in before 'docker' works without sudo"
note "  • install the Gas City stack with its own bootstrap (see below)"

# ─────────────────────────────────────────────────────────────────────────────
# DEFERRED — Gas City / Gas Town stack (belongs in a separate bootstrap):
#   brew: gascity gastown beads bv dolt      (gc, gt, lookout live under these)
#   The stowed wezterm.lua city orchestration needs `lookout` at
#   /home/sirwassail/source/city_hy/lookout/lookout and uses socat (installed
#   above) for the hall shim. None of that is provisioned here by design.
#
# OPTIONAL nice-to-haves you don't currently run (uncomment to add):
#   sudo apt-get install -y neovim fzf fd-find bat        # note: apt neovim lags
#   brew install eza zoxide starship                      # modern CLI extras
#   sudo snap install yazi --classic                      # TUI file manager (you had this)
