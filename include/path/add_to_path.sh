#!/bin/bash
# add_to_path.sh - Add a directory to the beginning of PATH
# Category: path

add_to_path() {
    local dir="$1"
    if [[ -d "$dir" && ":$PATH:" != *":$dir:"* ]]; then
        export PATH="$dir:$PATH"
        return 0
    fi
    return 1
}

# Export the function
export -f add_to_path
# EOF
