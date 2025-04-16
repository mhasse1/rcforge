#!/usr/bin/env bash
# check-checksums.sh - Verify checksums of shell RC files
# Author: Mark Hasse
# Date: 2025-04-06
# Category: system/core # Updated Category for core script
# Version: 0.4.1
# Description: Checks and validates checksums for shell configuration files (.bashrc, .zshrc)

# Source utility libraries
source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/utility-functions.sh"

# Set strict error handling
set -o nounset # Treat unset variables as errors
# set -o errexit  # Exit immediately if a command exits with a non-zero status

# Global constants initialized from environment variables set in rcforge.sh
[[ -v gc_version ]] || readonly gc_version="${RCFORGE_VERSION:-ENV_ERROR}"
[[ -v gc_app_name ]] || readonly gc_app_name="${RCFORGE_APP_NAME:-ENV_ERROR}"
readonly gc_supported_rc_files=(
    ".bashrc"
    ".zshrc"
)

# ============================================================================
# Function: DetermineRcForgeDir
# Description: Determine the effective rcForge root directory.
#              Checks RCFORGE_ROOT env var first, then defaults to standard user config path.
# Usage: DetermineRcForgeDir
# Returns: Echoes the path to the rcForge configuration directory.
# ============================================================================
DetermineRcForgeDir() {
    # Use RCFORGE_ROOT if set and is a directory, otherwise default
    if [[ -n "${RCFORGE_ROOT:-}" && -d "${RCFORGE_ROOT}" ]]; then
        echo "${RCFORGE_ROOT}"
    else
        echo "$HOME/.config/rcforge"
    fi
}

# ============================================================================
# Function: CalculateChecksum
# Description: Calculate the MD5 checksum of a given file.
#              Handles differences between macOS (md5) and Linux (md5sum).
# Usage: CalculateChecksum filepath
# Arguments:
#   filepath (required) - Path to the file to checksum.
# Returns: Echoes the MD5 checksum of the file. Assumes file exists (caller checks).
# ============================================================================
CalculateChecksum() {
    local file="$1"
    # Assume file exists, caller should verify first

    case "$(uname -s)" in
        Darwin)
            # macOS uses md5
            md5 -q "$file"
            ;;
        *)
            # Linux and other Unix-like systems use md5sum
            md5sum "$file" | awk '{ print $1 }'
            ;;
    esac
}

# ============================================================================
# Function: ParseArguments
# Description: Process command-line arguments for the script.
#              Sets RCFORGE_FIX_CHECKSUMS environment variable if --fix is present.
# Usage: ParseArguments "$@"
# Arguments: Passes all script arguments ("$@").
# Returns: None. Exports RCFORGE_FIX_CHECKSUMS. Exits on --help or unknown arg.
# ============================================================================
ParseArguments() {
    local fix_checksums=0 # Use local variable

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --fix)
                fix_checksums=1
                ;;
            --help)
                DisplayUsage # Call function
                exit 0
                ;;
            *)
                ErrorMessage "Unknown parameter: $1"
                DisplayUsage # Call function
                exit 1
                ;;
        esac
        shift
    done

    export RCFORGE_FIX_CHECKSUMS="$fix_checksums"
}

# ============================================================================
# Function: DisplayUsage
# Description: Show script usage information and examples.
# Usage: DisplayUsage
# Arguments: None
# Returns: None. Prints usage to stdout.
# ============================================================================
DisplayUsage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --fix    Update checksum files to match current RC files"
    echo "  --help   Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0          Check RC file checksums"
    echo "  $0 --fix    Update checksums if files have changed"
}

# ============================================================================
# Function: VerifyRcFileChecksum
# Description: Verify checksum for a specific RC file against its stored checksum.
#              Optionally updates the stored checksum if --fix is enabled.
# Usage: VerifyRcFileChecksum rc_file checksum_file rc_name
# Arguments:
#   rc_file (required) - Full path to the RC file (e.g., ~/.bashrc).
#   checksum_file (required) - Full path to the corresponding checksum file.
#   rc_name (required) - Short name of the RC file (e.g., .bashrc).
# Returns:
#   0 - If checksum matches, file doesn't exist, or checksum was updated successfully.
#   1 - If checksum mismatches and --fix was not specified.
# ============================================================================
VerifyRcFileChecksum() {
    local rc_file="$1"
    local checksum_file="$2"
    local rc_name="$3"
    local current_sum=""
    local stored_sum=""

    # Skip if the RC file doesn't exist in the user's home directory
    [[ ! -f "$rc_file" ]] && return 0

    # Initialize checksum file if it doesn't exist
    if [[ ! -f "$checksum_file" ]]; then
        InfoMessage "Initializing checksum for $rc_name..."
        current_sum=$(CalculateChecksum "$rc_file") # Call
        echo "$current_sum" >"$checksum_file"
        SuccessMessage "Checksum stored for $rc_name."
        return 0
    fi

    # Get stored and current checksums
    stored_sum=$(cat "$checksum_file")
    current_sum=$(CalculateChecksum "$rc_file") # Call

    # Compare checksums
    if [[ "$stored_sum" != "$current_sum" ]]; then
        TextBlock "CHECKSUM MISMATCH DETECTED" "$RED" "${BG_WHITE:-}" # Use standard color vars

        WarningMessage "File changed: $rc_name"
        InfoMessage "Current shell: $(DetectShell)" # Call
        InfoMessage "Expected checksum: $stored_sum"
        InfoMessage "Actual checksum:   $current_sum" # Aligned for readability

        # Update the checksum if fix flag is set
        if [[ "${RCFORGE_FIX_CHECKSUMS:-0}" -eq 1 ]]; then
            InfoMessage "Updating checksum for $rc_name..."
            echo "$current_sum" >"$checksum_file"
            SuccessMessage "Checksum updated for $rc_name."
            return 0 # Return 0 as the mismatch was resolved
        else
            WarningMessage "To update the checksum, run with --fix option."
            return 1 # Return 1 indicating an unresolved mismatch
        fi
    fi

    # Checksums match
    return 0
}

# Within system/core/check-checksums.sh

# ... (rest of the script above main) ...

# ============================================================================
# Function: main
# Description: Main execution logic.
# Usage: main "$@"
# Returns: 0 if OK/fixed, 1 otherwise. Uses 'return' if sourced, 'exit' otherwise.
# ============================================================================
main() {
    local is_sourced=false
    # Check if the first argument is --sourced (and remove it)
    if [[ "${1:-}" == "--sourced" ]]; then
        is_sourced=true
        shift
    fi

    # Parse command-line arguments (remaining ones)
    ParseArguments "$@" # Call local function

    # Determine rcForge directory using sourced function
    local rcforge_dir
    rcforge_dir=$(DetermineRcForgeDir) # Call sourced function

    # Define and create checksum directory if it doesn't exist
    local checksum_dir="${rcforge_dir}/checksums"
    mkdir -p "$checksum_dir" || {
        ErrorMessage "Cannot create checksum directory: $checksum_dir"
        if $is_sourced; then return 1; else exit 1; fi
    }
    chmod 700 "$checksum_dir" || WarningMessage "Could not set permissions (700) on $checksum_dir"

    # Track if any mismatch occurred and wasn't fixed
    local any_unresolved_mismatch=0

    InfoMessage "Verifying RC file checksums..."

    # Verify checksums for each supported RC file
    local rc_file_basename="" # Loop variable
    for rc_file_basename in "${gc_supported_rc_files[@]}"; do
        local full_rc_path="${HOME}/${rc_file_basename}"
        local checksum_path="${checksum_dir}/${rc_file_basename}.md5"

        # Call local function
        if ! VerifyRcFileChecksum "$full_rc_path" "$checksum_path" "$rc_file_basename"; then
            any_unresolved_mismatch=1
        fi
    done

    # Report final status
    if [[ $any_unresolved_mismatch -eq 1 ]]; then
        WarningMessage "One or more RC files have changed. Run with --fix to update checksums."
    else
        if [[ "${RCFORGE_FIX_CHECKSUMS:-0}" -ne 1 ]]; then
            SuccessMessage "All RC file checksums verified successfully."
        fi
    fi

    # Use return if sourced, exit otherwise
    if [[ "$is_sourced" == "true" ]]; then
        return $any_unresolved_mismatch
    else
        # This part is only reached when executed directly
        # We don't need an explicit exit here if the bottom execution block handles it
        : # No action needed, main function ends, execution block handles exit
    fi
}

# Execute the main function IF NOT sourced OR if sourced but called directly/via rc
# The IsExecutedDirectly check handles direct `bash script.sh` calls.
# The "$0" == *"rc"* check handles being called via the `rc` wrapper script.
# We need to pass arguments correctly, stripping --sourced if present.

_main_args=("$@") # Copy original args
_is_sourced_arg=false
if [[ "${_main_args[0]:-}" == "--sourced" ]]; then
    _is_sourced_arg=true
    # Remove --sourced for passing to main when executed directly
    unset '_main_args[0]'           # Remove element (might leave gap)
    _main_args=("${_main_args[@]}") # Re-index array
fi

# Only run main and exit if NOT sourced during rcforge.sh init
# Or if sourced but called via rc wrapper (where exit is ok)
if ! $_is_sourced_arg || [[ "$0" == *"rc"* ]]; then
    if IsExecutedDirectly || [[ "$0" == *"rc"* ]]; then
        main "${_main_args[@]}" # Pass potentially modified args
        exit $?                 # Exit with the status from main
    fi
fi

# EOF
