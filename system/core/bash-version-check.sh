#!/usr/bin/env bash
# bash-version-check.sh - Check Bash version compatibility for rcForge
# Author: rcForge Team
# Date: 2025-04-08 # Updated Required Version
# Version: 0.4.1
# Category: system/core # Set Category
# RC Summary: Check if Bash version meets system requirements (4.3+)
# Description: Validates Bash version compatibility (4.3+) for rcForge and provides upgrade instructions

# Source required libraries
source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/utility-functions.sh"

# Set strict error handling
set -o nounset # Treat unset variables as errors
# set -o errexit  # Exit immediately if a command exits with a non-zero status

# Global constants
readonly gc_required_bash_version="4.3" # UPDATED requirement to 4.3+
[ -v gc_version ] || readonly gc_version="${RCFORGE_VERSION:-ENV_ERROR}"
[ -v gc_app_name ] || readonly gc_app_name="${RCFORGE_APP_NAME:-ENV_ERROR}"

# ============================================================================
# Function: CheckBashVersion
# Description: Validate Bash version compatibility against a minimum version.
# Usage: CheckBashVersion [optional_minimum_version] [is_verbose]
# Arguments:
#   optional_minimum_version (optional) - Minimum version string (e.g., "4.3"). Defaults to gc_required_bash_version.
#   is_verbose (optional) - Boolean ('true' or 'false'). Default false.
# Returns: 0 if current Bash version meets requirements, 1 if not or not running Bash.
# ============================================================================
CheckBashVersion() {
    local min_version="${1:-$gc_required_bash_version}" # Use updated default
    local is_verbose="${2:-false}"                      # Accept verbose flag

    # Check if running in Bash
    if [[ -z "${BASH_VERSION:-}" ]]; then
        WarningMessage "Not running in Bash shell. Current shell: $(basename "${SHELL:-unknown}")"
        # Still return 1 as the check technically fails if not bash
        return 1
    fi

    # More robust comparison using sort -V (handles versions like 4.1 vs 4.3 correctly)
    if printf '%s\n' "$min_version" "$BASH_VERSION" | sort -V -C &>/dev/null; then
        # Current version is >= min_version
        if [[ "$is_verbose" == "true" ]]; then
            InfoMessage "Bash version check:"
            InfoMessage "  Required: ${min_version}+"
            InfoMessage "  Current:  ${BASH_VERSION} (OK)" # Added OK indicator
        fi
        return 0 # Compatible
    else
        # Current version is < min_version
        if [[ "$is_verbose" == "true" ]]; then
            InfoMessage "Bash version check:"
            InfoMessage "  Required: ${min_version}+"
            InfoMessage "  Current:  ${BASH_VERSION} (${RED}INCOMPATIBLE${RESET})" # Added color
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

    WarningMessage "Your current Bash version ${BASH_VERSION:-unknown} is below the required ${gc_required_bash_version}."
    WarningMessage "While some parts of rcForge might load, certain utilities require Bash ${gc_required_bash_version}+ due to features like namerefs."
    echo ""
    InfoMessage "Upgrade instructions for $os_type:"
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
        echo "  Debian/Ubuntu: sudo apt update && sudo apt install --only-upgrade bash"
        echo "  Fedora/RHEL:   sudo dnf upgrade bash"
        echo "  Arch Linux:    sudo pacman -Syu bash" # Often -Syu updates bash
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
#   is_verbose (required) - Boolean (true or false).
# Returns: 0 if a compatible version is found, 1 otherwise.
# ============================================================================
FindBashInstallations() {
    local is_verbose="${1:-false}"
    local common_paths=(
        "/bin/bash"
        "/usr/bin/bash"
        "/usr/local/bin/bash"
    )
    # Add Homebrew paths dynamically if brew command exists
    if command -v brew &>/dev/null; then
        common_paths+=("$(brew --prefix bash 2>/dev/null || echo)/bin/bash")
        common_paths+=("$(brew --prefix)/bin/bash")
    fi
    # Remove duplicates and invalid paths
    local -a unique_paths
    local path=""
    declare -A seen_paths
    for path in "${common_paths[@]}"; do
        if [[ -n "$path" && -x "$path" && -z "${seen_paths[$path]:-}" ]]; then
            unique_paths+=("$path")
            seen_paths["$path"]=1
        fi
    done

    InfoMessage "Checking known Bash installations on your system:"
    echo ""

    local found_compatible=false
    local bash_path=""
    local version_string=""
    local version_number=""

    for bash_path in "${unique_paths[@]}"; do
        # Get version string safely
        version_string=$("$bash_path" --version 2>/dev/null | head -n 1) || version_string="Error checking version"
        version_number=$(echo "$version_string" | sed -n 's/.*GNU bash, version \([0-9]\+\.[0-9.]*\).*/\1/p') # Allow more version digits

        printf "%-30s: %s" "$bash_path" "${version_number:-?}" # Show '?' if version unknown

        if [[ -n "$version_number" ]]; then
            # Check compatibility using robust sort -V
            if printf '%s\n' "$gc_required_bash_version" "$version_number" | sort -V -C &>/dev/null; then
                printf " %b✓ (compatible)%b\n" "$GREEN" "$RESET"
                found_compatible=true
            else
                printf " %b✗ (incompatible: requires ${gc_required_bash_version}+)%b\n" "$RED" "$RESET" # Add requirement info
            fi
        else
            printf " %b? (version unknown)%b\n" "$YELLOW" "$RESET"
        fi
    done

    echo ""
    if [[ "$found_compatible" == "true" ]]; then
        SuccessMessage "You have at least one compatible Bash installation (v${gc_required_bash_version}+)."
        InfoMessage "If rcForge requires it and it's not your default, start rcForge with:"
        InfoMessage "<path_to_compatible_bash> -c \"source ~/.config/rcforge/rcforge.sh\""
        return 0
    else
        WarningMessage "No compatible Bash installations (v${gc_required_bash_version}+) found in common locations."
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
    # Use helper from utility-functions.sh (if sourced)
    if command -v ExtractSummary &>/dev/null; then
        ExtractSummary "$0" # $0 should be the script path when called
    else
        echo "Check if Bash version meets system requirements (${gc_required_bash_version}+)" # Fallback with version
    fi
}

# ============================================================================
# Function: ShowHelp
# Description: Display detailed help information for this utility.
# Usage: ShowHelp (called via --help)
# Returns: None. Prints help text to stdout.
# ============================================================================
ShowHelp() {
    # Use internal helper _rcforge_show_help if available, otherwise basic echo
    if command -v _rcforge_show_help &>/dev/null; then
        _rcforge_show_help <<EOF
  Validates if your current Bash version is compatible with ${gc_app_name:-rcForge} (v${gc_required_bash_version}+)
  and provides upgrade instructions if needed.

Usage:
  rc bash-version-check [options]
  $0 [options] # Direct usage

Options:
  --list          List all Bash installations found in common paths
  --verbose, -v   Show detailed check output
EOF
    else
        # Fallback basic help if helper function unavailable
        echo "bash-version-check - Check Bash version compatibility for ${gc_app_name:-rcForge}"
        echo ""
        echo "Description:"
        echo "  Validates if your current Bash version is compatible (v${gc_required_bash_version}+)"
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
        echo "  --version       Show version information"
        echo ""
        echo "Examples:"
        echo "  rc bash-version-check        # Check if current Bash is compatible"
        echo "  rc bash-version-check --list # List found Bash installations"
    fi
    exit 0
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
        --help | -h) ShowHelp ;; # Exits
        --summary)
            ShowSummary
            exit $?
            ;; # Exits with status
        --version)
            _rcforge_show_version "$0"
            exit 0
            ;; # Exits
        --verbose | -v) is_verbose=true ;;
        --list) list_bash=true ;;
        *)
            ErrorMessage "Unknown option: $1"
            ShowHelp # Show help before exiting
            exit 1
            ;;
        esac
        shift
    done

    # Use sourced function
    SectionHeader "Bash Version Compatibility Check (v${gc_version})"

    # List Bash installations if requested
    if [[ "$list_bash" == "true" ]]; then
        FindBashInstallations "$is_verbose"
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
    if CheckBashVersion "${gc_required_bash_version}" "$is_verbose"; then
        SuccessMessage "Your Bash version meets the requirement (v${gc_required_bash_version}+) for ${gc_app_name:-rcForge}!"
        check_status=0
    else
        # CheckBashVersion prints specific warning if not bash
        # If it was bash but version too low:
        if [[ -n "${BASH_VERSION:-}" ]]; then
            # ErrorMessage already displayed by DisplayUpgradeInstructions essentially
            echo ""
            DisplayUpgradeInstructions # Call local function
            echo ""
            InfoMessage "Use '--list' to see detected Bash installations."
        else
            # Message about not being in bash was already displayed by CheckBashVersion
            ErrorMessage "${gc_app_name:-rcForge} utilities require Bash v${gc_required_bash_version}+."
        fi
        check_status=1 # Mark as failure
    fi

    return $check_status
}

# Execute main function if run directly or via rc command
if IsExecutedDirectly || [[ "$0" == *"rc"* ]]; then
    main "$@"
    exit $? # Exit with the return code of main
fi

# EOF
