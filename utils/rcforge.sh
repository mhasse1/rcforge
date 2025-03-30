#!/bin/bash
# rcforge.sh - Main loader script for the rcForge shell configuration system
# Author: Mark Hasse
# Copyright: Analog Edge LLC
# Date: 2025-03-30
# Version: 0.2.0

# Set strict error handling
set -o nounset  # Treat unset variables as errors
set -o errexit  # Exit immediately if a command exits with a non-zero status

# Detect rcForge library path based on operating system
DetectRcForgePath() {
    local os=$(uname -s)
    local distribution=""
    local system_base=""
    local docs_base=""

    # Detect distribution for Linux systems
    if [[ "$os" == "Linux" ]]; then
        # ... existing distribution detection code ...
    fi

    # Define path mapping
    case "$os" in
        Darwin)
            if command -v brew >/dev/null 2>&1; then
                system_base="$(brew --prefix)/share/rcforge"
                docs_base="$(brew --prefix)/share/doc/rcforge"
            elif command -v port >/dev/null 2>&1; then
                system_base="/opt/local/share/rcforge"
                docs_base="/opt/local/share/doc/rcforge"
            else
                system_base="/usr/local/share/rcforge"
                docs_base="/usr/local/share/doc/rcforge"
            fi
            ;;
        Linux)
            case "$distribution" in
                rhel|centos|fedora|rocky|almalinux|debian|ubuntu|elementary|pop|arch|alpine|gentoo|void|nixos)
                    system_base="/usr/share/rcforge"
                    docs_base="/usr/share/doc/rcforge"
                    ;;
                *)
                    system_base="/usr/local/share/rcforge"
                    docs_base="/usr/local/share/doc/rcforge"
                    ;;
            esac
            ;;
        OpenBSD|FreeBSD|NetBSD)
            system_base="/usr/local/share/rcforge"
            docs_base="/usr/local/share/doc/rcforge"
            ;;
        SunOS)
            system_base="/usr/local/share/rcforge"
            docs_base="/usr/local/share/doc/rcforge"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            system_base="/usr/share/rcforge"
            docs_base="/usr/share/doc/rcforge"
            ;;
        *)
            system_base="/usr/local/share/rcforge"
            docs_base="/usr/local/share/doc/rcforge"
            ;;
    esac

    # Export the system and docs paths
    export RCFORGE_SYSTEM="$system_base"
    export RCFORGE_DOCS="$docs_base"

    # Return the library path (for backwards compatibility)
    echo "$system_base/lib"
}

# Detect current shell and hostname
DetectEnvironment() {
    # Detect shell type
    if [[ -n "${BASH_VERSION:-}" ]]; then
        export SHELL_TYPE="bash"
        export SHELL_VERSION="$BASH_VERSION"
    elif [[ -n "${ZSH_VERSION:-}" ]]; then
        export SHELL_TYPE="zsh"
        export SHELL_VERSION="$ZSH_VERSION"
    else
        ErrorMessage "Unsupported shell"
        return 1
    fi

    # Detect hostname
    if command -v hostname >/dev/null 2>&1; then
        export CURRENT_HOSTNAME=$(hostname | cut -d. -f1)
    else
        export CURRENT_HOSTNAME=${HOSTNAME:-$(uname -n | cut -d. -f1)}
    fi
}

# Load utility libraries
LoadUtilityLibraries() {
    local libraries=(
        "shell-colors.sh"
        "utility-functions.sh"
        "include-functions.sh"
    )

    for lib in "${libraries[@]}"; do
        local lib_path=""

        # Search potential locations, prioritizing system paths
        for search_dir in \
            "$RCFORGE_LIB" \
            "/usr/share/rcforge/lib" \
            "$HOME/.config/rcforge/lib"
        do
            if [[ -f "$search_dir/$lib" ]]; then
                lib_path="$search_dir/$lib"
                break
            fi
        done

        if [[ -n "$lib_path" ]]; then
            # Simple sourcing with basic error handling
            if ! source "$lib_path"; then
                ErrorMessage "Failed to load utility library: $lib"
                return 1
            fi
        else
            WarningMessage "Utility library not found: $lib"
        fi
    done
}

# Validate shell environment
ValidateShellEnvironment() {
    # Check Bash version for include system
    if [[ "$SHELL_TYPE" == "bash" ]]; then
        local bash_major_version=${BASH_VERSION%%.*}

        if [[ "$bash_major_version" -lt 4 ]]; then
            ErrorMessage "rcForge requires Bash 4.0+ (current version: $BASH_VERSION)"
            return 1
        fi
    fi
}

# Main rcForge initialization function
InitializeRcForge() {
    # Detect library path
    export RCFORGE_LIB=$(DetectRcForgePath)

    # Load core utility libraries
    if ! LoadUtilityLibraries; then
        ErrorMessage "Failed to load utility libraries"
        return 1
    fi

    # Detect environment details
    if ! DetectEnvironment; then
        ErrorMessage "Failed to detect shell environment"
        return 1
    fi

    # Validate shell compatibility
    if ! ValidateShellEnvironment; then
        ErrorMessage "Shell environment validation failed"
        return 1
    fi

    # Source configuration files
    SourceConfigurationFiles
}

# Source configuration files matching current environment
SourceConfigurationFiles() {
    local config_dirs=(
        "$HOME/.config/rcforge/scripts"
        "/usr/share/rcforge/scripts"
    )

    local shell_patterns=(
        "[0-9]*_global_common_*.sh"
        "[0-9]*_global_${SHELL_TYPE}_*.sh"
        "[0-9]*_${CURRENT_HOSTNAME}_common_*.sh"
        "[0-9]*_${CURRENT_HOSTNAME}_${SHELL_TYPE}_*.sh"
    )

    for dir in "${config_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            for pattern in "${shell_patterns[@]}"; do
                for config in "$dir"/$pattern; do
                    if [[ -f "$config" ]]; then
                        source "$config"
                    fi
                done
            done
        fi
    done
}

# Execute rcForge initialization
InitializeRcForge

# Optional: Run system checks if not disabled
if [[ -z "${RCFORGE_NO_CHECKS:-}" ]]; then
    # Run additional system checks in the background
    (
        "$RCFORGE_LIB/check-seq.sh" >/dev/null 2>&1
        "$RCFORGE_LIB/check-checksums.sh" >/dev/null 2>&1
    ) &
fi

# EOF