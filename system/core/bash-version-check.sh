#!/usr/bin/env bash
# bash-version-check.sh - Check Bash version compatibility for rcForge
# Author: rcForge Team
# Date: 2025-04-06 # Updated Date
# Version: 0.3.0
# Category: system/core # Set Category
# RC Summary: Check if Bash version meets system requirements
# Description: Validates Bash version compatibility for rcForge and provides upgrade instructions

# Source required libraries
# Standard sourcing assuming shell-colors.sh exists in a valid install
source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/shell-colors.sh"

# Set strict error handling
set -o nounset  # Treat unset variables as errors
 # set -o errexit  # Exit immediately if a command exits with a non-zero status

# Global constants
readonly gc_required_bash_version="4.0"
readonly gc_app_name="${RCFORGE_APP_NAME:-ENV_ERROR}" # Use ENV_ERROR default
readonly gc_version="${RCFORGE_VERSION:-ENV_ERROR}" # Use ENV_ERROR default

# ============================================================================
# Function: CheckBashVersion
# Description: Validate Bash version compatibility against a minimum version.
# Usage: CheckBashVersion [optional_minimum_version]
# Arguments:
#   optional_minimum_version (optional) - Minimum version string (e.g., "4.0"). Defaults to gc_required_bash_version.
# Returns: 0 if current Bash version meets requirements, 1 if not or not running Bash.
# ============================================================================
CheckBashVersion() {
    local min_version="${1:-$gc_required_bash_version}"
    local is_verbose="${2:-false}" # Accept verbose flag if needed

    # Check if running in Bash
    if [[ -z "${BASH_VERSION:-}" ]]; then
        WarningMessage "Not running in Bash shell. Current shell: $(basename "${SHELL:-unknown}")"
        return 1
    fi

    # Extract major version number (simple check)
    local current_major_version="${BASH_VERSION%%.*}"
    local required_major_version
    required_major_version=$(echo "$min_version" | cut -d. -f1)

    # More robust comparison using sort -V (handles versions like 4.1 vs 4.0 correctly)
    if printf '%s\n' "$min_version" "$BASH_VERSION" | sort -V -C &>/dev/null; then
        # Current version is >= min_version
         if [[ "$is_verbose" == "true" ]]; then
             InfoMessage "Bash version check:"
             InfoMessage "  Required: ${min_version}+"
             InfoMessage "  Current:  ${BASH_VERSION}"
         fi
        return 0 # Compatible
    else
        # Current version is < min_version
         if [[ "$is_verbose" == "true" ]]; then
             InfoMessage "Bash version check:"
             InfoMessage "  Required: ${min_version}+"
             InfoMessage "  Current:  ${BASH_VERSION} (INCOMPATIBLE)"
         fi
        return 1 # Not compatible
    fi
}

# ============================================================================
# Function: DisplayUpgradeInstructions
# Description: Provide OS-specific instructions for upgrading Bash.
# Usage: DisplayUpgradeInstructions
# Arguments: None
# Returns: None. Prints instructions to stdout.
# ============================================================================
DisplayUpgradeInstructions() {
    local os_type="" # Use more descriptive name
    if [[ "$(uname)" == "Darwin" ]]; then
        os_type="macOS"
    elif [[ "$(uname)" == "Linux" ]]; then
        os_type="Linux"
    else
        os_type="Unknown"
    fi

    echo "Upgrade instructions for $os_type:"
    echo ""

    case "$os_type" in
        macOS)
            InfoMessage "1. Install Homebrew (if not installed):"
            echo '   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
            InfoMessage "2. Install latest Bash:"
            echo "   brew install bash"
            InfoMessage "3. Add new Bash to allowed shells:"
            echo "   sudo bash -c \"echo $(brew --prefix)/bin/bash >> /etc/shells\""
            InfoMessage "4. Change default shell (optional, requires logout/login):"
            echo "   chsh -s $(brew --prefix)/bin/bash"
            ;;
        Linux)
            InfoMessage "Use your distribution's package manager. Examples:"
            echo "  Debian/Ubuntu: sudo apt update && sudo apt install bash"
            echo "  Fedora/RHEL:   sudo dnf install bash"
            echo "  Arch Linux:    sudo pacman -S bash"
            ;;
        *)
            WarningMessage "Could not determine specific Linux distribution."
            InfoMessage "Please use your system's package manager or build Bash from source:"
            InfoMessage "https://www.gnu.org/software/bash/"
            ;;
    esac
}

# ============================================================================
# Function: FindBashInstallations
# Description: Look for existing Bash installations on the system and check compatibility.
# Usage: FindBashInstallations is_verbose
# Arguments:
#   is_verbose (required) - Boolean (true or false). Included for consistency, but currently always prints.
# Returns: 0 if a compatible version is found, 1 otherwise.
# ============================================================================
FindBashInstallations() {
    local is_verbose="${1:-false}" # Currently unused, but good practice
    local common_paths=(
        "/bin/bash"
        "/usr/bin/bash"
        "/usr/local/bin/bash"
        # Add more potential paths if needed
    )
    # Add Homebrew paths dynamically if brew command exists
    if command -v brew &>/dev/null; then
         common_paths+=("$(brew --prefix bash 2>/dev/null || echo)/bin/bash") # Get specific prefix for bash package if possible
         common_paths+=("$(brew --prefix)/bin/bash") # General brew prefix
    fi
    # Remove duplicates and invalid paths
    local -a unique_paths
    local path="" # Loop variable
    declare -A seen_paths # Associative array for uniqueness
    for path in "${common_paths[@]}"; do
        if [[ -n "$path" && -x "$path" && -z "${seen_paths[$path]:-}" ]]; then
             unique_paths+=("$path")
             seen_paths["$path"]=1
        fi
    done


    InfoMessage "Checking known Bash installations on your system:"
    echo ""

    local found_compatible=false
    local bash_path="" # Loop variable
    local version_string=""
    local version_number=""

    for bash_path in "${unique_paths[@]}"; do
        # Get version string safely
        version_string=$("$bash_path" --version 2>/dev/null | head -n 1) || version_string="Error checking version"

        # Try to extract version number (e.g., 4.4)
        version_number=$(echo "$version_string" | sed -n 's/.*GNU bash, version \([0-9]\+\.[0-9]\+\).*/\1/p')

        printf "%-30s: %s" "$bash_path" "$version_number"

        # Check compatibility if we got a version number
        if [[ -n "$version_number" ]]; then
             # Use more robust check here too
             if printf '%s\n' "$gc_required_bash_version" "$version_number" | sort -V -C &>/dev/null; then
                 # Compatible
                 printf " %b✓ (compatible)%b\n" "$GREEN" "$RESET"
                 found_compatible=true
             else
                 # Incompatible
                 printf " %b✗ (incompatible)%b\n" "$RED" "$RESET"
             fi
        else
             # Could not parse version
             printf " %b? (version unknown)%b\n" "$YELLOW" "$RESET"
        fi
    done

    echo ""
    if [[ "$found_compatible" == "true" ]]; then
        SuccessMessage "You have at least one compatible Bash installation."
        InfoMessage "If rcForge requires it and it's not your default, start rcForge with:"
        InfoMessage "<path_to_compatible_bash> -c \"source ~/.config/rcforge/rcforge.sh\""
        return 0
    else
        WarningMessage "No compatible Bash installations found in common locations."
        InfoMessage "Please upgrade using the instructions above or ensure a compatible version exists."
        return 1
    fi
}

# ============================================================================
# RC Command Interface Functions (PascalCase as they are interfaces)
# ============================================================================

# ============================================================================
# Function: ShowSummary
# Description: Display one-line summary for rc help command.
# Usage: ShowSummary (called via --summary)
# Returns: Echoes summary string.
# ============================================================================
ShowSummary() {
    grep '^# RC Summary:' "$0" | sed 's/^# RC Summary: //'
}

# ============================================================================
# Function: ShowHelp
# Description: Display detailed help information for this utility.
# Usage: ShowHelp (called via --help)
# Returns: None. Prints help text to stdout.
# ============================================================================
ShowHelp() {
    echo "bash-version-check - Check Bash version compatibility for ${gc_app_name}"
    echo ""
    echo "Description:"
    echo "  Validates if your current Bash version is compatible with ${gc_app_name} v${gc_version}"
    echo "  and provides upgrade instructions if needed."
    echo ""
    echo "Usage:"
    echo "  rc bash-version-check [options]"
    echo "  $0 [options]" # Direct usage
    echo ""
    echo "Options:"
    echo "  --help, -h      Show this help message"
    echo "  --summary       Show a one-line description (for rc help)"
    echo "  --list          List all Bash installations found in common paths"
    echo "  --verbose, -v   Show detailed check output"
    echo ""
    echo "Examples:"
    echo "  rc bash-version-check        # Check if current Bash is compatible"
    echo "  rc bash-version-check --list # List found Bash installations"
}

# ============================================================================
# Function: main
# Description: Main execution logic. Parses arguments, runs checks/lists installations.
# Usage: main "$@"
# Returns: 0 if compatible or list successful, 1 if incompatible or error.
# ============================================================================
main() {
    local is_verbose=false # Use standard boolean naming
    local list_bash=false
    local check_status=0 # Track status

    # Process command-line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h) ShowHelp; exit 0 ;; # Call PascalCase
            --summary) ShowSummary; exit 0 ;; # Call PascalCase
            --verbose|-v) is_verbose=true ;;
            --list) list_bash=true ;;
            *)
                ErrorMessage "Unknown option: $1"
                ShowHelp # Call PascalCase
                exit 1 ;;
        esac
        shift
    done

    # Call PascalCase function (SectionHeader assumed defined in utility-functions.sh)
    SectionHeader "Bash Version Compatibility Check (v${gc_version})"

    # List Bash installations if requested
    if [[ "$list_bash" == "true" ]]; then
        FindBashInstallations "$is_verbose" # Call PascalCase
        exit $? # Exit with status from FindBashInstallations
    fi

    # Display current Bash information if running Bash
    if [[ -n "${BASH_VERSION:-}" ]]; then
         InfoMessage "Current Bash version: ${BASH_VERSION}"
    else
         InfoMessage "Currently not running in Bash (Shell: $(basename "${SHELL:-unknown}"))"
    fi
    InfoMessage "Required version:     ${gc_required_bash_version}+"
    echo ""

    # Check Bash version compatibility
    if CheckBashVersion "${gc_required_bash_version}" "$is_verbose"; then # Call PascalCase
        SuccessMessage "Your Bash version is compatible with ${gc_app_name}!"
        check_status=0
    else
        # CheckBashVersion prints specific warning if not bash
        # If it was bash but version too low:
        if [[ -n "${BASH_VERSION:-}" ]]; then
             ErrorMessage "Your Bash version is NOT compatible with ${gc_app_name} v${gc_version}."
             echo ""
             WarningMessage "While ${gc_app_name} might partially function, Bash ${gc_required_bash_version}+ is required for full compatibility."
             echo ""
             DisplayUpgradeInstructions # Call PascalCase
             echo ""
             InfoMessage "Use '--list' to see detected Bash installations."
        fi
        check_status=1 # Mark as failure
    fi

    return $check_status
}

# Execute main function if run directly or via rc command
if [[ "${BASH_SOURCE[0]}" == "${0}" ]] || [[ "${BASH_SOURCE[0]}" != "${0}" && "$0" == *"rc"* ]]; then
    main "$@"
    exit $? # Exit with the return code of main
fi

# EOF