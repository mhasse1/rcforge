#!/usr/bin/env bash
# check-bash-version.sh - Checks Bash version compatibility for rcForge
# Author: Mark Hasse
# Copyright: Analog Edge LLC
# Date: 2025-03-30
# Version: 0.2.1
# Description: Validates Bash version and provides guidance for upgrades

# Import core utility libraries
source shell-colors.sh

# Set strict error handling
set -o nounset  # Treat unset variables as errors
set -o errexit  # Exit immediately if a command exits with a non-zero status

# Global constants
readonly gc_min_bash_version="4.0"
readonly gc_app_name="rcForge"
readonly gc_app_version="0.2.1"

# Detect project root dynamically
DetectProjectRoot() {
    local possible_roots=(
        "${RCFORGE_ROOT:-}"                  # Explicitly set environment variable
        "$(dirname "$SCRIPT_DIR")"           # Parent of script directory
        "$HOME/src/rcforge"                  # Common developer location
        "$HOME/Projects/rcforge"             # Alternative project location
        "$HOME/Development/rcforge"          # Another alternative
        "/usr/share/rcforge"                 # System-wide location (Linux/Debian)
        "/opt/homebrew/share/rcforge"        # Homebrew on Apple Silicon
        "$(brew --prefix 2>/dev/null)/share/rcforge" # Homebrew (generic)
        "/opt/local/share/rcforge"           # MacPorts
        "/usr/local/share/rcforge"           # Alternative system location
        "$HOME/.config/rcforge"              # User configuration directory
    )

    for dir in "${possible_roots[@]}"; do
        if [[ -n "$dir" && -d "$dir" && -f "$dir/rcforge.sh" ]]; then
            echo "$dir"
            return 0
        fi
    done

    # If not found, default to user configuration directory
    echo "$HOME/.config/rcforge"
}

# Validate Bash version
ValidateBashVersion() {
    local current_version="$1"
    local major_version=${current_version%%.*}
    local rest_version=${current_version#*.}
    local minor_version=${rest_version%%.*}

    # Convert versions to comparable numeric format
    local min_major=${gc_min_bash_version%%.*}
    local min_minor=${gc_min_bash_version#*.}

    if [[ "$major_version" -lt "$min_major" ]]; then
        return 1
    elif [[ "$major_version" -eq "$min_major" && "$minor_version" -lt "$min_minor" ]]; then
        return 1
    fi

    return 0
}

# Display bash installation options
DisplayUpgradeOptions() {
    local current_version="$1"

    if command -v brew >/dev/null 2>&1; then
        TextBlock "Homebrew Installation Options:" "$CYAN"
        echo "1. Install/update Bash via Homebrew:"
        echo "   brew install bash"
        echo ""
        echo "2. Add the new Bash to your available shells:"
        echo "   sudo bash -c 'echo $(brew --prefix)/bin/bash >> /etc/shells'"
        echo ""
        echo "3. (Optional) Change your default shell:"
        echo "   chsh -s $(brew --prefix)/bin/bash"
    else
        TextBlock "Bash Upgrade Recommendations:" "$YELLOW"
        echo "1. Install Homebrew (https://brew.sh):"
        echo '   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        echo ""
        echo "2. Then install Bash:"
        echo "   brew install bash"
    fi
}

# Find alternative Bash installations
FindBashInstallations() {
    local common_paths=(
        "/opt/homebrew/bin/bash"
        "/usr/local/bin/bash"
        "/bin/bash"
        "/usr/bin/bash"
    )
    local found_installations=0

    InfoMessage "Checking alternative Bash installations:"
    for path in "${common_paths[@]}"; do
        if [[ -x "$path" ]]; then
            local version
            version=$("$path" --version | head -n 1 | sed 's/.*version \([0-9]*\.[0-9]*\).*/\1/')
            echo "  ${YELLOW}$path${RESET} - version ${CYAN}$version${RESET}"
            ((found_installations++))
        fi
    done

    if [[ $found_installations -eq 0 ]]; then
        WarningMessage "No alternative Bash installations found"
    fi
}

# Main script execution
Main() {
    # Detect script directory
    local SCRIPT_DIR
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Detect project root
    local RCFORGE_DIR
    RCFORGE_DIR=$(DetectProjectRoot)

    # Display header
    SectionHeader "${gc_app_name} Bash Version Compatibility Check"

    # Check if running Bash
    if [[ -z "$BASH_VERSION" ]]; then
        WarningMessage "Not running Bash. Current shell: $(basename "$SHELL")"
        WarningMessage "${gc_app_name} requires Bash ${gc_min_bash_version}+ or Zsh 5.0+"
        exit 0
    fi

    # Display current Bash information
    InfoMessage "Current Bash Details:"
    echo -e "  Version:    ${YELLOW}$BASH_VERSION${RESET}"
    echo -e "  Binary:     ${YELLOW}$(command -v bash)${RESET}"
    echo -e "  Required:   ${CYAN}${gc_min_bash_version}+${RESET}"
    echo ""

    # Validate Bash version
    if ! ValidateBashVersion "$BASH_VERSION"; then
        ErrorMessage "Bash version ${BASH_VERSION} does not meet requirements for ${gc_app_name} v${gc_app_version}"
        
        # Display Homebrew/upgrade options
        DisplayUpgradeOptions "$BASH_VERSION"
        
        # Show alternative installations
        FindBashInstallations
        
        exit 1
    fi

    # Check Homebrew status
    if command -v brew >/dev/null 2>&1; then
        SuccessMessage "Homebrew is installed"
        local homebrew_bash
        homebrew_bash=$(brew --prefix)/bin/bash
        if [[ -x "$homebrew_bash" ]]; then
            echo -e "  Homebrew Bash: ${YELLOW}$homebrew_bash${RESET}"
        else
            WarningMessage "Homebrew Bash not installed"
        fi
    else
        WarningMessage "Homebrew not installed"
    fi

    # Success message
    SuccessMessage "Bash version meets ${gc_app_name} requirements!"
}

# Detect if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Execute main script only if run directly
    Main "$@"
fi
