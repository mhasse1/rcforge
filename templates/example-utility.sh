#!/usr/bin/env bash
# findlarge.sh - Find large files in specified directories
# Author: rcForge Team
# Date: 2025-04-17
# Version: 0.4.1
# Category: system/utility
# RC Summary: Locates and lists large files in specified directories
# Description: Searches directories for files exceeding a specified size threshold,
#              with flexible sorting and filtering options.

# Source necessary libraries
source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/utility-functions.sh"

# Set strict error handling
set -o nounset
set -o pipefail

# ============================================================================
# GLOBAL CONSTANTS
# ============================================================================
[ -v gc_version ] || readonly gc_version="${RCFORGE_VERSION:-0.4.1}"
[ -v gc_app_name ] || readonly gc_app_name="${RCFORGE_APP_NAME:-rcForge}"
readonly UTILITY_NAME="findlarge"

# ============================================================================
# Function: ShowHelp
# Description: Display detailed help information for this utility.
# Usage: ShowHelp
# Exits: 0
# ============================================================================
ShowHelp() {
    local script_name
    script_name=$(basename "$0")

    echo "${UTILITY_NAME} - rcForge Utility (v${gc_version})"
    echo ""
    echo "Description:"
    echo "  Finds files larger than a specified size in directories."
    echo "  Useful for identifying space-consuming files and cleaning up disk space."
    echo ""
    echo "Usage:"
    echo "  rc ${UTILITY_NAME} [options] [directories...]"
    echo "  ${script_name} [options] [directories...]"
    echo ""
    echo "Options:"
    echo "  --size=SIZE      Minimum file size (default: 100M)"
    echo "                   Units: K (KB), M (MB), G (GB), T (TB)"
    echo "  --count=N        Limit to N results (default: 10)"
    echo "  --sort=METHOD    Sort method (size, name, modified) (default: size)"
    echo "  --exclude=PATTERN Exclude files matching pattern"
    echo "  --summary, -s    Only show summary statistics"
    echo "  --verbose, -v    Show additional details"
    echo "  --help, -h       Show this help message"
    echo "  --version        Show version information"
    echo ""
    echo "Examples:"
    echo "  rc ${UTILITY_NAME} --size=500M ~/Downloads          # Find files over 500MB in Downloads"
    echo "  rc ${UTILITY_NAME} --count=5 --sort=modified ~      # Find 5 largest files in home, sorted by date"
    echo "  rc ${UTILITY_NAME} --exclude='*.iso' --size=1G /tmp # Find files over 1GB in /tmp, excluding ISOs"
    exit 0
}

# ============================================================================
# Function: ExtractSizeInBytes
# Description: Convert human-readable size to bytes
# Usage: bytes=$(ExtractSizeInBytes "100M")
# Returns: Size in bytes, or -1 on error
# ============================================================================
ExtractSizeInBytes() {
    local size_str="$1"
    local num_part unit multiplier

    # Extract numerical part and unit
    if [[ "$size_str" =~ ^([0-9]+)([KMGT])?$ ]]; then
        num_part="${BASH_REMATCH[1]}"
        unit="${BASH_REMATCH[2]:-}"
    else
        ErrorMessage "Invalid size format: $size_str. Use format like 100M, 2G, etc."
        return -1
    fi

    # Determine multiplier based on unit
    case "$unit" in
        K) multiplier=1024 ;;
        M) multiplier=$((1024 * 1024)) ;;
        G) multiplier=$((1024 * 1024 * 1024)) ;;
        T) multiplier=$((1024 * 1024 * 1024 * 1024)) ;;
        "") multiplier=1 ;; # No unit means bytes
        *)
            ErrorMessage "Invalid size unit: $unit. Use K, M, G, or T."
            return -1
            ;;
    esac

    # Calculate and return bytes
    echo $((num_part * multiplier))
    return 0
}

# ============================================================================
# Function: FormatSizeHuman
# Description: Format byte size to human-readable format
# Usage: human_size=$(FormatSizeHuman 1048576)
# Returns: Human-readable size (e.g., "1.0M")
# ============================================================================
FormatSizeHuman() {
    local size="$1"
    local -a suffixes=("" "K" "M" "G" "T" "P")
    local suffix_index=0

    # Calculate appropriate suffix
    while [[ $size -ge 1024 && $suffix_index -lt ${#suffixes[@]}-1 ]]; do
        size=$((size / 1024))
        ((suffix_index++))
    done

    echo "${size}${suffixes[$suffix_index]}"
    return 0
}

# ============================================================================
# Function: ParseArguments
# Description: Parse command-line arguments for findlarge utility.
# Usage: declare -A options; ParseArguments options "$@"
# Returns: Populates associative array by reference. Returns 0 on success, 1 on error.
# ============================================================================
ParseArguments() {
    local -n options_ref="$1"
    shift

    # Ensure Bash 4.3+ for namerefs (-n)
    if [[ "${BASH_VERSINFO[0]}" -lt 4 || ("${BASH_VERSINFO[0]}" -eq 4 && "${BASH_VERSINFO[1]}" -lt 3) ]]; then
        ErrorMessage "Internal Error: ParseArguments requires Bash 4.3+ for namerefs."
        return 1
    fi

    # Set default values
    options_ref["size"]="100M"
    options_ref["count"]="10"
    options_ref["sort"]="size"
    options_ref["exclude"]=""
    options_ref["summary_only"]=false
    options_ref["verbose_mode"]=false
    options_ref["directories"]=()

    # Single loop for arguments
    while [[ $# -gt 0 ]]; do
        local key="$1"
        case "$key" in
            -h | --help)
                ShowHelp # Exits
                ;;
            --summary)
                if [[ "$#" -eq 1 || "$2" == -* ]]; then
                    # This is the RC summary request
                    ExtractSummary "$0"
                    exit $?
                else
                    # This is the summary-only flag
                    options_ref["summary_only"]=true
                    shift
                fi
                ;;
            -s)
                options_ref["summary_only"]=true
                shift
                ;;
            --version)
                _rcforge_show_version "$0"
                exit 0
                ;;
            --size=*)
                options_ref["size"]="${key#*=}"
                shift
                ;;
            --size)
                shift
                if [[ -z "${1:-}" || "$1" == -* ]]; then
                    ErrorMessage "--size requires a value."
                    return 1
                fi
                options_ref["size"]="$1"
                shift
                ;;
            --count=*)
                options_ref["count"]="${key#*=}"
                shift
                ;;
            --count)
                shift
                if [[ -z "${1:-}" || "$1" == -* ]]; then
                    ErrorMessage "--count requires a value."
                    return 1
                fi
                options_ref["count"]="$1"
                shift
                ;;
            --sort=*)
                local sort_method="${key#*=}"
                if [[ "$sort_method" != "size" && "$sort_method" != "name" && "$sort_method" != "modified" ]]; then
                    ErrorMessage "Invalid sort method: $sort_method. Must be 'size', 'name', or 'modified'."
                    return 1
                fi
                options_ref["sort"]="$sort_method"
                shift
                ;;
            --sort)
                shift
                if [[ -z "${1:-}" || "$1" == -* ]]; then
                    ErrorMessage "--sort requires a value."
                    return 1
                fi
                local sort_method="$1"
                if [[ "$sort_method" != "size" && "$sort_method" != "name" && "$sort_method" != "modified" ]]; then
                    ErrorMessage "Invalid sort method: $sort_method. Must be 'size', 'name', or 'modified'."
                    return 1
                fi
                options_ref["sort"]="$sort_method"
                shift
                ;;
            --exclude=*)
                options_ref["exclude"]="${key#*=}"
                shift
                ;;
            --exclude)
                shift
                if [[ -z "${1:-}" || "$1" == -* ]]; then
                    ErrorMessage "--exclude requires a pattern."
                    return 1
                fi
                options_ref["exclude"]="$1"
                shift
                ;;
            -v | --verbose)
                options_ref["verbose_mode"]=true
                shift
                ;;
            --)
                shift
                break
                ;;
            -*)
                ErrorMessage "Unknown option: $key"
                return 1
                ;;
            *)
                # Collect directory arguments
                if [[ -d "$key" || "$key" == "~" || "$key" == "~/"* ]]; then
                    # Expand ~/ if present
                    if [[ "$key" == "~" || "$key" == "~/"* ]]; then
                        key="${key/#\~/$HOME}"
                    fi
                    # Add to directories array
                    options_ref["directories"]+=" $key"
                else
                    ErrorMessage "Directory not found: $key"
                    return 1
                fi
                shift
                ;;
        esac
    done

    # Add remaining arguments as directories
    while [[ $# -gt 0 ]]; do
        local dir="$1"
        # Expand ~/ if present
        if [[ "$dir" == "~" || "$dir" == "~/"* ]]; then
            dir="${dir/#\~/$HOME}"
        fi
        if [[ -d "$dir" ]]; then
            options_ref["directories"]+=" $dir"
        else
            ErrorMessage "Directory not found: $dir"
            return 1
        fi
        shift
    done

    # Set current directory as default if no directories specified
    if [[ -z "${options_ref["directories"]}" ]]; then
        options_ref["directories"]="$(pwd)"
    fi

    # Validate size format
    local size_bytes
    size_bytes=$(ExtractSizeInBytes "${options_ref["size"]}")
    if [[ $? -ne 0 || $size_bytes -lt 0 ]]; then
        return 1 # Error message already printed
    fi

    # Validate count is a number
    if ! [[ "${options_ref["count"]}" =~ ^[0-9]+$ ]]; then
        ErrorMessage "Count must be a positive number: ${options_ref["count"]}"
        return 1
    fi

    return 0
}

# ============================================================================
# Function: FindLargeFiles
# Description: Find large files in specified directories
# Usage: FindLargeFiles directories size_bytes count sort_method exclude_pattern summary_only
# Returns: 0 on success, non-zero on failure
# ============================================================================
FindLargeFiles() {
    local dirs="$1"
    local min_size_bytes="$2"
    local count="$3"
    local sort_method="$4"
    local exclude_pattern="${5:-}"
    local summary_only="${6:-false}"
    local is_verbose="${7:-false}"

    local find_cmd="find"
    local find_args=()
    local total_size=0
    local file_count=0
    local results=()
    local max_filename_length=0

    # Add directories to find command
    for dir in $dirs; do
        find_args+=("$dir")
    done

    # Add standard find options
    find_args+=("-type" "f" "-size" "+${min_size_bytes}c")

    # Add exclude pattern if specified
    if [[ -n "$exclude_pattern" ]]; then
        find_args+=("!" "-path" "$exclude_pattern")
    fi

    # Execute find command to get matching files
    VerboseMessage "$is_verbose" "Executing find command: find ${find_args[*]}"

    # Use null terminator to handle filenames with spaces and special characters
    while IFS= read -r -d '\0' file; do
        local file_size
        file_size=$(stat -c "%s" "$file" 2>/dev/null || stat -f "%z" "$file" 2>/dev/null)

        if [[ -n "$file_size" ]]; then
            # Track total size and count
            total_size=$((total_size + file_size))
            ((file_count++))

            # Only collect details if we're not in summary-only mode
            if [[ "$summary_only" == "false" ]]; then
                # Get file modified time (in seconds since epoch)
                local modified
                modified=$(stat -c "%Y" "$file" 2>/dev/null || stat -f "%m" "$file" 2>/dev/null)

                # Store result with size and modified time for sorting
                results+=("$file_size|$modified|$file")

                # Track longest filename for formatting
                local filename_length=${#file}
                if [[ $filename_length -gt $max_filename_length ]]; then
                    max_filename_length=$filename_length
                fi
            fi
        fi
    done < <(find "${find_args[@]}" -print0 2>/dev/null)

    # Display summary
    SectionHeader "Large File Search Results"

    InfoMessage "Search criteria:"
    echo "  Minimum size: $(FormatSizeHuman "$min_size_bytes")"
    echo "  Directories: $dirs"
    [[ -n "$exclude_pattern" ]] && echo "  Excluding: $exclude_pattern"
    echo ""

    InfoMessage "Summary statistics:"
    echo "  Files found: $file_count"
    echo "  Total size: $(FormatSizeHuman "$total_size")"
    echo ""

    # Return if summary-only mode or no files found
    if [[ "$summary_only" == "true" || $file_count -eq 0 ]]; then
        [[ $file_count -eq 0 ]] && InfoMessage "No files matching criteria were found."
        return 0
    fi

    # Sort results based on sort method
    case "$sort_method" in
        size)
            # Sort by size (descending, numeric)
            IFS='\n' sorted_results=($(sort -t'|' -k1,1nr <<<"${results[*]}"))
            ;;
        name)
            # Sort by filename (ascending, alphabetical)
            IFS='\n' sorted_results=($(sort -t'|' -k3,3 <<<"${results[*]}"))
            ;;
        modified)
            # Sort by modification time (newest first)
            IFS='\n' sorted_results=($(sort -t'|' -k2,2nr <<<"${results[*]}"))
            ;;
        *)
            ErrorMessage "Internal error: Invalid sort method '$sort_method'"
            return 1
            ;;
    esac

    # Format and display results
    InfoMessage "Top ${count} files by ${sort_method}:"
    echo ""

    # Print header
    printf "%-15s %-20s %s\n" "SIZE" "MODIFIED" "FILENAME"
    printf "%s\n" "$(printf '=%.0s' {1..80})"

    # Display results (limited by count)
    local displayed=0
    for result in "${sorted_results[@]}"; do
        # Limit displayed results
        if [[ $displayed -ge $count ]]; then
            break
        fi

        # Parse fields
        IFS='|' read -r file_size modified file <<<"$result"

        # Format size and modification time
        local size_human
        size_human=$(FormatSizeHuman "$file_size")
        local mod_date
        mod_date=$(date -d @"$modified" "+%Y-%m-%d %H:%M:%S" 2>/dev/null ||
            date -r "$modified" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)

        # Print formatted result
        printf "%-15s %-20s %s\n" "$size_human" "$mod_date" "$file"

        ((displayed++))
    done

    echo ""
    InfoMessage "To display more results, use --count=[number]"
    return 0
}

# ============================================================================
# Function: main
# Description: Main execution logic.
# Usage: main "$@"
# Returns: 0 on success, 1 on failure.
# ============================================================================
main() {
    # Use associative array for options (requires Bash 4+)
    declare -A options
    # Parse arguments, exit if parser returns non-zero (error)
    ParseArguments options "$@" || exit $?

    # Access options from the array
    local size_str="${options[size]}"
    local count="${options[count]}"
    local sort_method="${options[sort]}"
    local exclude_pattern="${options[exclude]}"
    local summary_only="${options[summary_only]}"
    local is_verbose="${options[verbose_mode]}"
    local directories="${options[directories]}"

    # Convert size to bytes
    local size_bytes
    size_bytes=$(ExtractSizeInBytes "$size_str")
    if [[ $? -ne 0 || $size_bytes -lt 0 ]]; then
        exit 1 # Error message already printed by ExtractSizeInBytes
    fi

    # Run the find operation
    FindLargeFiles "$directories" "$size_bytes" "$count" "$sort_method" "$exclude_pattern" "$summary_only" "$is_verbose"
    return $?
}

# ============================================================================
# Script Execution
# ============================================================================
# Execute main function if run directly or via rc command wrapper
# Use sourced IsExecutedDirectly function
if IsExecutedDirectly || [[ "$0" == *"rc"* ]]; then
    main "$@"
    exit $? # Exit with status from main
fi

# EOF
