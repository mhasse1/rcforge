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

source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/utility-functions.sh"

# Set strict error handling
set -o nounset
 # set -o errexit
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
    exit 0
}


# ============================================================================
# Function: ShowHelp
# Description: Show help message for the script.
# Usage: ShowHelp
# ============================================================================
ShowHelp() {
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

    exit 0
}

# ============================================================================
# Function: ParseArguments
# Description: Parse command-line arguments for concat-files script.
# Usage: declare -A options; ParseArguments options "$@"
# Returns: Populates associative array. Returns 0 on success, 1 on error or help/summary.
# ============================================================================
ParseArguments() {
    local -n options_ref="$1" # Use nameref (Bash 4.3+)
    shift # Remove array name from args

    # Default values
    options_ref["find_pattern"]="*" # Default pattern finds everything [cite: 1045]
    options_ref["recursive"]=true # [cite: 1045]
    # options_ref["args"]=() # For any future positional args

     # --- Pre-parse checks for summary/help ---
     # Check BEFORE the loop if only summary/help is requested
     if [[ "$#" -eq 1 ]]; then
         case "$1" in
             -h|--help) ShowHelp; return 1 ;;
             --summary) ShowSummary; return 0 ;; # Handle summary
         esac
     # Also handle case where summary/help might be first but other args exist
     elif [[ "$#" -gt 0 ]]; then
          case "$1" in
             -h|--help) ShowHelp; return 1 ;;
             --summary) ShowSummary; return 0 ;; # Handle summary
         esac
     fi
    # --- End pre-parse ---

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) ShowHelp; return 1 ;;
            --summary) ShowSummary; return 0 ;; # Handle summary
            -p|--pattern)
                # Ensure value exists and is not another option
                if [[ -z "${2:-}" || "$2" == -* ]]; then ErrorMessage "Option '$1' requires a PATTERN argument."; return 1; fi # [cite: 1048]
                options_ref["find_pattern"]="$2"
                shift 2 # past argument and value [cite: 1049]
                ;;
            -nr|--no-recursive)
                options_ref["recursive"]=false # [cite: 1050]
                shift # past argument [cite: 1050]
                ;;
            *)
                ErrorMessage "Unknown option: $1" # [cite: 1051]
                ShowHelp
                return 1
                ;;
        esac
    done

    # No positional arguments expected for this script currently
    # Add validation here if needed in the future

    return 0 # Success
}

# ============================================================================
# Function: main
# Description: Main logic - parse args, find files, print content.
# Usage: main "$@"
# ============================================================================
main() {
    declare -A options
    ParseArguments options "$@" || exit $? # Parse args or exit

    # Use options from the array
    local find_pattern="${options[find_pattern]}"
    local max_depth_option="" # Default is recursive
    if [[ "${options[recursive]}" == "false" ]]; then
        max_depth_option="-maxdepth 1" # [cite: 1050]
    fi

    # Build find command arguments into an array for safety
    local -a find_args=(".") # Start with current directory [cite: 1052]

    # Add maxdepth option if set
    if [[ -n "$max_depth_option" ]]; then
        find_args+=("$max_depth_option") # [cite: 1053]
    fi

    # Always exclude .git directory
    find_args+=(-path "./.git" -prune -o) # [cite: 1053]

    # Add the name pattern if specified
    if [[ "$find_pattern" != "*" ]]; then
         find_args+=(-name "$find_pattern") # [cite: 1054]
    fi

    # Always look for files and print0
    find_args+=(-type f -print0) # [cite: 1054]

    # Execute find and loop through results safely
    find "${find_args[@]}" | while IFS= read -r -d '' file; do # [cite: 1055]
        # Print marker with filename
        echo "# ========== <${file}>" # [cite: 1055]
        # Print file content safely
        cat "$file" # [cite: 1055]
        # Add a newline after file content for separation
        echo "" # [cite: 1055]
    done
}

# Execute main function, passing all script arguments
main "$@"

# EOF