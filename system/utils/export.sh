#!/usr/bin/env bash
# export.sh - Export shell configurations for remote servers
# Author: rcForge Team
# Date: 2025-04-07 # Updated for refactor
# Version: 0.4.1 # Version bump
# Category: system/utility
# RC Summary: Exports rcForge shell configurations for use on remote systems
# Description: Exports shell configurations with flexible options for use on remote servers

# Source necessary libraries
source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/utility-functions.sh" # Assumes added by user

# Set strict error handling
set -o nounset
# set -o errexit

# ============================================================================
# GLOBAL CONSTANTS
# ============================================================================
[ -v gc_version ]  || readonly gc_version="${RCFORGE_VERSION:-ENV_ERROR}"
[ -v gc_app_name ] || readonly gc_app_name="${RCFORGE_APP_NAME:-ENV_ERROR}"
readonly gc_default_export_dir="${HOME}/.config/rcforge/exports"

# ============================================================================
# UTILITY FUNCTIONS (Local to export.sh or Sourced)
# ============================================================================
ShowSummary() {
    grep '^# RC Summary:' "$0" | sed 's/^# RC Summary: //'
}
ShowHelp() {
    # ... (help text unchanged) ...
    echo "export - rcForge Configuration Export Utility (v${gc_version})"
    echo ""
    echo "Description:"
    echo "  Exports shell configurations with flexible options for use on remote servers,"
    echo "  allowing you to create portable configuration files."
    echo ""
    echo "Usage:"
    echo "  rc export [options]"
    echo "  $(basename "$0") [options]"
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
ValidateShellType() {
    # ... (function unchanged) ...
    local shell="$1"
    if [[ "$shell" != "bash" && "$shell" != "zsh" ]]; then
        ErrorMessage "Invalid shell type specified: '$shell'. Must be 'bash' or 'zsh'."
        return 1
    fi
    return 0
}

# ============================================================================
# FindConfigFiles (REMOVED - Use FindRcScripts from library directly)
# ============================================================================

# ============================================================================
# Function: ProcessConfigFiles (Local logic)
# ============================================================================
ProcessConfigFiles() {
    local shell_type="$1"
    local hostname="$2" # Can be empty
    local keep_debug="$3"
    local strip_comments="$4"
    shift 4
    local -a files=("$@")
    local output_content=""
    local file_content=""
    local file=""

    output_content+="#!/usr/bin/env $shell_type\n"
    output_content+="# Exported rcForge Configuration (v${gc_version})\n"
    output_content+="# Generated: $(date)\n"
    output_content+="# Target Shell: $shell_type\n"
    [[ -n "$hostname" ]] && output_content+="# Hostname Filter: $hostname\n"
    output_content+="# WARNING: This is a generated file. Do not edit directly.\n\n"

    for file in "${files[@]}"; do
        if [[ ! -r "$file" ]]; then
            WarningMessage "Cannot read file, skipping: $file"
            continue
        fi
        # Read file content safely, handle potential errors?
        file_content=$(<"$file") || { WarningMessage "Error reading file: $file"; continue; }

        # Process content (stripping comments/debug)
        if [[ "$keep_debug" == "false" ]]; then
            # Remove lines starting with optional space then debug_echo or #...debug
            file_content=$(printf '%s\n' "$file_content" | grep -Ev '^[[:space:]]*debug_echo|^\s*#.*debug')
        fi
        if [[ "$strip_comments" == "true" ]]; then # Note: keep_debug=true prevents this
             # Remove lines starting with optional space then #, and blank lines
             file_content=$(printf '%s\n' "$file_content" | sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d')
        fi

        # Append processed content if not empty
        if [[ -n "$file_content" ]]; then
             output_content+="# --- Source: $(basename "$file") ---\n"
             output_content+="$file_content\n\n"
        fi
    done

    printf '%s' "$output_content" # Use %s to avoid interpreting backslashes in content
}


# ============================================================================
# Function: ExportConfiguration (Local logic)
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
    local -a config_files
    local exported_config
    local output_path=""
    local export_dir=""

    # Determine final output path
    output_path="${output_file:-$gc_default_export_dir/rcforge_${hostname:-global}_${shell_type}.sh}"

    if [[ "$is_verbose" == "true" ]]; then
        InfoMessage "Exporting configuration..."
        InfoMessage "  Shell: $shell_type"
        [[ -n "$hostname" ]] && InfoMessage "  Hostname: $hostname"
        InfoMessage "  Output File: $output_path"
        InfoMessage "  Keep Debug: $keep_debug"
        # strip_comments is implied by keep_debug=false
        InfoMessage "  Strip Comments: $strip_comments (Effective)"
        InfoMessage "  Force Overwrite: $force_overwrite"
    fi

    export_dir=$(dirname "$output_path")
    mkdir -p "$export_dir" || { ErrorMessage "Failed to create export directory: $export_dir"; return 1; }
    chmod 700 "$export_dir" || WarningMessage "Could not set permissions (700) on $export_dir"

    # Check for existing file
    if [[ -f "$output_path" && "$force_overwrite" == "false" ]]; then
        ErrorMessage "Output file already exists: $output_path. Use --force or -f to overwrite."
        return 1
    elif [[ -f "$output_path" && "$force_overwrite" == "true" ]]; then
         WarningMessage "Overwriting existing file: $output_path"
    fi

    # Find config files using the *sourced* FindRcScripts function
    mapfile -t config_files < <(FindRcScripts "$shell_type" "$hostname")
    # Check mapfile status and array length
    if [[ $? -ne 0 || ${#config_files[@]} -eq 0 ]]; then
        # FindRcScripts prints error if dir missing, otherwise just returns 0 with no output
        InfoMessage "No configuration files found for shell: $shell_type${hostname:+ (hostname: $hostname)}. Nothing to export."
        return 0 # Not necessarily an error if no files found
    fi

    if [[ "$is_verbose" == "true" ]]; then
        InfoMessage "Found ${#config_files[@]} configuration files to process:"
        printf '  %s\n' "${config_files[@]}"
    fi

    # Process the found files
    exported_config=$(ProcessConfigFiles "$shell_type" "$hostname" "$keep_debug" "$strip_comments" "${config_files[@]}")

    # Write the processed content to the output file
    if printf '%s' "$exported_config" > "$output_path"; then # Use %s
         chmod 600 "$output_path" || WarningMessage "Could not set permissions (600) on $output_path"
         SuccessMessage "Configuration successfully exported to: $output_path"
         if [[ "$is_verbose" == "true" ]]; then
              InfoMessage "Exported ${#config_files[@]} configuration files."
         fi
         return 0
    else
         ErrorMessage "Failed to write exported configuration to: $output_path"
         # Clean up empty file if write failed
         [[ ! -s "$output_path" ]] && rm -f "$output_path" &>/dev/null
         return 1
    fi
}

# ============================================================================
# Function: ParseArguments (Local to export.sh)
# ============================================================================
ParseArguments() {
    # ... (function unchanged) ...
    local -n options_ref="$1"; shift
    if [[ "${BASH_VERSINFO[0]}" -lt 4 || ( "${BASH_VERSINFO[0]}" -eq 4 && "${BASH_VERSINFO[1]}" -lt 3 ) ]]; then ErrorMessage "Internal Error: ParseArguments requires Bash 4.3+ for namerefs."; return 1; fi

    options_ref["shell_type"]=""
    options_ref["hostname"]=""
    options_ref["output_file"]=""
    options_ref["verbose_mode"]=false
    options_ref["keep_debug"]=false
    options_ref["strip_comments"]=true # Default is true
    options_ref["force_overwrite"]=false

    if [[ "$#" -eq 1 ]]; then case "$1" in --help|-h) ShowHelp; return 1 ;; --summary) ShowSummary; return 1 ;; esac; fi
    if [[ "$#" -gt 0 ]]; then case "$1" in --help|-h) ShowHelp; return 1 ;; --summary) ShowSummary; return 1 ;; esac; fi

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --help|-h) ShowHelp; return 1 ;;
            --summary) ShowSummary; return 1 ;;
            --shell=*) options_ref["shell_type"]="${1#*=}"; if ! ValidateShellType "${options_ref["shell_type"]}"; then return 1; fi; shift ;;
            --hostname=*) options_ref["hostname"]="${1#*=}"; shift ;;
            --output=*) options_ref["output_file"]="${1#*=}"; shift ;;
            --verbose|-v) options_ref["verbose_mode"]=true; shift ;;
            --keep-debug) options_ref["keep_debug"]=true; options_ref["strip_comments"]=false; shift ;; # keep-debug implies keep comments
            --force|-f) options_ref["force_overwrite"]=true; shift ;;
            *) ErrorMessage "Unknown parameter or unexpected argument: $1"; ShowHelp; return 1 ;;
        esac
    done

    if [[ -z "${options_ref["shell_type"]}" ]]; then
        ErrorMessage "Shell type must be specified (--shell=bash or --shell=zsh)."
        ShowHelp
        return 1
    fi
    return 0
}

# ============================================================================
# Function: main
# ============================================================================
main() {
    local rcforge_dir
    rcforge_dir=$(DetermineRcForgeDir) # Use sourced function
    declare -A options

    # Parse Arguments, exit if signaled
    ParseArguments options "$@" || exit $?

    SectionHeader "rcForge Configuration Export (v${gc_version})" # Use sourced function

    # Call local ExportConfiguration
    ExportConfiguration \
        "$rcforge_dir" \
        "${options[shell_type]}" \
        "${options[hostname]}" \
        "${options[output_file]}" \
        "${options[keep_debug]}" \
        "${options[strip_comments]}" \
        "${options[force_overwrite]}" \
        "${options[verbose_mode]}"

    return $? # Return status of ExportConfiguration
}


# Execute main function if run directly or via rc command wrapper
if IsExecutedDirectly || [[ "$0" == *"rc"* ]]; then # Use sourced function
    main "$@"
    exit $?
fi

# EOF