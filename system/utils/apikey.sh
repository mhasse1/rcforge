#!/usr/bin/env bash
# apikey.sh - API Key Management Utility
# Author: rcForge Team
# Date: 2025-04-21
# Version: 0.5.0
# Category: system/utility
# RC Summary: Store and manage API keys for external services
# Description: Manages API keys in config file with set, list, remove, and show commands.

# Source required libraries
source "${RCFORGE_LIB:-$HOME/.local/share/rcforge/system/lib}/utility-functions.sh"

# Set strict error handling
set -o nounset
set -o pipefail

# Global constants
[ -v gc_version ] || readonly gc_version="${RCFORGE_VERSION:-0.5.0}"
[ -v gc_app_name ] || readonly gc_app_name="${RCFORGE_APP_NAME:-rcForge}"
readonly UTILITY_NAME="apikey"
readonly API_KEY_FILE="${RCFORGE_DATA_ROOT}/config/api-keys.conf"

# ============================================================================
# Function: ShowHelp
# Description: Display help information for this utility.
# Usage: ShowHelp
# Returns: None. Exits with status 0.
# ============================================================================
ShowHelp() {
    echo "${UTILITY_NAME} - ${gc_app_name} API Key Manager (v${gc_version})"
    echo ""
    echo "Description:"
    echo "  Manages API keys stored in ${API_KEY_FILE}"
    echo ""
    echo "Usage:"
    echo "  rc ${UTILITY_NAME} <command> [options]"
    echo "  $(basename "$0") <command> [options]"
    echo ""
    echo "Commands:"
    echo "  set KEY_NAME 'value'      Store or update an API key"
    echo "  remove KEY_NAME           Remove an API key"
    echo "  list                      List stored API keys (names only)"
    echo "  show KEY_NAME             Show the value of a specific API key"
    echo "  help                      Show this help message"
    echo ""
    echo "Options:"
    echo "  --help, -h                Show this help message"
    echo "  --summary                 Show one-line description (for rc help)"
    echo "  --version                 Show version information"
    echo ""
    echo "Examples:"
    echo "  rc ${UTILITY_NAME} set GEMINI_API_KEY 'your-api-key-here'"
    echo "  rc ${UTILITY_NAME} list"
    exit 0
}

# ============================================================================
# Function: SetApiKey
# Description: Store or update an API key
# Usage: SetApiKey KEY_NAME VALUE
# Arguments:
#   $1 (required) - Key name (must be letters, numbers, and underscores only)
#   $2 (required) - Key value to store
# Returns: 0 on success, 1 on failure.
# ============================================================================
SetApiKey() {
    local key_name="$1"
    local key_value="$2"

    # Validate key name
    if [[ ! "$key_name" =~ ^[A-Za-z0-9_]+$ ]]; then
        ErrorMessage "Invalid key name. Use only letters, numbers, and underscores."
        return 1
    fi

    # Verify API key file exists
    if [[ ! -f "$API_KEY_FILE" ]]; then
        ErrorMessage "API key file not found: $API_KEY_FILE"
        return 1
    fi

    # Check if key already exists and update or append
    if grep -q "^${key_name}=" "$API_KEY_FILE"; then
        # Update existing key using sed in-place
        sed -i "s|^${key_name}=.*|${key_name}='${key_value}'|" "$API_KEY_FILE" || {
            ErrorMessage "Failed to update key: $key_name"
            return 1
        }
    else
        # Append new key
        echo "${key_name}='${key_value}'" >> "$API_KEY_FILE" || {
            ErrorMessage "Failed to add key: $key_name"
            return 1
        }
    fi
    
    echo "Key $key_name updated."
    return 0
}

# ============================================================================
# Function: RemoveApiKey
# Description: Remove an API key from the configuration
# Usage: RemoveApiKey KEY_NAME
# Arguments:
#   $1 (required) - Key name to remove
# Returns: 0 on success, 1 on failure.
# ============================================================================
RemoveApiKey() {
    local key_name="$1"

    # Verify API key file exists
    if [[ ! -f "$API_KEY_FILE" ]]; then
        ErrorMessage "API key file not found: $API_KEY_FILE"
        return 1
    fi

    # Check if key exists
    if ! grep -q "^${key_name}=" "$API_KEY_FILE"; then
        ErrorMessage "Key not found: $key_name"
        return 1
    fi

    # Remove the key using sed in-place
    sed -i "/^${key_name}=/d" "$API_KEY_FILE" || {
        ErrorMessage "Failed to remove key: $key_name"
        return 1
    }
    
    echo "Key $key_name removed."
    return 0
}

# ============================================================================
# Function: ListApiKeys
# Description: List all stored API keys (names only)
# Usage: ListApiKeys
# Arguments: None
# Returns: 0 on success, 1 on failure.
# ============================================================================
ListApiKeys() {
    # Verify API key file exists
    if [[ ! -f "$API_KEY_FILE" ]]; then
        ErrorMessage "API key file not found: $API_KEY_FILE"
        return 1
    fi

    echo "API Keys:"

    # Extract and display key names
    local key_count=0
    while IFS= read -r line; do
        # Skip comments and empty lines
        if [[ "$line" =~ ^# || -z "$line" ]]; then
            continue
        fi

        # Extract key name
        local key_name
        key_name=$(echo "$line" | cut -d= -f1)
        echo "  $key_name"
        key_count=$((key_count + 1))
    done < "$API_KEY_FILE"

    if [[ $key_count -eq 0 ]]; then
        echo "No keys found."
    fi

    return 0
}

# ============================================================================
# Function: ShowApiKey
# Description: Show the value of a specific API key
# Usage: ShowApiKey KEY_NAME
# Arguments:
#   $1 (required) - Key name to display
# Returns: 0 on success, 1 on failure.
# ============================================================================
ShowApiKey() {
    local key_name="$1"

    # Verify API key file exists
    if [[ ! -f "$API_KEY_FILE" ]]; then
        ErrorMessage "API key file not found: $API_KEY_FILE"
        return 1
    fi

    # Extract and display key value
    local key_line
    key_line=$(grep "^${key_name}=" "$API_KEY_FILE")

    if [[ -z "$key_line" ]]; then
        ErrorMessage "Key not found: $key_name"
        return 1
    fi

    # Extract value part (everything after the first =)
    local key_value="${key_line#*=}"
    
    echo "$key_name=$key_value"
    return 0
}

# ============================================================================
# Function: main
# Description: Main execution logic
# Usage: main "$@"
# Arguments: Command line arguments
# Returns: 0 on success, non-zero on failure
# ============================================================================
main() {
    # Handle no arguments
    if [[ $# -eq 0 ]]; then
        ErrorMessage "No command specified."
        echo "Available commands: set, remove, list, show, help"
        return 1
    fi

    # Process standard options first
    case "$1" in
        -h|--help)
            ShowHelp
            ;;
        --summary)
            ExtractSummary "$0"
            return $?
            ;;
        --version)
            ShowVersionInfo "$0"
            return 0
            ;;
    esac

    # Process command
    local command="$1"
    shift

    case "$command" in
        set)
            # Require exactly two arguments for set
            if [[ $# -ne 2 ]]; then
                ErrorMessage "Usage: apikey set KEY_NAME VALUE"
                return 1
            fi
            SetApiKey "$1" "$2"
            ;;
        remove)
            # Require exactly one argument for remove
            if [[ $# -ne 1 ]]; then
                ErrorMessage "Usage: apikey remove KEY_NAME"
                return 1
            fi
            RemoveApiKey "$1"
            ;;
        list)
            # Accept no arguments for list
            if [[ $# -ne 0 ]]; then
                ErrorMessage "Usage: apikey list"
                return 1
            fi
            ListApiKeys
            ;;
        show)
            # Require exactly one argument for show
            if [[ $# -ne 1 ]]; then
                ErrorMessage "Usage: apikey show KEY_NAME"
                return 1
            fi
            ShowApiKey "$1"
            ;;
        help)
            ShowHelp
            ;;
        *)
            ErrorMessage "Unknown command: $command"
            echo "Available commands: set, remove, list, show, help"
            return 1
            ;;
    esac

    return $?
}

# Execute main if run directly or via rc command
if IsExecutedDirectly || [[ "$0" == *"rc"* ]]; then
    main "$@"
    exit $?
fi

# EOF
