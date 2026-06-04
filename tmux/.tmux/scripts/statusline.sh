#!/bin/bash
# Tmux status line script - shows git branch and dev server
# Reads dev ports from Gas Town's .dev-ports/ directory (same as Claude Code statusline)

DEV_PORTS_DIR="/home/sirwassail/source/hypar_gt/.dev-ports"

# Get git branch from pane's current path
get_git_branch() {
    local pane_path="$1"
    if [ -n "$pane_path" ] && [ -d "$pane_path" ]; then
        git -C "$pane_path" rev-parse --abbrev-ref HEAD 2>/dev/null
    fi
}

# Determine crew name from path (matches Claude Code's statusline logic)
get_crew_from_path() {
    local pane_path="$1"
    case "$pane_path" in
        */crew/*)
            echo "$pane_path" | sed 's|.*/crew/\([^/]*\).*|\1|'
            ;;
        */mayor/rig*)
            echo "mayor"
            ;;
        */polecats/*)
            echo "$pane_path" | sed 's|.*/polecats/\([^/]*\).*|\1|'
            ;;
    esac
}

# Get dev server port for this crew
get_dev_port() {
    local crew="$1"
    if [ -n "$crew" ] && [ -f "$DEV_PORTS_DIR/$crew" ]; then
        cat "$DEV_PORTS_DIR/$crew" 2>/dev/null | tr -d '[:space:]'
    fi
}

# Main
pane_path="$1"

branch=$(get_git_branch "$pane_path")
crew=$(get_crew_from_path "$pane_path")
dev_port=$(get_dev_port "$crew")

output=""

if [ -n "$branch" ]; then
    output=" ${branch}"
fi

if [ -n "$dev_port" ]; then
    if [ -n "$output" ]; then
        output="${output} │"
    fi
    output="${output} localhost:${dev_port}"
fi

echo "$output"
