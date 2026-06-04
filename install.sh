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
#   - Stow refuses to clobber existing real files. On a machine that already has
#     ~/.zshrc, back it up / remove it first, or use `stow --adopt` (pulls the
#     existing file into the repo, then symlinks — review the diff after!).
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
  packages=(zsh tmux git wezterm claude)
fi

for pkg in "${packages[@]}"; do
  if [ ! -d "$pkg" ]; then
    echo "skip: no such package '$pkg'" >&2
    continue
  fi
  echo "stow: $pkg"
  stow --target="$HOME" --restow "$pkg"
done

echo "Done. Open a new shell (or 'source ~/.zshrc') to pick up changes."
