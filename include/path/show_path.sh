#!/bin/bash
# show_path.sh - Display PATH contents in a readable format
# Category: path

show_path() {
    echo "Current PATH:"
    echo "$PATH" | tr ':' '\n' | nl
}

# Export the function
export -f show_path
# EOF
