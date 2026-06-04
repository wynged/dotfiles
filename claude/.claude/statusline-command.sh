#!/bin/sh
input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
dir=$(basename "$cwd")
model=$(echo "$input" | jq -r '.model.display_name // empty')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Build git branch string
branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)
if [ -z "$branch" ]; then
  branch=$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
fi
if [ -n "$branch" ]; then
  branch_str=" | \033[1;33m${branch}\033[0m"
else
  branch_str=""
fi

# Determine crew name and city root from CWD path
crew=""
city_root=""
rig=""
case "$cwd" in
  */.gc/worktrees/*/*)
    # Gas City layout: <city_root>/.gc/worktrees/<rig>/<agent>[/...]
    city_root=$(echo "$cwd" | sed 's|/\.gc/worktrees/.*||')
    rig=$(echo "$cwd" | sed 's|.*/\.gc/worktrees/\([^/]*\)/.*|\1|')
    crew=$(echo "$cwd" | sed 's|.*/\.gc/worktrees/[^/]*/\([^/]*\).*|\1|')
    ;;
  */.gc/agents/*)
    # Mayor/city agents: <city_root>/.gc/agents/<agent>
    city_root=$(echo "$cwd" | sed 's|/\.gc/agents/.*||')
    crew="mayor"
    ;;
esac

# Build dev port string (read from city-level .dev-ports/$CREW)
dev_port=""
if [ -n "$crew" ] && [ -n "$city_root" ]; then
  port_file="${city_root}/.dev-ports/${crew}"
  if [ -f "$port_file" ]; then
    dev_port=$(cat "$port_file" 2>/dev/null | tr -d '[:space:]')
  fi
fi
if [ -n "$dev_port" ]; then
  port_str=" | \033[1;36mlocalhost:${dev_port}\033[0m"
else
  port_str=""
fi

# Build context usage indicator (green < 20%, yellow 20-30%, red >= 30%)
if [ -n "$used" ]; then
  used_int=$(printf "%.0f" "$used")
  if [ "$used_int" -ge 30 ]; then
    ctx_color="\033[31m"
  elif [ "$used_int" -ge 20 ]; then
    ctx_color="\033[33m"
  else
    ctx_color="\033[32m"
  fi
  ctx_str=" | ${ctx_color}ctx: ${used_int}%\033[0m"
else
  ctx_str=""
fi

# --- Rate limit bars from /usage probe ---
#
# Reads usage percentages from ~/.claude/.usage-tracking/usage.json
# (populated by usage-probe.sh running periodically).
# Time cursor is computed from the reset times in that same JSON.

USAGE_FILE="$HOME/.claude/.usage-tracking/usage.json"

# Render a bar: $1=usage_pct $2=time_pct $3=bar_width
render_bar() {
  local usage_pct="$1" time_pct="$2" width="$3"

  awk -v usage_pct="$usage_pct" -v time_pct="$time_pct" -v width="$width" '
  BEGIN {
    usage_pos = int(usage_pct * width / 100)
    time_pos = int(time_pct * width / 100)
    if (time_pos >= width) time_pos = width - 1
    if (time_pos < 0) time_pos = 0

    if (usage_pct >= 80)           color = "\033[31m"
    else if (usage_pct > time_pct) color = "\033[33m"
    else                           color = "\033[2;37m"

    reset = "\033[0m"
    dim = "\033[2m"

    printf "%s", color
    for (i = 0; i < width; i++) {
      at_cursor = (i == time_pos)
      filled = (i < usage_pos)
      if (at_cursor) {
        if (filled) printf "%s▐%s", reset, color
        else        printf "%s▎%s%s", reset, dim, reset
      } else if (filled) {
        printf "█"
      } else {
        printf "%s░%s", dim, reset
      }
    }
    printf "%s %d%%", reset, usage_pct
  }' /dev/null
}

# Compute time elapsed percentage for the 5h window
# Reset string is like "3:30pm (America/New_York)" — parse to epoch, walk back 5h
compute_5h_time_pct() {
  local resets="$1"
  local time_part=$(echo "$resets" | sed 's/ *(.*//')
  [ -z "$time_part" ] && echo 50 && return

  local reset_epoch=$(date -d "$time_part" +%s 2>/dev/null)
  [ -z "$reset_epoch" ] && echo 50 && return

  local now_epoch=$(date +%s)
  # date -d "3:30pm" assumes today; if that's already past, the next reset is tomorrow
  if [ "$reset_epoch" -le "$now_epoch" ]; then
    reset_epoch=$((reset_epoch + 86400))
  fi
  local block_start=$((reset_epoch - 18000))
  local elapsed=$((now_epoch - block_start))
  local pct=$((elapsed * 100 / 18000))
  [ "$pct" -gt 100 ] && pct=100
  [ "$pct" -lt 0 ] && pct=0
  echo "$pct"
}

# Compute time elapsed percentage for the 7d window
# Reset string is like "Mar 19, 11pm (America/New_York)"
compute_7d_time_pct() {
  local resets="$1"
  # Parse "Mar 19, 11pm" — extract the reset epoch
  local date_part=$(echo "$resets" | sed 's/ *(.*//;s/,//g;s/  */ /g')
  [ -z "$date_part" ] && echo 50 && return

  # Try to parse with date
  local reset_epoch=$(date -d "$date_part" +%s 2>/dev/null)
  [ -z "$reset_epoch" ] && echo 50 && return

  local now_epoch=$(date +%s)
  local window_start=$((reset_epoch - 604800))
  local elapsed=$((now_epoch - window_start))
  local pct=$((elapsed * 100 / 604800))
  [ "$pct" -gt 100 ] && pct=100
  [ "$pct" -lt 0 ] && pct=0
  echo "$pct"
}

usage_str=""
if [ -f "$USAGE_FILE" ]; then
  pct_5h=$(jq -r '.session_5h_pct // empty' "$USAGE_FILE")
  pct_7d=$(jq -r '.week_all_pct // empty' "$USAGE_FILE")
  resets_5h=$(jq -r '.session_5h_resets // empty' "$USAGE_FILE")
  resets_7d=$(jq -r '.week_all_resets // empty' "$USAGE_FILE")

  if [ -n "$pct_5h" ]; then
    time_5h=$(compute_5h_time_pct "$resets_5h")
    bar_5h=$(render_bar "$pct_5h" "$time_5h" 10)
    usage_str="${usage_str} | \033[36m5h\033[0m ${bar_5h}"
  fi

  if [ -n "$pct_7d" ]; then
    time_7d=$(compute_7d_time_pct "$resets_7d")
    bar_7d=$(render_bar "$pct_7d" "$time_7d" 10)
    usage_str="${usage_str} | \033[35m7d\033[0m ${bar_7d}"
  fi
fi

# Build project/hook bead string — read from lookout's focus cache.
# The cache is populated by `lookout --refresh-focus` or by pressing F in
# the lookout TUI. The statusline itself never touches dolt.
hook_str=""
if [ -n "$crew" ] && [ "$crew" != "mayor" ] && [ -n "$rig" ]; then
  cache_base="${XDG_CACHE_HOME:-$HOME/.cache}/lookout/focus"
  cache_file="${cache_base}/${rig}__${crew}.txt"
  if [ -f "$cache_file" ]; then
    { read -r display; read -r extra; read -r refreshed_at; } < "$cache_file"
    extra=${extra:-0}
    if [ -n "$display" ]; then
      if [ ${#display} -gt 40 ]; then
        display="$(echo "$display" | cut -c1-39)…"
      fi
      # Fade the icon if the cache is older than 30 minutes so stale entries
      # are visually distinct from fresh ones.
      now=$(date +%s)
      age=$((now - ${refreshed_at:-0}))
      if [ "$age" -gt 1800 ]; then
        icon_color="\033[2;36m"
      else
        icon_color="\033[36m"
      fi
      if [ "$extra" -gt 0 ]; then
        hook_str="${icon_color}🪝 ${display} +${extra}\033[0m"
      else
        hook_str="${icon_color}🪝 ${display}\033[0m"
      fi
    fi
  fi
fi

# Build model string
if [ -n "$model" ]; then
  model_str=" | ${model}"
else
  model_str=""
fi

printf "\033[1;32m%s\033[0m%b%b\033[0;37m%s\033[0m%b%b" "$dir" "$branch_str" "$port_str" "$model_str" "$ctx_str" "$usage_str"
if [ -n "$hook_str" ]; then
  printf "\n%b" "$hook_str"
fi
