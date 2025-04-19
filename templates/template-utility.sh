#!/usr/bin/env bash
# utility-name.sh - Short utility description
# Author: Your Name
# Date: YYYY-MM-DD
# Version: 0.4.1
# Category: system/utility
# RC Summary: One-line description for RC help display
# Description: More detailed explanation of what this utility does

# Source necessary libraries (utility-functions sources shell-colors)
source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/utility-functions.sh"

# Set strict error handling
set -o nounset
set -o pipefail
# set -o errexit # Let functions handle errors

# ============================================================================
# GLOBAL CONSTANTS
# ============================================================================
# Use sourced constants or define your own
[ -v gc_version ] || readonly gc_version="${RCFORGE_VERSION:-0.4.1}"
[ -v gc_app_name ] || readonly gc_app_name="${RCFORGE_APP_NAME:-rcForge}"
readonly UTILITY_NAME="utility-name" # Replace with actual name

# ============================================================================
# Function: ShowHelp
# Description: Display detailed help information for this utility.
# Usage: ShowHelp
# Exits: 0
# ============================================================================
ShowHelp() {
	local script_name
	script_name=$(basename "$0")

	echo "${UTILITY_NAME} - rcForge Utility (v${gc_version})"
	echo ""
	echo "Description:"
	echo "  Detailed description of what this utility does and why it's useful."
	echo ""
	echo "Usage:"
	echo "  rc ${UTILITY_NAME} [options] <arguments>"
	echo "  ${script_name} [options] <arguments>"
	echo ""
	echo "Options:"
	echo "  --option1=VALUE    Description of option1"
	echo "  --option2          Description of option2"
	echo "  --verbose, -v      Enable verbose output"
	echo "  --help, -h         Show this help message"
	echo "  --summary          Show a one-line description (for rc help)"
	echo "  --version          Show version information"
	echo ""
	echo "Examples:"
	echo "  rc ${UTILITY_NAME} --option1=value argument"
	echo "  rc ${UTILITY_NAME} --verbose argument"
	exit 0
}

# ============================================================================
# Function: ParseArguments
# Description: Parse command-line arguments for this utility.
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

	# Set default values
	options_ref["option1"]="" # Example option
	options_ref["verbose_mode"]=false

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
			--option1=*)
				options_ref["option1"]="${key#*=}"
				shift
				;;
			--option1)
				shift # Move past flag name
				if [[ -z "${1:-}" || "$1" == -* ]]; then
					ErrorMessage "--option1 requires a value."
					return 1
				fi
				options_ref["option1"]="$1"
				shift # Move past value
				;;
			-v | --verbose)
				options_ref["verbose_mode"]=true
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
				ShowHelp # Exits with help
				return 1
				;;
			# Positional argument - add handling as needed
			*)
				# Add positional arg handling here if needed
				# For example: positional_args+=("$1")
				ErrorMessage "Unexpected argument: $key"
				return 1
				;;
		esac
	done

	# Add any additional validation of arguments here

	return 0 # Success
}

# ============================================================================
# Function: main
# Description: Main execution logic.
# Usage: main "$@"
# Returns: 0 on success, 1 on failure.
# ============================================================================
main() {
	# Use associative array for options (requires Bash 4+)
	declare -A options
	# Parse arguments, exit if parser returns non-zero (error)
	ParseArguments options "$@" || exit $?

	# Access options from the array
	local option1="${options[option1]}"
	local is_verbose="${options[verbose_mode]}"

	# Display section header
	SectionHeader "rcForge ${UTILITY_NAME^} Utility (v${gc_version})"

	# Example verbose message
	VerboseMessage "$is_verbose" "Running with options: option1=${option1}, verbose=${is_verbose}"

	# Add your utility implementation logic here
	# ...

	# Example success message on completion
	SuccessMessage "Operation completed successfully."
	return 0
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
