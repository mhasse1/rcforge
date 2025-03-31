#!/usr/bin/env bash
# check-checksums.sh - Verify checksums of shell RC files
# Author: Mark Hasse
# Date: 2025-03-31
# Category: system
# Description: Checks and validates checksums for shell configuration files

# Source utility libraries
source shell-colors.sh

# Set strict error handling
set -o nounset  # Treat unset variables as errors
set -o errexit  # Exit immediately if a command exits with a non-zero status

# Global constants
readonly gc_app_name="rcForge"
readonly gc_version="0.2.0"
readonly gc_supported_rc_files=(
    ".bashrc"
    ".zshrc"
)

# DetectProjectRoot: Dynamically determine the project's root directory
# Usage: DetectProjectRoot
# Returns: Path to the project root directory
DetectProjectRoot() {
    local possible_roots=(
        "${RCFORGE_ROOT:-}"                  # Explicitly set environment variable
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

    # Fallback to user configuration directory
    echo "$HOME/.config/rcforge"
    return 0
}

# DetermineRcforgeDir: Set the rcForge directory based on environment
# Usage: DetermineRcforgeDir
# Returns: Path to the rcForge configuration directory
DetermineRcforgeDir() {
    local project_root=""
    
    # Determine if in development mode
    if [[ -n "${RCFORGE_DEV:-}" ]]; then
        project_root=$(DetectProjectRoot)
        echo "$project_root"
    else
        # Default to user configuration directory
        echo "$HOME/.config/rcforge"
    fi
}

# DetectCurrentShell: Determine the current shell
# Usage: DetectCurrentShell
# Returns: Name of the current shell
DetectCurrentShell() {
    if [[ -n "$ZSH_VERSION" ]]; then
        echo "zsh"
    elif [[ -n "$BASH_VERSION" ]]; then
        echo "bash"
    else
        # Fallback to $SHELL
        basename "$SHELL"
    fi
}

# CalculateChecksum: Calculate the checksum of a file
# Usage: CalculateChecksum filepath
# Returns: Checksum of the file or "NONE" if file doesn't exist
CalculateChecksum() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        echo "NONE"
        return 1
    }
    
    case "$(uname -s)" in
        Darwin)
            # macOS uses md5 instead of md5sum
            md5 -q "$file" 2>/dev/null
            ;;
        *)
            # Linux and other Unix-like systems
            md5sum "$file" 2>/dev/null | awk '{ print $1 }'
            ;;
    esac
}

# ParseArguments: Process command-line arguments
# Usage: ParseArguments "$@"
# Sets global variables for configuration
ParseArguments() {
    local fix_checksums=0

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --fix)
                fix_checksums=1
                ;;
            --help)
                DisplayUsage
                exit 0
                ;;
            *)
                ErrorMessage "Unknown parameter: $1"
                DisplayUsage
                exit 1
                ;;
        esac
        shift
    done

    # Export for use in other functions
    export RCFORGE_FIX_CHECKSUMS="$fix_checksums"
}

# DisplayUsage: Show script usage information
DisplayUsage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
  --fix    Update checksum files to match current RC files
  --help   Show this help message

Examples:
  $0               Check RC file checksums
  $0 --fix         Update checksums if files have changed
EOF
}

# VerifyRcFileChecksum: Verify checksum for a specific RC file
# Usage: VerifyRcFileChecksum rc_file checksum_file rc_name
# Returns: 0 if checksum matches, 1 if mismatch
VerifyRcFileChecksum() {
    local rc_file="$1"
    local checksum_file="$2"
    local rc_name="$3"
    local current_sum=""
    local stored_sum=""

    # Skip if the RC file doesn't exist
    [[ ! -f "$rc_file" ]] && return 0

    # Initialize checksums if they don't exist
    if [[ ! -f "$checksum_file" ]]; then
        current_sum=$(CalculateChecksum "$rc_file")
        echo "$current_sum" > "$checksum_file"
        return 0
    fi

    # Get stored and current checksums
    stored_sum=$(cat "$checksum_file")
    current_sum=$(CalculateChecksum "$rc_file")

    # Compare checksums
    if [[ "$stored_sum" != "$current_sum" ]]; then
        TextBlock "CHECKSUM MISMATCH DETECTED" "$c_RED" "$c_BG_WHITE"
        
        WarningMessage "File changed: $rc_name"
        InfoMessage "Current shell: $(DetectCurrentShell)"
        InfoMessage "Expected checksum: $stored_sum"
        InfoMessage "Actual checksum: $current_sum"

        # Update the checksum if fix flag is set
        if [[ "${RCFORGE_FIX_CHECKSUMS:-0}" -eq 1 ]]; then
            echo "$current_sum" > "$checksum_file"
            SuccessMessage "Updated checksum for $rc_name"
            return 0
        else
            WarningMessage "To update the checksum, run: $0 --fix"
            return 1
        fi
    fi

    return 0
}

# Main execution function
Main() {
    # Parse command-line arguments
    ParseArguments "$@"

    # Determine rcForge directory
    local rcforge_dir
    rcforge_dir=$(DetermineRcforgeDir)

    # Create checksum directory if it doesn't exist
    local checksum_dir="${rcforge_dir}/checksums"
    mkdir -p "$checksum_dir"

    # Track any mismatches
    local any_mismatch=0

    # Verify checksums for each supported RC file
    for rc_file in "${gc_supported_rc_files[@]}"; do
        local full_rc_path="${HOME}/${rc_file}"
        local checksum_path="${checksum_dir}/${rc_file}.md5"

        if ! VerifyRcFileChecksum "$full_rc_path" "$checksum_path" "$rc_file"; then
            any_mismatch=1
        fi
    done

    # Exit with appropriate status
    exit $any_mismatch
}

# Export utility functions
export -f DetectProjectRoot
export -f DetermineRcforgeDir
export -f CalculateChecksum
export -f DetectCurrentShell

# Execute the main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    Main "$@"
fi
# EOF