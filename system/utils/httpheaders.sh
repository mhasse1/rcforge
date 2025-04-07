#!/usr/bin/env bash
# httpheaders.sh - HTTP Headers Utility
# Author: rcForge Team
# Date: 2025-04-06 # Updated Date
# Version: 0.3.0
# Category: system/utility # Set Category
# RC Summary: Retrieves and displays HTTP headers for the specified URL
# Description: Utility to fetch and display HTTP headers from any URL with formatting options

# Source required libraries
# Standard sourcing assuming shell-colors.sh exists in a valid install
source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/shell-colors.sh"

# Set strict error handling
set -o nounset  # Treat unset variables as errors
 # set -o errexit  # Exit immediately if a command exits with a non-zero status

# ============================================================================
# GLOBAL CONSTANTS
# ============================================================================
[ -v gc_version ]  || readonly gc_version="${RCFORGE_VERSION:-ENV_ERROR}"
[ -v gc_app_name ] || readonly gc_app_name="${RCFORGE_APP_NAME:-ENV_ERROR}"

# ============================================================================
# UTILITY FUNCTIONS (PascalCase)
# ============================================================================

# ============================================================================
# Function: ShowSummary
# Description: Display one-line summary for rc help command.
# Usage: ShowSummary (called via --summary)
# Returns: Echoes summary string.
# ============================================================================
ShowSummary() {
    grep '^# RC Summary:' "$0" | sed 's/^# RC Summary: //'
}

# ============================================================================
# Function: ShowHelp
# Description: Display detailed help information for this utility.
# Usage: ShowHelp (called via --help)
# Returns: None. Prints help text to stdout.
# ============================================================================
ShowHelp() {
    # Use cat << EOF for easier multi-line help text formatting
    cat << EOF
httpheaders - HTTP Headers Utility (v${gc_version})

Description:
  Retrieves and displays HTTP headers from a URL with formatting options.

Usage:
  rc httpheaders [options] <url>
  $0 [options] <url>

Options:
  -v, --verbose       Show detailed request/response information (default: true)
  -j, --json          Output in JSON format (default: text)
  -f, --follow        Follow redirects (default: false)
  -s, --save <file>   Save response headers to specified file
  -t, --timeout <secs> Set request timeout in seconds (default: 10)
  -h, --help          Show this help message
  --summary           Show a one-line description (for rc help)

Examples:
  rc httpheaders example.com
  rc httpheaders -v https://github.com
  rc httpheaders -j -f https://redirecting-site.com
  rc httpheaders -s headers.txt https://api.example.com
EOF
}

# ============================================================================
# Function: FormatHeader
# Description: Format a single "Header: Value" line for text display with colors.
# Usage: FormatHeader "Header: Value"
# Arguments:
#   line (required) - The raw header line.
# Returns: Echoes the formatted header line.
# ============================================================================
FormatHeader() {
    local line="$1"
    # Ensure proper handling if ':' is missing or line is empty
    if [[ ! "$line" == *": "* ]]; then
         echo "$line" # Print as is if format is unexpected
         return
    fi
    local name="${line%%:*}"
    local value="${line#*: }" # Correctly capture value after first ': '

    # Handle potential empty name or value after split, though unlikely with HTTP headers
    if [[ -z "$name" || -z "$value" ]]; then
        echo "$line"
        return
    fi

    # Use printf for reliable formatting and color application
    printf "%b%s%b: %s\n" "$CYAN" "$name" "$RESET" "$value"
}

# ============================================================================
# Function: OutputJson
# Description: Convert an array of raw header lines into JSON format.
# Usage: OutputJson headers_array_name # Pass array by name (Bash 4.3+) or elements
# Arguments: Takes header lines as individual arguments "$@"
# Returns: Echoes the JSON formatted string.
# ============================================================================
OutputJson() {
    # Use "$@" to get all header lines passed as arguments
    local -a headers=("$@")
    local json="{\n"
    local header="" # Loop variable
    local name=""
    local value=""
    local first_entry=true

    for header in "${headers[@]}"; do
        # Skip empty lines or lines without a colon separator (like status line)
        if [[ -z "$header" || ! "$header" == *": "* ]]; then
            continue
        fi

        name="${header%%:*}"
        value="${header#*: }"

        # Skip headers with empty names or values if necessary (optional)
        # [[ -z "$name" || -z "$value" ]] && continue

        # Escape backslashes first, then quotes for JSON compatibility
        value="${value//\\/\\\\}"
        value="${value//\"/\\\"}"
        # Trim leading/trailing whitespace from value? Usually not needed for headers.
        # value="$(echo "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

        # Add comma before adding the next entry (if not the first)
        if [[ "$first_entry" == "false" ]]; then
             json+=",\n"
        fi
        json+="  \"$name\": \"$value\""
        first_entry=false

    done

    json+="\n}" # Add closing brace

    # Use printf for safer output than echo -e
    printf '%s\n' "$json"
}

# ============================================================================
# Function: main
# Description: Main execution logic. Parses args, fetches, formats, and outputs headers.
# Usage: main "$@"
# Returns: 0 on success, 1 on failure.
# ============================================================================
main() {
    # Local variables for configuration options with defaults
    local url=""
    local follow_redirects=false
    local output_format="text"
    local is_verbose=true # Defaulting verbose to true as per original script
    local timeout_seconds=10
    local save_response=false
    local output_file=""

    # Check dependencies
    if ! command -v curl &>/dev/null; then
        ErrorMessage "This tool requires 'curl', but it's not installed."
        InfoMessage "Please install curl using your system's package manager."
        return 1
    fi

    # Parse command-line arguments, updating local variables
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h) ShowHelp; return 0 ;;
            --summary) ShowSummary; return 0 ;;
            --verbose|-v) is_verbose=true ;;
            # Add --quiet maybe?
            # --quiet) is_verbose=false ;;
            --json|-j) output_format="json" ;;
            --follow|-f) follow_redirects=true ;;
            --save|-s)
                save_response=true
                shift # Consume '-s'
                if [[ -z "${1:-}" ]]; then ErrorMessage "Option '-s/--save' requires a filename argument."; return 1; fi
                output_file="$1"
                ;;
            --timeout|-t)
                shift # Consume '-t'
                if [[ -z "${1:-}" ]]; then ErrorMessage "Option '-t/--timeout' requires a seconds argument."; return 1; fi
                # Validate timeout is a number
                if ! [[ "$1" =~ ^[0-9]+$ ]]; then ErrorMessage "Timeout value must be a positive integer."; return 1; fi
                timeout_seconds="$1"
                ;;
            -*) # Handle unknown options
                ErrorMessage "Unknown option: $1"
                ShowHelp
                return 1
                ;;
            *) # Handle the URL argument
                if [[ -z "$url" ]]; then
                    url="$1"
                else
                    ErrorMessage "Too many URL arguments provided: '$1'"
                    ShowHelp
                    return 1
                fi
                ;;
        esac
        shift # Move to next argument
    done

    # Validate required URL argument
    if [[ -z "$url" ]]; then
        ErrorMessage "No URL provided."
        ShowHelp
        return 1
    fi

    # Prepend http:// if no scheme provided
    if [[ ! "$url" =~ ^https?:// ]]; then
        url="http://$url"
        if [[ "$is_verbose" == "true" ]]; then
            InfoMessage "Assuming http scheme: $url"
        fi
    fi

    # Build curl command options into an array for safety
    local -a curl_opts=("-s" "-I") # Silent, Headers only

    if [[ "$follow_redirects" == "true" ]]; then
        curl_opts+=("-L")
    fi

    curl_opts+=("-m" "$timeout_seconds")

    if [[ "$is_verbose" == "true" ]]; then
        InfoMessage "Fetching headers from: $url"
        InfoMessage "Timeout: ${timeout_seconds}s, Follow Redirects: ${follow_redirects}"
        # Avoid printing exact command if URL contains sensitive info
        # InfoMessage "Executing: curl ${curl_opts[*]} \"$url\""
    fi

    # Fetch headers using curl, store response and exit status
    local raw_response=""
    local curl_exit_status=0
    # Use process substitution to avoid subshell variable scoping issues with mapfile
    raw_response=$(curl "${curl_opts[@]}" "$url") || curl_exit_status=$?


    # Check curl exit status
    if [[ $curl_exit_status -ne 0 ]]; then
        # Provide more specific error messages based on common curl exit codes
        case $curl_exit_status in
            6) ErrorMessage "Could not resolve host: $url";;
            7) ErrorMessage "Failed to connect to host: $url";;
            28) ErrorMessage "Operation timed out after ${timeout_seconds} seconds for $url";;
            *) ErrorMessage "curl command failed with exit code $curl_exit_status for $url";;
        esac
        return 1
    fi

    # Process the raw response into an array of lines
    local -a header_lines
    mapfile -t header_lines <<< "$raw_response"

    # Handle potential empty response after redirects or for certain servers
    if [[ ${#header_lines[@]} -eq 0 || -z "${header_lines[0]}" ]] && [[ "$follow_redirects" == "true" ]]; then
         WarningMessage "Received empty response, possibly after following redirects. Cannot display headers."
         # Consider this success or failure? Let's treat as partial success.
         return 0 # Or return 1 if empty headers are an error condition
    elif [[ ${#header_lines[@]} -eq 0 || -z "${header_lines[0]}" ]]; then
         ErrorMessage "No headers received from $url"
         return 1
    fi


    # Output based on requested format
    if [[ "$output_format" == "json" ]]; then
        # Pass header lines as arguments to OutputJson
        OutputJson "${header_lines[@]}"
    else # Default to text format
        # Print status line distinctly (first line)
        local status_line="${header_lines[0]}"
        printf "%b%s%b\n\n" "$GREEN" "$status_line" "$RESET" # Use printf for color safety

        # Print remaining headers using FormatHeader
        local i=0
        local line=""
        for (( i=1; i<${#header_lines[@]}; i++ )); do
            line="${header_lines[$i]}"
            # Skip empty lines that might separate header blocks after redirects
            if [[ -n "$line" && "$line" != $'\r' ]]; then # Check for empty or carriage return only lines
                 FormatHeader "$line" # Call PascalCase
            fi
        done
    fi

    # Save raw response to file if requested
    if [[ "$save_response" == "true" && -n "$output_file" ]]; then
        InfoMessage "Saving raw headers to: $output_file"
        # Use printf for safer writing
        if printf '%s\n' "$raw_response" > "$output_file"; then
            chmod 600 "$output_file" # Set permissions
            SuccessMessage "Headers saved successfully."
        else
            ErrorMessage "Failed to save headers to: $output_file"
            # Consider returning error?
        fi
    fi

    return 0 # Overall success
}

# Execute main function if run directly or via rc command
if [[ "${BASH_SOURCE[0]}" == "${0}" ]] || [[ "${BASH_SOURCE[0]}" != "${0}" && "$0" == *"rc"* ]]; then
    main "$@"
    exit $? # Exit with the return code of main
fi

# EOF