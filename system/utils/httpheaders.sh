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
    exit 0
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

    exit 0
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
# Function: ParseArguments
# Description: Parse command-line arguments for httpheaders script.
# Usage: declare -A options; ParseArguments options "$@"
# Returns: Populates associative array. Returns 0 on success, 1 on error or help/summary.
# ============================================================================
ParseArguments() {
    local -n options_ref="$1" # Use nameref (Bash 4.3+)
    shift # Remove array name from args

    # Default values
    options_ref["follow_redirects"]=false
    options_ref["output_format"]="text"
    options_ref["is_verbose"]=true # Default verbose is true
    options_ref["timeout_seconds"]=10
    options_ref["save_response"]=false
    options_ref["output_file"]=""
    options_ref["url"]=""
    #options_ref["args"]=() # For positional args

    # --- Pre-parse checks for summary/help ---
    # Check BEFORE the loop if only summary/help is requested
     if [[ "$#" -eq 1 ]]; then
         case "$1" in
             --help|-h) ShowHelp; return 1 ;;
             --summary) ShowSummary; return 0 ;;
         esac
     # Also handle case where summary/help might be first but other args exist
     elif [[ "$#" -gt 0 ]]; then
          case "$1" in
             --help|-h) ShowHelp; return 1 ;;
             --summary) ShowSummary; return 0 ;;
         esac
     fi
    # --- End pre-parse ---


    while [[ $# -gt 0 ]]; do
        case "$1" in
            # Help/Summary handled above, but keep for safety if called mid-args
            --help|-h) ShowHelp; return 1 ;;
            --summary) ShowSummary; return 0 ;;
            --verbose|-v) options_ref["is_verbose"]=true; shift ;;
            --json|-j) options_ref["output_format"]="json"; shift ;;
            --follow|-f) options_ref["follow_redirects"]=true; shift ;;
            --save|-s)
                options_ref["save_response"]=true
                shift # Consume '-s'
                # Ensure value exists and is not another option
                if [[ -z "${1:-}" || "$1" == -* ]]; then ErrorMessage "Option '-s/--save' requires a filename argument."; return 1; fi
                options_ref["output_file"]="$1"
                shift # Consume filename
                ;;
            --timeout|-t)
                shift # Consume '-t'
                # Ensure value exists and is not another option
                if [[ -z "${1:-}" || "$1" == -* ]]; then ErrorMessage "Option '-t/--timeout' requires a seconds argument."; return 1; fi
                if ! [[ "$1" =~ ^[0-9]+$ ]]; then ErrorMessage "Timeout value must be a positive integer."; return 1; fi
                options_ref["timeout_seconds"]="$1"
                shift # Consume seconds
                ;;
            -*) # Handle unknown options
                ErrorMessage "Unknown option: $1"
                ShowHelp
                return 1
                ;;
            *) # Positional argument (assume URL)
                 if [[ -z "${options_ref[url]}" ]]; then
                     options_ref["url"]="$1"
                 else
                     # If URL already set, treat as extra args or error
                     # options_ref["args"]+=("$1") # If you want to capture extra args
                     ErrorMessage "Unexpected positional argument: '$1'. Only one URL is expected."
                     ShowHelp
                     return 1
                 fi
                 shift # Consume positional arg
                ;;
        esac
    done

    # --- Post-parsing validation ---
    if [[ -z "${options_ref[url]}" ]]; then
        ErrorMessage "No URL provided." [cite: 933]
        ShowHelp
        return 1
    fi

    return 0 # Success
}


# ============================================================================
# Function: main
# Description: Main execution logic. Parses args, fetches, formats, and outputs headers.
# Usage: main "$@"
# Returns: 0 on success, 1 on failure.
# ============================================================================
main() {
    declare -A options # Declare associative array for options [cite: 1010]
    # Call ParseArguments, exit if it returns non-zero (e.g., help shown, error)
    ParseArguments options "$@" || exit $?

    # Check dependencies
    if ! command -v curl &>/dev/null; then
        ErrorMessage "This tool requires 'curl', but it's not installed." [cite: 916]
        InfoMessage "Please install curl using your system's package manager." [cite: 917]
        return 1
    fi

    # Use options from the array
    local url="${options[url]}"
    local curl_exit_status=0
    local raw_response=""

    # Prepend http:// if no scheme provided
    if [[ ! "$url" =~ ^https?:// ]]; then
        url="http://$url"
        if [[ "${options[is_verbose]}" == "true" ]]; then
            InfoMessage "Assuming http scheme: $url"
        fi
    fi

    # Build curl command options into an array for safety
    local -a curl_opts=("-s" "-I") # Silent, Headers only

    if [[ "${options[follow_redirects]}" == "true" ]]; then
        curl_opts+=("-L") # [cite: 937]
    fi

    curl_opts+=("-m" "${options[timeout_seconds]}")

    if [[ "${options[is_verbose]}" == "true" ]]; then
        InfoMessage "Fetching headers from: $url" [cite: 938]
        InfoMessage "Timeout: ${options[timeout_seconds]}s, Follow Redirects: ${options[follow_redirects]}" # [cite: 938]
    fi

    # Fetch headers
    raw_response=$(curl "${curl_opts[@]}" "$url") || curl_exit_status=$? # [cite: 939]


    # Check curl exit status (error handling remains the same)
    if [[ $curl_exit_status -ne 0 ]]; then
        case $curl_exit_status in
            6) ErrorMessage "Could not resolve host: $url";; # [cite: 940]
            7) ErrorMessage "Failed to connect to host: $url";; # [cite: 941]
            28) ErrorMessage "Operation timed out after ${options[timeout_seconds]} seconds for $url";; # [cite: 941]
            *) ErrorMessage "curl command failed with exit code $curl_exit_status for $url";; # [cite: 942]
        esac
        return 1
    fi

    # Process the raw response into an array of lines
    local -a header_lines
    mapfile -t header_lines <<< "$raw_response"

    # Handle potential empty response (logic remains the same)
    if [[ ${#header_lines[@]} -eq 0 || -z "${header_lines[0]}" ]] ; then # [cite: 944, 947]
         ErrorMessage "No headers received from $url" # [cite: 947]
         # Or WarningMessage + return 0 if redirects are expected to maybe be empty
         # WarningMessage "Received empty response..."
         return 1 # Treat no headers as failure
    fi


    # Output based on requested format
    if [[ "${options[output_format]}" == "json" ]]; then # [cite: 948]
        # Pass header lines as arguments to OutputJson
        OutputJson "${header_lines[@]}"
    else # Default to text format
        # Print status line distinctly (first line)
        local status_line="${header_lines[0]}"
        printf "%b%s%b\n\n" "$GREEN" "$status_line" "$RESET" # [cite: 949]

        # Print remaining headers using FormatHeader
        local i=0
        local line=""
        for (( i=1; i<${#header_lines[@]}; i++ )); do # [cite: 949]
            line="${header_lines[$i]}"
            # Skip empty lines that might separate header blocks after redirects
            if [[ -n "$line" && "$line" != $'\r' ]]; then # Check for empty or carriage return only lines [cite: 950]
                 FormatHeader "$line" # Call PascalCase [cite: 951]
            fi
        done
    fi

    # Save raw response to file if requested
    if [[ "${options[save_response]}" == "true" && -n "${options[output_file]}" ]]; then # [cite: 951]
        InfoMessage "Saving raw headers to: ${options[output_file]}" # [cite: 952]
        # Use printf for safer writing
        if printf '%s\n' "$raw_response" > "${options[output_file]}"; then # [cite: 952]
            chmod 600 "${options[output_file]}" # Set permissions [cite: 953]
            SuccessMessage "Headers saved successfully." [cite: 953]
        else
            ErrorMessage "Failed to save headers to: ${options[output_file]}" # [cite: 954]
        fi
    fi

    return 0 # Overall success [cite: 955]
}

# Execute main function if run directly or via rc command
if [[ "${BASH_SOURCE[0]}" == "${0}" ]] || [[ "${BASH_SOURCE[0]}" != "${0}" && "$0" == *"rc"* ]]; then
    main "$@"
    exit $? # Exit with the return code of main
fi

# EOF