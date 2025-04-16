#!/usr/bin/env bash
# check-checksums.sh - Verify checksums of standard shell RC files
# Author: Mark Hasse / rcForge Team (AI Refactored)
# Date: 2025-04-16 # Updated Date
# Version: 0.4.2 # Core Version
# Category: system/utility
# RC Summary: Checks and validates checksums for shell configuration files (.bashrc, .zshrc).
# Description: Verifies checksums for standard shell configuration files
#              (~/.bashrc, ~/.zshrc) against previously stored values.
#              Includes an option to update stored checksums if files change.

# Source necessary libraries (utility-functions sources shell-colors)
# RCFORGE_LIB should be set by the rc command wrapper or sourced environment
source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/utility-functions.sh"

# Set strict error handling
set -o nounset # Treat unset variables as errors
# set -o errexit  # Let functions handle errors and return status
set -o pipefail # Ensure pipeline fails on any component failing

# ============================================================================
# GLOBAL CONSTANTS (Readonly)
# ============================================================================
# Inherited from sourced utility-functions: gc_version, gc_app_name
readonly gc_supported_rc_files=(
    ".bashrc"
    ".zshrc"
    # Add other relevant RC files here if needed in the future
)

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# ============================================================================
# Function: CalculateChecksum
# Description: Calculate the MD5 checksum of a given file. Handles macOS (md5)
#              and Linux (md5sum) differences.
# Usage: local sum; sum=$(CalculateChecksum "/path/to/file") || HandleError
# Arguments:
#   $1 (required) - Path to the file to checksum.
# Returns: Echoes the MD5 checksum string on success. Returns status 1 on error.
# ============================================================================
CalculateChecksum() {
    local file_path="$1"
    local checksum=""

    # Check if file exists and is readable first
    if [[ ! -f "$file_path" ]]; then
        # Warning issued by caller (VerifyRcFileChecksum)
        return 1
    elif [[ ! -r "$file_path" ]]; then
        WarningMessage "Cannot read file for checksum calculation: $file_path"
        return 1
    fi

    # Calculate checksum based on OS
    case "$(uname -s)" in
        Darwin)
            # macOS uses md5
            checksum=$(md5 -q "$file_path")
            ;;
        *)
            # Linux and other Unix-like systems use md5sum
            checksum=$(md5sum "$file_path" | awk '{ print $1 }')
            ;;
    esac

    # Check if checksum calculation succeeded (produced non-empty output)
    if [[ -n "$checksum" ]]; then
        echo "$checksum"
        return 0
    else
        WarningMessage "Checksum calculation failed for: $file_path"
        return 1
    fi
}

# ============================================================================
# Function: VerifyRcFileChecksum
# Description: Verify checksum for a specific RC file against its stored checksum.
#              Optionally updates the stored checksum if fix_mode is true.
# Usage: VerifyRcFileChecksum rc_file checksum_file rc_name fix_mode
# Arguments:
#   $1 (required) - Full path to the RC file (e.g., ~/.bashrc).
#   $2 (required) - Full path to the corresponding checksum file.
#   $3 (required) - Short name of the RC file (e.g., .bashrc).
#   $4 (required) - Boolean ('true'/'false') indicating if fix mode is active.
# Returns: 0 if checksum matches, file doesn't exist, or checksum updated successfully.
#          1 if checksum mismatches and fix_mode was false.
# ============================================================================
VerifyRcFileChecksum() {
    local rc_file="$1"
    local checksum_file="$2"
    local rc_name="$3"
    local fix_mode="$4" # Renamed from RCFORGE_FIX_CHECKSUMS env var
    local current_sum=""
    local stored_sum=""

    # Skip check if the RC file doesn't exist in the user's home directory
    if [[ ! -f "$rc_file" ]]; then
        # InfoMessage "RC file not found, skipping checksum check: $rc_name" # Optional info
        return 0
    fi

    # Calculate current checksum first, handle potential error
    current_sum=$(CalculateChecksum "$rc_file")
    if [[ $? -ne 0 ]]; then
        # Error message already printed by CalculateChecksum
        return 1 # Propagate error
    fi

    # Initialize checksum file if it doesn't exist
    if [[ ! -f "$checksum_file" ]]; then
        InfoMessage "Initializing checksum for ${rc_name}..."
        # Write the already calculated checksum
        if echo "$current_sum" >"$checksum_file"; then
            # Set permissions after writing
            if ! chmod 600 "$checksum_file"; then
                WarningMessage "Could not set permissions (600) on: $checksum_file"
            fi
            SuccessMessage "Checksum stored for ${rc_name}."
            return 0
        else
            WarningMessage "Failed to write initial checksum for ${rc_name} to: $checksum_file"
            return 1 # Indicate failure
        fi
    fi

    # Get stored checksum
    stored_sum=$(cat "$checksum_file")

    # Compare checksums
    if [[ "$stored_sum" == "$current_sum" ]]; then
        # Match! No action needed, return success.
        return 0
    fi

    # --- Mismatch Detected ---
    TextBlock "CHECKSUM MISMATCH DETECTED for ${rc_name}" "$RED" "${BG_WHITE:-$BG_RED}"
    WarningMessage "File may have been modified unexpectedly: ${rc_name} ($rc_file)"
    InfoMessage "  Stored Checksum: $stored_sum"
    InfoMessage "  Actual Checksum: $current_sum"

    # Update the checksum file if fix mode is enabled
    if [[ "$fix_mode" == "true" ]]; then
        InfoMessage "Attempting to update checksum for ${rc_name} (--fix enabled)..."
        if echo "$current_sum" >"$checksum_file"; then
            # Re-verify permissions after writing
            if ! chmod 600 "$checksum_file"; then
                WarningMessage "Could not set permissions (600) on updated: $checksum_file"
            fi
            SuccessMessage "Checksum updated successfully for ${rc_name}."
            return 0 # Return 0 because the mismatch was resolved by fixing
        else
            ErrorMessage "Failed to update checksum file: $checksum_file"
            return 1 # Return 1 indicating fix failure
        fi
    else
        # Mismatch found, fix mode not enabled
        WarningMessage "Run with --fix to update the stored checksum to match the current file."
        return 1 # Return 1 indicating an unresolved mismatch
    fi
}

# ============================================================================
# Function: ShowHelp
# Description: Displays help information for the check-checksums utility.
# Usage: ShowHelp
# Arguments: None
# Returns: None. Prints help message to stdout. Exits script.
# ============================================================================
ShowHelp() {
    local script_specific_options
    # Format script-specific options for clarity
    script_specific_options=$(
        cat <<EOF
  --fix              Update stored checksums to match current RC files if mismatches are found.
EOF
    )
    # Use the standard help function from utility-functions.sh
    ShowStandardHelp "$script_specific_options" "$0" # Pass $0 for script name detection
    exit 0
}

# ============================================================================
# Function: main
# Description: Main execution logic for the check-checksums script.
# Usage: main "$@"
# Arguments:
#   $@ - Command line arguments passed to the script.
# Returns: 0 if checksums are OK or successfully fixed, 1 otherwise.
# ============================================================================
main() {
    local fix_mode=false # Default to check-only
    local rcforge_dir=""
    local checksum_dir=""
    local any_unresolved_mismatch=0 # Track overall status
    local rc_file_basename=""       # Loop variable
    local full_rc_path=""           # Loop variable
    local checksum_path=""          # Loop variable

    # --- Argument Parsing ---
    # Simple loop for this utility's specific options
    while [[ $# -gt 0 ]]; do
        local key="$1"
        case "$key" in
            --fix)
                fix_mode=true
                shift
                ;;
            # Standard args handled by wrapper or direct call patterns
            -h | --help) ShowHelp ;; # Exits
            --summary)
                ExtractSummary "$0"
                exit $?
                ;; # Exits
            --version)
                ShowVersionInfo "$0"
                exit 0
                ;; # Exits
            --)
                shift
                break
                ;; # End of options
            -*)
                ErrorMessage "Unknown option: $key"
                ShowHelp
                ;; # Exits
            *)
                ErrorMessage "Unexpected positional argument: $key"
                ShowHelp
                ;; # Exits
        esac
    done
    # --- End Argument Parsing ---

    # Determine rcForge directory using sourced function
    rcforge_dir=$(DetectRcForgeDir) # Use sourced function

    # Define checksum directory path
    checksum_dir="${rcforge_dir}/docs/checksums" # Store in docs/checksums

    # Ensure checksum directory exists
    if ! mkdir -p "$checksum_dir"; then
        ErrorMessage "Cannot create checksum directory: $checksum_dir" 1 # Exit with error code
    fi
    # Corrected permission check logic:
    if ! chmod 700 "$checksum_dir"; then
        WarningMessage "Could not set permissions (700) on: $checksum_dir"
    fi

    SectionHeader "rcForge RC File Checksum Verification"
    if [[ "$fix_mode" == "true" ]]; then
        InfoMessage "Running in FIX mode: Stored checksums will be updated on mismatch."
    else
        InfoMessage "Running in CHECK mode. Use --fix to update checksums on mismatch."
    fi
    echo "" # Add newline

    # Verify checksums for each supported RC file
    for rc_file_basename in "${gc_supported_rc_files[@]}"; do
        full_rc_path="${HOME}/${rc_file_basename}"
        checksum_path="${checksum_dir}/${rc_file_basename}.md5"

        # Call local verification function, update overall status if it returns non-zero
        if ! VerifyRcFileChecksum "$full_rc_path" "$checksum_path" "$rc_file_basename" "$fix_mode"; then
            any_unresolved_mismatch=1
        fi
    done

    # Report final overall status
    echo "" # Add newline before final message
    if [[ $any_unresolved_mismatch -eq 1 ]]; then
        WarningMessage "Checksum verification finished: One or more files have changed and were not updated (--fix not used or failed)."
        return 1 # Indicate failure/unresolved mismatch
    else
        # Only show success if not in fix mode (fix mode shows individual success/updates)
        if [[ "$fix_mode" == "false" ]]; then
            SuccessMessage "Checksum verification finished: All checked RC file checksums are valid."
        else
            # In fix mode, just indicate completion if no errors occurred during fixing
            SuccessMessage "Checksum verification/update process finished."
        fi
        return 0 # Indicate success
    fi
}

# ============================================================================
# Script Execution Guard
# ============================================================================
# Ensure main execution logic runs only when script is executed directly
# or via the 'rc' command wrapper function. Uses sourced IsExecutedDirectly.
if IsExecutedDirectly || [[ "$0" == *"rc"* ]]; then
    main "$@"
    exit $? # Exit with status from main function
fi

# EOF
