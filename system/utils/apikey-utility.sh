#!/usr/bin/env bash
# apikey.sh - API Key Management Utility
# Author: rcForge Team
# Date: 2025-04-18
# Version: 0.5.0
# Category: system/utility
# RC Summary: Store and manage API keys for external services
# Description: Securely stores and manages API keys in a config file,
#              with commands to set, list, remove, and display keys.

# Source necessary libraries (utility-functions sources shell-colors)
source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/utility-functions.sh"

# Set strict error handling
set -o nounset
set -o pipefail
# set -o errexit # Let functions handle their own errors

# ============================================================================
# GLOBAL CONSTANTS
# ============================================================================
[ -v gc_version ]  || readonly gc_version="${RCFORGE_VERSION:-0.5.0}"
[ -v gc_app_name ] || readonly gc_app_name="${RCFORGE_APP_NAME:-rcForge}"
readonly UTILITY_NAME="apikey"
readonly API_KEY_FILE="${HOME}/.local/rcforge/config/api_key_settings"

# ============================================================================
# Function: ShowHelp
# Description: Display detailed help information for this utility.
# Usage: ShowHelp
# Exits: 0
# ============================================================================
ShowHelp() {
    local script_name
    script_name=$(basename "$0")

    echo "${UTILITY_NAME} - ${gc_app_name} API Key Manager (v${gc_version})"
    echo ""
    echo "Description:"
    echo "  Securely manages API keys used by ${gc_app_name} and your shell environment."
    echo "  Keys are stored in ${API_KEY_FILE} and automatically exported"
    echo "  as environment variables when rcForge loads."
    echo ""
    echo "Usage:"
    echo "  rc ${UTILITY_NAME} <command> [options]"
    echo "  ${script_name} <command> [options]"
    echo ""
    echo "Commands:"
    echo "  set KEY_NAME 'value'      Store a new API key or update an existing one"
    echo "  remove KEY_NAME           Remove an API key"
    echo "  list                      List all stored API keys (names only, not values)"
    echo "  show KEY_NAME             Show the value of a specific API key"
    echo "  help                      Show this help message"
    echo ""
    echo "Options:"
    echo "  --verbose, -v             Enable verbose output"
    echo "  --help, -h                Show this help message"
    echo "  --summary                 Show one-line description (for rc help)"
    echo "  --version                 Show version information"
    echo ""
    echo "Examples:"
    echo "  rc ${UTILITY_NAME} set GEMINI_API_KEY 'your-api-key-here'"
    echo "  rc ${UTILITY_NAME} list"
    echo "  rc ${UTILITY_NAME} remove OLD_KEY"
    exit 0
}

# ============================================================================
# Function: EnsureKeyFile
# Description: Create API key file with proper permissions if it doesn't exist
# Usage: EnsureKeyFile
# Returns: 0 on success, 1 on failure.
# ============================================================================
EnsureKeyFile() {
    local api_key_dir
    api_key_dir=$(dirname "$API_KEY_FILE")
    
    # Create directory if it doesn't exist
    if [[ ! -d "$api_key_dir" ]]; then
        if ! mkdir -p "$api_key_dir"; then
            ErrorMessage "Failed to create API key directory: $api_key_dir"
            return 1
        fi
        chmod 700 "$api_key_dir"
    fi
    
    # Create file if it doesn't exist
    if [[ ! -f "$API_KEY_FILE" ]]; then
        cat > "$API_KEY_FILE" << EOF
# rcForge API Key Settings
# This file contains API keys that will be exported as environment variables.
# Lines starting with # are ignored.
# Format: NAME='value'
#
# Examples:
# GEMINI_API_KEY='your-api-key-here'
# CLAUDE_API_KEY='your-api-key-here'
# AWS_API_KEY='your-api-key-here'
EOF
        
        # Set permissions to user read/write only
        chmod 600 "$API_KEY_FILE"
        SuccessMessage "Created API key configuration file: $API_KEY_FILE"
    fi
    
    # Verify file is readable and writable
    if [[ ! -r "$API_KEY_FILE" || ! -w "$API_KEY_FILE" ]]; then
        ErrorMessage "API key file exists but has incorrect permissions: $API_KEY_FILE"
        return 1
    fi
    
    return 0
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
    local temp_file="/tmp/rcforge_apikey_${RANDOM}"
    local key_exists=false
    
    # Validate key name
    if [[ ! "$key_name" =~ ^[A-Za-z0-9_]+$ ]]; then
        ErrorMessage "Invalid key name. Use only letters, numbers, and underscores."
        return 1
    fi
    
    # Ensure key file exists
    EnsureKeyFile || return 1
    
    # Check if key already exists
    if grep -q "^${key_name}=" "$API_KEY_FILE"; then
        key_exists=true
    fi
    
    # Create a temporary file with updated content
    if [[ "$key_exists" == "true" ]]; then
        # Update existing key
        sed "s|^${key_name}=.*|${key_name}='${key_value}'|" "$API_KEY_FILE" > "$temp_file"
    else
        # Add new key
        cat "$API_KEY_FILE" > "$temp_file"
        echo "${key_name}='${key_value}'" >> "$temp_file"
    fi
    
    # Replace the original file
    if mv "$temp_file" "$API_KEY_FILE"; then
        chmod 600 "$API_KEY_FILE" # Ensure proper permissions
        if [[ "$key_exists" == "true" ]]; then
            SuccessMessage "Updated API key: $key_name"
        else
            SuccessMessage "Added new API key: $key_name"
        fi
        return 0
    else
        ErrorMessage "Failed to update API key file."
        return 1
    fi
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
    local temp_file="/tmp/rcforge_apikey_${RANDOM}"
    
    # Ensure key file exists
    if [[ ! -f "$API_KEY_FILE" ]]; then
        ErrorMessage "API key file does not exist: $API_KEY_FILE"
        return 1
    fi
    
    # Check if key exists
    if ! grep -q "^${key_name}=" "$API_KEY_FILE"; then
        ErrorMessage "API key not found: $key_name"
        return 1
    fi
    
    # Create a temporary file with the key removed
    grep -v "^${key_name}=" "$API_KEY_FILE" > "$temp_file"
    
    # Replace the original file
    if mv "$temp_file" "$API_KEY_FILE"; then
        chmod 600 "$API_KEY_FILE" # Ensure proper permissions
        SuccessMessage "Removed API key: $key_name"
        return 0
    else
        ErrorMessage "Failed to update API key file."
        return 1
    fi
}

# ============================================================================
# Function: ListApiKeys
# Description: List all stored API keys (names only)
# Usage: ListApiKeys
# Arguments: None
# Returns: 0 on success, 1 on failure.
# ============================================================================
ListApiKeys() {
    # Ensure key file exists
    if [[ ! -f "$API_KEY_FILE" ]]; then
        ErrorMessage "API key file does not exist: $API_KEY_FILE"
        return 1
    fi
    
    SectionHeader "Stored API Keys"
    
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
        InfoMessage "No API keys found."
    else
        InfoMessage "Total keys: $key_count"
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
    
    # Ensure key file exists
    if [[ ! -f "$API_KEY_FILE" ]]; then
        ErrorMessage "API key file does not exist: $API_KEY_FILE"
        return 1
    fi
    
    # Extract and display key value
    local key_value
    key_value=$(grep "^${key_name}=" "$API_KEY_FILE" | cut -d= -f2-)
    
    if [[ -z "$key_value" ]]; then
        ErrorMessage "API key not found: $key_name"
        return 1
    fi
    
    echo "API Key: $key_name"
    echo "Value:   $key_value"
    
    return 0
}

# ============================================================================
# Function: ParseArguments
# Description: Parse command-line arguments for this utility.
# Usage: declare -A options; ParseArguments options "$@"
# Arguments:
#   $1 (required) - Reference to associative array for storing parsed options
#   $2+ (required) - Command line arguments to parse
# Returns: Populates associative array by reference. Returns 0 on success, 1 on error.
# ============================================================================
ParseArguments() {
    local -n options_ref="$1"
    shift
    
    # Ensure Bash 4.3+ for namerefs (-n)
    if [[ "${BASH_VERSINFO[0]}" -lt 4 || ( "${BASH_VERSINFO[0]}" -eq 4 && "${BASH_VERSINFO[1]}" -lt 3 ) ]]; then
        ErrorMessage "Internal Error: ParseArguments requires Bash 4.3+ for namerefs."
        return 1
    fi

    # Set default values
    options_ref["command"]=""
    options_ref["key_name"]=""
    options_ref["key_value"]=""
    options_ref["verbose_mode"]=false

    # Handle no arguments
    if [[ $# -eq 0 ]]; then
        ErrorMessage "No command specified. Use 'help' to see available commands."
        return 1
    fi
    
    # First argument is the command
    options_ref["command"]="$1"
    shift
    
    # Process standard options
    while [[ $# -gt 0 ]]; do
        local key="$1"
        case "$key" in
            -h|--help)
                ShowHelp # Exits
                ;;
            --summary)
                ExtractSummary "$0"; exit $? # Call helper and exit
                ;;
            --version)
                _rcforge_show_version "$0"; exit 0 # Call helper and exit
                ;;
            -v|--verbose)
                options_ref["verbose_mode"]=true
                shift ;;
            --)
                shift # Move past --
                break # Stop processing options
                ;;
            -*)
                ErrorMessage "Unknown option: $key"
                return 1 ;;
            *)
                # Process based on the command
                case "${options_ref["command"]}" in
                    set)
                        if [[ -z "${options_ref["key_name"]}" ]]; then
                            options_ref["key_name"]="$key"
                        elif [[ -z "${options_ref["key_value"]}" ]]; then
                            options_ref["key_value"]="$key"
                        else
                            ErrorMessage "Too many arguments for 'set' command."
                            return 1
                        fi
                        ;;
                    remove|show)
                        if [[ -z "${options_ref["key_name"]}" ]]; then
                            options_ref["key_name"]="$key"
                        else
                            ErrorMessage "Too many arguments for '${options_ref["command"]}' command."
                            return 1
                        fi
                        ;;
                    *)
                        ErrorMessage "Unexpected argument: $key"
                        return 1
                        ;;
                esac
                shift
                ;;
        esac
    done
    
    # Validate arguments based on command
    case "${options_ref["command"]}" in
        set)
            if [[ -z "${options_ref["key_name"]}" ]]; then
                ErrorMessage "Missing key name for 'set' command."
                return 1
            fi
            if [[ -z "${options_ref["key_value"]}" ]]; then
                ErrorMessage "Missing value for 'set' command."
                return 1
            fi
            ;;
        remove|show)
            if [[ -z "${options_ref["key_name"]}" ]]; then
                ErrorMessage "Missing key name for '${options_ref["command"]}' command."
                return 1
            fi
            ;;
        list|help)
            # No additional arguments needed
            ;;
        *)
            ErrorMessage "Unknown command: ${options_ref["command"]}"
            echo "Available commands: set, remove, list, show, help"
            return 1
            ;;
    esac
    
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
    local command="${options[command]}"
    local key_name="${options[key_name]}"
    local key_value="${options[key_value]}"
    local is_verbose="${options[verbose_mode]}"

    # Display section header
    SectionHeader "rcForge API Key Management"
    
    # Execute the appropriate command
    case "$command" in
        set)
            VerboseMessage "$is_verbose" "Setting API key: $key_name"
            SetApiKey "$key_name" "$key_value"
            ;;
        remove)
            VerboseMessage "$is_verbose" "Removing API key: $key_name"
            RemoveApiKey "$key_name"
            ;;
        list)
            VerboseMessage "$is_verbose" "Listing API keys"
            ListApiKeys
            ;;
        show)
            VerboseMessage "$is_verbose" "Showing API key: $key_name"
            ShowApiKey "$key_name"
            ;;
        help)
            ShowHelp # Exits
            ;;
    esac
    
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