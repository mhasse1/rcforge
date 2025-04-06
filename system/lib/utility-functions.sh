#!/usr/bin/env bash
# utility-functions.sh - Common utilities for command-line scripts
# Author: rcForge Team
# Date: 2025-04-06 # Updated Date
# Version: 0.3.0
# Category: system/library
# Description: This library provides common utilities for rcForge command-line scripts,
#              including argument processing, help display, and execution context detection.

# Note: Do not use 'set -e' or 'set -u' in sourced library scripts.

# Source color utilities if available (required by messaging functions below)
# Standard sourcing assuming shell-colors.sh exists in a valid install
if [[ -f "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/shell-colors.sh" ]]; then
  # shellcheck disable=SC1090
  source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/shell-colors.sh"
else
  # Minimal fallbacks if colors aren't available (should not happen in normal operation)
  echo "ERROR: Cannot source required library: shell-colors.sh" >&2
  # Define minimal functions to avoid errors in scripts sourcing this
  ErrorMessage() { echo "ERROR: $1" >&2; [[ -n "${2:-}" ]] && exit "$2"; }
  WarningMessage() { echo "WARNING: $1" >&2; }
  InfoMessage() { echo "INFO: $1"; }
  SuccessMessage() { echo "SUCCESS: $1"; }
fi

# ============================================================================
# GLOBAL CONSTANTS & VARIABLES (Exported)
# ============================================================================

# Debug mode flag (can be overridden by environment before sourcing)
export DEBUG_MODE="${DEBUG_MODE:-false}"
# Use rcForge core version if available, otherwise use ENV_ERROR default
[[ ! -v gc_version ]] && readonly gc_version="${RCFORGE_VERSION:-ENV_ERROR}"
readonly gc_app_name="${RCFORGE_APP_NAME:-ENV_ERROR}"
readonly gc_copyright="Copyright (c) $(date +%Y) rcForge Team" # Dynamic year
readonly gc_license="Released under the MIT License"

# ============================================================================
# CONTEXT DETECTION FUNCTIONS (PascalCase)
# ============================================================================

# ============================================================================
# Function: IsExecutedDirectly
# Description: Detects if script is being sourced or executed directly.
# Usage: if IsExecutedDirectly; then ... fi
# Returns: 0 (true) if executed directly, 1 (false) if sourced.
# ============================================================================
IsExecutedDirectly() {
  [[ "${BASH_SOURCE[0]}" == "${0}" ]]
}

# ============================================================================
# Function: DetectShell
# Description: Determines the name of the currently running shell.
# Usage: current_shell=$(DetectShell)
# Returns: Echoes shell name (bash, zsh, unknown).
# ============================================================================
DetectShell() {
  if [[ -n "${ZSH_VERSION:-}" ]]; then
    echo "zsh"
  elif [[ -n "${BASH_VERSION:-}" ]]; then
    echo "bash"
  else
    basename "${SHELL:-unknown}" # Fallback using $SHELL env var
  fi
}

# ============================================================================
# Function: DetectOS
# Description: Detects the operating system (linux, macos, windows, unknown).
# Usage: os_type=$(DetectOS)
# Returns: Echoes OS name string.
# ============================================================================
DetectOS() {
  local os_name="unknown" # Default to unknown
  case "$(uname -s)" in
    Linux*)   os_name="linux";;
    Darwin*)  os_name="macos";;
    CYGWIN*)  os_name="windows";;
    MINGW*)   os_name="windows";;
    MSYS*)    os_name="windows";;
  esac
  echo "$os_name"
}

# ============================================================================
# Function: IsMacOS
# Description: Checks if the current operating system is macOS.
# Usage: if IsMacOS; then ... fi
# Returns: 0 (true) if macOS, 1 (false) otherwise.
# ============================================================================
IsMacOS() {
  [[ "$(DetectOS)" == "macos" ]] # Call PascalCase
}

# ============================================================================
# Function: IsLinux
# Description: Checks if the current operating system is Linux.
# Usage: if IsLinux; then ... fi
# Returns: 0 (true) if Linux, 1 (false) otherwise.
# ============================================================================
IsLinux() {
  [[ "$(DetectOS)" == "linux" ]] # Call PascalCase
}

# ============================================================================
# Function: CommandExists
# Description: Check if a command exists in the current PATH.
# Usage: if CommandExists git; then ... fi
# Returns: 0 (true) if command exists, 1 (false) otherwise.
# ============================================================================
CommandExists() {
  command -v "$1" >/dev/null 2>&1
}

# ============================================================================
# VERSION AND HELP DISPLAY FUNCTIONS (PascalCase)
# ============================================================================

# ============================================================================
# Function: ShowVersion
# Description: Displays standard version, copyright, and license info.
# Usage: ShowVersion [script_name]
# Arguments:
#   script_name (optional) - Name of the script (defaults to detected name).
# Returns: None. Prints info to stdout.
# ============================================================================
ShowVersion() {
  local script_name="${1:-$(basename "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}")}"
  # Use gc_version constant now available
  if command -v InfoMessage &> /dev/null; then
    InfoMessage "${script_name} (rcForge Utility) v${gc_version}"
    InfoMessage "${gc_copyright}"
    InfoMessage "${gc_license}"
  else
    echo "${script_name} v${gc_version}"
    echo "${gc_copyright}"
    echo "${gc_license}"
  fi
}

# ============================================================================
# Function: ShowHelp
# Description: Displays generic usage and standard options (--help, --version, --summary).
# Usage: ShowHelp "script_specific_options_string"
# Arguments:
#   script_specific_options (optional) - Multi-line string describing script-specific options.
# Returns: None. Prints help to stdout.
# ============================================================================
ShowHelp() {
  local script_specific_options="${1:-}"
  local script_name

  if [[ "${BASH_SOURCE[1]:-}" ]]; then
      script_name=$(basename "${BASH_SOURCE[1]}")
  else
      script_name=$(basename "${BASH_SOURCE[0]}")
  fi

  if command -v InfoMessage &> /dev/null; then
    InfoMessage "Usage: ${script_name} [OPTIONS] [ARGUMENTS...]"
    echo ""
    InfoMessage "Standard Options:"
    echo "  --help, -h      Show this help message and exit"
    echo "  --version       Show version information and exit"
    echo "  --summary       Show a one-line summary (for rc help framework)"

    if [[ -n "$script_specific_options" ]]; then
      echo ""
      InfoMessage "Script-specific options:"
      printf '%s\n' "${script_specific_options}"
    fi
  else
    # Basic fallback
    echo "Usage: ${script_name} [OPTIONS] [ARGUMENTS...]"
    echo ""
    echo "Options:"
    echo "  --help, -h      Show this help message and exit"
    echo "  --version       Show version information and exit"
    echo "  --summary       Show a one-line summary"
     if [[ -n "$script_specific_options" ]]; then
      echo ""
      echo "Script-specific options:"
      printf '%s\n' "${script_specific_options}"
    fi
  fi
  echo ""
}

# ============================================================================
# Function: ShowSummary
# Description: Displays one-line summary, attempting to extract from script header.
# Usage: ShowSummary [summary_text]
# Arguments:
#   summary_text (optional) - Explicit summary text. If omitted, attempts to parse calling script.
# Returns: Echoes the summary string.
# ============================================================================
ShowSummary() {
  local summary="${1:-}"
  local script_file=""
  script_file="${BASH_SOURCE[1]:-}" # Caller script path

  if [[ -z "$summary" && -n "$script_file" && -f "$script_file" ]]; then
    summary=$(grep -m 1 '^# RC Summary:' "$script_file" | sed 's/^# RC Summary: //')
    if [[ -z "$summary" ]]; then
      summary=$(grep -m 1 '^# Description:' "$script_file" | sed 's/^# Description: //')
    fi
  fi

  : "${summary:=No summary available for $(basename "${script_file:-$0}")}"
  echo "$summary"
}

# ============================================================================
# ARGUMENT PROCESSING FUNCTIONS (PascalCase)
# ============================================================================

# ============================================================================
# Function: ProcessCommonArgs
# Description: Processes standard --help, --version, --summary arguments.
#              Exits script if argument is handled.
# Usage: ProcessCommonArgs arg
# Returns: 0 if handled (and exits), echoes original arg otherwise.
# ============================================================================
ProcessCommonArgs() {
  local arg="${1:-}"
  case "$arg" in
    --help|-h) ShowHelp; exit 0 ;;      # Call PascalCase & exit
    --version) ShowVersion; exit 0 ;;    # Call PascalCase & exit
    --summary) ShowSummary; exit 0 ;;    # Call PascalCase & exit
    *)
      echo "$arg" # Return unhandled arg
      return 0   # Indicate arg was "processed" by returning it
      ;;
  esac
}

# ============================================================================
# Function: ProcessArguments
# Description: Iterates through arguments, handling common ones via ProcessCommonArgs.
#              Gathers arguments not handled by ProcessCommonArgs.
# Usage: mapfile -t unprocessed_args < <(ProcessArguments "$@")
# Returns: Echoes unprocessed arguments, one per line.
# ============================================================================
ProcessArguments() {
  local arg=""
  local processed_arg=""
  for arg in "$@"; do
    processed_arg=$(ProcessCommonArgs "$arg") # Call PascalCase
    # If ProcessCommonArgs echoed (returned) the arg, print it for mapfile
    if [[ -n "$processed_arg" ]]; then
      printf '%s\n' "$processed_arg"
    fi
    # Note: ProcessCommonArgs exits on handled args, so loop won't continue
  done
}


# ============================================================================
# FILE AND PATH OPERATION FUNCTIONS (PascalCase)
# ============================================================================

# ============================================================================
# Function: AddToPath
# Description: Adds a directory to PATH if it exists and is not already present.
# Usage: AddToPath directory [prepend|append]
# Returns: 0. Modifies PATH environment variable.
# ============================================================================
AddToPath() {
  local dir="$1"
  local position="${2:-prepend}"

  # Check existence first
  if [[ ! -d "$dir" ]]; then return 0; fi

  # Check if already in PATH
  case ":${PATH}:" in
    *":${dir}:"*) return 0 ;;
    *":${dir}/:"*) return 0 ;; # Handle trailing slash case
  esac

  # Add to PATH, handling potentially empty initial PATH
  if [[ "$position" == "append" ]]; then
    export PATH="${PATH:+$PATH:}$dir"
  else
    export PATH="$dir${PATH:+:$PATH}"
  fi
  return 0
}

# ============================================================================
# Function: ShowPath
# Description: Displays current PATH entries, one per line.
# Usage: ShowPath
# Returns: None. Prints PATH entries to stdout.
# ============================================================================
ShowPath() {
  # Use printf and parameter expansion for safer output than tr
  printf '%s\n' "${PATH//:/$'\n'}"
}

# ============================================================================
# Function: FindInPath
# Description: Finds all executable instances of a command in the current PATH.
# Usage: FindInPath command_name
# Returns: Echoes full paths of found command instances, one per line.
# ============================================================================
FindInPath() {
  local cmd="$1"
  local dir=""
  local found_path=""
  local old_ifs="$IFS"
  IFS=:
  for dir in $PATH; do
    # Skip empty directories resulting from :: or leading/trailing :
    [[ -z "$dir" ]] && continue
    found_path="${dir}/${cmd}"
    # Check if it's executable and not a directory
    if [[ -x "$found_path" && ! -d "$found_path" ]]; then
      echo "$found_path"
    fi
  done
  IFS="$old_ifs" # Restore original IFS
}

# ============================================================================
# SELF-EXECUTION HANDLING (Display info if run directly)
# ============================================================================

# Check if the script is being executed directly
if IsExecutedDirectly; then # Call PascalCase
  InfoMessage "This is a utility library meant to be sourced by other scripts." # Call PascalCase
  echo ""
  # Call PascalCase
  ShowHelp "This script provides common functions and is not meant to be executed directly."
  echo "To use this library, source it in your scripts:"
  echo ""
  echo "  source \"\${RCFORGE_LIB:-~/.config/rcforge/system/lib}/utility-functions.sh\""
  echo ""
  exit 0 # Exit cleanly after showing info
fi

# ============================================================================
# EXPORT FUNCTIONS (Make functions available to sourcing scripts)
# ============================================================================

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
# Note: Messaging functions (ErrorMessage etc.) are exported by shell-colors.sh

# EOF