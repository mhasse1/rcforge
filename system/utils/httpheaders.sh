#!/usr/bin/env bash
# httpheaders.sh - HTTP Headers Utility
# Author: rcForge Team
# Date: 2025-04-05
# Version: 0.3.0
# RC Summary: Retrieves and displays HTTP headers for the specified URL
# Description: Utility to fetch and display HTTP headers from any URL with formatting options

# Source required libraries
if [[ -f "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/shell-colors.sh" ]]; then
  source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/shell-colors.sh"
else
  # Minimal color definitions if shell-colors.sh is not available
  export RED='\033[0;31m'
  export GREEN='\033[0;32m'
  export YELLOW='\033[0;33m'
  export BLUE='\033[0;34m'
  export CYAN='\033[0;36m'
  export RESET='\033[0m'
  
  # Minimal message functions
  ErrorMessage() { echo -e "${RED}ERROR:${RESET} $1" >&2; }
  WarningMessage() { echo -e "${YELLOW}WARNING:${RESET} $1" >&2; }
  InfoMessage() { echo -e "${BLUE}INFO:${RESET} $1"; }
  SuccessMessage() { echo -e "${GREEN}SUCCESS:${RESET} $1"; }
fi

# Set strict error handling
set -o nounset  # Treat unset variables as errors
set -o errexit  # Exit immediately if a command exits with a non-zero status

# ============================================================================
# CONFIGURATION
# ============================================================================

# Default options
declare FOLLOW_REDIRECTS=false
declare OUTPUT_FORMAT="text"
declare VERBOSE_MODE=true
declare TIMEOUT=10
declare SAVE_RESPONSE=false
declare OUTPUT_FILE=""

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Function: ShowSummary
# Description: Display one-line summary for rc help
# Usage: ShowSummary
ShowSummary() {
  echo "Retrieves and displays HTTP headers for the specified URL"
}

# Function: ShowHelp
# Description: Display help information
# Usage: ShowHelp
ShowHelp() {
  cat << EOF
HTTP Headers Utility

Description:
  Retrieves and displays HTTP headers from a URL with formatting options.

Usage:
  rc httpheaders [options] <url>

Options:
  -v, --verbose         Show detailed request/response information
  -j, --json            Output in JSON format
  -f, --follow          Follow redirects
  -s, --save <file>     Save response headers to file
  -t, --timeout <secs>  Set request timeout (default: 10s)
  -h, --help            Show this help message
  --summary             Show one-line description

Examples:
  rc httpheaders example.com
  rc httpheaders -v https://github.com
  rc httpheaders -j -f https://redirecting-site.com
  rc httpheaders -s headers.txt https://api.example.com
EOF
}

# Function: FormatHeader
# Description: Format a header line for display
# Usage: FormatHeader "Header: Value"
FormatHeader() {
  local line="$1"
  local name="${line%%:*}"
  local value="${line#*: }"
  
  if [[ -z "$name" || "$name" == "$value" ]]; then
    echo "$line"
    return
  fi
  
  printf "${CYAN}%s${RESET}: %s\n" "$name" "$value"
}

# Function: OutputJSON
# Description: Convert headers to JSON format
# Usage: OutputJSON headers_array
OutputJSON() {
  local -a headers=("$@")
  local json="{\n"
  
  for header in "${headers[@]}"; do
    if [[ "$header" == *":"* ]]; then
      local name="${header%%:*}"
      local value="${header#*: }"
      
      # Skip empty lines
      if [[ -n "$name" && "$name" != "$value" ]]; then
        # Escape quotes in the value
        value="${value//\"/\\\"}"
        json+="  \"$name\": \"$value\",\n"
      fi
    fi
  done
  
  # Remove trailing comma and add closing brace
  json="${json%,\\n}"
  json+="\n}"
  
  # Output formatted JSON
  echo -e "$json"
}

# ============================================================================
# MAIN FUNCTIONALITY
# ============================================================================

# Main function
main() {
  # Check dependencies
  if ! command -v curl &>/dev/null; then
    ErrorMessage "This tool requires curl, but it's not installed."
    echo "Please install curl and try again."
    return 1
  }
  
  # Reset option variables
  local URL=""
  
  # Parse command-line arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        ShowHelp
        return 0
        ;;
      --summary)
        ShowSummary
        return 0
        ;;
      --verbose|-v)
        VERBOSE_MODE=true
        ;;
      --json|-j)
        OUTPUT_FORMAT="json"
        ;;
      --follow|-f)
        FOLLOW_REDIRECTS=true
        ;;
      --save|-s)
        SAVE_RESPONSE=true
        shift
        OUTPUT_FILE="$1"
        ;;
      --timeout|-t)
        shift
        TIMEOUT="$1"
        ;;
      -*)
        ErrorMessage "Unknown option: $1"
        echo "Use --help to see available options."
        return 1
        ;;
      *)
        # If no URL has been set, use this argument as the URL
        if [[ -z "$URL" ]]; then
          URL="$1"
        else
          ErrorMessage "Too many URL arguments provided"
          echo "Use --help to see available options."
          return 1
        fi
        ;;
    esac
    shift
  done
  
  # Validate URL
  if [[ -z "$URL" ]]; then
    ErrorMessage "No URL provided"
    echo "Usage: rc httpheaders [options] <url>"
    return 1
  fi
  
  # Add http:// prefix if missing
  if [[ ! "$URL" =~ ^https?:// ]]; then
    URL="http://$URL"
    if [[ "$VERBOSE_MODE" == "true" ]]; then
      InfoMessage "Added HTTP prefix: $URL"
    fi
  fi
  
  # Build curl command
  local curl_cmd="curl -s -I"
  
  # Add options
  if [[ "$FOLLOW_REDIRECTS" == "true" ]]; then
    curl_cmd+=" -L"
  fi
  
  curl_cmd+=" -m $TIMEOUT"
  
  if [[ "$VERBOSE_MODE" == "true" ]]; then
    InfoMessage "Fetching headers from: $URL"
    InfoMessage "Command: $curl_cmd $URL"
  fi
  
  # Fetch headers
  local response
  response=$($curl_cmd "$URL")
  local status=$?
  
  # Check for errors
  if [[ $status -ne 0 ]]; then
    case $status in
      6)
        ErrorMessage "Could not resolve host: $URL"
        ;;
      7)
        ErrorMessage "Failed to connect to host: $URL"
        ;;
      28)
        ErrorMessage "Operation timed out after $TIMEOUT seconds"
        ;;
      *)
        ErrorMessage "curl failed with exit code $status"
        ;;
    esac
    return 1
  fi
  
  # Process response
  local -a headers
  mapfile -t headers <<< "$response"
  
  # Check if we got any headers
  if [[ ${#headers[@]} -eq 0 ]]; then
    ErrorMessage "No headers received from $URL"
    return 1
  fi
  
  # Output based on format
  if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    OutputJSON "${headers[@]}"
  else
    # Extract status line
    local status_line="${headers[0]}"
    echo -e "${GREEN}$status_line${RESET}"
    echo ""
    
    # Output remaining headers
    for i in $(seq 1 $((${#headers[@]} - 1))); do
      local line="${headers[$i]}"
      if [[ -n "$line" ]]; then
        FormatHeader "$line"
      fi
    done
  fi
  
  # Save to file if requested
  if [[ "$SAVE_RESPONSE" == "true" && -n "$OUTPUT_FILE" ]]; then
    echo "$response" > "$OUTPUT_FILE"
    if [[ $? -eq 0 ]]; then
      SuccessMessage "Headers saved to: $OUTPUT_FILE"
    else
      ErrorMessage "Failed to save headers to: $OUTPUT_FILE"
    fi
  fi
  
  # Success
  return 0
}

# Execute main function if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
  exit $?
fi

# Also execute if called via the rc command
if [[ "${BASH_SOURCE[0]}" != "${0}" && "$0" == *"rc"* ]]; then
  main "$@"
  exit $?
fi

# EOF