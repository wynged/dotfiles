#!/usr/bin/env bash
# Symlink dotfiles into $HOME using GNU Stow.
#
# Each top-level dir (except wallpapers/) is a stow "package" whose contents
# mirror the layout under $HOME. Running `stow zsh` symlinks zsh/.zshrc -> ~/.zshrc,
# zsh/.zshenv -> ~/.zshenv, etc.
#
# Usage:
#   ./install.sh            # stow every package
#   ./install.sh zsh tmux   # stow only the named packages
#
# Notes:
#   - Real files (not symlinks) that conflict are backed up to <file>.bak.TIMESTAMP
#     before stowing, so re-runs are safe and no data is lost.
#   - wallpapers/ is storage only and is never stowed.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES_DIR"

if ! command -v stow >/dev/null 2>&1; then
  echo "GNU Stow is not installed. Install it with:  sudo apt install stow" >&2
  exit 1
fi

# Default package list = every dir that contains dotfiles (skip repo meta + storage).
if [ "$#" -gt 0 ]; then
  packages=("$@")
else
  packages=(zsh tmux git wezterm claude regolith polybar vocalinux dunst nautilus)
fi

# Back up any real files (not symlinks) that would block stow, then remove them
# so the subsequent stow call can create the symlink cleanly.
backup_conflicts() {
  local pkg="$1" sim_out
  # Capture separately so stow's non-zero exit (conflict found) doesn't kill us.
  sim_out=$(stow --target="$HOME" --simulate --restow "$pkg" 2>&1) || true
  # grep exits 1 when there are no matches; || true keeps the pipeline happy.
  grep -oP '(?<=existing target )\S+' <<< "$sim_out" \
    | while read -r rel; do
        local full="$HOME/$rel"
        if [ -e "$full" ] && [ ! -L "$full" ]; then
          local backup="${full}.bak.$(date +%Y%m%d%H%M%S)"
          echo "  backing up ~/$rel → $backup"
          mv "$full" "$backup"
        fi
      done || true
}

for pkg in "${packages[@]}"; do
  if [ ! -d "$pkg" ]; then
    echo "skip: no such package '$pkg'" >&2
    continue
  fi
  echo "stow: $pkg"
  backup_conflicts "$pkg"
  stow --target="$HOME" --restow "$pkg"
done

echo "Done. Open a new shell (or 'source ~/.zshrc') to pick up changes."
