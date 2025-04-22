#!/usr/bin/env bash
# utility-functions.sh - Common utilities for rcForge shell scripts
# Author: rcForge Team
# Date: 2025-04-21 # Updated for XDG compliance
# Version: 0.5.0
# Category: system/library
# Description: Core library providing essential functions for rcForge scripts
#              including shell detection, path management, messaging, and
#              environment checks. Intended to be sourced by other scripts.

# --- Include Guard ---
if [[ -n "${_RCFORGE_UTILITY_FUNCTIONS_SH_SOURCED:-}" ]]; then
	return 0
fi
_RCFORGE_UTILITY_FUNCTIONS_SH_SOURCED=true
# --- End Include Guard ---

# --- Source Libraries ---
source "${XDG_DATA_HOME:-$HOME/.local/share}/rcforge/system/lib/set-rcforge-environment.sh"

if [[ -f "${RCFORGE_LIB}/shell-colors.sh" ]]; then
	# shellcheck disable=SC1090
	source "${RCFORGE_LIB}/shell-colors.sh"
else
	# Critical dependency missing, print basic error and exit sourcing
	echo -e "\033[0;31mERROR:\033[0m Cannot source required library: shell-colors.sh" >&2
	return 1
fi
# --- End Source Libraries ---

# ============================================================================
# GLOBAL CONSTANTS (Readonly, NOT Exported)
# ============================================================================
[[ -v gc_version ]] || readonly gc_version="${RCFORGE_VERSION:-0.5.0}"
[[ -v gc_app_name ]] || readonly gc_app_name="${RCFORGE_APP_NAME:-rcForge}"

# ============================================================================
# SHELL DETECTION FUNCTIONS
# ============================================================================

# Function: DetectShell
# Description: Identifies the current shell
# Usage: shell=$(DetectShell)
# Returns: Name of the current shell (bash, zsh, or other)
DetectShell() {
	if [[ -n "${ZSH_VERSION:-}" ]]; then
		echo "zsh"
	elif [[ -n "${BASH_VERSION:-}" ]]; then
		echo "bash"
	else
		basename "${SHELL:-unknown}"
	fi
}

# Function: IsZsh
# Description: Checks if current shell is Zsh
# Usage: if IsZsh; then ...; fi
# Returns: 0 if Zsh, 1 otherwise
IsZsh() {
	[[ -n "${ZSH_VERSION:-}" ]]
}

# Function: IsBash
# Description: Checks if current shell is Bash
# Usage: if IsBash; then ...; fi
# Returns: 0 if Bash, 1 otherwise
IsBash() {
	[[ -n "${BASH_VERSION:-}" ]]
}

# Function: IsExecutedDirectly
# Description: Checks if script is being executed directly vs. sourced
# Usage: if IsExecutedDirectly; then ...; fi
# Returns: 0 if executed directly, 1 if sourced
IsExecutedDirectly() {
	if IsZsh; then
		[[ "$ZSH_EVAL_CONTEXT" != *:file:* ]] && return 0 || return 1
	elif IsBash; then
		[[ "${BASH_SOURCE[0]}" == "${0}" ]] && return 0 || return 1
	else
		# Fallback heuristic for other shells
		[[ "$0" == *"$(basename "$0")"* ]] && return 0 || return 1
	fi
}

# ============================================================================
# SYSTEM DETECTION FUNCTIONS
# ============================================================================

# Function: DetectHostname
# Description: Gets the short hostname
# Usage: hostname=$(DetectHostname)
# Returns: Short hostname string
DetectHostname() {
	if command -v hostname &>/dev/null; then
		hostname -s 2>/dev/null || hostname | cut -d. -f1
	elif [[ -n "${HOSTNAME:-}" ]]; then
		echo "$HOSTNAME" | cut -d. -f1
	else
		uname -n | cut -d. -f1
	fi
}

# Function: DetectOS
# Description: Identifies the operating system
# Usage: os=$(DetectOS)
# Returns: 'linux', 'macos', 'windows', or 'unknown'
DetectOS() {
	case "$(uname -s)" in
		Linux*) echo "linux" ;;
		Darwin*) echo "macos" ;;
		CYGWIN* | MINGW* | MSYS*) echo "windows" ;;
		*) echo "unknown" ;;
	esac
}

# Function: IsMacOS
# Description: Checks if system is macOS
# Usage: if IsMacOS; then ...; fi
# Returns: 0 if macOS, 1 otherwise
IsMacOS() {
	[[ "$(DetectOS)" == "macos" ]]
}

# Function: IsLinux
# Description: Checks if system is Linux
# Usage: if IsLinux; then ...; fi
# Returns: 0 if Linux, 1 otherwise
IsLinux() {
	[[ "$(DetectOS)" == "linux" ]]
}

# Function: CommandExists
# Description: Checks if a command exists in PATH
# Usage: if CommandExists "git"; then ...; fi
# Returns: 0 if command exists, 1 otherwise
CommandExists() {
	command -v "$1" >/dev/null 2>&1
}

# ============================================================================
# SECURITY FUNCTIONS
# ============================================================================

# Function: CheckRoot
# Description: Prevents execution as root without override
# Usage: CheckRoot || return 1
# Returns: 0 if execution is allowed, 1 if execution as root is blocked
CheckRoot() {
	local skip_interactive=false
	[[ "${1:-}" == "--skip-interactive" ]] && skip_interactive=true

	# Check if running as root
	if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
		# Allow if override is set
		if [[ -n "${RCFORGE_ALLOW_ROOT:-}" ]]; then
			[[ "$skip_interactive" == "false" ]] && WarningMessage "Proceeding with root execution (RCFORGE_ALLOW_ROOT override)."
			return 0
		fi

		# Block root execution
		if [[ "$skip_interactive" == "false" ]]; then
			local non_root_user="${SUDO_USER:-$USER}"
			TextBlock "SECURITY WARNING: Root Execution Prevented" "$RED" "${BG_WHITE:-$BG_RED}"
			ErrorMessage "rcForge should not be run as root or with sudo."
			InfoMessage "Run as regular user (e.g., '${non_root_user}') or use RCFORGE_ALLOW_ROOT=1 to override."
		fi
		return 1
	fi

	return 0
}

# ============================================================================
# PATH MANAGEMENT FUNCTIONS
# ============================================================================

# Function: AddToPath
# Description: Adds directory to PATH if it exists and isn't already included
# Usage: AddToPath "/path/to/add" [prepend|append]
# Returns: 0 (always)
AddToPath() {
	local dir_to_add="$1"
	local position="${2:-prepend}"

	# Handle ~ expansion
	if [[ "$dir_to_add" == "~"* ]]; then
		dir_to_add="${HOME}/${dir_to_add#\~}"
	fi

	# Skip if directory doesn't exist
	[[ ! -d "$dir_to_add" ]] && return 0

	# Skip if already in PATH
	case ":${PATH}:" in
		*":${dir_to_add}:"* | *":${dir_to_add}/:"*)
			return 0
			;;
	esac

	# Add to PATH based on position
	if [[ "$position" == "append" ]]; then
		export PATH="${PATH:+$PATH:}$dir_to_add"
	else
		export PATH="$dir_to_add${PATH:+:$PATH}"
	fi

	return 0
}

# Function: AppendToPath
# Description: Adds directory to the end of PATH
# Usage: AppendToPath "/path/to/append"
# Returns: 0 (always)
AppendToPath() {
	AddToPath "$1" "append"
}

# Function: RemoveFromPath
# Description: Removes a directory from PATH if it exists
# Usage: RemoveFromPath "/path/to/remove"
# Returns: 0 if directory was removed, 1 if directory wasn't in PATH
RemoveFromPath() {
	local dir_to_remove="$1"
	local found=false
	local new_path=""
	local separator=""

	# Handle ~ expansion
	if [[ "$dir_to_remove" == "~"* ]]; then
		dir_to_remove="${HOME}/${dir_to_remove#\~/}"
	fi

	# Skip if directory isn't in PATH
	if [[ ":${PATH}:" != *":${dir_to_remove}:"* ]]; then
		return 1
	fi

	# Rebuild PATH without the specified directory
	for path_entry in ${PATH//:/ }; do
		if [[ "$path_entry" != "$dir_to_remove" ]]; then
			new_path+="${separator}${path_entry}"
			separator=":"
		else
			found=true
		fi
	done

	# Update PATH if we found and removed the directory
	if $found; then
		export PATH="$new_path"
		return 0
	fi

	return 1
}

# Function: ShowPath
# Description: Displays current PATH entries, one per line
# Usage: ShowPath
ShowPath() {
	printf '%s\n' "${PATH//:/$'\n'}"
}

# ============================================================================
# SCRIPT CONFIGURATION FUNCTIONS
# ============================================================================

# Function: FindRcScripts
# Description: Finds matching RC scripts for given shell and hostname
# Usage: mapfile -t scripts < <(FindRcScripts "bash" "hostname")
# Returns: Newline-separated list of script paths
FindRcScripts() {
	local shell=${1:-$(DetectShell)}
	local hostname=${2:-$(DetectHostname)}
	local pattern="[0-9]{3}_(global|${hostname})_(common|${shell})_.*\.sh"

	# Check if the scripts directory exists
	if [[ ! -d "$RCFORGE_SCRIPTS" ]]; then
		WarningMessage "rc-scripts directory not found: $RCFORGE_SCRIPTS"
		return 1
	fi

	# Find matching scripts and sort by sequence number
	find "$RCFORGE_SCRIPTS" -type f -perm -u+x -name '*sh' | grep -E "$pattern" | sort -n || {
		echo "No rc files found."
		return 1
	}
}

# Function: ExtractSummary
# Description: Extracts summary from script file
# Usage: summary=$(ExtractSummary "/path/to/script")
# Returns: Script summary or error message
ExtractSummary() {
	local script_file="${1:-}"
	local summary=""

	# Validate input
	if [[ -z "$script_file" ]]; then
		echo "(Error: No script path provided)"
		return 1
	elif [[ ! -f "$script_file" || ! -r "$script_file" ]]; then
		echo "(Error: Script file not found or not readable)"
		return 1
	fi

	# Try to extract RC Summary first
	summary=$(grep -m 1 '^# RC Summary:' "$script_file" || true)
	if [[ -n "$summary" ]]; then
		echo "${summary#\# RC Summary: }"
		return 0
	fi

	# Fallback to Description
	summary=$(grep -m 1 '^# Description:' "$script_file" || true)
	if [[ -n "$summary" ]]; then
		echo "${summary#\# Description: }"
		return 0
	fi

	# Nothing found
	echo "No summary available for $(basename "${script_file}")"
	return 1
}

# ============================================================================
# USER INTERFACE HELPERS
# ============================================================================

# Function: ShowVersionInfo
# Description: Displays version and copyright information
# Usage: ShowVersionInfo ["/path/to/script"]
ShowVersionInfo() {
	local script_name=""
	if [[ -n "${1:-}" ]]; then
		script_name=$(basename "$1")
	elif [[ -n "${BASH_SOURCE[0]:-}" ]]; then
		script_name=$(basename "${BASH_SOURCE[0]}")
	else
		script_name=$(basename "$0")
	fi

	InfoMessage "${script_name} (${gc_app_name} Utility) v${gc_version}"
	InfoMessage "Copyright (c) $(date +%Y) rcForge Team"
	InfoMessage "Released under the MIT License"
}

# Function: ShowStandardHelp
# Description: Displays standardized help information
# Usage: ShowStandardHelp ["script-specific help text"] ["/path/to/script"]
ShowStandardHelp() {
	local script_specific_options="${1:-}"
	local script_path="${2:-}"
	local script_name=""

	# Determine script name
	if [[ -n "$script_path" ]]; then
		script_name=$(basename "$script_path")
	elif [[ -n "${BASH_SOURCE[1]:-}" ]]; then
		script_name=$(basename "${BASH_SOURCE[1]}")
	elif [[ -n "${BASH_SOURCE[0]:-}" ]]; then
		script_name=$(basename "${BASH_SOURCE[0]}")
	else
		script_name=$(basename "$0")
	fi

	InfoMessage "Usage: ${script_name} [OPTIONS] [ARGUMENTS...]"
	echo ""
	InfoMessage "Standard Options:"
	printf "  %-18s %s\n" "--help, -h" "Show this help message and exit."
	printf "  %-18s %s\n" "--version" "Show version information and exit."
	printf "  %-18s %s\n" "--summary" "Show a one-line summary (for 'rc list')."

	if [[ -n "$script_specific_options" ]]; then
		echo ""
		InfoMessage "Script-Specific Options:"
		printf '%s\n' "${script_specific_options}"
	fi
	echo ""
}

# ============================================================================
# ARGUMENT PROCESSING
# ============================================================================

# ============================================================================
# Function: StandardParseArgs
# Description: Standardized argument parser with subcommand support
# Usage: declare -A options; StandardParseArgs options [defaults] -- "$@"
# Returns: 0 on success, 1 on error
# ============================================================================
StandardParseArgs() {
	local -n _options_ref="$1"
	shift

	# Ensure Bash 4.3+ for namerefs
	if [[ "${BASH_VERSINFO[0]}" -lt 4 || ("${BASH_VERSINFO[0]}" -eq 4 && "${BASH_VERSINFO[1]}" -lt 3) ]]; then
		ErrorMessage "Internal Error: StandardParseArgs requires Bash 4.3+."
		return 1
	fi

	# Set default values from arguments before --
	while [[ $# -gt 0 && "$1" != "--" ]]; do
		local default_option="$1"
		shift

		if [[ "$default_option" =~ ^--([^=]+)=(.*) ]]; then
			_options_ref["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
		else
			WarningMessage "Invalid default option format: $default_option"
		fi
	done

	# Skip the -- separator
	if [[ "$1" == "--" ]]; then shift; fi

	# Check for subcommand as first non-flag argument
	if [[ $# -gt 0 && ! "$1" =~ ^- ]]; then
		_options_ref["command"]="$1"
		shift
	fi

	# Parse remaining arguments
	while [[ $# -gt 0 ]]; do
		local arg="$1"

		# Handle --option=value
		if [[ "$arg" =~ ^--([^=]+)=(.*) ]]; then
			_options_ref["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"

		# Handle --option value
		elif [[ "$arg" =~ ^--(.*) ]]; then
			local option_name="${BASH_REMATCH[1]}"

			# Boolean flag
			if [[ -v "_options_ref[$option_name]" && "${_options_ref[$option_name]}" =~ ^(true|false)$ ]]; then
				_options_ref["$option_name"]="true"
			# Option with value
			elif [[ $# -gt 1 && ! "$2" =~ ^- ]]; then
				shift
				_options_ref["$option_name"]="$1"
			else
				_options_ref["$option_name"]="true" # Flag without value
			fi

		# Handle short flags -v
		elif [[ "$arg" =~ ^-([a-zA-Z]+)$ ]]; then
			local flags="${BASH_REMATCH[1]}"
			for ((i = 0; i < ${#flags}; i++)); do
				local flag="${flags:$i:1}"
				case "$flag" in
					h) _options_ref["help"]="true" ;;
					v) _options_ref["verbose_mode"]="true" ;;
					# Add other short flags as needed
					*)
						ErrorMessage "Unknown short flag: -$flag"
						return 1
						;;
				esac
			done

		# Handle --
		elif [[ "$arg" == "--" ]]; then
			shift
			break

		# Handle positional arguments (beyond subcommand)
		else
			if [[ -v "_options_ref[args]" ]]; then
				_options_ref["args"]+=" $arg"
			else
				_options_ref["args"]="$arg"
			fi
		fi

		shift
	done

	# Add remaining arguments after -- to args
	while [[ $# -gt 0 ]]; do
		if [[ -v "_options_ref[args]" ]]; then
			_options_ref["args"]+=" $1"
		else
			_options_ref["args"]="$1"
		fi
		shift
	done

	return 0
}

# Function: InitUtility
# Description: Initialize a standard rcForge utility environment
# Usage: InitUtility "utility_name" "$@"
# Returns: 0 on success, exits on standard options
InitUtility() {
	local utility_name="$1"
	shift
	export UTILITY_NAME="$utility_name"

	# Process standard options
	for arg in "$@"; do
		case "$arg" in
			--help | -h)
				ShowStandardHelp
				exit 0
				;;
			--version)
				ShowVersionInfo "$0"
				exit 0
				;;
			--summary)
				ExtractSummary "$0"
				exit $?
				;;
		esac
	done

	return 0
}

# Function: _rcforge_show_help
# Description: Standardized help text display with heredoc support
# Usage: _rcforge_show_help <<EOF
#   Help text here
# EOF
# Returns: Echoes formatted help text
_rcforge_show_help() {
	local script_name=""
	if [[ -n "${BASH_SOURCE[1]:-}" ]]; then
		script_name=$(basename "${BASH_SOURCE[1]}")
	elif [[ -n "${BASH_SOURCE[0]:-}" ]]; then
		script_name=$(basename "${BASH_SOURCE[0]}")
	else
		script_name=$(basename "$0")
	fi

	echo "${UTILITY_NAME:-$script_name} - ${gc_app_name} Utility (v${gc_version})"
	echo ""

	# Read heredoc content from stdin
	if [[ -p /dev/stdin ]]; then
		# If stdin is a pipe (heredoc)
		cat
	else
		# Fallback message if no heredoc provided
		echo "No detailed help available."
	fi
}

# Function: _rcforge_show_version
# Description: Displays version information in a standardized format
# Usage: _rcforge_show_version ["/path/to/script"]
# Returns: Echoes version information
_rcforge_show_version() {
	local script_path="${1:-$0}"
	local script_name=$(basename "$script_path")

	echo "${script_name} (${gc_app_name} Utility) v${gc_version}"
	echo "Copyright (c) $(date +%Y) ${gc_app_name} Team"
	echo "Released under the MIT License"
}

# ============================================================================
# EXPORT PUBLIC FUNCTIONS FOR BASH
# ============================================================================
# Only export for Bash, Zsh exports sourced functions automatically
if IsBash; then
	export -f _rcforge_show_help
	export -f _rcforge_show_version
	export -f DetectShell
	export -f IsZsh
	export -f IsBash
	export -f DetectOS
	export -f IsMacOS
	export -f IsLinux
	export -f CommandExists
	export -f DetectHostname
	export -f FindRcScripts
	export -f CheckRoot
	export -f AddToPath
	export -f AppendToPath
	export -f ShowPath
	export -f ExtractSummary
	export -f ShowVersionInfo
	export -f ShowStandardHelp
	export -f StandardParseArgs
	export -f InitUtility
	export -f IsExecutedDirectly
fi

# EOF
