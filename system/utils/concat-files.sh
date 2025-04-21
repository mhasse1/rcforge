#!/usr/bin/env bash
# concat-files.sh - Concatenate specified files with markers
# Author: rcForge Team
# Date: 2025-04-21
# Version: 0.5.0
# Category: system/utility
# RC Summary: Concatenates files matching a pattern with clear markers
# Description: Finds files in the current directory (optionally recursively)
#              matching an optional pattern, then prints their name and
#              content to standard output, separated by start/end markers.

# Source required libraries
source "${RCFORGE_LIB:-${XDG_DATA_HOME:-$HOME/.local/share}/rcforge/system/lib}/utility-functions.sh"

# Set strict error handling
set -o nounset
set -o pipefail

# Global constants
[ -v gc_version ]  || readonly gc_version="${RCFORGE_VERSION:-0.5.0}"
[ -v gc_app_name ] || readonly gc_app_name="${RCFORGE_APP_NAME:-rcForge}"
readonly UTILITY_NAME="concat-files"

# ============================================================================
# Function: ShowHelp
# Description: Display detailed help information for this utility.
# Usage: ShowHelp
# Arguments: None
# Returns: None. Exits with status 0.
# ============================================================================
ShowHelp() {
    _rcforge_show_help <<EOF
  Finds files in the current directory (optionally recursively) matching an
  optional pattern, then prints their name and content to standard output,
  separated by start/end markers.

Usage:
  rc ${UTILITY_NAME} [options]
  $0 [options]

Options:
  -p, --pattern PATTERN   Find files matching PATTERN (e.g., '*.sh')
                          Default: all files (*)
  -nr, --no-recursive     Only search the current directory (non-recursive)
  --help, -h              Show this help message
  --version               Show version information
  --summary               Show one-line description (for rc help)

Examples:
  rc ${UTILITY_NAME} -p '*.sh'            # Concatenate all .sh files recursively
  rc ${UTILITY_NAME} -p '*.md' -nr        # Concatenate .md files in current dir only
  rc ${UTILITY_NAME} > all_files.txt      # Save concatenated files to a file
EOF
    exit 0
}

# ============================================================================
# Function: main
# Description: Main execution logic.
# Usage: main "$@"
# Arguments: Command-line arguments
# Returns: 0 on success, 1 on error.
# ============================================================================
main() {
    # Parse arguments using standardized function
    declare -A options
    
    # Set default values for options
    StandardParseArgs options \
        --pattern="*" \
        --recursive=true \
        -- "$@" || exit $?

    # Handle standard flags automatically
    for arg in "$@"; do
        case "$arg" in
            --help|-h)
                ShowHelp  # Exit after showing help
                ;;
            --version)
                _rcforge_show_version "$0"
                exit 0
                ;;
            --summary)
                ExtractSummary "$0"
                exit $?
                ;;
        esac
    done

    local find_pattern="${options[pattern]}"
    local is_recursive="${options[recursive]}"
    
    # Display section header
    SectionHeader "File Concatenation Utility"

    # Build find command with simplified approach
    local find_cmd="find ."
    
    # Add maxdepth if non-recursive
    if [[ "$is_recursive" == "false" ]]; then
        find_cmd+=" -maxdepth 1"
    fi
    
    # Add standard exclusions
    find_cmd+=" \\( -path './.git' -o -path './node_modules' \\) -prune -o"
    
    # Add pattern and file type
    find_cmd+=" -name '$find_pattern' -type f -print0"
    
    # Create introduction header
    local intro_line=$(printf '%*s' "75" '' | tr ' ' '-')
    cat <<EOF
${intro_line}
# Introduction
This file contains a concatenation of files. The individual files are
delimited by lines formatted as:

    ========== <./path/to/file> ==========

The delimiter provides the name of the file and its path from the
project root.
${intro_line}
EOF

    # Flag to track if any files were found
    local file_found=false
    
    # Use process substitution to safely handle filenames with spaces/special chars
    while IFS= read -r -d '' file; do
        file_found=true
        
        # Display filename with consistent marker format
        local display_path="${file#./}"
        echo "# ========== <./${display_path}> =========="
        
        # Output file content (using -- to handle filenames starting with -)
        cat -- "$file"
        
        # Add blank line after each file for better readability
        echo ""
    done < <(eval "$find_cmd")
    
    # Report if no files were found
    if [[ "$file_found" == "false" ]]; then
        if [[ "$is_recursive" == "true" ]]; then
            InfoMessage "No files found matching pattern '$find_pattern' (recursive search)"
        else
            InfoMessage "No files found matching pattern '$find_pattern' (current directory only)"
        fi
    fi
    
    return 0
}

# Execute main function if run directly or via rc command
if IsExecutedDirectly || [[ "$0" == *"rc"* ]]; then
    main "$@"
    exit $? # Exit with status from main
fi

# EOF
