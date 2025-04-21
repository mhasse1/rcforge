#!/usr/bin/env bash
# concat-files.sh - Concatenate specified files with markers for processing
# Author: User Provided / Updated by AI
# Date: 2025-04-08 # Updated for style/summary refactor
# Version: 0.4.1
# Category: system/utility
# RC Summary: Finds files and concatenates their content with markers.
# Description: Finds files in the current directory (optionally recursively)
#              matching an optional pattern, then prints their name and
#              content to standard output, separated by start/end markers.

# Source necessary libraries (utility-functions sources shell-colors)
# Need ErrorMessage, ExtractSummary from libraries
source "${RCFORGE_LIB}/utility-functions.sh"

# Set strict error handling
set -o nounset
set -o pipefail
# set -o errexit # Let script handle errors where needed

# ============================================================================
# Function: ShowHelp
# Description: Show help message for the script.
# Usage: ShowHelp
# Exits: 0
# ============================================================================
ShowHelp() {
	# Use sourced constants
	local script_name
	script_name=$(basename "$0")
	local version="${gc_version:-0.4.1}" # Use global constant with fallback

	echo "Usage: ${script_name} [options]"
	echo ""
	echo "Description:"
	echo "  Finds files and concatenates their content with markers."
	echo ""
	echo "Options:"
	echo "  -p, --pattern PATTERN   Find files matching PATTERN (e.g., '*.sh'). Defaults to all files."
	echo "  -nr, --no-recursive   Only search the current directory (do not recurse into subdirectories)."
	echo "  -h, --help            Show this help message."
	echo "  --summary             Show one-line summary."    # Added standard option
	echo "  --version             Show version information." # Added standard option
	echo ""
	echo "Example:"
	echo "  ${script_name} -p '*.sh' -nr   # Concatenate all .sh files in the current directory only"
	exit 0
}

# ============================================================================
# Function: ParseArguments (Refactored to standard loop)
# Description: Parse command-line arguments for concat-files script.
# Usage: declare -A options; ParseArguments options "$@"
# Returns: Populates associative array by reference. Returns 0 on success, 1 on error.
#          Exits directly for --help, --summary, --version.
# ============================================================================
ParseArguments() {
	local -n options_ref="$1" # Use nameref (Bash 4.3+)
	shift                     # Remove array name from args

	# Ensure Bash 4.3+ for namerefs (-n)
	if [[ "${BASH_VERSINFO[0]}" -lt 4 || ("${BASH_VERSINFO[0]}" -eq 4 && "${BASH_VERSINFO[1]}" -lt 3) ]]; then
		ErrorMessage "Internal Error: ParseArguments requires Bash 4.3+ for namerefs."
		return 1
	fi

	# Default values
	options_ref["find_pattern"]="*" # Default pattern finds everything
	options_ref["recursive"]=true

	# Single loop for arguments
	while [[ $# -gt 0 ]]; do
		local key="$1"
		case "$key" in
			-h | --help)
				ShowHelp # Exits
				;;
			--summary)
				ExtractSummary "$0" # Call helper directly
				exit $?             # Exit with helper status
				;;
			--version)
				_rcforge_show_version "$0" # Call helper
				exit 0                     # Exit after showing version
				;;
			-p | --pattern)
				# Ensure value exists and is not another option
				if [[ -z "${2:-}" || "$2" == -* ]]; then
					ErrorMessage "Option '$key' requires a PATTERN argument."
					return 1
				fi
				options_ref["find_pattern"]="$2"
				shift 2 # past argument and value
				;;
			-nr | --no-recursive)
				options_ref["recursive"]=false
				shift # past argument
				;;
				# End of options marker
			--)
				shift # Move past --
				break # Stop processing options, remaining args are positional (none expected for this script)
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

	return 0 # Success
}

# ============================================================================
# Function: main
# Description: Main logic - parse args, find files, print content.
# Usage: main "$@"
# Returns: Exit status of the script.
# ============================================================================
main() {
	# Use associative array for options (requires Bash 4+)
	declare -A options
	# Parse arguments, exit if parser returns non-zero (error)
	# Note: --help, --summary, --version exit directly from ParseArguments now
	ParseArguments options "$@" || exit 1

	# Use options from the array
	local find_pattern="${options[find_pattern]}"
	local max_depth_option="" # Default is recursive
	if [[ "${options[recursive]}" == "false" ]]; then
		max_depth_option="-maxdepth 1"
	fi

	# Build find command arguments into an array for safety
	local -a find_args=(".") # Start with current directory

	# Add maxdepth option if set
	if [[ -n "$max_depth_option" ]]; then
		find_args+=("$max_depth_option")
	fi

	# Always exclude .git directory and node_modules, and potentially others
	find_args+=(\( -path "./.git" -o -path "./node_modules" \) -prune -o) # Exclude .git and node_modules

	# Add the name pattern
	find_args+=(-name "$find_pattern")

	# Always look for files and print0
	find_args+=(-type f -print0)

	# Flag to track if any files were found
	local file_found=false

	# Create a line of -'s to deliniate the intro text
	local intro_len=75
	local intro_line
	intro_line=$(printf '%*s' "$intro_len" '' | tr ' ' '-')

	# Provide the structure of the files to follow.
	cat <<EOF
${intro_line}
# Introduction
This file contains a concatenation of files. The individual files are
delimited by lines formatted as:

    ========== <./path/to/file> ==========

The delimiter provides the name of the file and its path from the
project root.
${intro_line}
EOF

	# Execute find and loop through results safely
	# Use Bash process substitution and while loop for safety with filenames
	while IFS= read -r -d '' file; do
		file_found=true # Mark that we found at least one file
		# Print marker with filename (ensure path is relative to PWD)
		# Use parameter expansion to remove leading ./ if present
		local display_path="${file#./}"
		echo "# ========== <./${display_path}> =========="
		# Print file content safely
		cat -- "$file" # Use -- to handle filenames starting with -
		# Add a newline after file content for separation
		echo ""
	done < <(find "${find_args[@]}")
	# Capture find exit status? Usually not needed unless checking for find errors itself

	# Report if no files were found matching criteria
	if [[ "$file_found" == "false" ]]; then
		InfoMessage "No files found matching pattern '$find_pattern' ${options[recursive]:+in current directory only}."
	fi
	return 0 # Success
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
