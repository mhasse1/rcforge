#!/usr/bin/env bash
# utility-functions.sh - Common utilities for command-line scripts
# Author: Mark Hasse
# Date: 2025-04-01
#
# This library provides common utilities for rcForge command-line scripts,
# including argument processing, help display, and execution context detection.

# Source color utilities if available
if [[ -f "${RCFORGE_SYSTEM:-/usr/share/rcforge}/lib/shell-colors.sh" ]]; then
  source "${RCFORGE_SYSTEM:-/usr/share/rcforge}/lib/shell-colors.sh"
else
  # Define minimal color variables if shell-colors.sh not available
  export RED='\033[0;31m'
  export GREEN='\033[0;32m'
  export YELLOW='\033[0;33m'
  export BLUE='\033[0;34m'
  export CYAN='\033[0;36m'
  export RESET='\033[0m'
fi

# Set strict error handling
set -o nounset  # Treat unset variables as errors
set -o errexit  # Exit immediately if a command exits with a non-zero status

# Exported variables (for use in exported functions)
export UTILITY_DEBUG_MODE=false
export UTILITY_VERSION="0.2.1"

# Global constants (not exported)
readonly gc_copyright="Copyright (c) 2025 Analog Edge LLC"
readonly gc_license="Released under the MIT License"

# Function: IsExecutedDirectly
# Description: Detects if script is being sourced or executed directly
# Usage: IsExecutedDirectly
# Returns: 0 if executed directly, 1 if sourced
IsExecutedDirectly() {
  # Check if script is being sourced (bash-specific method)
  if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # Script is being sourced
    return 1
  else
    # Script is being executed directly
    return 0
  fi
}

# Function: ShowVersion
# Description: Displays version information for the script
# Usage: ShowVersion [script_name]
# Arguments:
#   script_name - Optional script name to display (defaults to current script)
ShowVersion() {
  local script_name="${1:-$(basename "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}")}"
  
  if [[ -n "${CYAN:-}" && -n "${RESET:-}" ]]; then
    echo -e "${CYAN}${script_name}${RESET} v${UTILITY_VERSION}"
    echo -e "${gc_copyright}"
    echo -e "${gc_license}"
  else
    echo "${script_name} v${UTILITY_VERSION}"
    echo "${gc_copyright}"
    echo "${gc_license}"
  fi
}

# Function: ShowHelp
# Description: Displays help information for the script
# Usage: ShowHelp [script_specific_options]
# Arguments:
#   script_specific_options - Optional string containing script-specific options
ShowHelp() {
  local script_specific_options="${1:-}"
  local script_name
  
  # If called via a symlink, show the symlink name instead of the script name
  if [[ "$0" != "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}" ]]; then
    script_name=$(basename "$0")
  else
    script_name=$(basename "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}")
  fi
  
  # Display usage information
  if [[ -n "${BLUE:-}" && -n "${RESET:-}" && -n "${CYAN:-}" ]]; then
    echo -e "${BLUE}Usage:${RESET} ${CYAN}${script_name}${RESET} [OPTIONS]"
  else
    echo "Usage: ${script_name} [OPTIONS]"
  fi
  
  echo ""
  echo "Options:"
  echo "  --help, -h     Show this help message"
  echo "  --version, -v  Show version information"
  
  # Add script-specific options if provided
  if [[ -n "$script_specific_options" ]]; then
    echo ""
    echo "Script-specific options:"
    echo "${script_specific_options}"
  fi
  
  echo ""
}

# Function: ProcessCommonArgs
# Description: Processes common command-line arguments
# Usage: ProcessCommonArgs arg
# Arguments:
#   arg - Command line argument to process
# Returns:
#   0 if argument was handled, non-empty string with the argument if not handled
ProcessCommonArgs() {
  local arg="${1:-}"
  
  # Validate input
  if [[ -z "$arg" ]]; then
    [[ "$UTILITY_DEBUG_MODE" == true ]] && echo "WARNING: Empty argument passed to ProcessCommonArgs" >&2
    return 0
  fi
  
  # Process standard arguments
  case "$arg" in
    --help|-h)
      ShowHelp
      exit 0
      ;;
    --version|-v)
      ShowVersion
      exit 0
      ;;
    *)
      # Return the unprocessed argument
      echo "$arg"
      return 0
      ;;
  esac
}

# Function: ErrorMessage
# Description: Displays an error message and optionally exits
# Usage: ErrorMessage message [exit_code]
# Arguments:
#   message - Error message to display
#   exit_code - Optional exit code (if provided, script will exit)
ErrorMessage() {
  local message="${1:-Unknown error}"
  local exit_code="${2:-}"
  
  # Display message with color if available
  if [[ -n "${RED:-}" && -n "${RESET:-}" ]]; then
    echo -e "${RED}ERROR:${RESET} ${message}" >&2
  else
    echo "ERROR: ${message}" >&2
  fi
  
  # Exit if code provided
  if [[ -n "$exit_code" ]]; then
    exit "$exit_code"
  fi
}

# Function: WarningMessage
# Description: Displays a warning message
# Usage: WarningMessage message
# Arguments:
#   message - Warning message to display
WarningMessage() {
  local message="${1:-Warning}"
  
  # Display message with color if available
  if [[ -n "${YELLOW:-}" && -n "${RESET:-}" ]]; then
    echo -e "${YELLOW}WARNING:${RESET} ${message}" >&2
  else
    echo "WARNING: ${message}" >&2
  fi
}

# Function: SuccessMessage
# Description: Displays a success message
# Usage: SuccessMessage message
# Arguments:
#   message - Success message to display
SuccessMessage() {
  local message="${1:-Operation completed successfully}"
  
  # Display message with color if available
  if [[ -n "${GREEN:-}" && -n "${RESET:-}" ]]; then
    echo -e "${GREEN}SUCCESS:${RESET} ${message}"
  else
    echo "SUCCESS: ${message}"
  fi
}

# Function: InfoMessage
# Description: Displays an informational message
# Usage: InfoMessage message
# Arguments:
#   message - Informational message to display
InfoMessage() {
  local message="${1:-Information}"
  
  # Display message with color if available
  if [[ -n "${BLUE:-}" && -n "${RESET:-}" ]]; then
    echo -e "${BLUE}INFO:${RESET} ${message}"
  else
    echo "INFO: ${message}"
  fi
}

# Function: ProcessArguments
# Description: Processes all command-line arguments, with both common and specific handling
# Usage: ProcessArguments "$@"
# Arguments:
#   "$@" - All command-line arguments
# Returns:
#   0 on success, non-zero on error
ProcessArguments() {
  local args=("$@")
  local unprocessed_args=()
  
  # Process each argument
  for arg in "${args[@]}"; do
    local processed=$(ProcessCommonArgs "$arg")
    
    # If non-empty result, add to unprocessed args
    if [[ -n "$processed" ]]; then
      unprocessed_args+=("$processed")
    fi
  done
  
  # Return unprocessed arguments
  if [[ ${#unprocessed_args[@]} -gt 0 ]]; then
    echo "${unprocessed_args[@]}"
  fi
  
  return 0
}

# Self-execution handling
if IsExecutedDirectly; then
  # Show basic usage information when script is executed directly
  InfoMessage "This is a utility library meant to be sourced by other scripts."
  echo ""
  ShowHelp "This script is not meant to be executed directly."
  echo "To use this library, source it in your scripts:"
  echo ""
  echo "  source \"\${RCFORGE_SYSTEM}/lib/utility-functions.sh\""
  echo ""
  exit 0
fi

# Export functions for use in other scripts
export -f IsExecutedDirectly
export -f ShowVersion
export -f ShowHelp
export -f ProcessCommonArgs
export -f ErrorMessage
export -f WarningMessage
export -f SuccessMessage
export -f InfoMessage
export -f ProcessArguments

# Legacy function exports (for backward compatibility)
export -f is_executed_directly="IsExecutedDirectly"
export -f show_version="ShowVersion"
export -f show_help="ShowHelp"
export -f process_common_args="ProcessCommonArgs"

# EOF
