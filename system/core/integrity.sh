#!/usr/bin/env bash
# integrity.sh - Validate rcForge installation integrity
# Author: rcForge Team
# Date: 2025-04-07 # Updated for refactor
# Category: system/core
# Version: 0.4.1
# RC Summary: Checks the integrity of the rcForge installation
# Description: Validates the integrity of rcForge installation and environment

# Source required libraries
source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/utility-functions.sh"

# Set strict error handling
set -o nounset  # Treat unset variables as errors
# set -o errexit # Let functions handle errors

# Global constants initialized from environment variables set in rcforge.sh
# Use sourced constants
[ -v gc_version ]  || readonly gc_version="${RCFORGE_VERSION:-ENV_ERROR}"
[ -v gc_app_name ] || readonly gc_app_name="${RCFORGE_APP_NAME:-ENV_ERROR}"

# Define critical files needed for core operation
readonly gc_required_files=(
    "rcforge.sh"
    "system/lib/shell-colors.sh"
    "system/lib/utility-functions.sh"
    "system/core/functions.sh"
    "system/core/rc.sh" # Check for the new standalone rc script
)

readonly gc_min_bash_version="4.0" # Minimum Bash version needed for rcForge core

# ============================================================================
# RC Command Interface Functions (Local to this script)
# ============================================================================
# Function: ShowSummary
ShowSummary() {
    grep '^# RC Summary:' "$0" | sed 's/^# RC Summary: //'
}
# Function: ShowHelp
ShowHelp() {
    echo "integrity - rcForge Installation Integrity Check (v${gc_version})"
    # ... (rest of help text unchanged) ...
    echo "  0 - All integrity checks passed"
    echo "  1 - One or more integrity checks failed"
}

# ============================================================================
# DetermineRcForgeDir (REMOVED - Now sourced from utility-functions.sh)
# ============================================================================

# ============================================================================
# Integrity Check Functions (Local Helpers)
# ============================================================================
# Function: CheckFileIntegrity
CheckFileIntegrity() {
    # ... (function unchanged) ...
    local rcforge_dir="$1"
    local is_verbose="${2:-false}"
    local missing_files=false
    local file_rel_path="" # Relative path from manifest/constants

    InfoMessage "Checking for critical files..."

    for file_rel_path in "${gc_required_files[@]}"; do
        local full_path="${rcforge_dir}/${file_rel_path}"
        if [[ ! -f "$full_path" ]]; then
            ErrorMessage "Missing critical file: $full_path"
            missing_files=true
        elif [[ "$is_verbose" == "true" ]]; then
            InfoMessage "[OK] File exists: $full_path"
        fi
    done

    if [[ "$missing_files" == "true" ]]; then
        WarningMessage "File integrity check failed (missing files)."
        return 1
    else
        SuccessMessage "All critical files present."
        return 0
    fi
}
# Function: CheckPermissions
CheckPermissions() {
    # ... (function unchanged) ...
    local rcforge_dir="$1"
    local is_verbose="${2:-false}"
    local permissions_issue=false
    local item_path="" # Path to check
    local item_perms="" # Permissions string
    local expected_perms=""

    InfoMessage "Checking directory and file permissions..."

    # Check main directory permissions (expect 700)
    item_path="$rcforge_dir"
    expected_perms="700"
    item_perms=$(stat -c "%a" "$item_path" 2>/dev/null || stat -f "%Lp" "$item_path" 2>/dev/null || echo "ERR")
    if [[ "$item_perms" == "ERR" ]]; then
        ErrorMessage "Could not stat directory: $item_path"
        permissions_issue=true
    elif [[ "$item_perms" != "$expected_perms" ]]; then
        WarningMessage "Incorrect permissions for $item_path (Expected: $expected_perms, Found: $item_perms)"
        permissions_issue=true
    elif [[ "$is_verbose" == "true" ]]; then
        InfoMessage "[OK] Directory permissions correct ($expected_perms): $item_path"
    fi

    # Check critical file permissions (executables 700, others 600)
    for file_rel_path in "${gc_required_files[@]}"; do
        item_path="${rcforge_dir}/${file_rel_path}"
        # Skip check if file was missing (already reported)
        [[ ! -f "$item_path" ]] && continue

        if [[ "$item_path" == *.sh ]]; then
            expected_perms="700" # Executable scripts
        else
            expected_perms="600" # Non-executable files (libs, potentially docs if listed)
        fi

        item_perms=$(stat -c "%a" "$item_path" 2>/dev/null || stat -f "%Lp" "$item_path" 2>/dev/null || echo "ERR")
        if [[ "$item_perms" == "ERR" ]]; then
             ErrorMessage "Could not stat file: $item_path"
             permissions_issue=true
        elif [[ "$item_perms" != "$expected_perms" ]]; then
            WarningMessage "Incorrect permissions for $item_path (Expected: $expected_perms, Found: $item_perms)"
            permissions_issue=true
        elif [[ "$is_verbose" == "true" ]]; then
             InfoMessage "[OK] File permissions correct ($expected_perms): $item_path"
        fi
    done

    # Check subdirectories explicitly (lib, core, utils, rc-scripts, user utils, backups, docs)
    local subdirs=("system/lib" "system/core" "system/utils" "rc-scripts" "utils" "backups" "docs")
    expected_perms="700" # Directories should be 700
    for subdir in "${subdirs[@]}"; do
        item_path="${rcforge_dir}/${subdir}"
        # Check if directory exists before checking perms
        if [[ -d "$item_path" ]]; then
            item_perms=$(stat -c "%a" "$item_path" 2>/dev/null || stat -f "%Lp" "$item_path" 2>/dev/null || echo "ERR")
            if [[ "$item_perms" == "ERR" ]]; then
                ErrorMessage "Could not stat directory: $item_path"
                permissions_issue=true
            elif [[ "$item_perms" != "$expected_perms" ]]; then
                WarningMessage "Incorrect permissions for $item_path (Expected: $expected_perms, Found: $item_perms)"
                permissions_issue=true
            elif [[ "$is_verbose" == "true" ]]; then
                InfoMessage "[OK] Directory permissions correct ($expected_perms): $item_path"
            fi
        else
             VerboseMessage "$is_verbose" "Directory not found (optional?): $item_path"
        fi
    done


    if [[ "$permissions_issue" == "true" ]]; then
        WarningMessage "Permission check found issues."
        return 1
    else
        SuccessMessage "Permissions check completed successfully."
        return 0
    fi
}
# Function: CheckEnvironment
CheckEnvironment() {
    # ... (function unchanged) ...
    local is_verbose="${1:-false}"
    local env_issue=false
    local var="" # Loop variable
    local var_value=""

    InfoMessage "Checking environment variables..."

    # Standard variables expected to be set by rcforge.sh
    local standard_vars=(
        "RCFORGE_ROOT"
        "RCFORGE_SCRIPTS"
        "RCFORGE_LIB"
        "RCFORGE_CORE" # Added core
        "RCFORGE_UTILS"
        "RCFORGE_USER_UTILS" # Added user utils
    )

    for var in "${standard_vars[@]}"; do
        # Use indirect expansion with default to get value safely
        var_value="${!var:-}"

        if [[ -z "$var_value" ]]; then
            ErrorMessage "$var is not set." # More direct error
            env_issue=true
        else
            # Check if the directory it points to exists
            if [[ ! -d "$var_value" ]]; then
                ErrorMessage "Directory for $var does not exist: $var_value"
                env_issue=true
            elif [[ "$is_verbose" == "true" ]]; then
                InfoMessage "[OK] $var = $var_value (exists)"
            fi
        fi
    done

    if [[ "$env_issue" == "true" ]]; then
        WarningMessage "Environment variable check found issues."
        return 1
    else
        SuccessMessage "Environment variables check completed successfully."
        return 0
    fi
}
# Function: CheckBashVersionLocal
CheckBashVersionLocal() {
    # ... (function unchanged) ...
    local is_verbose="$1"
    InfoMessage "Checking Bash version..."

    if [[ -z "${BASH_VERSION:-}" ]]; then
        ErrorMessage "Not running in Bash shell. Current shell: $(basename "$SHELL")"
        WarningMessage "rcForge core requires Bash ${gc_min_bash_version}+."
        return 1 # Treat as failure for integrity check
    fi

    # Use sort -V for robust comparison
    if printf '%s\n%s\n' "$gc_min_bash_version" "$BASH_VERSION" | sort -V -C &>/dev/null; then
        if [[ "$is_verbose" == "true" ]]; then
             InfoMessage "[OK] Bash version $BASH_VERSION >= $gc_min_bash_version"
        fi
        SuccessMessage "Bash version meets minimum requirement ($gc_min_bash_version+)."
        return 0
    else
        ErrorMessage "Bash version $BASH_VERSION is lower than required version $gc_min_bash_version."
        return 1
    fi
}

# ============================================================================
# Function: main
# ============================================================================
main() {
    local is_verbose=false
    local overall_status=0 # Use 0 for success, 1 for failure

    # Process command arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --verbose|-v) is_verbose=true ;;
            --help|-h) ShowHelp; exit 0 ;;
            --summary) ShowSummary; exit 0 ;;
            *)
                ErrorMessage "Unknown option: $1"
                ShowHelp
                exit 1 ;;
        esac
        shift
    done

    SectionHeader "rcForge v${gc_version} Integrity Check" # Use sourced function

    # Determine rcForge directory (use sourced function)
    local rcforge_dir
    rcforge_dir=$(DetermineRcForgeDir) # Uses sourced function
    if [[ ! -d "$rcforge_dir" ]]; then
         ErrorMessage "rcForge installation directory not found: $rcforge_dir"
         exit 1
    fi
    InfoMessage "Checking installation at: $rcforge_dir"
    echo ""


    # Perform integrity checks, update overall_status on failure
    CheckFileIntegrity "$rcforge_dir" "$is_verbose" || overall_status=1
    echo ""
    CheckPermissions "$rcforge_dir" "$is_verbose" || overall_status=1
    echo ""
    CheckEnvironment "$is_verbose" || overall_status=1
    echo ""
    CheckBashVersionLocal "$is_verbose" || overall_status=1 # Use local renamed check
    echo ""

    # Final summary based on overall_status
    if [[ $overall_status -eq 0 ]]; then
        SuccessMessage "All integrity checks passed successfully."
    else
        ErrorMessage "One or more integrity checks failed. Please review the output above."
    fi

    exit $overall_status
}


# Execute main function if run directly or via rc command wrapper
if IsExecutedDirectly || [[ "$0" == *"rc"* ]]; then # Use sourced function
    main "$@"
fi

# EOF