# --- Native Ubuntu note ---
# Migrated from WSL. The old WSLg display exports (DISPLAY/WAYLAND_DISPLAY/
# XDG_RUNTIME_DIR), the "strip Windows PATH parens" guard, BROWSER=wslview, and
# the Zed.exe interop alias were all WSL-only and have been removed — on a native
# desktop session these are provided by systemd/pam and xdg-open.

# If you come from bash you might have to change your $PATH.
export PATH=$HOME/source/hypar_gt/scripts:$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Add wisely, as too many plugins slow down shell startup.
plugins=(git)

# Custom completions (gt, bd)
fpath=(~/.zsh/completions $fpath)

source $ZSH/oh-my-zsh.sh
unalias gc 2>/dev/null

# Oh My Posh draws the prompt (half-life theme). oh-my-zsh stays for plugins/
# completions/aliases; this overrides its theme's prompt. If oh-my-posh isn't
# installed, the ZSH_THEME prompt above remains as a fallback.
if command -v oh-my-posh >/dev/null; then
  eval "$(oh-my-posh init zsh --config "$HOME/.config/oh-my-posh/half-life.omp.json")"
fi

# User configuration

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Homebrew (linuxbrew) — guarded so a fresh machine without brew installed yet
# doesn't error on shell start.
if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"
fi

# Claude aliases
alias cc="claude"
alias ccd="claude --dangerously-skip-permissions"

# Gas Town tmux (avoids remembering -L hypar-gt)
alias gtx="tmux -L hypar-gt"

# Quick attach to mayor session
alias gca="gc session attach mayor"

# --- Gas Town Integration (managed by gt) ---
[[ -f "$HOME/.config/gastown/shell-hook.sh" ]] && source "$HOME/.config/gastown/shell-hook.sh"
# --- End Gas Town ---

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# brew-provided toolchains (guarded — only export if brew is present)
if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
  export PATH="/home/linuxbrew/.linuxbrew/opt/openjdk@21/bin:$PATH"
  export PATH="/home/linuxbrew/.linuxbrew/opt/dotnet@8/bin:$PATH"
  export DOTNET_ROOT="/home/linuxbrew/.linuxbrew/opt/dotnet@8/libexec"
fi

export PATH="$HOME/.cargo/bin:$PATH"
export NODE_OPTIONS="--experimental-vm-modules"
export PATH="$HOME/.dotnet/tools:$PATH"
export PATH="$HOME/.local/bin:$PATH"

alias diskcheck='df -h / && sudo du -sh /var/log /var/lib/docker /tmp /home 2>/dev/null'

# Warn on shell start if root disk usage >= 85%
_disk_usage_warn() {
  local use=$(df -P / | awk 'NR==2 {gsub("%","",$5); print $5}')
  if [ -n "$use" ] && [ "$use" -ge 85 ]; then
    print -P "%F{red}⚠ Disk usage on / is ${use}%%%f — run %F{yellow}diskcheck%f or %F{yellow}sudo ncdu /%f"
  fi
}
_disk_usage_warn

# pyenv — Python version manager (guarded: no-op if not installed)
export PYENV_ROOT="$HOME/.pyenv"
if [ -d "$PYENV_ROOT/bin" ]; then
  export PATH="$PYENV_ROOT/bin:$PATH"
  command -v pyenv >/dev/null && eval "$(pyenv init - zsh)"
fi

# --- Modern CLI tools (installed via brew by bootstrap.sh) ---
# Each is guarded so this block is harmless if the tool isn't installed.
# fd and bat need no wiring (brew installs them under their real names).

# fzf: Ctrl-R fuzzy history, Ctrl-T fuzzy file picker, ** completion
command -v fzf >/dev/null && source <(fzf --zsh)

# zoxide: `z <partial>` jumps to your most-used matching dir (smarter cd)
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"

# eza: modern ls (icons, git status, tree). Leaves plain `ls` alone.
if command -v eza >/dev/null; then
  alias ll='eza -lah --git --group-directories-first'
  alias la='eza -a --group-directories-first'
  alias lt='eza --tree --level=2 --group-directories-first'
fi

# yazi: `y` opens the TUI file manager and cd's to wherever you quit
if command -v yazi >/dev/null; then
  y() {
    local tmp cwd; tmp="$(mktemp -t yazi-cwd.XXXXXX)"
    yazi "$@" --cwd-file="$tmp"
    cwd="$(command cat -- "$tmp")"
    [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
    rm -f -- "$tmp"
  }
fi

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
