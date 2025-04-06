#!/usr/bin/env bash
# functions.sh - Core utility functions for rcForge
# Author: Mark Hasse
# Date: 2025-04-06
# Category: core
# Version: 0.3.0
# Description: Provides utility functions for secure script execution

# Source shared utilities
source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/shell-colors.sh"

# Set strict error handling
set -o nounset  # Treat unset variables as errors
 # set -o errexit  # Exit immediately if a command exits with a non-zero status

# Global constants initialized from environment variables set in rcforge.sh
readonly gc_app_name="${RCFORGE_APP_NAME:-ENV_ERROR}"
readonly gc_version="${RCFORGE_VERSION:-ENV_ERROR}"

# ============================================================================
# Function: CheckRoot
# Description: Prevent execution of shell configuration scripts as root user.
#              Displays warnings and checks for override variable RCFORGE_ALLOW_ROOT.
# Usage: CheckRoot [--skip-interactive]
# Arguments:
#   --skip-interactive (optional) - If provided, suppresses the detailed warning messages.
# Returns:
#   0 - If execution is allowed (not root, or root override is set).
#   1 - If execution should be stopped (is root and no override is set).
# Environment Variables:
#   RCFORGE_ALLOW_ROOT - If set (to any non-empty value), allows root execution despite warnings.
# ============================================================================
CheckRoot() {
    # Check if current user is root (UID 0)
    if [[ ${EUID:-$(id -u)} -eq 0 ]]; then # Safer check for EUID
        # Determine the non-root user
        local non_root_user="${SUDO_USER:-$USER}"

        # Skip interactive warning if --skip-interactive flag is provided
        if [[ "${1:-}" != "--skip-interactive" ]]; then
            # Display detailed warning about root execution risks using standard functions/colors
            TextBlock "SECURITY WARNING: Root Execution Prevented" "$RED" "${BG_WHITE:-}" # Use standard color vars, provide default for BG_WHITE if needed

            ErrorMessage "Shell configuration tools should not be run as root or with sudo."

            WarningMessage "Running as root can:"
            # Using InfoMessage for list items for consistent indentation/prefix if desired, or keep echo
            InfoMessage "  - Create files with incorrect permissions"
            InfoMessage "  - Pose significant security risks"
            InfoMessage "  - Potentially compromise system configuration"

            InfoMessage "Recommended actions:"
            InfoMessage "1. Run this script as a regular user: ${non_root_user}"
            InfoMessage "2. If you must proceed, set RCFORGE_ALLOW_ROOT=1"
        fi

        # Check for explicit root override (using standard env var naming)
        if [[ -n "${RCFORGE_ALLOW_ROOT:-}" ]]; then
            WarningMessage "Proceeding with root execution due to RCFORGE_ALLOW_ROOT override."
            WarningMessage "THIS IS NOT RECOMMENDED FOR SECURITY REASONS."
            return 0
        fi

        # Prevent root execution by default
        return 1
    fi

    # Not root, allow execution to continue
    return 0
}

# Export the function to make it available in other scripts
export -f CheckRoot

# If script is executed directly, perform a root check demonstration
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Call function using PascalCase
    if ! CheckRoot; then
        ErrorMessage "Root execution prevented."
        exit 1
    fi

    SuccessMessage "Script executed successfully as non-root user."
fi

# EOF