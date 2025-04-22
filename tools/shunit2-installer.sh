#!/usr/bin/env bash
# shunit2-install.sh - Install/update shUnit2 testing framework
# Author: rcForge Team
# Date: 2025-04-22
# Version: 0.5.0
# Category: system/utility
# RC Summary: Install or update the shUnit2 testing framework for rcForge
# Description: Downloads the latest stable version of shUnit2 from GitHub
#              and integrates it with the rcForge testing structure.

# Source necessary libraries
source "${RCFORGE_LIB:-$HOME/.local/share/rcforge/system/lib}/utility-functions.sh"
source "${RCFORGE_LIB:-$HOME/.local/share/rcforge/system/lib}/shunit2.sh"

# Set strict error handling
set -o nounset
set -o pipefail

# Global constants
[ -v gc_version ]  || readonly gc_version="${RCFORGE_VERSION:-0.5.0}"
[ -v gc_app_name ] || readonly gc_app_name="${RCFORGE_APP_NAME:-rcForge}"
readonly UTILITY_NAME="shunit2-install"

# ============================================================================
# Function: ShowHelp
# Description: Display detailed help information for this utility.
# Usage: ShowHelp
# Arguments: None
# Returns: None. Exits with status 0.
# ============================================================================
ShowHelp() {
    echo "${UTILITY_NAME} - ${gc_app_name} Utility (v${gc_version})"
    echo ""
    echo "Description:"
    echo "  Installs or updates the shUnit2 testing framework for rcForge."
    echo "  This downloads the stable version from GitHub and integrates"
    echo "  it with the rcForge testing structure."
    echo ""
    echo "Usage:"
    echo "  rc ${UTILITY_NAME} [options]"
    echo "  $(basename "$0") [options]"
    echo ""
    echo "Options:"
    echo "  --force, -f         Force update even if already installed"
    echo "  --version=VERSION   Specify a different shUnit2 version (default: 2.1.8)"
    echo "  --help, -h          Show this help message"
    echo "  --summary           Show a one-line description (for rc help)"
    echo "  --version           Show version information"
    echo ""
    echo "Examples:"
    echo "  rc ${UTILITY_NAME}              # Install standard version"
    echo "  rc ${UTILITY_NAME} --force      # Force reinstallation"
    echo "  rc ${UTILITY_NAME} --version=2.1.7  # Install specific version"
    exit 0
}

# ============================================================================
# Function: main
# Description: Main execution logic for shunit2 installation.
# Usage: main "$@"
# Arguments: Command-line arguments
# Returns: 0 on success, non-zero on error.
# ============================================================================
main() {
    local force_update=false
    local version="${SHUNIT2_VERSION:-2.1.8}"
    
    # Process command-line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                ShowHelp
                ;;
            --summary)
                ExtractSummary "$0"
                exit $?
                ;;
            --version)
                echo "${UTILITY_NAME} (${gc_app_name}) v${gc_version}"
                exit 0
                ;;
            -f|--force)
                force_update=true
                shift
                ;;
            --version=*)
                version="${1#*=}"
                shift
                ;;
            *)
                ErrorMessage "Unknown option: $1"
                echo "Use --help for usage information."
                return 1
                ;;
        esac
    done

    # Display section header
    SectionHeader "Installing shUnit2 Testing Framework"
    
    # Set up test directory structure
    local test_dirs=(
        "${RCFORGE_DATA_ROOT}/tests/lib"
        "${RCFORGE_DATA_ROOT}/tests/unit"
        "${RCFORGE_DATA_ROOT}/tests/integration"
        "${RCFORGE_DATA_ROOT}/tests/scripts"
    )
    
    InfoMessage "Creating test directory structure..."
    for dir in "${test_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            if mkdir -p "$dir"; then
                chmod 700 "$dir"
                InfoMessage "  Created: $dir"
            else
                ErrorMessage "Failed to create directory: $dir"
                return 1
            fi
        else
            InfoMessage "  Already exists: $dir"
        fi
    done
    
    # Call the install function from shunit2.sh
    InstallShunit2 "$force_update"
    local install_status=$?
    
    if [[ $install_status -eq 0 ]]; then
        SuccessMessage "shUnit2 installation completed successfully."
        InfoMessage "You can now run tests using the rcForge testing framework."
        InfoMessage "See documentation for details on writing and running tests."
    else
        ErrorMessage "shUnit2 installation failed."
        return 1
    fi
    
    # Check if shUnit2 wrapper is available
    if [[ -f "${RCFORGE_LIB}/shunit2.sh" ]]; then
        InfoMessage "Verify installation..."
        InfoMessage "  Framework: ${RCFORGE_LIB}/shunit2.sh"
        InfoMessage "  Library: $(FindShunit2)"
    fi
    
    return 0
}

# Execute main function if run directly or via rc command
if IsExecutedDirectly || [[ "$0" == *"rc"* ]]; then
    main "$@"
    exit $? # Exit with status from main
fi

# EOF
