#!/usr/bin/env bash
# Open a clean, searchable copy of a pane's entire scrollback in a pager,
# WITHOUT touching the live history.
#
# Why: with `window-size latest`, a client resize makes tmux reflow history
# and apps that repaint in place (Claude Code's transcript) leave duplicated
# text in the scrollback — hard to read back through in long threads. There
# is no tmux primitive that de-duplicates history in place, and clearing it
# loses the thread. This instead snapshots the whole buffer with wrapped
# lines re-joined (so no mid-word breaks) and hands it to `less`, where you
# can scroll and `/`-search the full thread cleanly. The real pane is
# untouched.
#
# Called from the `prefix + R` binding with the pane id as $1.
set -euo pipefail

pane="${1:?usage: thread-view.sh <pane-id>}"

out=$(mktemp "${TMPDIR:-/tmp}/tmux-thread.XXXXXX.txt")

# -p print to stdout, -e keep colour escapes, -J join wrapped lines,
# -S - capture from the very start of history to the visible screen.
tmux capture-pane -t "$pane" -p -e -J -S - > "$out"

# New window so the live pane/layout is undisturbed; +G opens at the end
# (most recent). Closing less (q) closes the window and removes the temp.
tmux new-window -n thread "less -R +G '$out'; rm -f '$out'"
