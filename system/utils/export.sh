#!/usr/bin/env bash
# export.sh - Export shell configurations for remote servers
# Author: rcForge Team
# Date: 2025-04-08 # Updated for style/summary refactor
# Version: 0.4.1
# Category: system/utility
# RC Summary: Exports rcForge shell configurations for use on remote systems
# Description: Exports shell configurations with flexible options for use on remote servers

# Source necessary libraries (utility-functions sources shell-colors)
source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/utility-functions.sh"

# Set strict error handling
set -o nounset
set -o pipefail
# set -o errexit # Let functions handle errors

# ============================================================================
# GLOBAL CONSTANTS
# ============================================================================
# Use sourced constants, provide fallback just in case
[[ -v gc_version ]] || readonly gc_version="${RCFORGE_VERSION:-0.4.1}"
[[ -v gc_app_name ]] || readonly gc_app_name="${RCFORGE_APP_NAME:-rcForge}"
readonly GC_DEFAULT_EXPORT_DIR="${HOME}/.config/rcforge/exports"

# ============================================================================
# LOCAL HELPER FUNCTIONS
# ============================================================================

# ============================================================================
# Function: ShowHelp
# Description: Display detailed help information for the export command.
# Usage: ShowHelp
# Exits: 0
# ============================================================================
ShowHelp() {
    local script_name
    script_name=$(basename "$0")

    echo "export - rcForge Configuration Export Utility (v${gc_version})"
    echo ""
    echo "Description:"
    echo "  Exports shell configurations with flexible options for use on remote servers,"
    echo "  allowing you to create portable configuration files."
    echo ""
    echo "Usage:"
    echo "  rc export [options]"
    echo "  ${script_name} [options]"
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
    echo "  --version         Show version information"
    echo ""
    echo "Examples:"
    echo "  rc export --shell=bash                         # Export global/bash configurations"
    echo "  rc export --shell=zsh --hostname=laptop      # Export zsh configs for 'laptop'"
    echo "  rc export --shell=bash --output=~/bashrc.exp # Export to specific file"
    echo "  rc export --shell=zsh --force -v             # Export zsh, overwrite, verbose"
    exit 0
}

# ============================================================================
# Function: ValidateShellType (Local validator)
# Description: Validate shell type ('bash' or 'zsh').
# Usage: ValidateShellType shell_type
# Returns: 0 if valid, 1 if invalid.
# ============================================================================
ValidateShellType() {
    local shell_to_check="${1:-}"
    local -r supported_shells=("bash" "zsh") # Use local readonly constant
    local supported=""

    for supported in "${supported_shells[@]}"; do
        if [[ "$shell_to_check" == "$supported" ]]; then
            return 0
        fi
    done
    ErrorMessage "Invalid shell type specified: '$shell_to_check'. Must be 'bash' or 'zsh'."
    return 1
}

# ============================================================================
# Function: ProcessConfigFiles
# Description: Concatenate and process configuration files, optionally stripping comments/debug.
# Usage: ProcessConfigFiles shell_type hostname keep_debug strip_comments file1 [file2...]
# Returns: Echoes the processed and concatenated configuration content.
# ============================================================================
ProcessConfigFiles() {
    local shell_type="${1:-bash}" # Default shell just in case
    local hostname="${2:-}"       # Can be empty
    local keep_debug="${3:-false}"
    local strip_comments="${4:-true}"
    shift 4
    local -a files=("$@")
    local output_content=""
    local file_content=""
    local file=""

    output_content+="#!/usr/bin/env ${shell_type}\n" # Use specified shell type
    output_content+="# Exported rcForge Configuration (v${gc_version})\n"
    output_content+="# Generated: $(date)\n"
    output_content+="# Target Shell: ${shell_type}\n"
    [[ -n "$hostname" ]] && output_content+="# Hostname Filter: ${hostname}\n"
    output_content+="# WARNING: This is a generated file. Do not edit directly.\n"
    output_content+="\n"

    for file in "${files[@]}"; do
        if [[ ! -r "$file" ]]; then
            WarningMessage "Cannot read file, skipping: $file"
            continue
        fi
        # Read file content safely
        file_content=$(<"$file") || {
            WarningMessage "Error reading file: $file"
            continue
        }

        # Process content (stripping comments/debug)
        if [[ "$keep_debug" == "false" ]]; then
            # Remove lines starting with optional space then debug_echo or #...debug
            # Use printf for portability with echo contents
            file_content=$(printf '%s\n' "$file_content" | grep -Ev '^[[:space:]]*debug_echo|^\s*#.*debug')
        fi
        if [[ "$strip_comments" == "true" ]]; then # keep_debug=true prevents this
            # Remove lines starting with optional space then #, and blank lines
            file_content=$(printf '%s\n' "$file_content" | sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d')
        fi

        # Append processed content if not empty
        if [[ -n "$file_content" ]]; then
            output_content+="# --- Source: $(basename "$file") ---\n"
            output_content+="$file_content\n\n"
        fi
    done

    # Add final EOF marker
    output_content+="# EOF\n"

    printf '%s' "$output_content" # Use %s to avoid interpreting backslashes
}

# ============================================================================
# Function: ExportConfiguration
# Description: Orchestrates finding, processing, and writing the exported config file.
# Usage: ExportConfiguration options_assoc_array_name
# Arguments: $1 - Name of the associative array holding parsed options.
# Returns: 0 on success, 1 on failure.
# ============================================================================
ExportConfiguration() {
    local -n options_ref="$1" # Use nameref (Bash 4.3+)

    local rcforge_dir
    rcforge_dir=$RCFORGE_CONFIG_ROOT

    # Extract options using default expansion for safety
    local shell_type="${options_ref[shell_type]:-}"
    local hostname="${options_ref[hostname]:-}"
    local output_file="${options_ref[output_file]:-}"
    local keep_debug="${options_ref[keep_debug]:-false}"
    local strip_comments="${options_ref[strip_comments]:-true}" # Should be handled by keep_debug logic
    local force_overwrite="${options_ref[force_overwrite]:-false}"
    local is_verbose="${options_ref[verbose_mode]:-false}"

    local -a config_files # Declare array
    local exported_config # Declare variable
    local output_path=""
    local export_dir=""
    local find_output=""
    local find_status=0

    # Recalculate strip_comments based on keep_debug
    [[ "$keep_debug" == "true" ]] && strip_comments=false

    # Determine final output path
    output_path="${output_file:-${GC_DEFAULT_EXPORT_DIR}/rcforge_${hostname:-global}_${shell_type}.sh}"

    if [[ "$is_verbose" == "true" ]]; then
        InfoMessage "Exporting configuration..."
        InfoMessage "  Shell: $shell_type"
        [[ -n "$hostname" ]] && InfoMessage "  Hostname: $hostname"
        InfoMessage "  Output File: $output_path"
        InfoMessage "  Keep Debug: $keep_debug"
        InfoMessage "  Strip Comments: $strip_comments" # Show effective value
        InfoMessage "  Force Overwrite: $force_overwrite"
    fi

    export_dir=$(dirname "$output_path")
    # Ensure export directory exists
    mkdir -p "$export_dir" || {
        ErrorMessage "Failed to create export directory: $export_dir"
        return 1
    }
    chmod 700 "$export_dir" || WarningMessage "Could not set permissions (700) on $export_dir"

    # Check for existing file
    if [[ -f "$output_path" && "$force_overwrite" == "false" ]]; then
        ErrorMessage "Output file already exists: $output_path. Use --force or -f to overwrite."
        return 1
    elif [[ -f "$output_path" && "$force_overwrite" == "true" ]]; then
        WarningMessage "Overwriting existing file: $output_path"
    fi

    # Find config files using the *sourced* FindRcScripts function
    config_files=$(FindRcScripts "$shell_type" "$hostname")
    find_status=$?

    if [[ $find_status -ne 0 ]]; then
        # Error message already printed by FindRcScripts
        return 1
    elif [[ -z "$find_output" ]]; then
        InfoMessage "No configuration files found for shell: $shell_type${hostname:+ (hostname: $hostname)}. Nothing to export."
        return 0 # Not an error if no files found
    fi

    if [[ "$is_verbose" == "true" ]]; then
        InfoMessage "Found ${#config_files[@]} configuration files to process:"
        printf '    %s\n' "${config_files[@]}" # Indent list for clarity
    fi

    # Process the found files
    exported_config=$(ProcessConfigFiles "$shell_type" "$hostname" "$keep_debug" "$strip_comments" "${config_files[@]}")

    # Write the processed content to the output file
    if printf '%s' "$exported_config" >"$output_path"; then # Use %s
        if ! chmod 600 "$output_path"; then                    # Executable not needed for exported file
            WarningMessage "Could not set permissions (600) on $output_path"
        fi
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
# Function: ParseArguments (Refactored Standard Loop)
# Description: Parse command-line arguments for export script.
# Usage: declare -A options; ParseArguments options "$@"
# Returns: Populates associative array by reference. Returns 0 on success, 1 on error.
#          Exits directly for --help, --summary, --version.
# ============================================================================
ParseArguments() {
    local -n options_ref="$1"
    shift
    # Ensure Bash 4.3+ for namerefs (-n)
    if [[ "${BASH_VERSINFO[0]}" -lt 4 || ("${BASH_VERSINFO[0]}" -eq 4 && "${BASH_VERSINFO[1]}" -lt 3) ]]; then
        ErrorMessage "Internal Error: ParseArguments requires Bash 4.3+ for namerefs."
        return 1
    fi

    # Default values
    options_ref["shell_type"]="" # Required, must be set by argument
    options_ref["hostname"]=""
    options_ref["output_file"]=""
    options_ref["verbose_mode"]=false
    options_ref["keep_debug"]=false
    options_ref["strip_comments"]=true # Default is true, overridden by keep_debug
    options_ref["force_overwrite"]=false

    # Single loop for arguments
    while [[ $# -gt 0 ]]; do
        local key="$1"
        case "$key" in
            -h | --help)
                ShowHelp # Exits
                ;;
            --summary)
                ExtractSummary "$0"
                exit $? # Call helper and exit
                ;;
            --version)
                _rcforge_show_version "$0"
                exit 0 # Call helper and exit
                ;;
            --shell=*)
                options_ref["shell_type"]="${key#*=}"
                if ! ValidateShellType "${options_ref["shell_type"]}"; then return 1; fi
                shift
                ;;
            --shell)
                shift # Move past --shell flag
                if [[ -z "${1:-}" || "$1" == -* ]]; then
                    ErrorMessage "--shell requires a value (bash or zsh)."
                    return 1
                fi
                options_ref["shell_type"]="$1"
                if ! ValidateShellType "${options_ref["shell_type"]}"; then return 1; fi
                shift # Move past value
                ;;
            --hostname=*)
                options_ref["hostname"]="${key#*=}"
                shift
                ;;
            --hostname)
                shift # Move past --hostname flag
                if [[ -z "${1:-}" || "$1" == -* ]]; then
                    ErrorMessage "--hostname requires a value."
                    return 1
                fi
                options_ref["hostname"]="$1"
                shift # Move past value
                ;;
            --output=*)
                options_ref["output_file"]="${key#*=}"
                shift
                ;;
            --output)
                shift # Move past --output flag
                if [[ -z "${1:-}" || "$1" == -* ]]; then
                    ErrorMessage "--output requires a filename."
                    return 1
                fi
                options_ref["output_file"]="$1"
                shift # Move past value
                ;;
            -v | --verbose)
                options_ref["verbose_mode"]=true
                shift
                ;;
            --keep-debug)
                options_ref["keep_debug"]=true
                options_ref["strip_comments"]=false # keep-debug implies keeping comments
                shift
                ;;
            -f | --force)
                options_ref["force_overwrite"]=true
                shift
                ;;
                # End of options marker
            --)
                shift # Move past --
                break # Stop processing options
                ;;
                # Unknown option
            -*)
                ErrorMessage "Unknown option: $key"
                ShowHelp # Exits
                return 1
                ;;
                # Positional argument (none expected)
            *)
                ErrorMessage "Unexpected positional argument: $key"
                ShowHelp # Exits
                return 1
                ;;
        esac
    done

    # --- Post-parsing validation ---
    if [[ -z "${options_ref["shell_type"]:-}" ]]; then
        ErrorMessage "Shell type must be specified (--shell=bash or --shell=zsh)."
        ShowHelp # Exits
        return 1 # Return error (though ShowHelp likely exited)
    fi

    return 0 # Success
}

# ============================================================================
# Function: main
# Description: Main execution logic for the export script.
# Usage: main "$@"
# Returns: 0 on success, 1 on failure.
# ============================================================================
main() {
    # Use associative array for options (requires Bash 4+)
    declare -A options
    local export_status=0

    # Parse Arguments, exit if parser returns non-zero (error or help/summary)
    ParseArguments options "$@" || exit $? # Exit using parser status

    SectionHeader "rcForge Configuration Export (v${gc_version})"

    # Call ExportConfiguration function using options from the associative array
    # Pass options array by name
    ExportConfiguration options
    export_status=$? # Capture status

    # Return the exit status of ExportConfiguration
    return $export_status
}

# ============================================================================
# Script Execution
# ============================================================================
# Execute main function if run directly or via rc command wrapper
# Use sourced IsExecutedDirectly function
if IsExecutedDirectly || [[ "$0" == *"rc"* ]]; then
    main "$@"
    exit $? # Exit with status from main
fi

# EOF
