#!/usr/bin/env bash
# utility-functions.sh - Common utilities for command-line scripts
# Author: rcForge Team
# Date: 2025-04-08 # Updated Date - Final version from discussion
# Version: 0.4.1
# Category: system/library
# Description: This library provides common utilities for rcForge command-line scripts.

# shellcheck disable=SC2034 # Disable unused variable warnings in this library file

# --- Include Guard ---
if [[ -n "${_RCFORGE_UTILITY_FUNCTIONS_SH_SOURCED:-}" ]]; then
    return 0
fi
_RCFORGE_UTILITY_FUNCTIONS_SH_SOURCED=true # NOT Exported
# --- End Include Guard ---

# --- Source Shell Colors Library --- ###
# Assume shell-colors.sh is in the same directory or found via RCFORGE_LIB
if [[ -f "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/shell-colors.sh" ]]; then
    # shellcheck disable=SC1090
    source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/shell-colors.sh"
else
    echo "ERROR: Cannot source required library: shell-colors.sh" >&2
    return 1
fi
# --- End Source Shell Colors --- ###

# ============================================================================
# GLOBAL CONSTANTS & VARIABLES (Readonly, NOT Exported)
# ============================================================================
DEBUG_MODE="${DEBUG_MODE:-false}"
# Use pattern to avoid readonly errors if sourced multiple times
[ -v gc_version ]   || readonly gc_version="${RCFORGE_VERSION:-ENV_ERROR}"
[ -v gc_app_name ]  || readonly gc_app_name="${RCFORGE_APP_NAME:-ENV_ERROR}"
[ -v gc_copyright ] || readonly gc_copyright="Copyright (c) $(date +%Y) rcForge Team"
[ -v gc_license ]   || readonly gc_license="Released under the MIT License"

# ============================================================================
# CONTEXT DETECTION FUNCTIONS (Selectively Exported)
# ============================================================================
# NOTE: Standard function headers are missing for several functions below
#       and should be added for conformance with the style guide.

# ============================================================================
# Function: DetectCurrentHostname
# (...) - ADD HEADER
# ============================================================================
DetectCurrentHostname() {
    if command -v hostname &> /dev/null; then
        hostname -s 2>/dev/null || hostname | cut -d. -f1
    elif [[ -n "${HOSTNAME:-}" ]]; then
        echo "$HOSTNAME" | cut -d. -f1
    else
        uname -n | cut -d. -f1
    fi
}

# ============================================================================
# Function: DetectRcForgeDir
# Description: Determine the effective rcForge root directory. Checks RCFORGE_ROOT env var first.
# Usage: local dir=$(DetectRcForgeDir)
# Arguments: None
# Returns: Echoes the path to the rcForge configuration directory.
# ============================================================================
DetectRcForgeDir() {
    # Use RCFORGE_ROOT if set and is a directory, otherwise default
    if [[ -n "${RCFORGE_ROOT:-}" && -d "${RCFORGE_ROOT}" ]]; then
        echo "${RCFORGE_ROOT}"
    else
        echo "$HOME/.config/rcforge"
    fi
}

# ============================================================================
# Function: FindRcScripts
# (...) - ADD HEADER
# ============================================================================
FindRcScripts() {
    local shell="${1:?Shell type required}"
    local hostname="${2:-}"
    local -a config_files=()
    local scripts_dir="${RCFORGE_SCRIPTS:-$HOME/.config/rcforge/rc-scripts}"
    local -a patterns
    local pattern=""
    local file=""
    local nullglob_enabled=false
    if [[ -z "$hostname" ]]; then
        hostname=$(DetectCurrentHostname)
    fi
    patterns=(
        "${scripts_dir}/[0-9][0-9][0-9]_global_common_*.sh"
        "${scripts_dir}/[0-9][0-9][0-9]_global_${shell}_*.sh"
        "${scripts_dir}/[0-9][0-9][0-9]_${hostname}_common_*.sh"
        "${scripts_dir}/[0-9][0-9][0-9]_${hostname}_${shell}_*.sh"
    )
    if [[ ! -d "$scripts_dir" ]]; then
        if command -v WarningMessage &>/dev/null; then
            WarningMessage "rc-scripts directory not found: $scripts_dir"
        else
             echo "WARNING: rc-scripts directory not found: $scripts_dir" >&2
        fi
        return 1
    fi
    shopt -q nullglob && nullglob_enabled=true
    shopt -s nullglob
    for pattern in "${patterns[@]}"; do
         for file in $pattern; do
             [[ -f "$file" ]] && config_files+=("$file")
         done
    done
    [[ "$nullglob_enabled" == "false" ]] && shopt -u nullglob
    if [[ ${#config_files[@]} -eq 0 ]]; then
        return 0
    fi
    printf '%s\n' "${config_files[@]}" | sort -n
    return 0
}

# ============================================================================
# Function: IsExecutedDirectly
# (...) - ADD HEADER (Using corrected logic)
# ============================================================================
IsExecutedDirectly() {
    local executing_script="${BASH_SOURCE[${#BASH_SOURCE[@]}-1]}"
    [[ "$0" == "$executing_script" ]]
}

# ============================================================================
# Function: DetectShell
# (...) - ADD HEADER
# ============================================================================
DetectShell() {
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        echo "zsh"
    elif [[ -n "${BASH_VERSION:-}" ]]; then
        echo "bash"
    else
        basename "${SHELL:-unknown}"
    fi
}

# ============================================================================
# Function: DetectOS
# (...) - ADD HEADER
# ============================================================================
DetectOS() {
    local os_name="unknown"
    case "$(uname -s)" in
        Linux*)   os_name="linux";;
        Darwin*)  os_name="macos";;
        CYGWIN*|MINGW*|MSYS*) os_name="windows";;
    esac
    echo "$os_name"
}

# ============================================================================
# Function: IsMacOS
# (...) - ADD HEADER
# ============================================================================
IsMacOS() {
    [[ "$(DetectOS)" == "macos" ]]
}

# ============================================================================
# Function: IsLinux
# (...) - ADD HEADER
# ============================================================================
IsLinux() {
    [[ "$(DetectOS)" == "linux" ]]
}

# ============================================================================
# Function: IsBSD
# (...) - ADD HEADER
# ============================================================================
IsBSD() {
    # Needs refinement for other BSDs
    [[ "$(DetectOS)" == "macos" ]]
}

# ============================================================================
# Function: CommandExists
# (...) - ADD HEADER
# ============================================================================
CommandExists() {
    command -v "$1" >/dev/null 2>&1
}

# Export Context Functions needed by rc.sh and potentially utilities
export -f DetectCurrentHostname
export -f DetectRcForgeDir
export -f FindRcScripts
export -f DetectShell
export -f DetectOS
export -f IsMacOS
export -f IsLinux
export -f IsBSD
export -f CommandExists

# ============================================================================
# VERSION AND HELP DISPLAY FUNCTIONS (Internal Helpers - NOT Exported)
# ============================================================================
# NOTE: Standard function headers are missing

# _rcforge_show_version - Internal helper
_rcforge_show_version() {
    local script_name="${1:-$(basename "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}")}"
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

# _rcforge_show_help - Internal helper
_rcforge_show_help() {
    local script_specific_options="${1:-}"
    local script_name
    if [[ -n "${BASH_SOURCE[1]:-}" ]]; then script_name=$(basename "${BASH_SOURCE[1]}"); else script_name=$(basename "${BASH_SOURCE[0]}"); fi
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
        echo "Usage: ${script_name} [OPTIONS] [ARGUMENTS...]"; echo ""; echo "Options:"; echo "  --help, -h      Show this help message and exit"; echo "  --version       Show version information and exit"; echo "  --summary       Show a one-line summary"; if [[ -n "$script_specific_options" ]]; then echo ""; echo "Script-specific options:"; printf '%s\n' "${script_specific_options}"; fi
    fi
    echo ""
}

# ============================================================================
# Function: ExtractSummary
# Description: Extracts the RC Summary comment line from a given script file.
#              Falls back to the Description line if RC Summary is missing.
#              Intended to be called by utility scripts handling --summary.
# Usage: ExtractSummary "/path/to/script.sh"
# Arguments:
#   $1 (required) - Full path to the script file to parse.
# Returns: Echoes the summary string or a default message. Status 0 or 1.
# ============================================================================
ExtractSummary() {
    local script_file="${1:-}"
    local summary=""

    # Validate input
    if [[ -z "$script_file" ]]; then
        if command -v WarningMessage &>/dev/null; then WarningMessage "No script path provided to ExtractSummary."; else echo "Warning: No script path provided to ExtractSummary." >&2; fi
        echo "(Error: No script path provided)"
        return 1
    elif [[ ! -f "$script_file" ]]; then
        if command -v WarningMessage &>/dev/null; then WarningMessage "Script file not found for summary: $script_file"; else echo "Warning: Script file not found for summary: $script_file" >&2; fi
        echo "(Error: Script file not found)"
        return 1
    elif [[ ! -r "$script_file" ]]; then
        if command -v WarningMessage &>/dev/null; then WarningMessage "Script file not readable for summary: $script_file"; else echo "Warning: Script file not readable for summary: $script_file" >&2; fi
        echo "(Error: Script file not readable)"
        return 1
    fi

    # Try RC Summary first
    summary=$(grep -m 1 '^# RC Summary:' "$script_file" || true) # Ignore grep status 1 (no match)
    if [[ -n "$summary" ]]; then
        summary=$(echo "$summary" | sed -e 's/^# RC Summary: //' -e 's/^[[:space:]]*//')
    fi

    # Try Description if summary empty
    if [[ -z "$summary" ]]; then
        summary=$(grep -m 1 '^# Description:' "$script_file" || true) # Ignore grep status 1
        if [[ -n "$summary" ]]; then
             summary=$(echo "$summary" | sed -e 's/^# Description: //' -e 's/^[[:space:]]*//')
        fi
    fi

    # Provide default
    : "${summary:=No summary available for $(basename "${script_file}")}"
    echo "$summary"

    # Return status
    if [[ "$summary" == "No summary available for"* ]]; then return 1; else return 0; fi
}
# --- IMPORTANT: Do NOT export ExtractSummary ---


# ============================================================================
# ARGUMENT PROCESSING FUNCTIONS (Internal Helpers - NOT Exported)
# ============================================================================
# NOTE: Standard function headers are missing

# ProcessCommonArgs - Handles standard --help, --version, --summary
ProcessCommonArgs() {
    local arg="${1:-}"
    local calling_script_path="${BASH_SOURCE[1]:-$0}"
    local specific_help_text="${2:-}" # Optional specific help text from caller

    case "$arg" in
        --help|-h) _rcforge_show_help "$specific_help_text"; exit 0 ;;
        --version) _rcforge_show_version "$calling_script_path"; exit 0 ;;
        --summary) ExtractSummary "$calling_script_path"; exit $? ;; # Use new function, exit with its status
        *)
          echo "$arg" # Return unhandled arg
          return 0   # Indicate arg was not one of the common ones handled
          ;;
    esac
}
# ProcessArguments - Example generic processor
ProcessArguments() {
    local arg=""
    local processed_arg=""
    for arg in "$@"; do
        # Pass along remaining args potentially for specific help text
        processed_arg=$(ProcessCommonArgs "$arg" "${@:2}")
        if [[ -n "$processed_arg" ]]; then
            printf '%s\n' "$processed_arg"
        fi
        # ProcessCommonArgs exits on handled args
    done
}

# ============================================================================
# SELF-EXECUTION HANDLING (Corrected Check)
# ============================================================================
# Check if THIS library file is being executed directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  if command -v InfoMessage &>/dev/null; then
      InfoMessage "This is a utility library meant to be sourced by other scripts."
      echo ""
      if command -v _rcforge_show_help &>/dev/null; then
           _rcforge_show_help "This script provides common functions and is not meant to be executed directly."
      else
           echo "ERROR: Cannot show full help as internal help function is unavailable." >&2
      fi
  else
      echo "INFO: This is a utility library meant to be sourced..." # Fallback echo
      echo "ERROR: Cannot show full help as messaging functions are unavailable (source shell-colors.sh first)." >&2
  fi
  echo "To use this library, source it AFTER sourcing shell-colors.sh:"
  echo ""
  echo "  source \"\${RCFORGE_LIB:-~/.config/rcforge/system/lib}/shell-colors.sh\""
  echo "  source \"\${RCFORGE_LIB:-~/.config/rcforge/system/lib}/utility-functions.sh\""
  echo ""
  exit 0
fi

# EOF