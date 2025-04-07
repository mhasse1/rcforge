#!/usr/bin/env bash
# rc-command.sh - Core rc command dispatcher (Full Implementation)
# Author: rcForge Team
# Date: 2025-04-07
# Version: 0.3.0
# Category: system/core
# Description: Finds and executes user or system utility scripts.

# Ensure core libraries are available (might be redundant if stub is called correctly, but safe)
[[ -z "${_RCFORGE_SHELL_COLORS_SH_SOURCED:-}" ]] && \
    source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/shell-colors.sh"
[[ -z "${_RCFORGE_UTILITY_FUNCTIONS_SH_SOURCED:-}" ]] && \
    source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/utility-functions.sh"

# Set strict modes for the implementation script
set -o nounset
# set -o errexit # Maybe disable errexit here to allow custom error handling

# ============================================================================
# Function: _rc_show_help (Internal Helper)
# ============================================================================
_rc_show_help() {
    # TODO: Implement logic to find all utils in RCFORGE_USER_UTILS and RCFORGE_UTILS
    #       and display their summaries.
    echo "rcForge Utility Command (v${RCFORGE_VERSION:-$gc_version})"
    echo ""
    echo "Usage: rc <command> [options] [arguments...]"
    echo ""
    echo "Available commands:"
    echo "  help             Show this help message"
    echo "  summary          (Used internally)"
    echo "  # Add discovered commands here later"
    echo "  httpheaders      (Example utility)"
    echo "  export           (Example utility)"
    echo "  diag             (Example utility)"
    echo "  seqcheck         (Example utility)"
    echo ""
    echo "Use 'rc <command> help' for detailed information about a command."
    echo "Use 'rc search <term>' to find commands (Not Yet Implemented)."
}

# ============================================================================
# Function: rc (Full Implementation - Overwrites Stub)
# ============================================================================
rc() {
    local command="${1:-help}" # Default to help if no command given
    shift || true # Shift args even if none exist initially

    # Handle core commands directly
    case "$command" in
        help|--help|-h)
            _rc_show_help
            return 0
            ;;
        summary|--summary)
             # This shouldn't typically be called directly by user
             echo "rc - rcForge command execution framework."
             return 0
            ;;
        search)
             # TODO: Implement search functionality
             ErrorMessage "Search functionality not yet implemented." 1
             ;;
        *)
             # --- Command Dispatch Logic ---
             # TODO: Implement search for command in:
             # 1. $RCFORGE_USER_UTILS/$command.sh
             # 2. $RCFORGE_UTILS/$command.sh
             # If found, execute the script, passing remaining args "$@"
             # If not found, show error.

             local user_util="${RCFORGE_USER_UTILS:-/invalid}/$command.sh"
             local system_util="${RCFORGE_UTILS:-/invalid}/$command.sh"
             local target_script=""

             if [[ -f "$user_util" && -x "$user_util" ]]; then
                 target_script="$user_util"
             elif [[ -f "$system_util" && -x "$system_util" ]]; then
                 target_script="$system_util"
             fi

             if [[ -n "$target_script" ]]; then
                 # Execute the found utility script with remaining arguments
                 "$target_script" "$@"
                 return $?
             else
                 ErrorMessage "Unknown command: '$command'"
                 _rc_show_help
                 return 127 # Command not found status
             fi
             ;;
    esac
}
# Ensure the full implementation is also exported if sourced directly somehow
export -f rc

# EOF
