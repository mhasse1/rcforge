#!/usr/bin/env bash
# rcforge.sh - Universal Shell Configuration Loader
# Author: Mark Hasse / rcForge Team (AI Refactored)
# Version: 0.4.3
# Category: core
# Description: Main loader script for rcForge shell configuration system.
#              Meant to be sourced by user's ~/.bashrc or ~/.zshrc.

# ============================================================================
# CORE SYSTEM INITIALIZATION & ENVIRONMENT SETUP
# ============================================================================

# Set strict modes early for initialization safety
set -o nounset

# Export core environment variables
export RCFORGE_APP_NAME="rcForge"
export RCFORGE_VERSION="0.4.3"
export RCFORGE_ROOT="${RCFORGE_ROOT:-$HOME/.config/rcforge}"

# --- Prepend compliant Bash path if recorded by installer ---
RCFORGE_BASH_LOCATION_FILE="${RCFORGE_ROOT}/docs/.bash_location"
if [[ -f "$RCFORGE_BASH_LOCATION_FILE" && -r "$RCFORGE_BASH_LOCATION_FILE" ]]; then
    RCFORGE_COMPLIANT_BASH_PATH=$(<"$RCFORGE_BASH_LOCATION_FILE")
    # Basic validation
    if [[ -n "$RCFORGE_COMPLIANT_BASH_PATH" && -x "$RCFORGE_COMPLIANT_BASH_PATH" ]]; then
        RCFORGE_COMPLIANT_BASH_DIR=$(dirname "$RCFORGE_COMPLIANT_BASH_PATH")
        # Prepend if not already effectively in PATH
        case ":${PATH}:" in
            *":${RCFORGE_COMPLIANT_BASH_DIR}:"*) : ;; # Already there
            *) export PATH="${RCFORGE_COMPLIANT_BASH_DIR}${PATH:+:${PATH}}" ;;
        esac
        unset RCFORGE_COMPLIANT_BASH_DIR # Clean up temp var
    fi
    unset RCFORGE_COMPLIANT_BASH_PATH # Clean up temp var
fi
unset RCFORGE_BASH_LOCATION_FILE # Clean up temp var
# --- End compliant Bash path prepend ---

# --- Prepend static paths from path.txt ---
RCFORGE_PATH_FILE="${RCFORGE_ROOT}/docs/path.txt" # Using docs/
if [[ -f "$RCFORGE_PATH_FILE" && -r "$RCFORGE_PATH_FILE" ]]; then
    temp_path=""
    separator=""
    path_line="" # Ensure defined before loop in strict mode

    while IFS= read -r path_line || [[ -n "$path_line" ]]; do
        # Trim whitespace
        path_line="${path_line#"${path_line%%[![:space:]]*}"}"
        path_line="${path_line%"${path_line##*[![:space:]]}"}"
        # Skip comments/empty
        if [[ -z "$path_line" || "$path_line" == \#* ]]; then
             continue
        fi
        # Manual ~ expansion
        if [[ "$path_line" == "~"* ]]; then
            path_line="${HOME}/${path_line#\~}"
        fi
        # Add if exists and not duplicate in this batch
        if [[ -d "$path_line" && ":${temp_path}:" != *":${path_line}:"* ]]; then
            temp_path+="${separator}${path_line}"
            separator=":"
        fi
    done < "$RCFORGE_PATH_FILE"

    # Prepend collected paths
    if [[ -n "$temp_path" ]]; then
        export PATH="${temp_path}${PATH:+:${PATH}}"
    fi
    unset temp_path path_line separator # Clean up block-local vars
fi
unset RCFORGE_PATH_FILE # Clean up temp var
# --- End static paths prepend ---

# Define and export remaining core paths
export RCFORGE_LIB="${RCFORGE_ROOT}/system/lib"
export RCFORGE_CORE="${RCFORGE_ROOT}/system/core"
export RCFORGE_UTILS="${RCFORGE_ROOT}/system/utils"
export RCFORGE_SCRIPTS="${RCFORGE_ROOT}/rc-scripts"
export RCFORGE_USER_UTILS="${RCFORGE_ROOT}/utils"

# --- Source Core Utility Library ---
# This needs to happen *after* PATH is set up potentially by path.txt
if [[ -f "${RCFORGE_LIB}/utility-functions.sh" ]]; then
    # shellcheck disable=SC1090
    source "${RCFORGE_LIB}/utility-functions.sh"
else
    # Cannot use ErrorMessage if sourcing failed, use basic echo
    echo -e "\033[0;31mERROR:\033[0m Critical library missing: ${RCFORGE_LIB}/utility-functions.sh. Cannot proceed." >&2
    return 1 # Stop sourcing this script
fi
# --- End Library Sourcing ---

# ============================================================================
# INTERNAL LOADER FUNCTIONS
# ============================================================================

# ============================================================================
# Function: SourceConfigFiles
# Description: Sources an array of configuration files, handling errors and optionally timing.
# Usage: SourceConfigFiles "file1" "file2" ...
# Arguments:
#   $@ - Array of absolute paths to configuration files to source.
# Returns: None. Sources files into the current shell environment.
# ============================================================================
SourceConfigFiles() {
    local -a files_to_source=("$@")
    local file=""
    local start_time=""
    local end_time=""
    local elapsed=""
    local have_bc=false
    local use_seconds=true # Default to using SECONDS fallback

    # Setup for optional timing
    if [[ "${DEBUG_MODE:-false}" == "true" ]]; then
        if CommandExists bc; then
             have_bc=true
        fi
        # Check if sub-second precision is available via date
        if date +%s.%N &>/dev/null; then
             use_seconds=false
        fi
        # Record start time
        if [[ "$use_seconds" == "false" ]]; then
             start_time=$(date +%s.%N)
        else
             start_time=$SECONDS
        fi
        DebugMessage "Starting rcForge configuration loading..."
    fi

    # Loop through and source files
    for file in "${files_to_source[@]}"; do
        if [[ -r "$file" ]]; then
            if [[ "${DEBUG_MODE:-false}" == "true" ]]; then
                 DebugMessage "Sourcing $file"
            fi
            # shellcheck disable=SC1090
            source "$file"
        else
            WarningMessage "Cannot read configuration file: $file. Skipping."
        fi
    done

    # Report timing if debug enabled
    if [[ "${DEBUG_MODE:-false}" == "true" ]]; then
        if [[ "$use_seconds" == "false" ]] && [[ "$have_bc" == "true" ]]; then
            end_time=$(date +%s.%N)
            elapsed=$(echo "$end_time - $start_time" | bc)
            DebugMessage "rcForge configuration loaded in $elapsed seconds."
        elif [[ "$use_seconds" == "true" ]]; then
            local duration=$((SECONDS - start_time))
            # Handle potential wrap-around or slight negative if start was near 0
            [[ $duration -lt 0 ]] && duration=0
            DebugMessage "rcForge configuration loaded in $duration seconds."
        else
            DebugMessage "rcForge configuration loading complete (precise timing unavailable)."
        fi
    fi
}

# ============================================================================
# RC COMMAND WRAPPER FUNCTION (Exported)
# ============================================================================
# ============================================================================
# Function: rc
# Description: Wrapper function to find and execute rcForge utility scripts.
#              Handles user overrides and dispatches to the core implementation.
# Usage: rc <command> [options] [arguments]
# Arguments:
#   $@ - Command name, options, and arguments passed to the utility script.
# Returns: Exit status of the executed utility script, or error status.
# ============================================================================
rc() {
    local rc_impl_path="${RCFORGE_CORE}/rc.sh"

    if [[ -f "$rc_impl_path" && -x "$rc_impl_path" ]]; then
        # Execute using bash to ensure consistency
        bash "$rc_impl_path" "$@"
        return $? # Return the exit status of the rc.sh script
    else
        # Use ErrorMessage if available (sourced from utility-functions)
        if CommandExists ErrorMessage; then
            ErrorMessage "rc command core script not found or not executable: $rc_impl_path" 127 # Provide exit code
        else
            # Fallback if ErrorMessage failed to load
            echo "ERROR: rc command core script not found or not executable: $rc_impl_path" >&2
        fi
        return 127 # Command not found status
    fi
}
# Export the 'rc' function for the current shell if possible (Bash requires -f)
if IsBash; then
    export -f rc
fi
# Zsh exports functions sourced by default, no explicit export needed

# ============================================================================
# MAIN LOADER FUNCTION
# ============================================================================
# ============================================================================
# Function: main (rcForge Loader)
# Description: Main entry point for the rcForge loader script. Performs checks,
#              finds relevant rc-scripts, and sources them.
# Usage: Called at the end of this script.
# Arguments:
#   $@ - Arguments passed when sourcing (usually none).
# Returns: 0 on successful loading, 1 on abort or critical failure.
# ============================================================================
main() {
    # --- Abort Check (optional) ---
    local user_input=""
    local timeout_seconds=1
    local read_cmd_status=0

    printf "%b" "${BRIGHT_BLUE}[INFO]${RESET} Initializing rcForge v${RCFORGE_VERSION}. ${BRIGHT_WHITE}(Press '.' within ${timeout_seconds}s to abort).${RESET}"

    # Read user input with timeout
    if IsZsh; then
        # Zsh: -k 1 for one char, -s silent, -t timeout
        read -s -t "$timeout_seconds" -k 1 user_input
        read_cmd_status=$?
    else
        # Bash: -N 1 for one char, -s silent, -t timeout
        read -s -N 1 -t "$timeout_seconds" user_input
        read_cmd_status=$?
    fi

    # Process read result
    echo "" # Print newline regardless of read outcome
    if [[ $read_cmd_status -eq 0 ]]; then
        if [[ "$user_input" == "." ]]; then
            WarningMessage "rcForge loading aborted by user."
            return 1
        fi
    # Check if read timed out (status > 128 in bash, non-zero in zsh might indicate timeout or error)
    elif [[ $read_cmd_status -gt 128 || (IsZsh && $read_cmd_status -ne 0) ]]; then
        # Timeout occurred, which is normal, continue silently
        : # No message needed for normal timeout
    else
        # Some other read error occurred
        WarningMessage "Read command failed unexpectedly during abort check (Status: $read_cmd_status). Continuing..."
    fi
    # --- End Abort Check ---

    # --- Core Loading Steps ---
    # Check root execution (uses sourced CheckRoot)
    if ! CheckRoot --skip-interactive; then
		if IsZsh; then
			export PS1="%{$(tput setaf 226)%}%n%{$(tput setaf 220)%}@%{$(tput setaf 214)%}%m %{$(tput setaf 14)%}%1~ %{$(tput sgr0)%}# "
		else
			export PS1="\[$(tput setaf 226)\]\u\[$(tput setaf 220)\]@\[$(tput setaf 214)\]\h \[$(tput setaf 14)\]\w \[$(tput sgr0)\]# "
     	fi
        return 1
    fi

    local current_shell
    current_shell=$(DetectShell) # Use sourced function
    if [[ "$current_shell" != "bash" && "$current_shell" != "zsh" ]]; then
        WarningMessage "Unsupported shell detected: '$current_shell'. rcForge primarily supports bash and zsh."
        # Continue anyway, maybe common scripts work
    fi

    # Perform integrity checks unless skipped
    if [[ -z "${RCFORGE_SKIP_CHECKS:-}" ]]; then
        SectionHeader "rcForge Integrity Checks"
        local check_runner_script="${RCFORGE_CORE}/run-integrity-checks.sh"
        local check_runner_status=0

        if [[ -f "$check_runner_script" && -x "$check_runner_script" ]]; then
            # Execute using bash to ensure correct environment for checks
            bash "$check_runner_script"
            check_runner_status=$?

            if [[ $check_runner_status -ne 0 ]]; then
                # Warnings already printed by runner script
                # Ask user whether to proceed if interactive
                if [[ -n "${RCFORGE_NONINTERACTIVE:-}" || ! -t 0 ]]; then
                     ErrorMessage "Running non-interactive. Aborting due to integrity issues." 1 # Use ErrorMessage to exit
                fi
                local response=""
                printf "%b" "${YELLOW}Integrity checks reported issues. Continue loading? (y/N):${RESET} "
                read -r response
                if [[ ! "$response" =~ ^[Yy]$ ]]; then
                    ErrorMessage "Aborted by user due to integrity issues." 1 # Use ErrorMessage
                else
                    SuccessMessage "Continuing despite integrity warnings..."
                fi
            else
                SuccessMessage "All integrity checks passed."
            fi
        else
            WarningMessage "Integrity check runner not found/executable: $check_runner_script"
            WarningMessage "Skipping integrity checks."
            # Consider if this should be fatal? For now, just warn.
        fi
        echo "" # Add newline after checks section
    else
        InfoMessage "Skipping integrity checks due to RCFORGE_SKIP_CHECKS."
    fi

    # --- Find and Source Configuration Files ---
    SectionHeader "Loading rcForge Configuration"
    InfoMessage "Locating and sourcing configuration files."

    local -a config_files_to_load=()
    local find_output=""
    local find_status=0

    # Call FindRcScripts (sourced from utility-functions)
    find_output=$(FindRcScripts "$current_shell")
    find_status=$?

    # Populate array based on shell
    if IsZsh; then
        config_files_to_load=( ${(f)find_output} ) # Zsh specific array assignment
    elif IsBash; then
        mapfile -t config_files_to_load <<< "$find_output" # Bash mapfile
    else
        # Basic fallback for other shells
        config_files_to_load=( $(echo "$find_output") )
    fi

    # Check if find failed *and* no files were loaded
    if [[ $find_status -ne 0 && ${#config_files_to_load[@]} -eq 0 ]]; then
        WarningMessage "FindRcScripts failed (status: $find_status) and no files loaded. Aborting load."
        return 1
    fi

    # Source the files
    if [[ ${#config_files_to_load[@]} -gt 0 ]]; then
        SourceConfigFiles "${config_files_to_load[@]}" # Call local function
    else
        InfoMessage "No specific rcForge configuration files found for ${current_shell} on $(DetectCurrentHostname)."
    fi
    SuccessMessage "Configuration files sourced."

    return 0 # Indicate successful loading
}

# ============================================================================
# EXECUTION START (When Sourced)
# ============================================================================

# Call the main loader function, capturing its status
main "$@"
_RCFORGE_INIT_STATUS=$?

# Clean up loader-specific function definitions from the shell environment
unset -f main
unset -f SourceConfigFiles
# Note: 'rc' function remains exported

# Return the final status of the main loader function
return $_RCFORGE_INIT_STATUS

# EOF
