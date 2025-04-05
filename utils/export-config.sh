#!/usr/bin/env bash
# export-config.sh - Export shell configurations for remote servers
# Author: Mark Hasse
# Copyright: Analog Edge LLC
# Date: 2025-03-30
# Version: 0.2.1
# Description: Exports rcForge shell configurations with flexible options

# Import core utility libraries
source shell-colors.sh

# Set strict error handling
set -o nounset  # Treat unset variables as errors
set -o errexit  # Exit immediately if a command exits with a non-zero status

# Global constants
readonly gc_app_name="rcForge"
readonly gc_version="0.2.1"
readonly gc_default_export_dir="${HOME}/.config/rcforge/exports"

# Configuration variables
export SHELL_TYPE=""
export HOSTNAME=""
export OUTPUT_FILE=""
export VERBOSE_MODE=false
export KEEP_DEBUG=false
export STRIP_COMMENTS=true
export FORCE_OVERWRITE=false

# Detect project root dynamically
DetectProjectRoot() {
    local possible_roots=(
        "${RCFORGE_ROOT:-}"
        "$HOME/src/rcforge"
        "$HOME/Projects/rcforge"
        "/usr/share/rcforge"
        "/opt/homebrew/share/rcforge"
        "$(brew --prefix 2>/dev/null)/share/rcforge"
        "/opt/local/share/rcforge"
        "/usr/local/share/rcforge"
        "$HOME/.config/rcforge"
    )

    for dir in "${possible_roots[@]}"; do
        if [[ -n "$dir" && -d "$dir" && -f "$dir/rcforge.sh" ]]; then
            echo "$dir"
            return 0
        fi
    done

    # Fallback to user configuration directory
    echo "$HOME/.config/rcforge"
}

# Validate input shell type
ValidateShellType() {
    local shell="$1"
    if [[ "$shell" != "bash" && "$shell" != "zsh" ]]; then
        ErrorMessage "Invalid shell type. Must be 'bash' or 'zsh'."
        return 1
    fi
    return 0
}

# Parse command-line arguments
ParseArguments() {
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --shell=*)
                SHELL_TYPE="${1#*=}"
                ValidateShellType "$SHELL_TYPE" || exit 1
                ;;
            --hostname=*)
                HOSTNAME="${1#*=}"
                ;;
            --output=*)
                OUTPUT_FILE="${1#*=}"
                ;;
            --verbose|-v)
                VERBOSE_MODE=true
                ;;
            --keep-debug)
                KEEP_DEBUG=true
                STRIP_COMMENTS=false
                ;;
            --force|-f)
                FORCE_OVERWRITE=true
                ;;
            --help|-h)
                DisplayHelp
                exit 0
                ;;
            --version)
                DisplayVersion
                exit 0
                ;;
            *)
                ErrorMessage "Unknown parameter: $1"
                DisplayHelp
                exit 1
                ;;
        esac
        shift
    done

    # Validate required parameters
    if [[ -z "$SHELL_TYPE" ]]; then
        ErrorMessage "Shell type must be specified (--shell=bash or --shell=zsh)"
        exit 1
    fi
}

# Display help information
DisplayHelp() {
    SectionHeader "${gc_app_name} Configuration Export Utility"
    
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --shell=TYPE         Specify shell type (bash or zsh) [REQUIRED]"
    echo "  --hostname=NAME      Filter configurations for specific hostname"
    echo "  --output=FILE        Specify output file path"
    echo "  --verbose, -v        Enable verbose output"
    echo "  --keep-debug         Preserve debug statements"
    echo "  --force, -f          Overwrite existing output file"
    echo "  --help, -h           Show this help message"
    echo "  --version            Show version information"
    echo ""
    echo "Examples:"
    echo "  $0 --shell=bash                 Export all Bash configurations"
    echo "  $0 --shell=zsh --hostname=laptop Export Zsh configs for 'laptop'"
    echo "  $0 --shell=bash --output=~/bashrc.exported"
}

# Display version information
DisplayVersion() {
    TextBlock "${gc_app_name} Configuration Export Utility" "$CYAN"
    echo "Version: ${gc_version}"
    echo "Copyright: Analog Edge LLC"
    echo "License: MIT"
}

# Find configuration files to export
FindConfigFiles() {
    local shell_type="$1"
    local hostname="${2:-}"
    local scripts_dir="${RCFORGE_DIR}/scripts"

    # Build pattern for file matching
    local patterns=(
        "[0-9]*_global_common_*.sh"
        "[0-9]*_global_${shell_type}_*.sh"
    )

    # Add hostname-specific patterns if provided
    if [[ -n "$hostname" ]]; then
        patterns+=(
            "[0-9]*_${hostname}_common_*.sh"
            "[0-9]*_${hostname}_${shell_type}_*.sh"
        )
    fi

    # Find matching files
    local config_files=()
    for pattern in "${patterns[@]}"; do
        while IFS= read -r -d '' file; do
            [[ -f "$file" ]] && config_files+=("$file")
        done < <(find "$scripts_dir" -maxdepth 1 -type f -name "$pattern" -print0 2>/dev/null)
    done

    # Validate found files
    if [[ ${#config_files[@]} -eq 0 ]]; then
        ErrorMessage "No configuration files found for shell: $shell_type${hostname:+ (hostname: $hostname)}"
        return 1
    fi

    # Sort files to ensure consistent order
    IFS=$'\n' config_files=($(sort <<< "${config_files[*]}"))
    unset IFS

    # Print found files in verbose mode
    if [[ "$VERBOSE_MODE" == true ]]; then
        InfoMessage "Found ${#config_files[@]} configuration files:"
        printf '  %s\n' "${config_files[@]}"
    fi

    # Output array of files
    printf '%s\n' "${config_files[@]}"
}

# Process configuration files
ProcessConfigFiles() {
    local files=("$@")
    local output_content=""

    # Add header
    output_content+="#!/usr/bin/env bash\n"
    output_content+="# Exported ${gc_app_name} Configuration\n"
    output_content+="# Generated: $(date)\n\n"

    # Process each file
    for file in "${files[@]}"; do
        local file_content
        file_content=$(cat "$file")

        # Optional: Strip debug statements
        if [[ "$KEEP_DEBUG" == false ]]; then
            file_content=$(echo "$file_content" | grep -v '^\s*debug_echo' | grep -v '^\s*#.*debug')
        fi

        # Optional: Strip comments
        if [[ "$STRIP_COMMENTS" == true ]]; then
            file_content=$(echo "$file_content" | sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d')
        fi

        # Add separator and file content
        output_content+="# Source: $(basename "$file")\n"
        output_content+="$file_content\n\n"
    done

    echo -e "$output_content"
}

# Export configuration
ExportConfiguration() {
    # Determine output file
    local output_path="${OUTPUT_FILE:-$gc_default_export_dir/$(hostname)_${SHELL_TYPE}rc}"

    # Create export directory if it doesn't exist
    mkdir -p "$(dirname "$output_path")"

    # Check if file exists and handle overwrite
    if [[ -f "$output_path" && "$FORCE_OVERWRITE" == false ]]; then
        ErrorMessage "Output file already exists: $output_path"
        echo "Use --force to overwrite."
        return 1
    fi

    # Find and process configuration files
    local config_files
    mapfile -t config_files < <(FindConfigFiles "$SHELL_TYPE" "$HOSTNAME")

    # Generate exported configuration
    local exported_config
    exported_config=$(ProcessConfigFiles "${config_files[@]}")

    # Write to output file
    echo -e "$exported_config" > "$output_path"

    # Set correct permissions
    chmod 600 "$output_path"

    # Confirmation message
    SuccessMessage "Configuration exported to: $output_path"
    
    if [[ "$VERBOSE_MODE" == true ]]; then
        echo "Exported ${#config_files[@]} configuration files"
    fi
}

# Main script execution
Main() {
    # Detect project root
    local RCFORGE_DIR
    RCFORGE_DIR=$(DetectProjectRoot)

    # Parse command-line arguments
    ParseArguments "$@"

    # Display header
    SectionHeader "${gc_app_name} Configuration Export"

    # Execute export
    ExportConfiguration
}

# Entry point - execute only if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    Main "$@"
fi
