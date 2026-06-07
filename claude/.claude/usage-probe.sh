#!/bin/sh
# usage-probe.sh — Scrape /usage from a headless Claude Code session
#
# Spawns a throwaway Claude session in a detached tmux pane, sends /usage,
# captures the dialog text, parses percentages and reset times, and writes
# them to ~/.claude/.usage-tracking/usage.json for the statusline to read.
#
# Designed to be called periodically (e.g., every 10 minutes via cron).
# Self-contained: creates and tears down its own tmux socket per run.

set -e

# Ensure claude is in PATH (cron has minimal PATH)
export PATH="$HOME/.local/bin:$PATH"

SOCKET="claude-usage-probe"
SESSION="usage-probe"
USAGE_DIR="$HOME/.claude/.usage-tracking"
OUTPUT="$USAGE_DIR/usage.json"

mkdir -p "$USAGE_DIR"

cleanup() {
  tmux -L "$SOCKET" kill-session -t "$SESSION" 2>/dev/null || true
}
trap cleanup EXIT

cleanup

# Start a detached Claude session using Haiku to minimize token usage
tmux -L "$SOCKET" new-session -d -s "$SESSION" -x 120 -y 40 \
  "claude --dangerously-skip-permissions --model haiku 2>&1"

# Wait for Claude to initialize (show the prompt)
for i in $(seq 1 20); do
  sleep 1
  if tmux -L "$SOCKET" capture-pane -t "$SESSION" -p 2>/dev/null | grep -q '❯'; then
    break
  fi
done

# Settle: the '❯' glyph shows up in the welcome splash before the input is
# actually ready, and SessionStart hooks (e.g. `bd prime`) trigger a redraw at
# startup that can swallow the first keystroke. Give it a moment before typing.
sleep 2

# Send /usage and submit as separate keystrokes, then poll until the usage
# dialog actually renders. If the first attempt got eaten during a redraw,
# re-send. We look for the parser's anchor text ("Current session" / "% used").
pane=""
for attempt in 1 2 3; do
  tmux -L "$SOCKET" send-keys -t "$SESSION" "/usage"
  sleep 1
  tmux -L "$SOCKET" send-keys -t "$SESSION" Enter

  # Poll up to ~8s for the dialog to appear
  for i in $(seq 1 8); do
    sleep 1
    pane=$(tmux -L "$SOCKET" capture-pane -t "$SESSION" -p 2>/dev/null)
    if echo "$pane" | grep -q 'Current session'; then
      break
    fi
  done

  echo "$pane" | grep -q 'Current session' && break

  # Not rendered — clear any stray input and try again
  tmux -L "$SOCKET" send-keys -t "$SESSION" Escape
  sleep 1
done

# Dismiss and exit
tmux -L "$SOCKET" send-keys -t "$SESSION" Escape
sleep 1
tmux -L "$SOCKET" send-keys -t "$SESSION" "/exit" Enter 2>/dev/null || true

# Parse the output
# NB: requires gawk — uses the 3-arg match($0, re, arr) form and strftime(),
# both GNU extensions. Call gawk explicitly so this never silently degrades
# to mawk (Ubuntu's default awk), which can't parse the script.
echo "$pane" | gawk '
BEGIN {
  section = ""
  print "{"
  first = 1
}
/Current session/ { section = "session_5h" }
/Current week \(all models\)/ { section = "week_all" }
/Current week \(Sonnet only\)/ { section = "week_sonnet" }
/% used/ {
  if (section != "") {
    match($0, /([0-9]+)% used/, m)
    pct = m[1]
    if (pct == "") {
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^[0-9]+%$/) {
          gsub(/%/, "", $i)
          pct = $i
        }
      }
    }
    if (pct != "") {
      if (!first) printf ",\n"
      first = 0
      printf "  \"%s_pct\": %s", section, pct
    }
  }
}
/Resets/ {
  if (section != "") {
    match($0, /Resets (.+)/, r)
    reset_str = r[1]
    if (reset_str == "") {
      sub(/.*Resets /, "", $0)
      reset_str = $0
    }
    gsub(/[[:space:]]+$/, "", reset_str)
    if (reset_str != "") {
      printf ",\n  \"%s_resets\": \"%s\"", section, reset_str
    }
    section = ""
  }
}
END {
  printf ",\n  \"updated_at\": \"%s\"", strftime("%Y-%m-%dT%H:%M:%S%z")
  print "\n}"
}
' > "$OUTPUT"

if jq empty "$OUTPUT" 2>/dev/null; then
  echo "Updated: $(cat "$OUTPUT")"
else
  echo "Parse failed, raw pane output:" >&2
  echo "$pane" >&2
  rm -f "$OUTPUT"
  exit 1
fi
