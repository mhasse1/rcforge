#!/usr/bin/env bash
# rcforge.sh - Universal Shell Configuration Loader
# Author: Mark Hasse
# Date: 2025-04-06
# Version: 0.4.0
# Category: core
# Description: Main loader script for rcForge shell configuration system. Meant to be sourced by user's ~/.bashrc or ~/.zshrc.

# ============================================================================
# CORE SYSTEM INITIALIZATION & ENVIRONMENT SETUP
# ============================================================================

set -o nounset

export RCFORGE_APP_NAME="rcForge"
export RCFORGE_VERSION="0.4.0"

export RCFORGE_ROOT="${RCFORGE_ROOT:-$HOME/.config/rcforge}"
export RCFORGE_LIB="${RCFORGE_ROOT}/system/lib"
export RCFORGE_CORE="${RCFORGE_ROOT}/system/core"
export RCFORGE_UTILS="${RCFORGE_ROOT}/system/utils"
export RCFORGE_SCRIPTS="${RCFORGE_ROOT}/rc-scripts"
export RCFORGE_USER_UTILS="${RCFORGE_ROOT}/utils"

if [[ -f "${RCFORGE_LIB}/shell-colors.sh" ]]; then
    source "${RCFORGE_LIB}/shell-colors.sh"
else
    export RED='\033[0;31m'; export GREEN='\033[0;32m'; export YELLOW='\033[0;33m';
    export BLUE='\033[0;34m'; export CYAN='\033[0;36m'; export RESET='\033[0m'; export BOLD='\033[1m';
    ErrorMessage() { echo -e "${RED}ERROR:${RESET} $1" >&2; }
    WarningMessage() { echo -e "${YELLOW}WARNING:${RESET} $1" >&2; }
    InfoMessage() { echo -e "${BLUE}INFO:${RESET} $1"; }
    SuccessMessage() { echo -e "${GREEN}SUCCESS:${RESET} $1"; }
    WarningMessage "Could not source ${RCFORGE_LIB}/shell-colors.sh. Using minimal output."
fi

if [[ -f "${RCFORGE_CORE}/functions.sh" ]]; then
     # shellcheck disable=SC1090
     source "${RCFORGE_CORE}/functions.sh"
else
     ErrorMessage "Core functions file missing: ${RCFORGE_CORE}/functions.sh"
fi

if [[ -f "${RCFORGE_LIB}/utility-functions.sh" ]]; then
     # shellcheck disable=SC1090
     source "${RCFORGE_LIB}/utility-functions.sh"
fi


# ============================================================================
# Function: DetectShell
# Description: Determine the currently running shell ('bash' or 'zsh').
# Usage: DetectShell
# Returns: Echoes the name of the current shell.
# ============================================================================
DetectShell() {
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        echo "zsh"
    elif [[ -n "${BASH_VERSION:-}" ]]; then
        echo "bash"
    else
        basename "${SHELL:-unknown}"
    fi
}


# ============================================================================
# Function: PerformIntegrityChecks
# Description: Verify the integrity of rcForge config by running check scripts.
#              Prompts user to continue or abort if issues are found (interactive).
# Usage: PerformIntegrityChecks
# Returns: 0 if all checks pass or user chose to continue, 1 if checks failed and user aborted or non-interactive.
# ============================================================================
PerformIntegrityChecks() {
    local continue_load=true
    local error_count=0
    local check_script_path=""
    local check_name=""

    if command -v SectionHeader &> /dev/null; then
        SectionHeader "rcForge Integrity Checks"
    else
        echo -e "\n${BOLD}${CYAN}rcForge Integrity Checks${RESET}\n${CYAN}==============================${RESET}\n"
    fi

    local -A checks=(
        ["Sequence Conflict Check"]="${RCFORGE_UTILS}/seqcheck.sh"
        ["RC File Checksum Check"]="${RCFORGE_CORE}/check-checksums.sh"
        # ["Core Integrity Check"]="${RCFORGE_UTILS}/integrity.sh" # Can add this
    )

    for check_name in "${!checks[@]}"; do
        check_script_path="${checks[$check_name]}"
        InfoMessage "Running: ${check_name}..."
        if [[ -f "$check_script_path" && -x "$check_script_path" ]]; then
            # Remove --non-interactive from the call
            if ! ( bash "$check_script_path" ); then
                WarningMessage "${check_name} detected issues."
                error_count=$((error_count + 1))
                continue_load=false
            else
                 SuccessMessage "${check_name} passed."
            fi
        else
            WarningMessage "Check script not found or not executable: $check_script_path"
            # Consider if this should count as an error
            # error_count=$((error_count + 1))
            # continue_load=false
        fi
    done

    if [[ "$continue_load" == "false" ]]; then
        echo ""
        WarningMessage "${BOLD}Potential rcForge integrity issues detected (${error_count} check(s) reported problems).${RESET}"
        InfoMessage "Your shell configuration might not load correctly."
        InfoMessage "${BOLD}Recommended Action:${RESET} Run utility scripts manually or consider reinstalling."
        InfoMessage "Example: ${CYAN}rc seqcheck --fix${RESET} or ${CYAN}rc check-checksums --fix${RESET}"
        InfoMessage "Reinstall: ${CYAN}curl -fsSL https://raw.githubusercontent.com/rcforge/install/main/install.sh | bash${RESET}"
        echo ""

        if [[ -n "${RCFORGE_NONINTERACTIVE:-}" || ! -t 0 ]]; then
            ErrorMessage "Running in non-interactive mode. Aborting rcForge initialization due to integrity issues."
            return 1
        fi

        local response=""
        # Use printf for prompt to avoid issues with echo -e/-n interpretation
        printf "%b" "${YELLOW}Do you want to continue loading rcForge despite issues? (y/N):${RESET} "
        read -r response # Use -r to read raw input
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            ErrorMessage "Shell configuration loading aborted by user."
            return 1
        else
            SuccessMessage "Continuing with rcForge initialization..."
        fi
    else
        SuccessMessage "All integrity checks passed."
    fi
    echo ""

    return 0
}

# ============================================================================
# Function: DetermineLoadPath
# Description: Wrapper function to call the shared FindRcScripts library function.
# Usage: DetermineLoadPath shell hostname
# Arguments:
#   $1 (required) - The current shell type ('bash' or 'zsh').
#   $2 (optional) - Specific hostname (defaults to current).
# Returns: Echoes newline-separated list from FindRcScripts. Passes through exit status.
# ============================================================================
DetermineLoadPath() {
    local shell="${1:?Shell type required}"
    local hostname="${2:-}" # Pass hostname if provided

    # Call the shared library function (ensure utility-functions.sh is sourced first)
    # Pass hostname explicitly if provided, otherwise FindRcScripts detects current
    FindRcScripts "$shell" "$hostname"
    return $? # Return the exit status of FindRcScripts
}

# ============================================================================
# Function: SourceConfigFiles
# Description: Source an array of configuration files in sequence. Includes optional debug timing.
# Usage: SourceConfigFiles config_file1 [config_file2 ...]
# Returns: None. Sources files into the current shell environment.
# ============================================================================
SourceConfigFiles() {
    local -a files_to_source=("$@")
    local file=""
    local start_time=""
    local end_time=""
    local elapsed=""
    local have_bc=false
    local use_seconds=true

    if [[ -n "${SHELL_DEBUG:-}" ]]; then
        if command -v bc &>/dev/null; then have_bc=true; fi
        if date +%s.%N &>/dev/null; then use_seconds=false; fi

        if [[ "$use_seconds" == "false" ]]; then start_time=$(date +%s.%N); else start_time=$SECONDS; fi
        InfoMessage "Starting rcForge configuration loading..."
    fi

    for file in "${files_to_source[@]}"; do
        if [[ -r "$file" ]]; then
            if [[ -n "${SHELL_DEBUG:-}" ]]; then echo "rcForge: Sourcing $file"; fi
            # shellcheck disable=SC1090
            source "$file"
        else
             WarningMessage "Cannot read configuration file: $file. Skipping."
        fi
    done

    if [[ -n "${SHELL_DEBUG:-}" ]]; then
        if [[ "$use_seconds" == "false" ]] && [[ "$have_bc" == "true" ]]; then
            end_time=$(date +%s.%N)
            elapsed=$(echo "$end_time - $start_time" | bc)
            InfoMessage "rcForge configuration loaded in $elapsed seconds."
        elif [[ "$use_seconds" == "true" ]]; then
            local duration=$(( SECONDS - start_time ))
            InfoMessage "rcForge configuration loaded in $duration seconds."
        else
             SuccessMessage "rcForge configuration loading complete."
        fi
    fi
}

# ============================================================================
# RC COMMAND STUB (Lazy Loader)
# ============================================================================
rc() {
    # Unset this stub function to avoid recursion on the next call
    unset -f rc

    # Define path to the actual implementation script
    # Ensure RCFORGE_CORE is set (should be exported by rcforge.sh)
    local rc_impl_path="${RCFORGE_CORE:-$HOME/.config/rcforge/system/core}/rc-command.sh" # Assuming this path for the full impl

    if [[ -f "$rc_impl_path" && -r "$rc_impl_path" ]]; then
        # Source the actual implementation
        # shellcheck disable=SC1090
        source "$rc_impl_path"

        # Now call the fully defined 'rc' function (from the sourced file)
        # with the original arguments passed to the stub
        rc "$@"
        return $? # Return the exit status of the real rc command
    else
        # Use ErrorMessage if available, otherwise plain echo
        if command -v ErrorMessage &>/dev/null; then
            ErrorMessage "rc command implementation not found or not readable: $rc_impl_path" 127 # Exit 127: Command not found
        else
            echo "ERROR: rc command implementation not found or not readable: $rc_impl_path" >&2
            return 127
        fi
    fi
}
export -f rc

# Existing EOF should be after this block in rcforge.sh
# EOF

# ============================================================================
# Function: main
# Description: Main execution logic for rcForge initialization.
# Usage: main "$@" (called at the end of this script when sourced)
# Returns: 0 on successful loading, 1 on failure.
# ============================================================================
main() {
    # --- Abort Check ---
    local user_input=""
    local timeout_seconds=1
    SectionHeader "${CYAN}INFO:${RESET} Initializing rcForge"
    # Use printf for potentially colored/formatted output consistency
    printf "%b" "${CYAN}INFO:${RESET} Initializing rcForge... (Press '.' within ${timeout_seconds}s to abort)..."
    # Read one character (-N 1), silently (-s), with a timeout (-t)
    if read -s -N 1 -t "$timeout_seconds" user_input; then
        # Read completed (didn't time out)
        echo "" # Add a newline after input
        if [[ "$user_input" == "." ]]; then
            WarningMessage "rcForge loading aborted by user."
            # Return non-zero to signal the sourcing process should stop (if possible)
            # Note: The parent shell might ignore this depending on its settings (e.g., set -e)
            return 1
        fi
        # If input wasn't '.', just continue silently or add verbose message
        # VerboseMessage "true" "Proceeding with rcForge load." # Requires utility-functions sourced
    else
        # Read timed out (exit status > 128 in Bash for read -t timeout)
        # Or read failed for another reason
        if [[ $? -gt 128 ]]; then
             echo "continuing." # Indicate timeout clearly
             # Continue loading automatically after timeout
        else
             # Handle other potential read errors if necessary
             WarningMessage "Read command failed unexpectedly during abort check. Continuing..."
        fi
    fi
    # echo "" # Add a newline for cleaner output flow
    # --- End Abort Check ---


    # Use CheckRoot from sourced functions.sh (already PascalCase)
    if command -v CheckRoot &> /dev/null; then
         if ! CheckRoot --skip-interactive; then return 0; fi
         # if ! CheckRoot --skip-interactive; then return 1; fi
    else
         WarningMessage "CheckRoot function not found - unable to verify non-root execution."
    fi

    local current_shell
    current_shell=$(DetectShell) # Call PascalCase
    if [[ "$current_shell" != "bash" && "$current_shell" != "zsh" ]]; then
         WarningMessage "Unsupported shell detected: '$current_shell'. rcForge supports bash and zsh."
    fi

    if [[ -z "${RCFORGE_SKIP_CHECKS:-}" ]]; then
         if ! PerformIntegrityChecks; then return 0; fi # Call PascalCase
         # if ! PerformIntegrityChecks; then return 1; fi # Call PascalCase
    else
         InfoMessage "Skipping integrity checks due to RCFORGE_SKIP_CHECKS."
    fi

    local -a config_files_to_load
    # Call PascalCase. Use process substitution.
    mapfile -t config_files_to_load < <(DetermineLoadPath "$current_shell") || {
         # return 1 # Propagate error if directory was missing
         return 0 # Propagate error if directory was missing
    }

    if [[ ${#config_files_to_load[@]} -gt 0 ]]; then
        # Call PascalCase
        SourceConfigFiles "${config_files_to_load[@]}"
    else
        : # No action needed if no files were found
    fi

    # TODO: Add lazy-loading setup for 'rc' command function here

    return 0
}

# ============================================================================
# EXECUTION START
# ============================================================================

# Execute main function when this script is sourced.
main "$@"

# EOF
