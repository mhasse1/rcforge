#!/usr/bin/env bash
# utility-functions.sh - Common utilities for command-line scripts
# Author: rcForge Team
# Date: 2025-04-08 # Updated Date - Final version from discussion
# Version: 0.4.1
# Category: system/library
# Description: This library provides common utilities for rcForge command-line scripts.

# shellcheck disable=SC2034 # Disable unused variable warnings in this library file

# --- Include Guard ---
if [[ -n "${_RCFORGE_UTILITY_FUNCTIONS_SH_SOURCED:-}" ]]; then
	return 0
fi
_RCFORGE_UTILITY_FUNCTIONS_SH_SOURCED=true # NOT Exported
# --- End Include Guard ---

# --- Source Shell Colors Library --- ###
# Assume shell-colors.sh is in the same directory or found via RCFORGE_LIB
if [[ -f "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/shell-colors.sh" ]]; then
	# shellcheck disable=SC1090
	source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/shell-colors.sh"
else
	echo "ERROR: Cannot source required library: shell-colors.sh" >&2
	return 1
fi
# --- End Source Shell Colors --- ###

# ============================================================================
# GLOBAL CONSTANTS & VARIABLES (Readonly, NOT Exported)
# ============================================================================
DEBUG_MODE="${DEBUG_MODE:-false}"
# Use pattern to avoid readonly errors if sourced multiple times
[[ -v gc_version ]] || readonly gc_version="${RCFORGE_VERSION:-ENV_ERROR}"
[[ -v gc_app_name ]] || readonly gc_app_name="${RCFORGE_APP_NAME:-ENV_ERROR}"
[[ -v gc_copyright ]] || readonly gc_copyright="Copyright (c) $(date +%Y) rcForge Team"
[[ -v gc_license ]] || readonly gc_license="Released under the MIT License"

# ============================================================================
# CONTEXT DETECTION FUNCTIONS (Selectively Exported)
# ============================================================================
# NOTE: Standard function headers are missing for several functions below
#       and should be added for conformance with the style guide.

# ============================================================================
# Function: DetectCurrentHostname
# ============================================================================

DetectCurrentHostname() {

	if command -v hostname &>/dev/null; then
		hostname -s 2>/dev/null || hostname | cut -d. -f1
	elif [[ -n "${HOSTNAME:-}" ]]; then
		echo "$HOSTNAME" | cut -d. -f1
	else
		uname -n | cut -d. -f1
	fi
}

# ============================================================================
# Function: DetectRcForgeDir
# Description: Determine the effective rcForge root directory. Checks RCFORGE_ROOT env var first.
# Usage: local dir=$(DetectRcForgeDir)
# Arguments: None
# Returns: Echoes the path to the rcForge configuration directory.
# ============================================================================
DetectRcForgeDir() {
	# Use RCFORGE_ROOT if set and is a directory, otherwise default
	if [[ -n "${RCFORGE_ROOT:-}" && -d "${RCFORGE_ROOT}" ]]; then
		echo "${RCFORGE_ROOT}"
	else
		echo "$HOME/.config/rcforge"
	fi
}

# ============================================================================
# Function: CheckRoot
# Description: Prevent execution of shell configuration scripts as root user.
#              Displays warnings and checks for override variable RCFORGE_ALLOW_ROOT.
# Usage: CheckRoot [--skip-interactive]
# Arguments:
#   --skip-interactive (optional) - If provided, suppresses the detailed warning messages.
# Returns:
#   0 - If execution is allowed (not root, or root override is set).
#   1 - If execution should be stopped (is root and no override is set).
# Environment Variables:
#   RCFORGE_ALLOW_ROOT - If set (to any non-empty value), allows root execution despite warnings.
# ============================================================================
CheckRoot() {
	# Check if current user is root (UID 0)
	if [[ ${EUID:-$(id -u)} -eq 0 ]]; then # Safer check for EUID
		# Determine the non-root user
		local non_root_user="${SUDO_USER:-$USER}"

		# Skip interactive warning if --skip-interactive flag is provided
		if [[ "${1:-}" != "--skip-interactive" ]]; then
			# Display detailed warning about root execution risks using standard functions/colors
			TextBlock "SECURITY WARNING: Root Execution Prevented" "$RED" "${BG_WHITE:-}" # Use standard color vars, provide default for BG_WHITE if needed

			ErrorMessage "Shell configuration tools should not be run as root or with sudo."

			WarningMessage "Running as root can:"
			# Using InfoMessage for list items for consistent indentation/prefix if desired, or keep echo
			InfoMessage "  - Create files with incorrect permissions"
			InfoMessage "  - Pose significant security risks"
			InfoMessage "  - Potentially compromise system configuration"

			InfoMessage "Recommended actions:"
			InfoMessage "1. Run this script as a regular user: ${non_root_user}"
			InfoMessage "2. If you must proceed, set RCFORGE_ALLOW_ROOT=1"
		fi

		# Check for explicit root override (using standard env var naming)
		if [[ -n "${RCFORGE_ALLOW_ROOT:-}" ]]; then
			WarningMessage "Proceeding with root execution due to RCFORGE_ALLOW_ROOT override."
			WarningMessage "THIS IS NOT RECOMMENDED FOR SECURITY REASONS."
			return 0
		fi

		# Prevent root execution by default
		return 1
	fi

	# Not root, allow execution to continue
	return 0
}

# ============================================================================
# Function: FindRcScripts
# ============================================================================
FindRcScripts() {
	local shell="${1:?Shell type required}"
	local hostname="${2:-}"
	local -a config_files=()
	local scripts_dir="${RCFORGE_SCRIPTS:-$HOME/.config/rcforge/rc-scripts}"
	local -a patterns
	local pattern=""
	local file=""
	local nullglob_enabled=false
	if [[ -z "$hostname" ]]; then
		hostname=$(DetectCurrentHostname)
	fi

	patterns=(
		"${scripts_dir}/[0-9][0-9][0-9]_global_common_*.sh"
		"${scripts_dir}/[0-9][0-9][0-9]_global_${shell}_*.sh"
		"${scripts_dir}/[0-9][0-9][0-9]_${hostname}_common_*.sh"
		"${scripts_dir}/[0-9][0-9][0-9]_${hostname}_${shell}_*.sh"
	)

	if [[ ! -d "$scripts_dir" ]]; then
		if command -v WarningMessage &>/dev/null; then
			WarningMessage "rc-scripts directory not found: $scripts_dir"
		else
			echo "WARNING: rc-scripts directory not found: $scripts_dir" >&2
		fi
		return 1
	fi

	#---

    # config_files=() is already declared at the top of the function

    local find_cmd_output # Variable to store find output
    local find_status     # Variable to store find status

    # Build the find command arguments safely
    local -a find_args=("$scripts_dir" -maxdepth 1 \( -false ) # Start with a false condition
    for pattern in "${patterns[@]}"; do
        # Extract just the filename pattern
        local filename_pattern="${pattern##*/}"
        find_args+=(-o -name "$filename_pattern")
    done
    find_args+=(\) -type f -print) # End grouping and specify file type

    # Execute find, capture output and status
    find_cmd_output=$(find "${find_args[@]}" 2>/dev/null)
    find_status=$?

    if [[ $find_status -ne 0 ]]; then
        WarningMessage "find command failed while searching for rc-scripts (status: $find_status)."
        # Optional: Show find args used for debugging
        # DebugMessage "Find arguments were: ${find_args[*]}"
        return 1
    fi

    # Populate the config_files array using the appropriate shell method
    if [[ -n "$find_cmd_output" ]]; then # Only process if find actually found something
        if IsZsh; then
            # Zsh: Use array assignment with line splitting
            config_files=( ${(f)find_cmd_output} ) # Assign to config_files
        elif IsBash; then
            # Bash: Use mapfile
            mapfile -t config_files <<< "$find_cmd_output" # Assign to config_files
        else
            # Fallback for other shells (less robust)
            config_files=( $(echo "$find_cmd_output") ) # Assign to config_files
        fi
    else
        config_files=() # Ensure array is empty if find returned nothing
    fi

	#---

	if [[ ${#config_files[@]} -eq 0 ]]; then
		return 0
	fi
	printf '%s\n' "${config_files[@]}" | sort -n

	return 0
}


# ============================================================================
# Function: IsExecutedDirectly
# Description: Check if the script is being executed directly.
# Usage: if IsExecutedDirectly; then ... fi
# Returns: 0 if likely executed directly, 1 if likely sourced.
# ============================================================================
IsExecutedDirectly() {
    if IsZsh; then
        # Zsh: Heuristic - Check if $0 is the script name itself (less reliable).
        # A better Zsh check might involve zsh_eval_context.
        [[ "$0" == *"$(basename "$0")"* ]] && return 0 || return 1
    elif IsBash; then
        # Bash: Compare $0 to the *last* element in BASH_SOURCE array.
        # BASH_SOURCE[0] is the current file, BASH_SOURCE[-1] is the initial script.
        [[ "$0" == "${BASH_SOURCE[-1]}" ]] && return 0 || return 1
    else
        # Fallback heuristic for other shells
        [[ "$0" == *"$(basename "$0")"* ]] && return 0 || return 1
    fi
}


# ============================================================================
# Function: DetectShell
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
# Function: IsZsh
# ============================================================================
IsZsh() {
	[[ "$(DetectShell)" == "zsh" ]]
}

# ============================================================================
# Function: IsBash
# ============================================================================
IsBash() {
	[[ "$(DetectShell)" == "bash" ]]
}

# ============================================================================
# Function: DetectOS
# ============================================================================
DetectOS() {
	local os_name="unknown"
	case "$(uname -s)" in
		Linux*) os_name="linux" ;;
		Darwin*) os_name="macos" ;;
		CYGWIN* | MINGW* | MSYS*) os_name="windows" ;;
	esac
	echo "$os_name"
}

# ============================================================================
# Function: IsMacOS
# ============================================================================
IsMacOS() {
	[[ "$(DetectOS)" == "macos" ]]
}

# ============================================================================
# Function: IsLinux
# ============================================================================
IsLinux() {
	[[ "$(DetectOS)" == "linux" ]]
}

# ============================================================================
# Function: IsBSD
# ============================================================================
IsBSD() {
	# Needs refinement for other BSDs
	[[ "$(DetectOS)" == "macos" ]]
}

# ============================================================================
# Function: CommandExists
# ============================================================================
CommandExists() {
	command -v "$1" >/dev/null 2>&1
}

# ============================================================================
# PATH UTILITY FUNCTIONS (PascalCase)
# ============================================================================

# ============================================================================
# Function: AddToPath
# Description: Add directory to PATH if it exists and isn't already there.
# Usage: AddToPath directory [prepend|append]
# Arguments:
#   directory (required) - The directory path to add.
#   position (optional) - 'prepend' (default) or 'append'.
# Returns: 0. Modifies PATH environment variable.
# ============================================================================
AddToPath() {
	local dir="$1"
	local position="${2:-prepend}" # Default to prepend

	# Resolve potential ~ or other expansions, handle non-existent dir gracefully
	# Use eval to expand ~ but be cautious
	# dir=$(eval echo "$dir") # Use cautiously or avoid if possible

	# Better: Check existence *before* modifying PATH
	if [[ ! -d "$dir" ]]; then
		# Optionally print verbose message if dir doesn't exist
		# [[ -n "${SHELL_DEBUG:-}" ]] && echo "rcForge PATH: Directory not found, skipping: $dir"
		return 0
	fi

	# Check if directory is already effectively in PATH (handles trailing slashes)
	case ":${PATH}:" in
		*":${dir}:"*) return 0 ;;  # Exact match
		*":${dir}/:"*) return 0 ;; # Match with trailing slash
	esac

	# Add to PATH
	if [[ "$position" == "append" ]]; then
		export PATH="${PATH:+$PATH:}$dir" # Append, handle empty initial PATH
	else
		export PATH="$dir${PATH:+:$PATH}" # Prepend, handle empty initial PATH
	fi
	# Optionally print verbose message
	# [[ -n "${SHELL_DEBUG:-}" ]] && echo "rcForge PATH: Added ($position): $dir"
	return 0
}

# ============================================================================
# Function: AppendToPath
# Description: Add directory to the END of PATH if it exists and isn't already there.
# Usage: AppendToPath directory
# Returns: 0. Modifies PATH environment variable.
# ============================================================================
AppendToPath() {
	AddToPath "$1" "append" # Call PascalCase
}

# ============================================================================
# Function: ShowPath
# Description: Display current PATH entries, one per line.
# Usage: ShowPath
# Returns: None. Prints PATH entries to stdout.
# ============================================================================
ShowPath() {
	# Use printf for safer handling of potential special characters if PATH was manipulated externally
	printf '%s\n' "${PATH//:/$'\n'}"
}

# ============================================================================
# VERSION AND HELP DISPLAY FUNCTIONS (Internal Helpers - NOT Exported)
# ============================================================================
# NOTE: Standard function headers are missing

# _rcforge_show_version - Internal helper
_rcforge_show_version() {
	local script_name="${1:-$(basename "$0")}"
	if command -v InfoMessage &>/dev/null; then
		InfoMessage "${script_name} (rcForge Utility) v${gc_version}"
		InfoMessage "${gc_copyright}"
		InfoMessage "${gc_license}"
	else
		echo "${script_name} v${gc_version}"
		echo "${gc_copyright}"
		echo "${gc_license}"
	fi
}

# _rcforge_show_help - Internal helper
_rcforge_show_help() {
	local script_specific_options="${1:-}"
	local script_name

	if [[ -n "${BASH_SOURCE[1]:-}" ]]; then
		script_name=$(basename "${BASH_SOURCE[1]}")
	else
		local script_name
		script_name=$(basename "$0")
	fi

	if command -v InfoMessage &>/dev/null; then
		InfoMessage "Usage: ${script_name} [OPTIONS] [ARGUMENTS...]"
		echo ""
		InfoMessage "Standard Options:"
		echo "  --help, -h      Show this help message and exit"
		echo "  --version       Show version information and exit"
		echo "  --summary       Show a one-line summary (for rc help framework)"
		if [[ -n "$script_specific_options" ]]; then
			echo ""
			InfoMessage "Script-specific options:"
			printf '%s\n' "${script_specific_options}"
		fi
	else
		echo "Usage: ${script_name} [OPTIONS] [ARGUMENTS...]"
		echo ""
		echo "Options:"
		echo "  --help, -h      Show this help message and exit"
		echo "  --version       Show version information and exit"
		echo "  --summary       Show a one-line summary"
		if [[ -n "$script_specific_options" ]]; then
			echo ""
			echo "Script-specific options:"
			printf '%s\n' "${script_specific_options}"
		fi
	fi
	echo ""
}

# ============================================================================
# Function: ExtractSummary
# Description: Extracts the RC Summary comment line from a given script file.
#              Falls back to the Description line if RC Summary is missing.
#              Intended to be called by utility scripts handling --summary.
# Usage: ExtractSummary "/path/to/script.sh"
# Arguments:
#   $1 (required) - Full path to the script file to parse.
# Returns: Echoes the summary string or a default message. Status 0 or 1.
# ============================================================================
ExtractSummary() {
	local script_file="${1:-}"
	local summary=""

	# Validate input
	if [[ -z "$script_file" ]]; then
		if command -v WarningMessage &>/dev/null; then WarningMessage "No script path provided to ExtractSummary."; else echo "Warning: No script path provided to ExtractSummary." >&2; fi
		echo "(Error: No script path provided)"
		return 1
	elif [[ ! -f "$script_file" ]]; then
		if command -v WarningMessage &>/dev/null; then WarningMessage "Script file not found for summary: $script_file"; else echo "Warning: Script file not found for summary: $script_file" >&2; fi
		echo "(Error: Script file not found)"
		return 1
	elif [[ ! -r "$script_file" ]]; then
		if command -v WarningMessage &>/dev/null; then WarningMessage "Script file not readable for summary: $script_file"; else echo "Warning: Script file not readable for summary: $script_file" >&2; fi
		echo "(Error: Script file not readable)"
		return 1
	fi

	# Try RC Summary first
	summary=$(grep -m 1 '^# RC Summary:' "$script_file" || true) # Ignore grep status 1 (no match)
	if [[ -n "$summary" ]]; then
		summary=$(echo "$summary" | sed -e 's/^# RC Summary: //' -e 's/^[[:space:]]*//')
	fi

	# Try Description if summary empty
	if [[ -z "$summary" ]]; then
		summary=$(grep -m 1 '^# Description:' "$script_file" || true) # Ignore grep status 1
		if [[ -n "$summary" ]]; then
			summary=$(echo "$summary" | sed -e 's/^# Description: //' -e 's/^[[:space:]]*//')
		fi
	fi

	# Provide default
	: "${summary:=No summary available for $(basename "${script_file}")}"
	echo "$summary"

	# Return status
	if [[ "$summary" == "No summary available for"* ]]; then return 1; else return 0; fi
}
# --- IMPORTANT: Do NOT export ExtractSummary ---

# ============================================================================
# ARGUMENT PROCESSING FUNCTIONS (Internal Helpers - NOT Exported)
# ============================================================================
# NOTE: Standard function headers are missing

# ProcessCommonArgs - Handles standard --help, --version, --summary
ProcessCommonArgs() {
	local arg="${1:-}"
	local calling_script_path="$0"
	local specific_help_text="${2:-}" # Optional specific help text from caller

	case "$arg" in
		--help | -h)
			_rcforge_show_help "$specific_help_text"
			exit 0
			;;
		--version)
			_rcforge_show_version "$calling_script_path"
			exit 0
			;;
		--summary)
			ExtractSummary "$calling_script_path"
			exit $?
			;; # Use new function, exit with its status
		*)
			echo "$arg" # Return unhandled arg
			return 0    # Indicate arg was not one of the common ones handled
			;;
	esac
}
# ProcessArguments - Example generic processor
ProcessArguments() {
	local arg=""
	local processed_arg=""
	for arg in "$@"; do
		# Pass along remaining args potentially for specific help text
		processed_arg=$(ProcessCommonArgs "$arg" "${@:2}")
		if [[ -n "$processed_arg" ]]; then
			printf '%s\n' "$processed_arg"
		fi
		# ProcessCommonArgs exits on handled args
	done
}

# Export Context Functions needed by rc.sh and potentially utilities
if $(IsBash); then
	export -f DetectCurrentHostname
	export -f DetectRcForgeDir
	export -f FindRcScripts
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
fi

# EOF
