#!/usr/bin/env bash
# functions.sh - Core utility functions for rcForge
# Author: Mark Hasse
# Date: 2025-03-31
# Category: system
# Description: Provides utility functions for secure script execution

# Source color and messaging utilities
source shell-colors.sh

# Set strict error handling
set -o nounset  # Treat unset variables as errors
set -o errexit  # Exit immediately if a command exits with a non-zero status

# Global constants
readonly gc_app_name="rcForge"
readonly gc_version="0.2.0"

# CheckRoot: Prevent execution of shell configuration scripts as root
# Usage: CheckRoot [--skip-interactive]
# Returns: 0 if allowed to continue, 1 if root execution should be stopped
CheckRoot() {
    # Check if current user is root (UID 0)
    if [[ $EUID -eq 0 || $(id -u) -eq 0 ]]; then
        # Determine the non-root user
        local non_root_user="${SUDO_USER:-$USER}"
        
        # Skip interactive warning if --skip-interactive flag is provided
        if [[ "${1:-}" != "--skip-interactive" ]]; then
            # Display detailed warning about root execution risks
            TextBlock "SECURITY WARNING: Root Execution Prevented" "$c_RED" "$c_BG_WHITE"
            
            ErrorMessage "Shell configuration tools should not be run as root or with sudo."
            
            WarningMessage "Running as root can:"
            echo "  - Create files with incorrect permissions"
            echo "  - Pose significant security risks"
            echo "  - Potentially compromise system configuration"
            
            InfoMessage "Recommended actions:"
            echo "1. Run this script as a regular user: ${non_root_user}"
            echo "2. If you must proceed, set RCFORGE_ALLOW_ROOT=1"
        fi
        
        # Check for explicit root override
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
    if ! CheckRoot; then
        ErrorMessage "Root execution prevented."
        exit 1
    fi
    
    SuccessMessage "Script executed successfully as non-root user."
fi
# EOF