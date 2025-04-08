#!/usr/bin/env bash
# rcforge.sh - Universal Shell Configuration Loader
# Author: Mark Hasse
# Date: 2025-04-07 # Updated Date for refactor
# Version: 0.4.1
# Category: core
# Description: Main loader script for rcForge shell configuration system. Meant to be sourced by user's ~/.bashrc or ~/.zshrc.

# ============================================================================
# CORE SYSTEM INITIALIZATION & ENVIRONMENT SETUP
# ============================================================================

set -o nounset # Keep nounset for safety during init

export RCFORGE_APP_NAME="rcForge"
export RCFORGE_VERSION="0.4.1"

export RCFORGE_ROOT="${RCFORGE_ROOT:-$HOME/.config/rcforge}"
export RCFORGE_LIB="${RCFORGE_ROOT}/system/lib"
export RCFORGE_CORE="${RCFORGE_ROOT}/system/core"
export RCFORGE_UTILS="${RCFORGE_ROOT}/system/utils"
export RCFORGE_SCRIPTS="${RCFORGE_ROOT}/rc-scripts"
export RCFORGE_USER_UTILS="${RCFORGE_ROOT}/utils"

# --- Source Core & Utility Functions ---

# Source core functions (e.g., CheckRoot) first
if [[ -f "${RCFORGE_CORE}/functions.sh" ]]; then
     # shellcheck disable=SC1090
     source "${RCFORGE_CORE}/functions.sh"
else
     # Use simple echo for error here, as full messaging might not be loaded yet
     echo -e "\033[0;31mERROR:\033[0m Core functions file missing: ${RCFORGE_CORE}/functions.sh. Cannot proceed." >&2
     return 1 # Stop sourcing if core functions missing
fi

# Source utility functions (which will internally source shell-colors)
if [[ -f "${RCFORGE_LIB}/utility-functions.sh" ]]; then
     # shellcheck disable=SC1090
     source "${RCFORGE_LIB}/utility-functions.sh"
else
    # Use ErrorMessage from core/functions.sh if possible, else fallback echo
    if command -v ErrorMessage &>/dev/null; then
        ErrorMessage "Utility functions file missing: ${RCFORGE_LIB}/utility-functions.sh. Cannot proceed."
    else
        echo -e "\033[0;31mERROR:\033[0m Utility functions file missing: ${RCFORGE_LIB}/utility-functions.sh. Cannot proceed." >&2
    fi
    return 1 # Stop sourcing
fi

# --- End Sourcing ---

# ============================================================================
# Shell Detection and Integrity Checks
# ============================================================================
PerformIntegrityChecks() {
    # ... (Function definition as corrected in the previous step) ...
    local continue_load=true
    local error_count=0
    local check_script_path=""
    local check_name=""
    local check_status=0 # Capture return status from sourced script

    SectionHeader "rcForge Integrity Checks" # Use sourced function

    local -A checks=(
        ["Sequence Conflict Check"]="${RCFORGE_UTILS}/seqcheck.sh"
        ["RC File Checksum Check"]="${RCFORGE_CORE}/check-checksums.sh"
        # ["Core Integrity Check"]="${RCFORGE_CORE}/integrity.sh" # Add this back if needed
    )

    for check_name in "${!checks[@]}"; do
        check_script_path="${checks[$check_name]}"
        InfoMessage "Running: ${check_name}..."
        if [[ -f "$check_script_path" && -r "$check_script_path" ]]; then # Check read permission for source
            source "$check_script_path" --sourced # Pass flag
            check_status=$?
            if [[ $check_status -ne 0 ]]; then
                WarningMessage "${check_name} detected issues (status: ${check_status})."
                error_count=$((error_count + 1))
                continue_load=false
            else
                 SuccessMessage "${check_name} passed."
            fi
        else
            WarningMessage "Check script not found or not readable: $check_script_path"
            error_count=$((error_count + 1))
            continue_load=false
        fi
    done

    if [[ "$continue_load" == "false" ]]; then
        echo ""
        WarningMessage "${BOLD}Potential rcForge integrity issues detected (${error_count} check(s) reported problems).${RESET}"
        InfoMessage "Your shell configuration might not load correctly."
        InfoMessage "${BOLD}Recommended Action:${RESET} Run utility scripts manually or consider reinstalling."
        InfoMessage "Example: ${CYAN}rc seqcheck --fix${RESET} or ${CYAN}rc check-checksums --fix${RESET}"
        InfoMessage "Reinstall: ${CYAN}curl -fsSL https://raw.githubusercontent.com/rcforge/install/main/install.sh | bash${RESET}" # Adjust URL if needed
        echo ""

        if [[ -n "${RCFORGE_NONINTERACTIVE:-}" || ! -t 0 ]]; then
            ErrorMessage "Running in non-interactive mode. Aborting rcForge initialization due to integrity issues."
            return 1
        fi

        local response=""
        printf "%b" "${YELLOW}Do you want to continue loading rcForge despite issues? (y/N):${RESET} "
        read -r response
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
# Function: SourceConfigFiles
# ============================================================================
SourceConfigFiles() {
    # ... (Function definition as before) ...
    local -a files_to_source=("$@")
    local file=""
    local start_time=""
    local end_time=""
    local elapsed=""
    local have_bc=false
    local use_seconds=true # Use SECONDS fallback

    if [[ "${DEBUG_MODE:-false}" == "true" ]]; then
        if command -v bc &>/dev/null; then have_bc=true; fi
        if date +%s.%N &>/dev/null; then use_seconds=false; fi
        if [[ "$use_seconds" == "false" ]]; then start_time=$(date +%s.%N); else start_time=$SECONDS; fi
        DebugMessage "Starting rcForge configuration loading..."
    fi

    for file in "${files_to_source[@]}"; do
        if [[ -r "$file" ]]; then
            if [[ "${DEBUG_MODE:-false}" == "true" ]]; then DebugMessage "Sourcing $file"; fi
            # shellcheck disable=SC1090
            source "$file"
        else
             WarningMessage "Cannot read configuration file: $file. Skipping."
        fi
    done

    if [[ "${DEBUG_MODE:-false}" == "true" ]]; then
        if [[ "$use_seconds" == "false" ]] && [[ "$have_bc" == "true" ]]; then
            end_time=$(date +%s.%N); elapsed=$(echo "$end_time - $start_time" | bc)
            DebugMessage "rcForge configuration loaded in $elapsed seconds."
        elif [[ "$use_seconds" == "true" ]]; then
            local duration=$(( SECONDS - start_time )); [[ $duration -lt 0 ]] && duration=0
            DebugMessage "rcForge configuration loaded in $duration seconds."
        else
             DebugMessage "rcForge configuration loading complete (timing unavailable)."
        fi
    fi
}

# ============================================================================
# RC COMMAND WRAPPER FUNCTION (Exported)
# ============================================================================
rc() {
    # ... (Function definition as corrected in the previous step) ...
    local rc_impl_path="${RCFORGE_CORE:-$HOME/.config/rcforge/system/core}/rc.sh"
    if [[ -f "$rc_impl_path" && -x "$rc_impl_path" ]]; then
        bash "$rc_impl_path" "$@"
        return $?
    else
        if command -v ErrorMessage &>/dev/null; then ErrorMessage "rc command script not found or not executable: $rc_impl_path"; else echo "ERROR: rc command script not found or not executable: $rc_impl_path" >&2; fi
        return 127
    fi
}
export -f rc

# ============================================================================
# Function: main (Loader Main Logic)
# ============================================================================
main() {
    # --- Abort Check (optional) ---
    local user_input=""
    local timeout_seconds=1
    printf "%b" "${CYAN}INFO:${RESET} Initializing rcForge v${RCFORGE_VERSION}... (Press '.' within ${timeout_seconds}s to abort)..."
    if read -s -N 1 -t "$timeout_seconds" user_input; then
        echo ""
        if [[ "$user_input" == "." ]]; then WarningMessage "rcForge loading aborted by user."; return 1; fi
    else
        if [[ $? -gt 128 ]]; then echo "continuing."; else WarningMessage "Read command failed unexpectedly during abort check. Continuing..."; fi
    fi
    # --- End Abort Check ---

    # --- Core Loading ---
    if ! CheckRoot --skip-interactive; then return 1; fi # Use sourced CheckRoot

    local current_shell
    current_shell=$(DetectShell) # Use sourced DetectShell
    if [[ "$current_shell" != "bash" && "$current_shell" != "zsh" ]]; then
         WarningMessage "Unsupported shell detected: '$current_shell'. rcForge primarily supports bash and zsh."
    fi

    if [[ -z "${RCFORGE_SKIP_CHECKS:-}" ]]; then
         if ! PerformIntegrityChecks; then return 1; fi # Use local PerformIntegrityChecks
    else
         InfoMessage "Skipping integrity checks due to RCFORGE_SKIP_CHECKS."
    fi

    # --- Determine Load Path (FIXED CALL) ---
    local -a config_files_to_load
    # Call FindRcScripts directly (from sourced utility-functions.sh)
    mapfile -t config_files_to_load < <(FindRcScripts "$current_shell")
    if [[ $? -ne 0 && ${#config_files_to_load[@]} -eq 0 ]]; then
        WarningMessage "Could not determine configuration load path. Aborting load."
        return 1
    fi
    # --- End Determine Load Path ---

    # Source the files
    if [[ ${#config_files_to_load[@]} -gt 0 ]]; then
        SourceConfigFiles "${config_files_to_load[@]}" # Use local SourceConfigFiles
    else
        # Use sourced InfoMessage and DetectCurrentHostname
        InfoMessage "No specific rcForge configuration files found to load for ${current_shell} on $(DetectCurrentHostname)."
    fi

    return 0 # Indicate successful sourcing
}

# ============================================================================
# EXECUTION START
# ============================================================================
main "$@"
_RCFORGE_INIT_STATUS=$?
unset -f main # Clean up main function definition
return $_RCFORGE_INIT_STATUS # Return final status

# EOF