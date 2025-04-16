#!/usr/bin/env bash
# utility-functions.sh - Common utilities for rcForge shell scripts
# Author: rcForge Team (AI Refactored)
# Date: 2025-04-16 # Updated Date
# Version: 0.4.2 # Core Version
# Category: system/library
# Description: This library provides common utilities for rcForge command-line scripts,
#              including context detection, PATH management, messaging wrappers,
#              and helper functions for argument processing and display.
#              Intended to be sourced by other rcForge scripts.

# shellcheck disable=SC2034 # Disable unused variable warnings for sourced library

# --- Include Guard ---
# Prevents multiple sourcing
if [[ -n "${_RCFORGE_UTILITY_FUNCTIONS_SH_SOURCED:-}" ]]; then
    return 0
fi
_RCFORGE_UTILITY_FUNCTIONS_SH_SOURCED=true # Not Exported
# --- End Include Guard ---

# --- Source Shell Colors Library ---
# Needs to be sourced before messaging functions are defined.
# Assumes shell-colors.sh is in the same directory or found via RCFORGE_LIB.
if [[ -f "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/shell-colors.sh" ]]; then
    # shellcheck disable=SC1090
    source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/shell-colors.sh"
else
    # Critical dependency missing, print basic error and exit sourcing.
    echo -e "\033[0;31mERROR:\033[0m Cannot source required library: shell-colors.sh. Utility functions unavailable." >&2
    return 1 # Stop sourcing this file
fi
# --- End Source Shell Colors ---

# ============================================================================
# GLOBAL CONSTANTS & VARIABLES (Readonly, NOT Exported)
# ============================================================================
# Inherited from sourcing environment or set default; readonly ensures they aren't changed here.
# Use pattern to avoid readonly errors if sourced multiple times.
[[ -v DEBUG_MODE ]] || DEBUG_MODE="${DEBUG_MODE:-false}"
[[ -v gc_version ]] || readonly gc_version="${RCFORGE_VERSION:-0.4.2}" # Use script's version if RCFORGE_VERSION unset
[[ -v gc_app_name ]] || readonly gc_app_name="${RCFORGE_APP_NAME:-rcForge}"
[[ -v gc_copyright ]] || readonly gc_copyright="Copyright (c) $(date +%Y) rcForge Team"
[[ -v gc_license ]] || readonly gc_license="Released under the MIT License"

# ============================================================================
# CONTEXT DETECTION FUNCTIONS (Public API - Exported for Bash)
# ============================================================================

# ============================================================================
# Function: DetectCurrentHostname
# Description: Detects the short hostname of the current machine.
# Usage: local host; host=$(DetectCurrentHostname)
# Arguments: None
# Returns: Echoes the short hostname string (e.g., 'my-laptop').
# ============================================================================
DetectCurrentHostname() {
    # Prefer hostname command with short flag if available
    if CommandExists hostname; then
        hostname -s 2>/dev/null || hostname | cut -d. -f1
    # Fallback to environment variable
    elif [[ -n "${HOSTNAME:-}" ]]; then
        echo "$HOSTNAME" | cut -d. -f1
    # Final fallback to uname
    else
        uname -n | cut -d. -f1
    fi
}

# ============================================================================
# Function: DetectRcForgeDir
# Description: Determine the effective rcForge root directory. Checks RCFORGE_ROOT
#              environment variable first, then defaults to standard user config path.
# Usage: local dir; dir=$(DetectRcForgeDir)
# Arguments: None
# Returns: Echoes the path to the rcForge configuration directory.
# ============================================================================
DetectRcForgeDir() {
    # Use RCFORGE_ROOT if set and is a valid directory, otherwise default
    if [[ -n "${RCFORGE_ROOT:-}" && -d "${RCFORGE_ROOT}" ]]; then
        echo "${RCFORGE_ROOT}"
    else
        echo "$HOME/.config/rcforge"
    fi
}

# ============================================================================
# Function: CheckRoot
# Description: Prevent execution of shell configuration scripts as root user,
#              unless explicitly overridden by RCFORGE_ALLOW_ROOT.
# Usage: CheckRoot [--skip-interactive] || return 1 # Or handle error
# Arguments:
#   --skip-interactive (optional) - Suppresses detailed warning messages.
# Returns: 0 if execution is allowed (not root, or override set).
#          1 if execution should be stopped (is root, no override).
# Environment: Reads RCFORGE_ALLOW_ROOT. Uses SUDO_USER/USER for messages.
# ============================================================================
CheckRoot() {
    local skip_interactive=false
    if [[ "${1:-}" == "--skip-interactive" ]]; then
        skip_interactive=true
    fi

    # Check if current effective user ID is 0 (root)
    if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
        # Check for explicit root override
        if [[ -n "${RCFORGE_ALLOW_ROOT:-}" ]]; then
            # Still show a warning even if overridden, unless skip_interactive is true
            if [[ "$skip_interactive" == "false" ]]; then
                 WarningMessage "Proceeding with root execution due to RCFORGE_ALLOW_ROOT override."
                 WarningMessage "THIS IS STRONGLY DISCOURAGED FOR SECURITY REASONS."
            fi
            return 0 # Allow execution
        fi

        # No override, prevent root execution
        if [[ "$skip_interactive" == "false" ]]; then
            local non_root_user="${SUDO_USER:-$USER}" # Determine original user if possible
            TextBlock "SECURITY WARNING: Root Execution Prevented" "$RED" "${BG_WHITE:-$BG_RED}"
            ErrorMessage "Shell configuration tools should NOT be run as root or with sudo."
            WarningMessage "Running as root can cause permission errors and security risks."
            InfoMessage "Recommended Action: Run this script as a regular user (e.g., '${non_root_user}')."
            InfoMessage "(To override this check, set export RCFORGE_ALLOW_ROOT=1)"
        fi
        return 1 # Prevent execution
    fi

    # Not root, allow execution
    return 0
}

# ============================================================================
# Function: FindRcScripts
# Description: Finds rcForge configuration scripts based on shell and hostname patterns.
#              Sorts the found files numerically based on sequence prefix.
# Usage: local -a files; mapfile -t files < <(FindRcScripts "bash" "myhost")
#        local files_str; files_str=$(FindRcScripts "zsh")
# Arguments:
#   $1 (required) - Target shell ('bash' or 'zsh').
#   $2 (optional) - Target hostname. Defaults to current hostname.
# Returns: Echoes a newline-separated list of matching script paths, sorted numerically.
#          Returns status 0 on success (even if no files found), 1 on error (e.g., dir missing).
# ============================================================================
FindRcScripts() {
    local shell="${1:?Shell type required for FindRcScripts}" # Exit if not provided
    local hostname="${2:-}"
    local scripts_dir="${RCFORGE_SCRIPTS:-$HOME/.config/rcforge/rc-scripts}"
    local -a patterns
    local pattern=""
    local find_cmd_output="" # Variable to store find output
    local find_status=0      # Variable to store find status
    local -a config_files=() # Array to hold results

    # Default to current hostname if not provided
    if [[ -z "$hostname" ]]; then
        hostname=$(DetectCurrentHostname)
    fi

    # Define filename patterns to search for
    patterns=(
        "${scripts_dir}/[0-9][0-9][0-9]_global_common_*.sh"       # Global common
        "${scripts_dir}/[0-9][0-9][0-9]_global_${shell}_*.sh"      # Global shell-specific
        "${scripts_dir}/[0-9][0-9][0-9]_${hostname}_common_*.sh"   # Hostname common
        "${scripts_dir}/[0-9][0-9][0-9]_${hostname}_${shell}_*.sh"  # Hostname shell-specific
    )

    # Check if the scripts directory exists
    if [[ ! -d "$scripts_dir" ]]; then
        WarningMessage "rc-scripts directory not found: $scripts_dir"
        return 1 # Indicate error
    fi

    # Build the find command arguments safely to handle potential spaces/special chars
    local -a find_args=("$scripts_dir" -maxdepth 1 \( -false ) # Start with a false condition for OR grouping
    for pattern in "${patterns[@]}"; do
        local filename_pattern="${pattern##*/}" # Extract just the filename pattern
        find_args+=(-o -name "$filename_pattern")
    done
    find_args+=(\) -type f -print) # End OR grouping and specify file type

    # Execute find, capture output and status
    find_cmd_output=$(find "${find_args[@]}" 2>/dev/null)
    find_status=$?

    if [[ $find_status -ne 0 ]]; then
        WarningMessage "Find command failed searching rc-scripts (status: $find_status)."
        # DebugMessage "Find arguments were: ${find_args[*]}" # Optional debug
        return 1 # Indicate error
    fi

    # Populate the config_files array using the appropriate shell method
    if [[ -n "$find_cmd_output" ]]; then # Only process if find actually found something
        if IsZsh; then
            config_files=( ${(f)find_cmd_output} ) # Zsh: Use field splitting on newlines
        elif IsBash; then
            mapfile -t config_files <<< "$find_cmd_output" # Bash: Use mapfile
        else
            # Basic fallback (may break with spaces/newlines in names)
            config_files=( $(echo "$find_cmd_output") )
        fi
    else
        config_files=() # Ensure array is empty if find returned nothing
    fi

    # Check if any files were found
    if [[ ${#config_files[@]} -eq 0 ]]; then
        return 0 # Not an error if no files match
    fi

    # Sort the found files numerically and print
    printf '%s\n' "${config_files[@]}" | sort -n

    return 0 # Success
}


# ============================================================================
# Function: IsExecutedDirectly
# Description: Check if the script is being executed directly vs. sourced.
# Usage: if IsExecutedDirectly; then ... fi
# Arguments: None
# Returns: 0 (true) if likely executed directly, 1 (false) if likely sourced.
# Note: Relies on shell-specific variables/behavior; may not be perfect in all shells.
# ============================================================================
IsExecutedDirectly() {
    if IsZsh; then
        # Zsh: Check zsh_eval_context for 'file' (indicates sourcing)
        [[ "$ZSH_EVAL_CONTEXT" != *:file:* ]] && return 0 || return 1
    elif IsBash; then
        # Bash: Compare $0 to the *first* element in BASH_SOURCE array.
        # If they are the same, it's likely being executed directly.
        [[ "${BASH_SOURCE[0]}" == "${0}" ]] && return 0 || return 1
    else
        # Fallback heuristic for other shells (less reliable)
        [[ "$0" == *"$(basename "$0")"* ]] && return 0 || return 1
    fi
}

# ============================================================================
# Function: DetectShell
# Description: Detects the name of the currently running shell.
# Usage: local shell; shell=$(DetectShell)
# Arguments: None
# Returns: Echoes the shell name ('bash', 'zsh', or basename of $SHELL) or 'unknown'.
# ============================================================================
DetectShell() {
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        echo "zsh"
    elif [[ -n "${BASH_VERSION:-}" ]]; then
        echo "bash"
    else
        # Fallback using the SHELL variable
        basename "${SHELL:-unknown}"
    fi
}

# ============================================================================
# Function: IsZsh
# Description: Checks if the current shell is Zsh.
# Usage: if IsZsh; then ... fi
# Arguments: None
# Returns: 0 (true) if Zsh, 1 (false) otherwise.
# ============================================================================
IsZsh() {
    [[ "$(DetectShell)" == "zsh" ]]
}

# ============================================================================
# Function: IsBash
# Description: Checks if the current shell is Bash.
# Usage: if IsBash; then ... fi
# Arguments: None
# Returns: 0 (true) if Bash, 1 (false) otherwise.
# ============================================================================
IsBash() {
    [[ "$(DetectShell)" == "bash" ]]
}

# ============================================================================
# Function: DetectOS
# Description: Detects the current operating system type.
# Usage: local os; os=$(DetectOS)
# Arguments: None
# Returns: Echoes 'linux', 'macos', 'windows', or 'unknown'.
# ============================================================================
DetectOS() {
    local os_name="unknown"
    # Use case statement for clarity
    case "$(uname -s)" in
        Linux*)     os_name="linux" ;;
        Darwin*)    os_name="macos" ;;
        CYGWIN*|MINGW*|MSYS*) os_name="windows" ;;
    esac
    echo "$os_name"
}

# ============================================================================
# Function: IsMacOS
# Description: Checks if the current OS is macOS.
# Usage: if IsMacOS; then ... fi
# Arguments: None
# Returns: 0 (true) if macOS, 1 (false) otherwise.
# ============================================================================
IsMacOS() {
    [[ "$(DetectOS)" == "macos" ]]
}

# ============================================================================
# Function: IsLinux
# Description: Checks if the current OS is Linux.
# Usage: if IsLinux; then ... fi
# Arguments: None
# Returns: 0 (true) if Linux, 1 (false) otherwise.
# ============================================================================
IsLinux() {
    [[ "$(DetectOS)" == "linux" ]]
}

# ============================================================================
# Function: IsBSD
# Description: Checks if the current OS is likely BSD-based (includes macOS).
# Usage: if IsBSD; then ... fi
# Arguments: None
# Returns: 0 (true) if macOS or other potential BSD, 1 (false) otherwise.
# Note: Needs refinement for more specific BSD checks if required.
# ============================================================================
IsBSD() {
    # Currently just checks for macOS as a common BSD-like system for 'ls' flags etc.
    IsMacOS
}

# ============================================================================
# Function: CommandExists
# Description: Checks if a command exists in the PATH and is executable.
# Usage: if CommandExists "my_command"; then ... fi
# Arguments:
#   $1 (required) - Name of the command to check.
# Returns: 0 (true) if the command exists, 1 (false) otherwise.
# ============================================================================
CommandExists() {
    command -v "$1" >/dev/null 2>&1
}

# ============================================================================
# PATH UTILITY FUNCTIONS (Public API - Exported for Bash)
# ============================================================================

# ============================================================================
# Function: AddToPath
# Description: Add a directory to the PATH environment variable if the directory
#              exists and the path is not already present. Handles prepending (default)
#              or appending. Avoids adding duplicates.
# Usage: AddToPath "/path/to/add" [prepend|append]
# Arguments:
#   $1 (required) - The directory path to add. Handles ~ expansion.
#   $2 (optional) - Position to add: 'prepend' (default) or 'append'.
# Returns: 0. Modifies the PATH environment variable.
# ============================================================================
AddToPath() {
    local dir_to_add="$1"
    local position="${2:-prepend}" # Default to prepend
    local expanded_dir=""

    # Handle ~ expansion manually for safety
    if [[ "$dir_to_add" == "~"* ]]; then
        expanded_dir="${HOME}/${dir_to_add#\~}"
    else
        expanded_dir="$dir_to_add"
    fi

    # Check if the directory actually exists
    if [[ ! -d "$expanded_dir" ]]; then
        # DebugMessage "Directory not found, skipping PATH modification: $expanded_dir" # Optional debug
        return 0
    fi

    # Check if the directory is already effectively in PATH (handles trailing slashes)
    case ":${PATH}:" in
        *":${expanded_dir}:"*)
            # DebugMessage "Directory already in PATH: $expanded_dir" # Optional debug
            return 0
            ;;
        *":${expanded_dir}/:"*) # Check with trailing slash as well
            # DebugMessage "Directory already in PATH (with slash): $expanded_dir" # Optional debug
            return 0
            ;;
    esac

    # Add to PATH based on position
    if [[ "$position" == "append" ]]; then
        # Append, handle potentially empty initial PATH
        export PATH="${PATH:+$PATH:}$expanded_dir"
        # DebugMessage "Appended to PATH: $expanded_dir" # Optional debug
    else
        # Prepend, handle potentially empty initial PATH
        export PATH="$expanded_dir${PATH:+:$PATH}"
        # DebugMessage "Prepended to PATH: $expanded_dir" # Optional debug
    fi

    return 0
}

# ============================================================================
# Function: AppendToPath
# Description: Convenience function to add a directory to the END of the PATH.
# Usage: AppendToPath "/path/to/append"
# Arguments:
#   $1 (required) - The directory path to append.
# Returns: 0. Modifies the PATH environment variable via AddToPath.
# ============================================================================
AppendToPath() {
    # Call AddToPath specifying the 'append' position
    AddToPath "$1" "append"
}

# ============================================================================
# Function: ShowPath
# Description: Displays current PATH entries, one per line, for easy viewing.
# Usage: ShowPath
# Arguments: None
# Returns: None. Prints PATH entries to stdout.
# ============================================================================
ShowPath() {
    # Use printf and parameter expansion for safe handling of PATH entries
    printf '%s\n' "${PATH//:/$'\n'}"
}

# ============================================================================
# VERSION AND HELP DISPLAY FUNCTIONS (Public API - Exported for Bash)
# ============================================================================

# ============================================================================
# Function: ShowVersionInfo
# Description: Displays standard version, copyright, and license information for a script.
# Usage: ShowVersionInfo ["/path/to/calling_script.sh"]
# Arguments:
#   $1 (optional) - Path to the script calling this function. Defaults to $0 if possible.
# Returns: None. Prints information to stdout.
# ============================================================================
ShowVersionInfo() {
    # Determine script name more reliably
    local script_name=""
    if [[ -n "${1:-}" ]]; then
        script_name=$(basename "$1")
    elif [[ -n "${BASH_SOURCE[0]:-}" ]]; then
        script_name=$(basename "${BASH_SOURCE[0]}") # Use BASH_SOURCE if available
    else
        script_name=$(basename "$0") # Fallback to $0
    fi

    # Use InfoMessage (sourced from shell-colors.sh) for consistent formatting
    InfoMessage "${script_name} (${gc_app_name} Utility) v${gc_version}"
    InfoMessage "${gc_copyright}"
    InfoMessage "${gc_license}"
}

# ============================================================================
# Function: ShowStandardHelp
# Description: Displays standard help wrapper including usage, standard options,
#              and optionally script-specific options.
# Usage: ShowStandardHelp ["Script-specific options text"] ["/path/to/calling_script.sh"]
# Arguments:
#   $1 (optional) - A string containing formatted script-specific options help.
#   $2 (optional) - Path to the script calling this function. Defaults reasonably.
# Returns: None. Prints help information to stdout.
# ============================================================================
ShowStandardHelp() {
    local script_specific_options="${1:-}"
    local calling_script_path="${2:-}"
    local script_name=""

    # Determine script name
    if [[ -n "$calling_script_path" ]]; then
        script_name=$(basename "$calling_script_path")
    elif [[ -n "${BASH_SOURCE[1]:-}" ]]; then
         # If called from another function in the script, BASH_SOURCE[1] might be the original script
        script_name=$(basename "${BASH_SOURCE[1]}")
    elif [[ -n "${BASH_SOURCE[0]:-}" ]]; then
        script_name=$(basename "${BASH_SOURCE[0]}")
    else
        script_name=$(basename "$0") # Fallback
    fi

    # Use InfoMessage for consistency
    InfoMessage "Usage: ${script_name} [OPTIONS] [ARGUMENTS...]"
    echo "" # Blank line for readability
    InfoMessage "Standard Options:"
    printf "  %-18s %s\n" "--help, -h" "Show this help message and exit."
    printf "  %-18s %s\n" "--version" "Show version information and exit."
    printf "  %-18s %s\n" "--summary" "Show a one-line summary (for 'rc list')."

    if [[ -n "$script_specific_options" ]]; then
        echo "" # Blank line before specific options
        InfoMessage "Script-Specific Options:"
        # Print the script-specific options passed in $1
        printf '%s\n' "${script_specific_options}"
    fi
    echo "" # Final blank line
}

# ============================================================================
# SUMMARY EXTRACTION FUNCTION (Public API - Exported for Bash)
# ============================================================================

# ============================================================================
# Function: ExtractSummary
# Description: Extracts the '# RC Summary:' comment line from a script file.
#              Falls back to '# Description:' if summary line is missing.
# Usage: summary=$(ExtractSummary "/path/to/script.sh") || handle_error
# Arguments:
#   $1 (required) - Full path to the script file to parse.
# Returns: Echoes the summary string or a default message.
#          Returns status 0 on success, 1 if no summary/description found or error.
# ============================================================================
ExtractSummary() {
    local script_file="${1:-}"
    local summary=""

    # Validate input file
    if [[ -z "$script_file" ]]; then
        WarningMessage "No script path provided to ExtractSummary."
        echo "(Error: No script path provided)"
        return 1
    elif [[ ! -f "$script_file" ]]; then
        WarningMessage "Script file not found for summary: $script_file"
        echo "(Error: Script file not found)"
        return 1
    elif [[ ! -r "$script_file" ]]; then
        WarningMessage "Script file not readable for summary: $script_file"
        echo "(Error: Script file not readable)"
        return 1
    fi

    # Try to extract '# RC Summary:' line using grep, suppressing "not found" error
    summary=$(grep -m 1 '^# RC Summary:' "$script_file" || true)
    if [[ -n "$summary" ]]; then
        # Strip prefix and leading whitespace
        summary=$(echo "$summary" | sed -e 's/^# RC Summary: //' -e 's/^[[:space:]]*//')
        echo "$summary"
        return 0
    fi

    # Fallback: Try to extract '# Description:' line
    summary=$(grep -m 1 '^# Description:' "$script_file" || true)
    if [[ -n "$summary" ]]; then
        # Strip prefix and leading whitespace
        summary=$(echo "$summary" | sed -e 's/^# Description: //' -e 's/^[[:space:]]*//')
        echo "$summary"
        return 0
    fi

    # If neither found, return default message and error status
    echo "No summary available for $(basename "${script_file}")"
    return 1
}

# ============================================================================
# INTERNAL ARGUMENT PROCESSING HELPERS (Not Exported)
# ============================================================================
# These are examples/placeholders and might be removed if not generally used
# across many utility scripts in a standardized way.

# ============================================================================
# Function: _process_common_args (Internal Helper)
# Description: Handles standard --help, --version, --summary arguments.
# Usage: local remaining_arg; remaining_arg=$(_process_common_args "$arg" "$specific_help") || exit $?
# Arguments:
#   $1 (required) - The argument to check.
#   $2 (optional) - Script-specific help text to pass to ShowStandardHelp.
# Returns: Echoes the argument if it's not a handled common arg.
#          Returns status 0 if arg is not handled, exits otherwise.
# ============================================================================
_process_common_args() {
    local arg="${1:-}"
    local specific_help_text="${2:-}" # Optional specific help text from caller
    # Determine calling script path more reliably if possible
    local calling_script_path="${BASH_SOURCE[1]:-$0}" # BASH_SOURCE[1] is the caller

    case "$arg" in
        --help | -h)
            ShowStandardHelp "$specific_help_text" "$calling_script_path" # Use public function
            exit 0
            ;;
        --version)
            ShowVersionInfo "$calling_script_path" # Use public function
            exit 0
            ;;
        --summary)
            ExtractSummary "$calling_script_path" # Use public function
            exit $? # Exit with status from ExtractSummary
            ;;
        *)
            # Argument was not one of the common ones
            echo "$arg" # Pass it back for further processing
            return 0
            ;;
    esac
}

# ============================================================================
# Function: _process_arguments (Internal Helper Example)
# Description: Example generic argument processor using _process_common_args.
# Usage: _process_arguments "$@" > /dev/null # To handle common args
# Arguments:
#   $@ - All arguments passed to the calling script.
# Returns: Echoes unhandled arguments, one per line. Exits if common args handled.
# ============================================================================
_process_arguments() {
    local arg=""
    local processed_arg=""
    local specific_help="" # Caller could potentially set this

    for arg in "$@"; do
        # Pass along remaining args potentially for specific help text in ShowStandardHelp
        processed_arg=$(_process_common_args "$arg" "$specific_help")
        # _process_common_args exits or returns the arg if not handled

        # If arg was returned, it needs further script-specific processing
        if [[ -n "$processed_arg" ]]; then
            # For this example, just echo unhandled args. Real scripts would parse them.
             printf '%s\n' "$processed_arg"
        fi
    done
}

# ============================================================================
# EXPORT PUBLIC FUNCTIONS FOR BASH
# ============================================================================
# Only export functions intended as the public API of this library for Bash.
# Zsh exports sourced functions automatically.
if IsBash; then
    export -f DetectCurrentHostname
    export -f DetectRcForgeDir
    export -f CheckRoot
    export -f FindRcScripts
    export -f IsExecutedDirectly
    export -f DetectShell
    export -f IsZsh
    export -f IsBash
    export -f DetectOS
    export -f IsMacOS
    export -f IsLinux
    export -f IsBSD
    export -f CommandExists
    export -f AddToPath
    export -f AppendToPath
    export -f ShowPath
    export -f ShowVersionInfo  # Renamed from _rcforge_show_version
    export -f ShowStandardHelp # Renamed from _rcforge_show_help
    export -f ExtractSummary
    # DO NOT EXPORT INTERNAL HELPERS like _process_common_args, _process_arguments
fi

# EOF
