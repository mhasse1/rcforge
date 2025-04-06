#!/usr/bin/env bash
# CmdExists.sh - Check if a command exists in the system PATH
# Category: common
# Author: Mark Hasse (converted to style guide)
# Date: 2025-03-31

# Function: CmdExists
# Description: Tests if a command exists in the system PATH
# Usage: CmdExists command_name
# Arguments:
#   $1 - The command name to check
# Returns: 0 if command exists, 1 otherwise
CmdExists() {
    # Validate input
    if [[ $# -eq 0 ]]; then
        echo "ERROR: No command name provided to check" >&2
        return 1
    fi
    
    # Use command -v which is more portable than 'which'
    command -v "$1" >/dev/null 2>&1
    return $?
}

# Export the function
export -f CmdExists
# EOF
