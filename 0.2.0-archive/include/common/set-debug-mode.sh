#!/usr/bin/env bash
# SetDebugMode.sh - Enable or disable debug mode for shell scripts
# Category: common
# Author: Mark Hasse (converted to style guide)
# Date: 2025-03-31

# Function: SetDebugMode
# Description: Toggles debug mode on or off for the current shell session
# Usage: SetDebugMode [on|off]
# Arguments:
#   $1 - Mode: "on" or "off" (default: "on")
# Returns: 0 on success
SetDebugMode() {
    local mode="${1:-on}"

    if [[ "$mode" == "on" ]]; then
        export SHELL_DEBUG=1
        set -x
    elif [[ "$mode" == "off" ]]; then
        unset SHELL_DEBUG
        set +x
    else
        echo "ERROR: Invalid mode '$mode'. Use 'on' or 'off'." >&2
        return 1
    fi
    
    return 0
}

# Export the function
export -f SetDebugMode
# EOF
