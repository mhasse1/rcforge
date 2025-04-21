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

main() {
	local continue_load=true
	local error_count=0
	local check_script_path=""
	local check_name=""
	local check_status=0 # Capture return status from sourced script

	local -A checks=(
		["Sequence Conflict Check"]="${RCFORGE_UTILS}/chkseq.sh"
		["RC File Checksum Check"]="${RCFORGE_UTILS}/checksums.sh"
	)

	for check_name in "${!checks[@]}"; do
		check_script_path="${checks[$check_name]}"
		if [[ -f "$check_script_path" && -r "$check_script_path" ]]; then
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
		echo ""
		# Don't prompt here, just return error status
		return 1
	fi

	return 0 # Return 0 if all checks passed
}

# --- Execution ---
main "$@"
echo ""
exit $? # Exit this script with the status from the function

# EOF
