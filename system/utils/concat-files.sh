#!/usr/bin/env bash
# concat-files.sh - Concatenate files with clear markers
# Author: rcForge Team
# Date: 2025-04-21
# Version: 0.5.0
# Category: system/utility
# RC Summary: Concatenates files matching a pattern with standard markers
# Description: Combines files matching a pattern into a single output with
#              filename markers for easy identification.

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
# Description: Display help information for this utility.
# Usage: ShowHelp
# Returns: Exits with status 0.
# ============================================================================
ShowHelp() {
    _rcforge_show_help <<EOF
  Combines files matching a pattern into a single output with
  filename markers for easy identification.

Usage:
  rc ${UTILITY_NAME} [options]
  $0 [options]

Options:
  -p, --pattern PATTERN   Find files matching PATTERN (default: *)
  -nr, --no-recursive     Search current directory only (non-recursive)
  --help, -h              Show this help message
  --version               Show version information
  --summary               Show one-line description

Examples:
  rc ${UTILITY_NAME} -p '*.sh'            # Concatenate all .sh files recursively
  rc ${UTILITY_NAME} -p '*.md' -nr        # Concatenate .md files in current dir only
  rc ${UTILITY_NAME} > all_files.txt      # Save output to a file
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
    # Set default options
    local pattern="*"
    local recursive=true

    # Process options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--pattern)
                shift
                [[ $# -eq 0 ]] && ErrorMessage "Missing pattern argument" && return 1
                pattern="$1"
                ;;
            --pattern=*)
                pattern="${1#*=}"
                ;;
            -nr|--no-recursive)
                recursive=false
                ;;
            --help|-h)
                ShowHelp
                ;;
            --version)
                _rcforge_show_version "$0"
                exit 0
                ;;
            --summary)
                ExtractSummary "$0"
                exit $?
                ;;
            *)
                ErrorMessage "Unknown option: $1"
                return 1
                ;;
        esac
        shift
    done
    
    # Build simple find command
    local find_opts=""
    [[ "$recursive" == "false" ]] && find_opts="-maxdepth 1"
    
    # Print header only if files found
    local file_count=0
    while IFS= read -r -d '' file; do
        if [[ $file_count -eq 0 ]]; then
            echo "# Start of concatenated files"
            echo "#"
            echo "# Files are separated by markers in this format:"
            echo "# ========== <file_path> =========="
            echo ""
        fi
        
        # Print filename marker
        local display_path="${file#./}"
        echo "# ========== <${display_path}> =========="
        
        # Output file content
        cat -- "$file"
        echo ""
        
        file_count=$((file_count + 1))
    done < <(find . $find_opts -type f -name "$pattern" -print0 2>/dev/null | sort)
    
    # Show message if no files found
    if [[ $file_count -eq 0 ]]; then
        local scope="recursively"
        [[ "$recursive" == "false" ]] && scope="in current directory"
        InfoMessage "No files matching pattern '$pattern' found $scope"
        return 0
    else
        echo "# End of concatenated files (total: $file_count)"
    fi
    
    return 0
}

# Execute main function if run directly or via rc command
if IsExecutedDirectly || [[ "$0" == *"rc"* ]]; then
    main "$@"
    exit $? # Exit with status from main
fi

# EOF