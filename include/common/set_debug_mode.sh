#!/bin/bash
# set_debug_mode.sh - Enable or disable debug mode for shell scripts
# Category: common

set_debug_mode() {
    local mode="${1:-on}"

    if [[ "$mode" == "on" ]]; then
        export SHELL_DEBUG=1
        set -x
    else
        unset SHELL_DEBUG
        set +x
    fi
}

# Export the function
export -f set_debug_mode
# EOF
