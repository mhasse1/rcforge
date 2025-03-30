#!/bin/bash
# cmd_exists.sh - Check if a command exists
# Category: common

cmd_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Export the function
export -f cmd_exists
# EOF
