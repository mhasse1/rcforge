#!/usr/bin/env bash
# integrity.sh - Validate rcForge installation integrity
# Author: rcForge Team
# Date: 2025-04-06
# Category: system/utility
# Version: 0.3.0
# Description: Validates the integrity of rcForge installation and environment

# Source required libraries
source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/shell-colors.sh"

# Set strict error handling
set -o nounset  # Treat unset variables as errors
# set -o errexit  # Exit immediately if a command exits with a non-zero status

# Global constants initialized from environment variables set in rcforge.sh
[ -v gc_version ]  || readonly gc_version="${RCFORGE_VERSION:-ENV_ERROR}"
[ -v gc_app_name ] || readonly gc_app_name="${RCFORGE_APP_NAME:-ENV_ERROR}"

readonly gc_required_files=(
    "rcforge.sh"
    "system/lib/shell-colors.sh"
    "system/lib/utility-functions.sh" # Assuming this exists, add to check if needed
    "system/core/functions.sh"
    "system/utils/seqcheck.sh" # Confirm this filename is correct for v0.3.0
)

readonly gc_min_bash_version="4.0"

# ============================================================================
# Function: DisplayUsage
# Description: Show script usage information and examples.
# Usage: DisplayUsage
# Arguments: None
# Returns: None. Prints usage to stdout.
# ============================================================================
DisplayUsage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --verbose, -v     Show detailed output"
    echo "  --help, -h        Show this help message"
}

# ============================================================================
# Function: CheckFileIntegrity
# Description: Verify critical rcForge files exist in the installation directory.
# Usage: CheckFileIntegrity rcforge_dir is_verbose
# Arguments:
#   rcforge_dir (required) - Path to the rcForge root directory.
#   is_verbose (required) - Boolean ('true' or 'false') for verbose output.
# Returns: 0 if all required files exist, 1 otherwise.
# ============================================================================
CheckFileIntegrity() {
    local rcforge_dir="$1"
    local is_verbose="${2:-false}" # Default to false if not provided
    local missing_files=false
    local file="" # Loop variable

    InfoMessage "Checking for critical files..."

    for file in "${gc_required_files[@]}"; do
        if [[ ! -f "$rcforge_dir/$file" ]]; then
            ErrorMessage "Missing critical file: $rcforge_dir/$file"
            missing_files=true
        else
            if [[ "$is_verbose" == "true" ]]; then
                InfoMessage "File exists: $rcforge_dir/$file"
            fi
        fi
    done

    if [[ "$missing_files" == "true" ]]; then
        ErrorMessage "File integrity check failed"
        return 1
    else
        SuccessMessage "All critical files present"
        return 0
    fi
}

# ============================================================================
# Function: CheckPermissions
# Description: Verify directory and file permissions match standards (700).
# Usage: CheckPermissions rcforge_dir is_verbose
# Arguments:
#   rcforge_dir (required) - Path to the rcForge root directory.
#   is_verbose (required) - Boolean ('true' or 'false') for verbose output.
# Returns: 0 if permissions are correct, 1 otherwise.
# ============================================================================
CheckPermissions() {
    local rcforge_dir="$1"
    local is_verbose="${2:-false}" # Default to false if not provided
    local permissions_issue=false
    local file="" # Loop variable
    local full_path=""
    local file_perms=""

    InfoMessage "Checking directory and file permissions..."

    # Check main directory permissions
    local main_dir_perms
    # Handle potential errors if stat fails (e.g., directory doesn't exist)
    main_dir_perms=$(stat -c "%a" "$rcforge_dir" 2>/dev/null || stat -f "%Lp" "$rcforge_dir" 2>/dev/null || echo "ERR")

    if [[ "$main_dir_perms" == "ERR" ]]; then
        ErrorMessage "Could not stat main directory: $rcforge_dir"
        permissions_issue=true
    elif [[ "$main_dir_perms" != "700" ]]; then
        WarningMessage "Main directory ($rcforge_dir) has incorrect permissions: $main_dir_perms (expected 700)"
        permissions_issue=true
    elif [[ "$is_verbose" == "true" ]]; then
         InfoMessage "Main directory ($rcforge_dir) permissions are correct (700)."
    fi

    # Check script permissions within required files list
    for file in "${gc_required_files[@]}"; do
        full_path="$rcforge_dir/$file"
        # Check only executable shell scripts that exist
        if [[ "$file" == *".sh" && -f "$full_path" ]]; then
            file_perms=$(stat -c "%a" "$full_path" 2>/dev/null || stat -f "%Lp" "$full_path" 2>/dev/null || echo "ERR")

            if [[ "$file_perms" == "ERR" ]]; then
                 ErrorMessage "Could not stat file: $full_path"
                 permissions_issue=true
            elif [[ "$file_perms" != "700" ]]; then
                WarningMessage "Script $file has incorrect permissions: $file_perms (expected 700)"
                permissions_issue=true
            elif [[ "$is_verbose" == "true" ]]; then
                 InfoMessage "Script ($file) permissions are correct (700)."
            fi
        fi
    done

    if [[ "$permissions_issue" == "true" ]]; then
        WarningMessage "Permission check found issues."
        return 1
    else
        SuccessMessage "Permissions check completed successfully." # Adjusted message
        return 0
    fi
}

# ============================================================================
# Function: CheckEnvironment
# Description: Validate required rcForge environment variables are set and point to valid directories.
# Usage: CheckEnvironment is_verbose
# Arguments:
#   is_verbose (required) - Boolean ('true' or 'false') for verbose output.
# Returns: 0 if environment is valid, 1 otherwise.
# ============================================================================
CheckEnvironment() {
    local is_verbose="${1:-false}" # Default to false if not provided
    local env_issue=false
    local var="" # Loop variable

    InfoMessage "Checking environment variables..."

    # Standard variables expected to be set by rcforge.sh or user
    local standard_vars=(
        "RCFORGE_ROOT"
        "RCFORGE_SCRIPTS"
        "RCFORGE_LIB"
        "RCFORGE_UTILS"
        # Add RCFORGE_USER_UTILS if its check is critical here
    )

    for var in "${standard_vars[@]}"; do
        # Check if the variable is set using indirect expansion with default
        if [[ -z "${!var:-}" ]]; then
            WarningMessage "Standard environment variable $var is not set."
            env_issue=true
        else
            # Check if the directory it points to exists
            if [[ ! -d "${!var}" ]]; then
                ErrorMessage "Directory for $var does not exist: ${!var}"
                env_issue=true
            elif [[ "$is_verbose" == "true" ]]; then
                InfoMessage "$var = ${!var}"
            fi
        fi
    done

    if [[ "$env_issue" == "true" ]]; then
        WarningMessage "Environment variable check found issues."
        return 1
    else
        SuccessMessage "Environment variables check completed successfully." # Adjusted message
        return 0
    fi
}

# ============================================================================
# Function: CheckBashVersion
# Description: Check if the current Bash version meets the minimum requirement (gc_min_bash_version).
# Usage: CheckBashVersion
# Arguments: None
# Returns: 0 if Bash version is sufficient, 1 otherwise.
# ============================================================================
CheckBashVersion() {
    InfoMessage "Checking Bash version..."

    # Check if running in Bash
    if [[ -z "${BASH_VERSION:-}" ]]; then
        WarningMessage "Not running in Bash shell. Current shell: $(basename "$SHELL")"
        WarningMessage "rcForge core requires Bash ${gc_min_bash_version}+."
        return 1 # Treat as failure for integrity check
    fi

    # Compare versions using sort -V for robust comparison (handles 4.1 vs 4.0)
    if printf '%s\n' "$gc_min_bash_version" "$BASH_VERSION" | sort -V -C; then
        SuccessMessage "Bash version $BASH_VERSION meets minimum requirement ($gc_min_bash_version)."
        return 0
    else
        ErrorMessage "Bash version $BASH_VERSION is lower than required version $gc_min_bash_version."
        return 1
    fi
}


# ============================================================================
# Function: DetermineRcforgeDir
# Description: Determine the effective rcForge root directory.
# Usage: DetermineRcforgeDir
# Returns: Echoes the path to the rcForge configuration directory.
# ============================================================================
DetermineRcforgeDir() {
    # Use RCFORGE_ROOT if set and is a directory, otherwise default
    if [[ -n "${RCFORGE_ROOT:-}" && -d "${RCFORGE_ROOT}" ]]; then
        echo "${RCFORGE_ROOT}"
    else
        echo "$HOME/.config/rcforge"
    fi
}

# ============================================================================
# Function: main
# Description: Main execution logic. Parses arguments and runs integrity checks.
# Usage: main "$@"
# Arguments: Passes all script arguments ("$@").
# Returns: Exits with 0 if all checks pass, 1 otherwise.
# ============================================================================
main() {
    local is_verbose=false # Use standard boolean naming convention
    local issues=0

    # Process command arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --verbose|-v)
                is_verbose=true
                ;;
            --help|-h)
                DisplayUsage # Call PascalCase
                # exit 0 # Exit success after displaying help
                ;;
            *)
                ErrorMessage "Unknown option: $1"
                DisplayUsage # Call PascalCase
                # exit 1 # Exit failure for unknown option
                ;;
        esac
        shift
    done

    InfoMessage "Starting rcForge v${gc_version} Integrity Check..."

    # Determine rcForge directory (should be done once if needed by multiple checks)
    local rcforge_dir
    rcforge_dir=$(DetermineRcforgeDir) # Call PascalCase

    # Perform integrity checks, passing verbose status
    # Use || issues=$((issues + 1)) for cleaner increment on failure
    CheckFileIntegrity "$rcforge_dir" "$is_verbose" || issues=$((issues + 1)) # Call PascalCase
    CheckPermissions "$rcforge_dir" "$is_verbose" || issues=$((issues + 1)) # Call PascalCase
    CheckEnvironment "$is_verbose" || issues=$((issues + 1)) # Call PascalCase
    CheckBashVersion || issues=$((issues + 1)) # Call PascalCase

    # Summary
    echo "" # Add a newline for separation
    if [[ $issues -eq 0 ]]; then
        SuccessMessage "All integrity checks passed successfully."
        return 0 # Return success code
    else
        ErrorMessage "Integrity check found $issues issue(s)."
        return 1 # Return failure code
    fi
}


# Run main function if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    # Exit using the return code from main
    # exit $?
fi

# EOF