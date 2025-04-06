#!/usr/bin/env bash
# concat-files.sh - Concatenate specified files with markers for processing
# Author: User Provided / Updated by AI
# Date: 2025-04-06
# Version: N/A
# Category: utility/developer
# RC Summary: Finds files and concatenates their content with markers.
# Description: Finds files in the current directory (optionally recursively)
#              matching an optional pattern, then prints their name and
#              content to standard output, separated by start/end markers.

# Set strict error handling
set -o nounset
set -o errexit
set -o pipefail

# ============================================================================
# Function: ShowSummary
# Description: Display one-line summary for rc help command.
# Usage: ShowSummary
# Arguments: None
# Returns: Echoes summary string.
# ============================================================================
ShowSummary() {
    grep '^# RC Summary:' "$0" | sed 's/^# RC Summary: //'
}


# ============================================================================
# Function: DisplayHelp
# Description: Show help message for the script.
# Usage: DisplayHelp
# ============================================================================
DisplayHelp() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Description:"
    echo "  Finds files and concatenates their content with markers."
    echo ""
    echo "Options:"
    echo "  -p, --pattern PATTERN   Find files matching PATTERN (e.g., '*.sh'). Defaults to all files."
    echo "  -nr, --no-recursive   Only search the current directory (do not recurse into subdirectories)."
    echo "  -h, --help            Show this help message."
    echo ""
    echo "Example:"
    echo "  $0 -p '*.sh' -nr   # Concatenate all .sh files in the current directory only"
}

# ============================================================================
# Function: main
# Description: Main logic - parse args, find files, print content.
# Usage: main "$@"
# ============================================================================
main() {
    # Default option values
    local find_pattern="*" # Default pattern finds everything (effectively)
    local max_depth_option="" # Default is recursive

    # Parse Arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                DisplayHelp
                exit 0
                ;;
            -p|--pattern)
                if [[ -z "${2:-}" ]]; then
                     echo "ERROR: Option '$1' requires a PATTERN argument." >&2
                     exit 1
                fi
                find_pattern="$2"
                shift # past argument
                shift # past value
                ;;
            -nr|--no-recursive)
                max_depth_option="-maxdepth 1"
                shift # past argument
                ;;
            *)
                echo "ERROR: Unknown option: $1" >&2
                DisplayHelp
                exit 1
                ;;
        esac
    done

    # Build find command arguments into an array for safety
    local -a find_args=(".") # Start with current directory

    # Add maxdepth option if set
    if [[ -n "$max_depth_option" ]]; then
        find_args+=("$max_depth_option")
    fi

    # Always exclude .git directory
    find_args+=(-path "./.git" -prune -o)

    # Add the name pattern if specified (use -name for simple patterns)
    # If using more complex paths, -path might be better
    if [[ "$find_pattern" != "*" ]]; then
         find_args+=(-name "$find_pattern")
    fi

    # Always look for files and print0
    find_args+=(-type f -print0)

    # Execute find and loop through results safely
    find "${find_args[@]}" | while IFS= read -r -d '' file; do
        # Print marker with filename
        echo "# ========== <${file}>"
        # Print file content safely
        cat "$file"
        # Add a newline after file content for separation
        echo ""
    done
}

# Execute main function, passing all script arguments
main "$@"

# EOF