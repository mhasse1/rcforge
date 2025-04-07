#!/usr/bin/env bash
# export.sh - Export shell configurations for remote servers
# Author: rcForge Team
# Date: 2025-04-06
# Version: 0.3.0
# Category: system/utility
# RC Summary: Exports rcForge shell configurations for use on remote systems
# Description: Exports shell configurations with flexible options for use on remote servers

# Source necessary libraries
source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/shell-colors.sh"
source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/utility-functions.sh" # Assuming SectionHeader is here

# Set strict error handling
set -o nounset  # Treat unset variables as errors
 # set -o errexit  # Exit immediately if a command exits with a non-zero status

# ============================================================================
# GLOBAL CONSTANTS
# ============================================================================
[ -v gc_version ]  || readonly gc_version="${RCFORGE_VERSION:-ENV_ERROR}"
[ -v gc_app_name ] || readonly gc_app_name="${RCFORGE_APP_NAME:-ENV_ERROR}"
readonly gc_default_export_dir="${HOME}/.config/rcforge/exports"

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# ============================================================================
# Function: ShowSummary
# Description: Display one-line summary for rc help command.
# Usage: ShowSummary
# Arguments: None
# Returns: Echoes summary string.
# ============================================================================
ShowSummary() {
    grep '^# RC Summary:' "$0" | sed 's/^# RC Summary: //'
}

# ============================================================================
# Function: ShowHelp
# Description: Display detailed help information for the export command.
# Usage: ShowHelp
# Arguments: None
# Returns: None. Prints help text to stdout.
# ============================================================================
ShowHelp() {
    echo "export - rcForge Configuration Export Utility (v${gc_version})"
    echo ""
    echo "Description:"
    echo "  Exports shell configurations with flexible options for use on remote servers,"
    echo "  allowing you to create portable configuration files."
    echo ""
    echo "Usage:"
    echo "  rc export [options]"
    echo "  $0 [options]" # Show direct usage too
    echo ""
    echo "Options:"
    echo "  --shell=TYPE      Specify shell type (bash or zsh) [REQUIRED]"
    echo "  --hostname=NAME   Filter configurations for specific hostname (optional)"
    echo "  --output=FILE     Specify output file path (optional, defaults to export dir)"
    echo "  --verbose, -v     Enable verbose output"
    echo "  --keep-debug      Preserve debug statements (implies keeping comments)"
    echo "  --force, -f       Overwrite existing output file"
    echo "  --help, -h        Show this help message"
    echo "  --summary         Show a one-line description (for rc help)"
    echo ""
    echo "Examples:"
    echo "  rc export --shell=bash                         # Export global/bash configurations"
    echo "  rc export --shell=zsh --hostname=laptop      # Export zsh configs for 'laptop'"
    echo "  rc export --shell=bash --output=~/bashrc.exp # Export to specific file"
    echo "  rc export --shell=zsh --force -v             # Export zsh, overwrite, verbose"
}

# ============================================================================
# Function: DetermineRcforgeDir
# Description: Determine the effective rcForge root directory.
# Usage: DetermineRcforgeDir
# Returns: Echoes the path to the rcForge configuration directory.
# ============================================================================
DetermineRcforgeDir() {
    if [[ -n "${RCFORGE_ROOT:-}" && -d "${RCFORGE_ROOT}" ]]; then
        echo "${RCFORGE_ROOT}"
    else
        echo "$HOME/.config/rcforge"
    fi
}

# ============================================================================
# Function: ValidateShellType
# Description: Validate shell type ('bash' or 'zsh').
# Usage: ValidateShellType shell_type
# Arguments:
#   shell_type (required) - The shell type string to validate.
# Returns: 0 if valid, 1 if invalid.
# ============================================================================
ValidateShellType() {
    local shell="$1"
    if [[ "$shell" != "bash" && "$shell" != "zsh" ]]; then
        ErrorMessage "Invalid shell type specified: '$shell'. Must be 'bash' or 'zsh'."
        return 1
    fi
    return 0
}

# ============================================================================
# Function: FindConfigFiles
# Description: Find rcForge configuration files matching shell/hostname criteria.
# Usage: FindConfigFiles rcforge_dir shell_type hostname is_verbose
# Arguments:
#   rcforge_dir (required) - Path to the rcForge root directory.
#   shell_type (required) - 'bash' or 'zsh'.
#   hostname (optional) - Specific hostname to filter for.
#   is_verbose (required) - Boolean ('true' or 'false') for verbose output.
# Returns: Echoes a newline-separated list of sorted config file paths. Exits 1 if none found.
# ============================================================================
FindConfigFiles() {
    local rcforge_dir="$1"
    local shell_type="$2"
    local hostname="${3:-}" # Optional hostname
    local is_verbose="${4:-false}"
    local scripts_dir="${rcforge_dir}/rc-scripts"
    local -a patterns
    local -a config_files
    local pattern="" # Loop variable
    local file=""    # Loop variable

    patterns=(
        "[0-9][0-9][0-9]_global_common_*.sh"
        "[0-9][0-9][0-9]_global_${shell_type}_*.sh"
    )

    if [[ -n "$hostname" ]]; then
        patterns+=(
            "[0-9][0-9][0-9]_${hostname}_common_*.sh"
            "[0-9][0-9][0-9]_${hostname}_${shell_type}_*.sh"
        )
    fi

    if [[ "$is_verbose" == "true" ]]; then
         InfoMessage "Searching for files in: $scripts_dir"
         InfoMessage "Using patterns: ${patterns[*]}"
    fi

    if [[ ! -d "$scripts_dir" ]]; then
         ErrorMessage "rc-scripts directory not found: $scripts_dir"
         return 1
    fi

    # Refactored find logic for clarity and robustness
    local find_pattern=""
    local first=true
    for pattern in "${patterns[@]}"; do
         if [[ "$first" == true ]]; then
             find_pattern="-name '$pattern'"
             first=false
         else
             find_pattern+=" -o -name '$pattern'"
         fi
    done

    mapfile -t config_files < <(find "$scripts_dir" -maxdepth 1 -type f \( $find_pattern \) -print0 | sort -z -n | xargs -0 -r printf '%s\n')

    if [[ ${#config_files[@]} -eq 0 ]]; then
        ErrorMessage "No configuration files found for shell: $shell_type${hostname:+ (hostname: $hostname)}"
        return 1
    fi

    if [[ "$is_verbose" == "true" ]]; then
        InfoMessage "Found ${#config_files[@]} configuration files to process:"
        printf '  %s\n' "${config_files[@]}"
    fi

    printf '%s\n' "${config_files[@]}"
    return 0
}


# ============================================================================
# Function: ProcessConfigFiles
# Description: Concatenate and process configuration files, optionally stripping comments/debug.
# Usage: ProcessConfigFiles shell_type hostname keep_debug strip_comments file1 [file2...]
# Arguments:
#   shell_type (required) - 'bash' or 'zsh'.
#   hostname (optional) - Hostname filter used.
#   keep_debug (required) - Boolean ('true' or 'false').
#   strip_comments (required) - Boolean ('true' or 'false').
#   fileN (required) - One or more config file paths.
# Returns: Echoes the processed and concatenated configuration content.
# ============================================================================
ProcessConfigFiles() {
    local shell_type="$1"
    local hostname="$2" # Can be empty
    local keep_debug="$3"
    local strip_comments="$4"
    shift 4 # Remove the first 4 args, rest are files
    local -a files=("$@") # Store remaining args (files) in an array
    local output_content=""
    local file_content=""
    local file="" # Loop variable

    output_content+="#!/usr/bin/env $shell_type\n" # Use specified shell type
    output_content+="# Exported rcForge Configuration (v${gc_version})\n"
    output_content+="# Generated: $(date)\n"
    output_content+="# Target Shell: $shell_type\n"
    [[ -n "$hostname" ]] && output_content+="# Hostname Filter: $hostname\n"
    output_content+="# WARNING: This is a generated file. Do not edit directly.\n"
    output_content+="\n"

    for file in "${files[@]}"; do
        if [[ ! -r "$file" ]]; then
            WarningMessage "Cannot read file, skipping: $file"
            continue
        fi
        file_content=$(<"$file")

        if [[ "$keep_debug" == "false" ]]; then
            file_content=$(echo "$file_content" | grep -Ev '^[[:space:]]*debug_echo|^\s*#.*debug')
        fi

        if [[ "$strip_comments" == "true" && "$keep_debug" == "false" ]]; then
             file_content=$(echo "$file_content" | sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d')
        fi

        if [[ -n "$file_content" ]]; then
             output_content+="# --- Source: $(basename "$file") ---\n"
             output_content+="$file_content\n\n"
        fi
    done

    printf '%s' "$output_content"
}


# ============================================================================
# Function: ExportConfiguration
# Description: Orchestrates finding, processing, and writing the exported config file.
# Usage: ExportConfiguration rcforge_dir shell_type hostname output_file keep_debug strip_comments force_overwrite is_verbose
# Arguments: Takes all configuration options as arguments.
# Returns: 0 on success, 1 on failure.
# ============================================================================
ExportConfiguration() {
    local rcforge_dir="$1"
    local shell_type="$2"
    local hostname="$3" # Optional
    local output_file="$4" # Optional, defaults handled below
    local keep_debug="$5"
    local strip_comments="$6"
    local force_overwrite="$7"
    local is_verbose="$8"
    local -a config_files # Declare array
    local exported_config # Declare variable
    local output_path=""
    local export_dir=""

    output_path="${output_file:-$gc_default_export_dir/rcforge_${hostname:-global}_${shell_type}.sh}" # Default filename convention

    if [[ "$is_verbose" == "true" ]]; then
        InfoMessage "Exporting configuration..."
        InfoMessage "  Shell: $shell_type"
        [[ -n "$hostname" ]] && InfoMessage "  Hostname: $hostname"
        InfoMessage "  Output File: $output_path"
        InfoMessage "  Keep Debug: $keep_debug"
        InfoMessage "  Strip Comments: $strip_comments"
        InfoMessage "  Force Overwrite: $force_overwrite"
    fi

    export_dir=$(dirname "$output_path")
    if ! mkdir -p "$export_dir"; then
         ErrorMessage "Failed to create export directory: $export_dir"
         return 1
    fi
    # Only show message if verbose or directory was actually created?
    # InfoMessage "Ensured export directory exists: $export_dir"


    if [[ -f "$output_path" && "$force_overwrite" == "false" ]]; then
        ErrorMessage "Output file already exists: $output_path"
        WarningMessage "Use --force or -f to overwrite."
        return 1
    elif [[ -f "$output_path" && "$force_overwrite" == "true" ]]; then
         WarningMessage "Overwriting existing file: $output_path"
    fi

    # Use process substitution and mapfile to read into array
    # Call PascalCase function
    mapfile -t config_files < <(FindConfigFiles "$rcforge_dir" "$shell_type" "$hostname" "$is_verbose") || {
         return 1
    }


    # Call PascalCase function
    exported_config=$(ProcessConfigFiles "$shell_type" "$hostname" "$keep_debug" "$strip_comments" "${config_files[@]}")

    if printf '%s' "$exported_config" > "$output_path"; then
         chmod 600 "$output_path"
         SuccessMessage "Configuration successfully exported to: $output_path"
         if [[ "$is_verbose" == "true" ]]; then
              InfoMessage "Exported ${#config_files[@]} configuration files."
         fi
         return 0
    else
         ErrorMessage "Failed to write exported configuration to: $output_path"
         [[ ! -s "$output_path" ]] && rm -f "$output_path"
         return 1
    fi
}


# ============================================================================
# Function: ParseArguments
# Description: Parse command-line arguments.
# Usage: declare -A options; ParseArguments options "$@"
# Arguments:
#   options (required) - Name of the associative array to populate.
#   "$@" (required) - The script's command-line arguments.
# Returns: Populates the associative array. Returns 0 on success, 1 on error or if help/summary shown.
# ============================================================================
ParseArguments() {
    local -n options_ref="$1" # Use nameref for associative array
    shift # Remove array name from args

    options_ref["shell_type"]=""
    options_ref["hostname"]=""
    options_ref["output_file"]=""
    options_ref["verbose_mode"]=false
    options_ref["keep_debug"]=false
    options_ref["strip_comments"]=true
    options_ref["force_overwrite"]=false

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --help|-h)
                ShowHelp # Call PascalCase
                return 1
                ;;
            --summary)
                ShowSummary # Call PascalCase
                return 1
                ;;
            --shell=*)
                options_ref["shell_type"]="${1#*=}"
                # Call PascalCase
                if ! ValidateShellType "${options_ref["shell_type"]}"; then return 1; fi
                ;;
            --hostname=*)
                options_ref["hostname"]="${1#*=}"
                ;;
            --output=*)
                options_ref["output_file"]="${1#*=}"
                ;;
            --verbose|-v)
                options_ref["verbose_mode"]=true
                ;;
            --keep-debug)
                options_ref["keep_debug"]=true
                options_ref["strip_comments"]=false
                ;;
             --force|-f)
                options_ref["force_overwrite"]=true
                ;;
            *)
                ErrorMessage "Unknown parameter: $1"
                echo "Use --help to see available options."
                return 1
                ;;
        esac
        shift
    done

    if [[ -z "${options_ref["shell_type"]}" ]]; then
        ErrorMessage "Shell type must be specified (--shell=bash or --shell=zsh)."
        ShowHelp # Call PascalCase
        return 1
    fi

    return 0 # Success
}

# ============================================================================
# Function: main
# Description: Main execution logic for the export script.
# Usage: main "$@"
# Arguments: Passes all script arguments ("$@").
# Returns: 0 on success, 1 on failure.
# ============================================================================
main() {
    local rcforge_dir
    rcforge_dir=$(DetermineRcforgeDir) # Call PascalCase
    declare -A options # Associative array for parsed options

    # Call PascalCase function. Exit if parse fails or help/summary shown.
    if ! ParseArguments options "$@"; then
         return 1
    fi

    # Call PascalCase function (SectionHeader assumed defined in utility-functions.sh)
    SectionHeader "rcForge Configuration Export (v${gc_version})"

    # Call PascalCase function using options from the associative array
    ExportConfiguration \
        "$rcforge_dir" \
        "${options[shell_type]}" \
        "${options[hostname]}" \
        "${options[output_file]}" \
        "${options[keep_debug]}" \
        "${options[strip_comments]}" \
        "${options[force_overwrite]}" \
        "${options[verbose_mode]}"

    return $? # Return the exit status of ExportConfiguration
}


# Execute main function if run directly or via rc command
if [[ "${BASH_SOURCE[0]}" == "${0}" ]] || [[ "${BASH_SOURCE[0]}" != "${0}" && "$0" == *"rc"* ]]; then
    main "$@"
    exit $? # Exit with the return code of main
fi

# EOF