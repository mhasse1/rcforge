#!/usr/bin/env bash
# core/bash-version-check.sh
# Shared function to check Bash version requirements
# Author: Mark Hasse
# Date: 2025-03-31
# Category: system
# Description: Validates Bash version compatibility for rcForge

# Source color utilities
source shell-colors.sh

# Set strict error handling
set -o nounset  # Treat unset variables as errors
set -o errexit  # Exit immediately if a command exits with a non-zero status

# Global constants
readonly gc_required_bash_version=4
readonly gc_app_name="rcForge"
readonly gc_version="0.2.1"

# CheckBashVersion: Validate Bash version compatibility
# Usage: CheckBashVersion [optional_minimum_version]
# Returns: 0 if version meets requirements, 1 if not
CheckBashVersion() {
    local min_version="${1:-$gc_required_bash_version}"
    
    # Check if using Bash
    if [[ -z "$BASH_VERSION" ]]; then
        WarningMessage "Not running in Bash shell. Current shell: $(basename "$SHELL")"
        return 1
    fi

    # Extract major version number
    local major_version=${BASH_VERSION%%.*}
    
    # Check version compatibility
    if [[ "$major_version" -lt "$min_version" ]]; then
        ErrorMessage "${gc_app_name} v${gc_version} requires Bash $min_version.0 or higher"
        InfoMessage "Your current Bash version is: $BASH_VERSION"
        
        # Provide installation guidance
        if [[ "$(uname -s)" == "Darwin" ]]; then
            InfoMessage "On macOS, you can install a newer Bash version with Homebrew:"
            InfoMessage "  brew install bash"
            InfoMessage ""
            InfoMessage "Then add it to your available shells:"
            InfoMessage "  sudo bash -c 'echo $(brew --prefix)/bin/bash >> /etc/shells'"
            InfoMessage ""
            InfoMessage "And optionally set it as your default shell:"
            InfoMessage "  chsh -s $(brew --prefix)/bin/bash"
        fi
        
        return 1
    fi
    
    SuccessMessage "Compatible Bash version: $BASH_VERSION"
    return 0
}

# Export the function to make it available in other scripts
export -f CheckBashVersion

# If the script is executed directly, run the version check
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    CheckBashVersion || exit 1
fi
# EOF