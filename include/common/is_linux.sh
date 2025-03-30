#!/bin/bash
# is_linux.sh - Detect if the current system is Linux
# Category: common

is_linux() {
    [[ "$(uname -s)" == "Linux" ]]
}

# Export the function
export -f is_linux
# EOF
