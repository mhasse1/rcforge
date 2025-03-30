#!/bin/bash
# is_macos.sh - Detect if the current system is macOS
# Category: common

is_macos() {
    [[ "$(uname -s)" == "Darwin" ]]
}

# Export the function
export -f is_macos
# EOF
