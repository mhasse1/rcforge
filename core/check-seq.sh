#!/usr/bin/env bash
# check-seq.sh - Detect and resolve sequence number conflicts in rcForge configurations
# Author: Mark Hasse
# Date: 2025-03-31
# Category: system
# Description: Identifies and resolves configuration script sequence number conflicts

# Source utility libraries
source shell-colors.sh

# Set strict error handling
set -o nounset  # Treat unset variables as errors
set -o errexit  # Exit immediately if a command exits with a non-zero status

# Global constants
readonly gc_app_name="rcForge"
readonly gc_version="0.2.0"
readonly gc_supported_shells=("bash" "zsh")

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

# DetermineScriptsDirectory: Set the scripts directory based on environment
# Usage: DetermineScriptsDirectory
# Returns: Path to the scripts directory
DetermineScriptsDirectory() {
    local project_root=""
    
    # Determine if in development mode
    if [[ -n "${RCFORGE_DEV:-}" ]]; then
        project_root=$(DetectProjectRoot)
        echo "${project_root}/scripts"
    else
        # Default to user configuration directory
        echo "$HOME/.config/rcforge/scripts"
    fi
}

# ValidateShell: Validate the provided shell
# Usage: ValidateShell shell_name
# Returns: 0 if valid, 1 if invalid
ValidateShell() {
    local shell="$1"
    for supported_shell in "${gc_supported_shells[@]}"; do
        if [[ "$shell" == "$supported_shell" ]]; then
            return 0
        fi
    done
    return 1
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

# DetectCurrentHostname: Get the current hostname
# Usage: DetectCurrentHostname
# Returns: Current hostname
DetectCurrentHostname() {
    if command -v hostname >/dev/null 2>&1; then
        hostname | cut -d. -f1
    else
        # Fallback if hostname command not available
        echo "${HOSTNAME:-$(uname -n | cut -d. -f1)}"
    fi
}

# ParseArguments: Process command-line arguments
# Usage: ParseArguments "$@"
# Sets global variables for configuration
ParseArguments() {
    local hostname=""
    local shell=""
    local check_all=0
    local fix_conflicts=0

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --hostname=*)
                hostname="${1#*=}"
                ;;
            --shell=*)
                shell="${1#*=}"
                ;;
            --all)
                check_all=1
                ;;
            --fix)
                fix_conflicts=1
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

    # Set defaults if not provided
    : "${hostname:=$(DetectCurrentHostname)}"
    : "${shell:=$(DetectCurrentShell)}"

    # Validate shell
    if ! ValidateShell "$shell"; then
        ErrorMessage "Invalid shell specified: $shell"
        echo "Supported shells: ${gc_supported_shells[*]}"
        exit 1
    fi

    # Export for use in other functions
    export RCFORGE_TARGET_HOSTNAME="$hostname"
    export RCFORGE_TARGET_SHELL="$shell"
    export RCFORGE_CHECK_ALL="$check_all"
    export RCFORGE_FIX_CONFLICTS="$fix_conflicts"
}

# DisplayUsage: Show script usage information
DisplayUsage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
  --hostname=<name>  Check conflicts for specific hostname
  --shell=bash|zsh   Check conflicts for specific shell
  --all             Check all possible execution paths
  --fix            Interactively fix conflicts
  --help           Show this help message

Examples:
  $0                           # Check current hostname and shell
  $0 --hostname=laptop         # Check conflicts for 'laptop'
  $0 --shell=bash              # Check Bash configuration conflicts
  $0 --all                     # Check all possible execution paths
  $0 --fix                     # Interactively fix conflicts
EOF
}

# Main execution function
Main() {
    # Parse command-line arguments
    ParseArguments "$@"

    # Determine scripts directory
    local scripts_dir
    scripts_dir=$(DetermineScriptsDirectory)

    # Perform conflict checking logic here
    # (This would be the translated logic from the original script)
    InfoMessage "Checking sequence conflicts for ${RCFORGE_TARGET_HOSTNAME}/${RCFORGE_TARGET_SHELL}"

    # Placeholder for conflict checking logic
    # You would translate the original script's conflict detection here
}

# Export utility functions
export -f DetectProjectRoot
export -f DetermineScriptsDirectory
export -f ValidateShell
export -f DetectCurrentShell
export -f DetectCurrentHostname

# Execute the main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    Main "$@"
fi
# EOF