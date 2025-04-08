#!/usr/bin/env bash
# httpheaders.sh - HTTP Headers Utility
# Author: rcForge Team
# Date: 2025-04-08
# Version: 0.4.1
# Category: system/utility
# RC Summary: Retrieves and displays HTTP headers for the specified URL
# Description: Utility to fetch and display HTTP headers from any URL with formatting options

# Source necessary libraries (utility-functions sources shell-colors)
# Default path used in case RCFORGE_LIB is not set (e.g., direct execution)
source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/utility-functions.sh"

# Set strict error handling
set -o nounset
set -o pipefail
# errexit is disabled as functions handle their own errors

# ============================================================================
# GLOBAL CONSTANTS (Not Exported)
# ============================================================================
# Use constants sourced from utility-functions.sh if available, else provide fallback
[ -v gc_version ]  || readonly gc_version="${RCFORGE_VERSION:-0.4.1}"
[ -v gc_app_name ] || readonly gc_app_name="${RCFORGE_APP_NAME:-rcForge}"

# ============================================================================
# LOCAL HELPER FUNCTIONS
# ============================================================================

# ============================================================================
# Function: ShowHelp
# Description: Display detailed help information for this utility.
# Usage: ShowHelp
# Returns: None. Prints help text to stdout.
# Exits: 0
# ============================================================================
ShowHelp() {
    local script_name
    script_name=$(basename "$0")
    # Use internal helper _rcforge_show_help if available, otherwise basic echo
    if command -v _rcforge_show_help &>/dev/null; then
        _rcforge_show_help <<EOF
  Retrieves and displays HTTP headers from a URL with formatting options.

Usage:
  rc httpheaders [options] <url>
  ${script_name} [options] <url>

Options:
  -v, --verbose       Show detailed request/response information (default: false)
  -j, --json          Output in JSON format (default: text)
  -f, --follow        Follow redirects (default: true)
  -s, --save <file>   Save raw response headers to specified file
  -t, --timeout <secs> Set request timeout in seconds (default: 10)

Examples:
  rc httpheaders example.com
  rc httpheaders -v https://github.com
  rc httpheaders -j -f https://redirecting-site.com
  rc httpheaders -s headers.txt https://api.example.com
EOF
    else
        # Fallback basic help if helper function unavailable
        echo "${script_name} - HTTP Headers Utility (v${gc_version})"
        echo ""
        echo "Description:"
        echo "  Retrieves and displays HTTP headers from a URL with formatting options."
        echo ""
        echo "Usage:"
        echo "  rc httpheaders [options] <url>"
        echo "  ${script_name} [options] <url>"
        echo ""
        echo "Options:"
        echo "  -v, --verbose       Show detailed request/response information (default: false)"
        echo "  -j, --json          Output in JSON format (default: text)"
        echo "  -f, --follow        Follow redirects (default: true)"
        echo "  -s, --save <file>   Save raw response headers to specified file"
        echo "  -t, --timeout <secs> Set request timeout in seconds (default: 10)"
        echo "  -h, --help          Show this help message"
        echo "  --summary           Show a one-line description (for rc help)"
        echo "  --version           Show version information"
        echo ""
        echo "Examples:"
        echo "  rc httpheaders example.com"
        echo "  rc httpheaders -v https://github.com"
        echo "  rc httpheaders -j -f https://redirecting-site.com"
        echo "  rc httpheaders -s headers.txt https://api.example.com"
    fi
    exit 0
}

# ============================================================================
# Function: FormatHeader
# Description: Format a single "Header: Value" line for text display with colors.
# Usage: FormatHeader "Header: Value"
# Arguments:
#   $1 (required) - The header line string.
# Returns: Echoes the formatted header line.
# ============================================================================
FormatHeader() {
    local line="${1:-}"
    # Validate line format
    if [[ ! "$line" == *": "* ]]; then
        # If not a standard header, print as is (e.g., HTTP status line)
        echo "$line"
        return 0
    fi

    local name="${line%%:*}"       # Extract name (part before first :)
    local value="${line#*: }"      # Extract value (part after first : and space)

    # Check if extraction was successful (basic check)
    if [[ -z "$name" || -z "$value" ]]; then
        echo "$line" # Print original if parsing failed
        return 0
    fi

    # Use color variables sourced from shell-colors.sh (via utility-functions.sh)
    # Provide default empty values in case colors are disabled or library failed
    printf "%b%s%b: %s\n" "${CYAN:-}" "$name" "${RESET:-}" "$value"
}

# ============================================================================
# Function: OutputJson
# Description: Convert an array of raw header lines into JSON format.
# Usage: OutputJson "${header_array[@]}"
# Arguments:
#   $@ (required) - Array containing raw header lines.
# Returns: Echoes the JSON formatted string.
# ============================================================================
OutputJson() {
    local -a headers=("$@")
    local json="{\n"
    local header=""
    local name=""
    local value=""
    local first_entry=true

    for header in "${headers[@]}"; do
        # Skip empty lines or lines not containing ': ' (like status lines)
        if [[ -z "$header" || ! "$header" == *": "* ]]; then
            continue
        fi

        # Extract name and value, trim whitespace
        name="${header%%:*}"; name="${name%"${name##*[![:space:]]}"}"; name="${name#"${name%%[![:space:]]*}"}"
        value="${header#*: }"; value="${value%"${value##*[![:space:]]}"}"; value="${value#"${value%%[![:space:]]*}"}"

        # Basic JSON escaping for value (backslash and double quote)
        value="${value//\\/\\\\}"; value="${value//\"/\\\"}"

        # Add comma before entry if not the first one
        if [[ "$first_entry" == "false" ]]; then
            json+=",\n"
        fi

        # Add "key": "value" entry
        json+="  \"$name\": \"$value\""
        first_entry=false
    done

    json+="\n}"
    printf '%s\n' "$json" # Use %s to print exactly, avoids interpreting backslashes
}

# ============================================================================
# Function: ParseArguments
# Description: Parse command-line arguments using a standard loop.
# Usage: declare -A options; ParseArguments options "$@"
# Arguments:
#   $1 (required) - Name of the associative array to populate (by nameref).
#   $@ (required) - Script arguments passed from main.
# Returns:
#   Populates the associative array by reference.
#   Returns 0 on success, 1 on error.
#   Exits directly for --help, --summary, --version via helpers.
# ============================================================================
ParseArguments() {
    local -n options_ref="$1" # Use nameref (requires Bash 4.3+)
    shift # Remove array name from args

    # --- Ensure Bash 4.3+ for Namerefs ---
    # (Check can be skipped if installer guarantees Bash 4.3+, but safer to include)
    if [[ "${BASH_VERSINFO[0]}" -lt 4 || ( "${BASH_VERSINFO[0]}" -eq 4 && "${BASH_VERSINFO[1]}" -lt 3 ) ]]; then
        # Use basic echo as ErrorMessage might not be fully reliable here
        echo "ERROR: Internal script error. Requires Bash 4.3+ for argument parsing." >&2
        return 1
    fi
    # --- End Bash Version Check ---

    # --- Set Default Option Values ---
    options_ref["follow_redirects"]=true
    options_ref["output_format"]="text"
    options_ref["is_verbose"]=false
    options_ref["timeout_seconds"]=10
    options_ref["save_response"]=false
    options_ref["output_file"]=""
    options_ref["url"]="" # URL will be captured from positional args

    local -a positional_args=() # Array to capture positional arguments

    # --- Argument Parsing Loop ---
    while [[ $# -gt 0 ]]; do
        local key="$1"
        case "$key" in
            # --- Standard rcForge Options ---
            -h|--help)
                ShowHelp # Exits
                ;;
            --summary)
                # Use helper from utility-functions.sh (if sourced)
                if command -v ExtractSummary &>/dev/null; then
                    ExtractSummary "$0" # $0 should be the script path when called
                    exit $?
                else
                    echo "Retrieves and displays HTTP headers for the specified URL" # Fallback
                    exit 0
                fi
                ;;
            --version)
                # Use helper from utility-functions.sh (if sourced)
                 if command -v _rcforge_show_version &>/dev/null; then
                    _rcforge_show_version "$0"
                else
                    echo "$(basename "$0") v${gc_version:-unknown}" # Fallback
                fi
                exit 0
                ;;

            # --- Script-Specific Options ---
            -v|--verbose)
                options_ref["is_verbose"]=true
                shift # past argument
                ;;
            -j|--json)
                options_ref["output_format"]="json"
                shift # past argument
                ;;
            -f|--follow)
                options_ref["follow_redirects"]=true
                shift # past argument
                ;;
            -s|--save)
                options_ref["save_response"]=true
                shift # past argument '-s'
                # Check if value exists and is not another option
                if [[ -z "${1:-}" || "$1" == -* ]]; then
                    ErrorMessage "Option '-s/--save' requires a filename argument."
                    return 1
                fi
                options_ref["output_file"]="$1"
                shift # past value
                ;;
            -t|--timeout)
                shift # past argument '-t'
                # Check if value exists and is not another option
                if [[ -z "${1:-}" || "$1" == -* ]]; then
                    ErrorMessage "Option '-t/--timeout' requires a seconds value."
                    return 1
                fi
                # Validate value is a positive integer
                if ! [[ "$1" =~ ^[0-9]+$ && "$1" -gt 0 ]]; then
                    ErrorMessage "Timeout must be a positive integer."
                    return 1
                fi
                options_ref["timeout_seconds"]="$1"
                shift # past value
                ;;

            # --- Standard Argument Handling ---
            --) # End of options marker
                shift # Move past '--'
                # All remaining arguments are positional
                positional_args+=("$@")
                break # Stop processing options
                ;;
            -*) # Unknown option
                ErrorMessage "Unknown option: $key"
                ShowHelp # Show help before returning error
                return 1
                ;;
            *) # Positional argument
                positional_args+=("$1")
                shift # Move to next argument
                ;;
        esac
    done
    # --- End Argument Parsing Loop ---

    # --- Positional Argument Validation ---
    if [[ ${#positional_args[@]} -eq 0 ]]; then
        ErrorMessage "No URL provided."
        ShowHelp
        return 1
    elif [[ ${#positional_args[@]} -gt 1 ]]; then
        ErrorMessage "Too many arguments. Expected exactly one URL."
        ShowHelp
        return 1
    else
        # Capture the single positional argument as the URL
        options_ref["url"]="${positional_args[0]}"
    fi

    # --- Further Validation (e.g., output file writability) ---
    if [[ "${options_ref[save_response]}" == "true" ]]; then
        # Ensure output file was actually set (should be by arg parsing)
        if [[ -z "${options_ref[output_file]}" ]]; then
            ErrorMessage "Internal Error: --save specified but no output file captured."
            return 1
        fi
        local output_dir
        output_dir=$(dirname "${options_ref[output_file]}")
        # Check if directory exists, create if not (using standard mkdir -p)
        if ! mkdir -p "$output_dir"; then
             ErrorMessage "Cannot create output directory: $output_dir"
             return 1
        fi
        # Check if directory is writable
        if [[ ! -w "$output_dir" ]]; then
            ErrorMessage "Output directory not writable: $output_dir"
            return 1
        fi
    fi
    # --- End Further Validation ---

    return 0 # Success
}


# ============================================================================
# Function: main
# Description: Main execution logic. Parses args, fetches, formats, and outputs headers.
# Usage: main "$@"
# Arguments:
#   $@ - Script arguments passed from execution block.
# Returns: 0 on success, 1 on failure.
# ============================================================================
main() {
    # Use associative array for options (requires Bash 4+)
    declare -A options
    # Parse arguments, exit if parsing fails or handled by helpers (help/version/summary)
    ParseArguments options "$@" || exit $?

    # Check for curl dependency using sourced function
    if ! CommandExists curl; then
        ErrorMessage "'curl' command is required but not found. Please install curl."
        return 1 # Return error status
    fi

    # Extract options from the array using parameter expansion with defaults
    local url="${options[url]:-}" # Should always be set by ParseArguments
    local is_verbose="${options[is_verbose]:-false}"
    local output_format="${options[output_format]:-text}"
    local follow_redirects="${options[follow_redirects]:-true}"
    local timeout_seconds="${options[timeout_seconds]:-10}"
    local save_response="${options[save_response]:-false}"
    local output_file="${options[output_file]:-}" # Will be empty if --save not used

    local curl_exit_status=0
    local raw_response=""
    local -a header_lines=()      # Array to hold lines from raw response
    local -a filtered_headers=()  # Array to hold final headers for output
    local line=""                 # Loop variable

    # --- URL Scheme Handling ---
    # Prepend http:// if no scheme is present
    # Use [[ ]] for pattern matching
    if [[ ! "$url" =~ ^https?:// ]]; then
        url="http://$url"
        # Use sourced InfoMessage if available
        InfoMessage "Assuming http scheme: $url" # No verbose check needed, this is helpful info
    fi
    # --- End URL Scheme Handling ---

    # --- Build curl Options ---
    local -a curl_opts=()
    curl_opts+=("-sS") # Silent mode with error reporting
    if [[ "$follow_redirects" == "true" ]]; then
        curl_opts+=("-L") # Follow redirects
    fi
    curl_opts+=("-I") # Fetch Headers only (HEAD request)
    curl_opts+=("-m" "$timeout_seconds") # Set timeout
    # Add verbose flag AFTER other options
    if [[ "$is_verbose" == "true" ]]; then
        curl_opts+=("-v") # Verbose output (includes request/response details)
        InfoMessage "Fetching headers from: $url"
        InfoMessage "  Timeout: ${timeout_seconds}s, Follow Redirects: ${follow_redirects}, Format: ${output_format}"
    fi
    # --- End Build curl Options ---

    # --- Execute curl ---
    # Capture stdout (headers) and stderr (verbose info/errors) separately if verbose
    # Need to handle potential command failure ($?)
    if [[ "$is_verbose" == "true" ]]; then
        # When verbose, curl outputs everything to stderr. We capture it.
        # The -I option usually doesn't produce stdout content, but redirect anyway.
        raw_response=$(curl "${curl_opts[@]}" "$url" 2>&1) || curl_exit_status=$?
    else
        # Not verbose, capture only headers (stdout) and ignore stderr
        raw_response=$(curl "${curl_opts[@]}" "$url" 2>/dev/null) || curl_exit_status=$?
    fi
    # --- End Execute curl ---

    # --- Check curl Exit Status ---
    if [[ $curl_exit_status -ne 0 ]]; then
        ErrorMessage "curl command failed with exit code $curl_exit_status for $url"
        # Show stderr output if verbose, as it contains error details
        if [[ "$is_verbose" == "true" && -n "$raw_response" ]]; then
            WarningMessage "Curl output (stderr):"; printf '%s\n' "$raw_response" >&2
        fi
        return 1
    fi
    # --- End Check curl Exit Status ---

    # --- Process Response ---
    # Read raw response line by line into header_lines array
    # tr -d '\r' handles potential Windows line endings
    mapfile -t header_lines < <(printf '%s' "$raw_response" | tr -d '\r')

    # Check if we actually got any lines
    if [[ ${#header_lines[@]} -eq 0 ]] ; then
        ErrorMessage "No response received from $url (Curl exit status was 0)."
        return 1
    fi

    # Filter lines if verbose (remove curl's internal markers like *, >, <)
    # Otherwise, use all lines received
    if [[ "$is_verbose" == "true" ]]; then
        for line in "${header_lines[@]}"; do
            # Keep HTTP status lines and actual header lines (Key: Value)
            # Exclude lines starting with curl's verbose markers (*, >, <)
            # Use [[ ]] and extended regex for safer matching
            if [[ "$line" == HTTP/* || ( "$line" == *": "* && ! "$line" =~ ^[[:space:]]*[<>*] ) ]]; then
                filtered_headers+=("$line")
            fi
        done
    else
        # Not verbose, assume all lines are headers or status lines
        filtered_headers=("${header_lines[@]}")
    fi

    # Check if filtering resulted in any headers
    if [[ ${#filtered_headers[@]} -eq 0 ]] ; then
        ErrorMessage "No valid HTTP headers found in the response from $url."
        # Show raw lines if verbose, helps debugging
        if [[ "$is_verbose" == "true" ]]; then
            WarningMessage "Raw response lines were:"; printf '  %s\n' "${header_lines[@]}" >&2
        fi
        return 1
    fi
    # --- End Process Response ---

    # --- Output Handling ---
    # Save raw response if requested
    if [[ "$save_response" == "true" && -n "$output_file" ]]; then
        InfoMessage "Saving raw headers to: ${output_file}"
        # Use printf '%s\n' to write the original multi-line raw response
        if printf '%s\n' "$raw_response" > "$output_file"; then
            # Set permissions (read-only for user)
            if ! chmod 600 "$output_file"; then
                WarningMessage "Could not set permissions (600) on saved file: $output_file"
            fi
            SuccessMessage "Raw headers saved successfully."
        else
            ErrorMessage "Failed to save headers to: ${output_file}"
            # Don't necessarily exit the whole script if saving fails, just report error
            # return 1 # Optional: make save failure critical
        fi
    fi

    # Print formatted output to standard output
    if [[ "$output_format" == "json" ]]; then
        # Pass filtered headers array to JSON formatter
        OutputJson "${filtered_headers[@]}"
    else # Default 'text' format
        local is_first_header_block=true
        # Handle potential multiple header blocks from redirects if verbose
        for line in "${filtered_headers[@]}"; do
            # Check for HTTP status line to add spacing between blocks
            if [[ "$line" == HTTP/* ]]; then
                # Add newline before subsequent status lines
                if [[ "$is_first_header_block" == "false" ]]; then
                    echo ""
                fi
                # Print status line highlighted (using FormatHeader handles colors)
                FormatHeader "$line" # Pass status line to formatter
                is_first_header_block=false
            elif [[ -n "$line" ]]; then # Check if line is not empty
                # Print regular header lines formatted
                FormatHeader "$line"
            fi
        done
    fi
    # --- End Output Handling ---

    return 0 # Indicate overall success
}

# ============================================================================
# Script Execution Block
# ============================================================================
# Standard execution check: run main only if script is executed directly
# or via the 'rc' command wrapper (identified by $0 containing 'rc').
# Use sourced function IsExecutedDirectly if available.
if command -v IsExecutedDirectly &>/dev/null; then
    if IsExecutedDirectly || [[ "$0" == *"rc"* ]]; then
        main "$@"
        exit $? # Exit with the status code from main
    fi
else
    # Fallback check if utility library wasn't sourced correctly
     if [[ "${BASH_SOURCE[0]}" == "${0}" ]] || [[ "$0" == *"rc"* ]]; then
        main "$@"
        exit $?
    fi
fi

# EOF