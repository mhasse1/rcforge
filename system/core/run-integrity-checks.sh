#!/usr/bin/env bash
# run-integrity-checks.sh - Executes rcForge integrity checks using Bash.
# Author: rcForge Team
# Date: 2025-04-09
# Version: 0.4.1
# Category: system/core
# Description: Contains the logic moved from PerformIntegrityChecks in rcforge.sh

# Ensure RCFORGE_LIB is available (should be exported by rcforge.sh)
# Provide a fallback just in case, though it shouldn't be needed when called correctly.
RCFORGE_LIB="${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}"

# Source utility functions
if [[ -f "${RCFORGE_LIB}/utility-functions.sh" ]]; then
    # shellcheck disable=SC1090
    source "${RCFORGE_LIB}/utility-functions.sh"
else
    # Cannot use ErrorMessage if sourcing failed
    echo -e "\033[0;31mERROR:\033[0m Cannot source utility-functions.sh in run-integrity-checks.sh" >&2
    exit 1
fi

# Set strict modes for this script
set -o nounset
# set -o errexit # Keep commented out, let checks return status

# --- PASTE THE PerformIntegrityChecks FUNCTION CODE HERE ---
# Copy the *entire* PerformIntegrityChecks function definition
# from rcforge.sh and paste it here.
# Example structure:
PerformIntegrityChecks() {
    local continue_load=true
    local error_count=0
    local check_script_path=""
    local check_name=""
    local check_status=0 # Capture return status from sourced script

    # SectionHeader "rcForge Integrity Checks" # Header printed by caller

    local -A checks=(
        ["Sequence Conflict Check"]="${RCFORGE_UTILS}/chkseq.sh"
        ["RC File Checksum Check"]="${RCFORGE_UTILS}/check-checksums.sh"
    )

    for check_name in "${!checks[@]}"; do
        check_script_path="${checks[$check_name]}"
        InfoMessage "Running: ${check_name}..." # This will now print from the bash sub-process
        if [[ -f "$check_script_path" && -r "$check_script_path" ]]; then
            # Subshell execution - simpler, no errexit handling needed here
            # Make sure check scripts are executable bash scripts
            if ! bash "$check_script_path"; then
                check_status=1 # Assume failure if subshell exits non-zero
            else
                check_status=0
            fi

            # Now check the status
            if [[ $check_status -ne 0 ]]; then
                WarningMessage "$check_name detected issues (status reported by script)."
                error_count=$((error_count + 1))
                continue_load=false
            else
                # We don't have SuccessMessage available here unless utility-functions defines it globally
                # Let's just rely on the internal messages from the check scripts.
                : # No action needed on success here
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
        # Reduce extra output, rely on check script output
        # InfoMessage "Your shell configuration might not load correctly."
        # InfoMessage "${BOLD}Recommended Action:${RESET} Run utility scripts manually or consider reinstalling."
        # InfoMessage "Example: ${CYAN}rc chkseq --fix${RESET} or ${CYAN}rc check-checksums --fix${RESET}"
        # InfoMessage "Reinstall: ${CYAN}curl -fsSL https://... | bash${RESET}"
        echo ""
        # Don't prompt here, just return error status
        return 1
        # else # Don't print overall success here, caller (rcforge.sh) will do it
        # SuccessMessage "All integrity checks passed." # Remove this
    fi
    return 0 # Return 0 if all checks passed
}
# --- END OF PASTED FUNCTION ---

# --- Execution ---
# Call the function directly within this script
PerformIntegrityChecks
exit $? # Exit this script with the status from the function

# EOF
