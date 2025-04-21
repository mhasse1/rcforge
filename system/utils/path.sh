#!/usr/bin/env bash
# path.sh - PATH environment variable management utility
# Author: rcForge Team
# Date: 2025-04-21
# Version: 0.5.0
# Category: system/utils
# RC Summary: Manage your PATH environment variable
# Description: Add, remove, append directories to PATH or display current PATH entries.
#              Provides a user-friendly interface to common PATH operations.

# Source required libraries
source "${RCFORGE_LIB:-$HOME/.local/share/rcforge/system/lib}/utility-functions.sh"

# Set strict error handling
set -o nounset
set -o pipefail

# Global constants (not exported)
[[ -v gc_version ]] || readonly gc_version="${RCFORGE_VERSION:-0.5.0}"
[[ -v gc_app_name ]] || readonly gc_app_name="${RCFORGE_APP_NAME:-rcForge}"
readonly UTILITY_NAME="path"

# ============================================================================
# Function: ShowHelp
# Description: Display detailed help information for this utility.
# Usage: ShowHelp
# Arguments: None
# Returns: None. Exits with status 0.
# ============================================================================
ShowHelp() {
	_rcforge_show_help <<EOF
  Manage your PATH environment variable

Usage:
  rc path [command] [options] [directory]

Commands:
  add <directory>     Add directory to the beginning of PATH
  append <directory>  Add directory to the end of PATH
  remove <directory>  Remove directory from PATH
  show                Display current PATH entries (one per line)
  help                Show this help message

Examples:
  rc path add ~/bin                  # Add ~/bin to beginning of PATH
  rc path append /usr/local/sbin     # Add to end of PATH
  rc path remove ~/old-tools         # Remove from PATH
  rc path show                       # Display current PATH entries
EOF
	exit 0
}

# ============================================================================
# Function: ShowSummary
# Description: Display one-line summary for rc help command.
# Usage: ShowSummary
# Returns: Echoes summary string.
# ============================================================================
ShowSummary() {
	if command -v ExtractSummary &>/dev/null; then
		ExtractSummary "$0"
	else
		echo "Manage your PATH environment variable"
	fi
}

# ============================================================================
# Function: main
# Description: Main execution logic for path utility.
# Usage: main "$@"
# Arguments: Command-line arguments
# Returns: 0 on success, non-zero on error.
# ============================================================================
main() {
	# Handle no arguments or help request
	if [[ $# -eq 0 || "$1" == "help" || "$1" == "--help" || "$1" == "-h" ]]; then
		ShowHelp
	fi

	# Handle summary request (for rc list)
	if [[ "$1" == "--summary" ]]; then
		ShowSummary
		return $?
	fi

	# Process commands
	local command="$1"
	shift

	case "$command" in
		add)
			if [[ $# -eq 0 ]]; then
				ErrorMessage "Missing directory for 'add' command"
				ShowHelp
				return 1
			fi

			if AddToPath "$1"; then
				SuccessMessage "Added '$1' to beginning of PATH"
			else
				InfoMessage "Directory '$1' was already in PATH or doesn't exist"
			fi
			;;

		append)
			if [[ $# -eq 0 ]]; then
				ErrorMessage "Missing directory for 'append' command"
				ShowHelp
				return 1
			fi

			if AppendToPath "$1"; then
				SuccessMessage "Added '$1' to end of PATH"
			else
				InfoMessage "Directory '$1' was already in PATH or doesn't exist"
			fi
			;;

		remove)
			if [[ $# -eq 0 ]]; then
				ErrorMessage "Missing directory for 'remove' command"
				ShowHelp
				return 1
			fi

			if RemoveFromPath "$1"; then
				SuccessMessage "Removed '$1' from PATH"
			else
				InfoMessage "Directory '$1' was not in PATH"
			fi
			;;

		show)
			SectionHeader "Current PATH Entries"
			ShowPath
			;;

		*)
			ErrorMessage "Unknown command: $command"
			ShowHelp
			return 1
			;;
	esac

	return 0
}

# Execute main function if run directly or via rc command
if IsExecutedDirectly || [[ "$0" == *"rc"* ]]; then
	main "$@"
	exit $? # Exit with the status from main
fi

# EOF
