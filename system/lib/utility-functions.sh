#!/usr/bin/env bash
# utility-functions.sh - Common utilities for command-line scripts
# Author: rcForge Team
# Date: 2025-04-05
# Version: 0.3.0
# Description: This library provides common utilities for rcForge command-line scripts,
#              including argument processing, help display, and execution context detection.

# Source color utilities if available
if [[ -f "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/shell-colors.sh" ]]; then
  source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/shell-colors.sh"
else
  # Define minimal color variables if shell-colors.sh not available
  export RED='\033[0;31m'
  export GREEN='\033[0;32m'
  export YELLOW='\033[0;33m'
  export BLUE='\033[0;34m'
  export CYAN='\033[0;36m'
  export RESET='\033[0m'
  
  # Define minimal messaging functions
  ErrorMessage() { echo -e "${RED}ERROR:${RESET} $1" >&2; }
  WarningMessage() { echo -e "${YELLOW}WARNING:${RESET} $1" >&2; }
  InfoMessage() { echo -e "${BLUE}INFO:${RESET} $1"; }
  SuccessMessage() { echo -e "${GREEN}SUCCESS:${RESET} $1"; }
fi

# Set strict error handling
set -o nounset  # Treat unset variables as errors
set -o errexit  # Exit immediately if a command exits with a non-zero status

# Exported variables (for use in exported functions)
export UTILITY_DEBUG_MODE="${UTILITY_DEBUG_MODE:-false}"
export UTILITY_VERSION="${RCFORGE_VERSION:-0.3.0}"

# Global constants (not exported)
readonly gc_copyright="Copyright (c) 2025 rcForge Team"
readonly gc_license="Released under the MIT License"

# ============================================================================
# CONTEXT DETECTION
# ============================================================================

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

# Function: DetectShell
# Description: Determines which shell is currently running
# Usage: DetectShell
# Returns: Outputs shell name (bash, zsh, etc.)
DetectShell() {
  if [[ -n "${ZSH_VERSION:-}" ]]; then
    echo "zsh"
  elif [[ -n "${BASH_VERSION:-}" ]]; then
    echo "bash"
  else
    # Fallback to $SHELL
    basename "$SHELL"
  fi
}

# Function: DetectOS
# Description: Detects the operating system
# Usage: DetectOS
# Returns: String identifying the OS (linux, macos, windows)
DetectOS() {
  local os_name
  
  case "$(uname -s)" in
    Linux*)     os_name="linux";;
    Darwin*)    os_name="macos";;
    CYGWIN*)    os_name="windows";;
    MINGW*)     os_name="windows";;
    *)          os_name="unknown";;
  esac
  
  echo "$os_name"
}

# Function: IsMacOS
# Description: Checks if running on macOS
# Usage: IsMacOS
# Returns: 0 if macOS, 1 otherwise
IsMacOS() {
  [[ "$(DetectOS)" == "macos" ]]
}

# Function: IsLinux
# Description: Checks if running on Linux
# Usage: IsLinux 
# Returns: 0 if Linux, 1 otherwise
IsLinux() {
  [[ "$(DetectOS)" == "linux" ]]
}

# Function: CommandExists
# Description: Check if a command exists in the path
# Usage: CommandExists command_name
# Returns: 0 if command exists, 1 otherwise
CommandExists() {
  command -v "$1" >/dev/null 2>&1
}

# ============================================================================
# VERSION AND HELP DISPLAY
# ============================================================================

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

# Function: ShowSummary 
# Description: Displays one-line summary for use with rc help
# Usage: ShowSummary [summary]
# Arguments:
#   summary - Optional summary text (will try to extract from script if not provided)
ShowSummary() {
  local summary="${1:-}"
  local script_file="${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}"
  
  # If no summary provided, try to extract from script header
  if [[ -z "$summary" && -f "$script_file" ]]; then
    summary=$(grep -m 1 "RC Summary:" "$script_file" | cut -d: -f2- | xargs)
    # If still not found, try to use description
    if [[ -z "$summary" ]]; then
      summary=$(grep -m 1 "Description:" "$script_file" | cut -d: -f2- | xargs)
    fi
  fi
  
  # Default if no summary can be found
  : "${summary:=No description available}"
  
  # Output summary
  echo "$summary"
}

# ============================================================================
# ARGUMENT PROCESSING
# ============================================================================

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
    --summary)
      ShowSummary
      exit 0
      ;;
    *)
      # Return the unprocessed argument
      echo "$arg"
      return 0
      ;;
  esac
}

# Function: ProcessArguments
# Description: Processes all command-line arguments, with both common and specific handling
# Usage: ProcessArguments "$@"
# Arguments:
#   "$@" - All command-line arguments
# Returns:
#   Array of unprocessed arguments
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
    printf '%s\n' "${unprocessed_args[@]}"
  fi
}

# ============================================================================
# FILE AND PATH OPERATIONS
# ============================================================================

# Function: AddToPath
# Description: Adds a directory to PATH if it exists and is not already in PATH
# Usage: AddToPath directory [prepend|append]
# Arguments:
#   directory - Directory to add to PATH
#   position - Where to add (prepend|append), defaults to prepend
AddToPath() {
  local dir="$1"
  local position="${2:-prepend}"
  
  # Skip if directory doesn't exist
  if [[ ! -d "$dir" ]]; then
    return 0
  fi
  
  # Skip if already in PATH
  if [[ ":$PATH:" == *":$dir:"* ]]; then
    return 0
  fi
  
  # Add to PATH based on position
  if [[ "$position" == "append" ]]; then
    export PATH="$PATH:$dir"
  else
    export PATH="$dir:$PATH"
  fi
}

# Function: ShowPath
# Description: Displays PATH entries one per line
# Usage: ShowPath
ShowPath() {
  echo "$PATH" | tr ':' '\n'
}

# Function: FindInPath
# Description: Finds all instances of a command in PATH
# Usage: FindInPath command_name
# Arguments:
#   command_name - Name of command to find
FindInPath() {
  local cmd="$1"
  
  # Check each directory in PATH
  local IFS=:
  for dir in $PATH; do
    if [[ -x "$dir/$cmd" ]]; then
      echo "$dir/$cmd"
    fi
  done
}

# ============================================================================
# SELF-EXECUTION HANDLING
# ============================================================================

# Display usage information if executed directly
if IsExecutedDirectly; then
  # Show basic usage information when script is executed directly
  InfoMessage "This is a utility library meant to be sourced by other scripts."
  echo ""
  ShowHelp "This script is not meant to be executed directly."
  echo "To use this library, source it in your scripts:"
  echo ""
  echo "  source \"\${RCFORGE_LIB}/utility-functions.sh\""
  echo ""
  exit 0
fi

# ============================================================================
# EXPORT FUNCTIONS
# ============================================================================

# Main function exports
export -f IsExecutedDirectly
export -f DetectShell
export -f DetectOS
export -f IsMacOS
export -f IsLinux
export -f CommandExists
export -f ShowVersion
export -f ShowHelp
export -f ShowSummary
export -f ProcessCommonArgs
export -f ProcessArguments
export -f AddToPath
export -f ShowPath
export -f FindInPath

# EOF