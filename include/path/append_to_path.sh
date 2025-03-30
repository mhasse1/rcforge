#!/bin/bash
# append_to_path.sh - Append a directory to the end of PATH
# Category: path

append_to_path() {
    local dir="$1"
    if [[ -d "$dir" && ":$PATH:" != *":$dir:"* ]]; then
        export PATH="$PATH:$dir"
        return 0
    fi
    return 1
}

# Export the function
export -f append_to_path
# EOF
