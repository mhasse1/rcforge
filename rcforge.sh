#!/usr/bin/env bash
# rcforge.sh - Universal Shell Configuration Loader
# Author: Mark Hasse
# Version: v0.5.0pre2
# Category: core
# Description: Main loader script for rcForge shell configuration system.
#              Meant to be sourced by user's ~/.bashrc or ~/.zshrc.
#              Now supports XDG structure and API key management.

# ============================================================================
# Local message function (when sourced colors not available)
# ============================================================================
_print() {
	local reset='\033[0m'
	local fg='\033[1;33m'
	local bg='\033[41m'
	local text_color=$_fg$_bg
	local nl=""

	# Basic options parsing
	if [[ $1 == "-n" ]]; then
		nl="\n"
		shift
	elif [[ $1 == "-r" ]]; then
		$nl="\r"
		shift
	fi
	local msg="${*}${nl}"

	printf "%b%s%b" $text_color $msg $reset
}

# ============================================================================
# CRITICAL: INTERACTIVE SOURCING CHECK
# ============================================================================
_interactive_source=true
# Handle Zsh
[[ -n "${ZSH_VERSION:-}" && "$ZSH_EVAL_CONTEXT" != *:file:* || ! -o interactive ]] && _interactive_source=false
# Handle Bash
[[ -n "${BASH_VERSION:-}" && "${BASH_SOURCE[0]}" == "${0}" || $- != *i* ]] && _interactive_source=false

if ! $_interactive_source; then
	_print -n "ERROR: rcForge must be sourced in an interactive shell."
	return 1
fi
unset _interactive_source

# ============================================================================
# CRITICAL: ABORT CHECK
# ============================================================================
_timeout=3
_print -r "Initializing rcForge. Press '.' to abort, 'd' for debug (${_timeout}s)..."

if [[ -n "${ZSH_VERSION:-}" ]]; then
	read -s -t "${_timeout}" -k 1 _rcf_key
else
	read -s -N 1 -t "${_timeout}" _rcf_key
fi

printf "%75s\r" "" # Clear line

if [[ "$_abort_key" == "." ]]; then
	echo "rcForge aborted by user."
	return 1
elif [[ "$_abort_key" == "d" ]]; then
	echo "DEBUG_MODE enabled."
	DEBUG_MODE=true
fi
unset _abort_key _timeout

# ============================================================================
# CORE SYSTEM INITIALIZATION & ENVIRONMENT SETUP
# ============================================================================

# Set strict modes early for initialization safety
set -o nounset

# Source rcForge environment variables
source "${XDG_DATA_HOME:-$HOME/.local/share}/rcforge/system/lib/set-rcforge-environment.sh"

# ============================================================================
# SIMPLIFIED CONFIGURATION PROCESSING
# ============================================================================
ProcessConfiguration() {
	local file="$1"
	local is_path="${2:-false}"
	local separator=""
	local new_path=""

	# Skip if file doesn't exist
	[[ ! -f "$file" ]] && return 0

	# Process file line by line
	while IFS= read -r line; do
		# Skip comments and empty lines
		[[ "$line" =~ ^# || -z "$line" ]] && continue

		if [[ "$is_path" == "true" ]]; then
			# Path configuration handling
			line=$(eval echo "$line")
			if [[ -d "$line" && ":$new_path:" != *":$line:"* ]]; then
				new_path+="${separator}${line}"
				separator=":"
			fi
		else
			# API key handling
			export "$line"
		fi
	done <"$file"

	# Update PATH for path configuration
	if [[ "$is_path" == "true" && -n "$new_path" ]]; then
		export PATH="$new_path"
	fi
}

# ============================================================================
# SIMPLIFIED BASH VERSION VERIFICATION
# ============================================================================
VerifyBashVersion() {
	local required="4.3"
	local bash_cmd=$(command -v bash || echo "")

	[[ -z "$bash_cmd" ]] && {
		echo "ERROR: Bash not found in PATH. Required: $required+" >&2
		return 1
	}

	local version=$("$bash_cmd" --version | grep -o "version [0-9]\+\.[0-9]\+" | cut -d' ' -f2)
	[[ -z "$version" ]] && {
		echo "ERROR: Could not determine Bash version." >&2
		return 1
	}

	printf '%s\n%s\n' "$required" "$version" | sort -V -C || {
		echo "ERROR: Bash version $version is too old. Required: $required+" >&2
		return 1
	}

	return 0
}

# Process configuration files
ProcessConfiguration "${RCFORGE_CONFIG}/path.conf" true
ProcessConfiguration "${RCFORGE_DATA_ROOT}/config/api-keys.conf" false

# Verify bash version right after setting PATH
if ! VerifyBashVersion; then
	return 1
fi

# --- Source Core Utility Library ---
if [[ -f "${RCFORGE_LIB}/utility-functions.sh" ]]; then
	# shellcheck disable=SC1090
	source "${RCFORGE_LIB}/utility-functions.sh"
else
	# Cannot use ErrorMessage if sourcing failed, use basic echo
	echo -e "${_text_color}ERROR:\033[0m Critical library missing: ${RCFORGE_LIB}/utility-functions.sh. Cannot proceed.${_reset}" >&2
	return 1 # Stop sourcing this script
fi
# --- End Library Sourcing ---

# ============================================================================
# CONFIGURATION FILE SOURCING
# ============================================================================
SourceConfigFiles() {
	local -a files_to_source=("$@")
	local file=""

	# Loop through and source files
	for file in "${files_to_source[@]}"; do
		if [[ -r "$file" ]]; then
			# shellcheck disable=SC1090
			source "$file"
		else
			echo "Warning: Cannot read configuration file: $file. Skipping." >&2
		fi
	done
}

# ============================================================================
# RC COMMAND WRAPPER FUNCTION (Exported)
# ============================================================================
rc() {
	local rc_impl_path="${RCFORGE_CORE}/rc.sh"

	if [[ -f "$rc_impl_path" && -x "$rc_impl_path" ]]; then
		# Execute using bash to ensure consistency
		bash "$rc_impl_path" "$@"
		return $? # Return the exit status of the rc.sh script
	else
		# Use ErrorMessage if available (sourced from utility-functions)
		if command -v ErrorMessage &>/dev/null; then
			ErrorMessage "rc command core script not found or not executable: $rc_impl_path"
		else
			# Fallback if ErrorMessage failed to load
			echo "ERROR: rc command core script not found or not executable: $rc_impl_path" >&2
		fi
		return 127 # Command not found status
	fi
}
# Export the 'rc' function for the current shell if possible (Bash requires -f)
if command -v IsBash &>/dev/null && IsBash; then
	export -f rc
fi
# Zsh exports functions sourced by default, no explicit export needed

# ============================================================================
# MAIN LOADER FUNCTION
# ============================================================================
main() {
	# Root execution check (simple, no messaging if passed)
	if command -v CheckRoot &>/dev/null; then
		CheckRoot --skip-interactive || return 1
	fi

	# Perform integrity check (simplified approach)
	local check_runner="${RCFORGE_CORE}/run-integrity-checks.sh"
	if [[ -x "$check_runner" ]]; then
		bash "$check_runner" || {
			echo -e "\033[0;33mIntegrity issues detected. Continue anyway? (y/N):\033[0m "
			read -r response
			[[ ! "$response" =~ ^[Yy]$ ]] && return 1
		}
	fi

	# Load configuration files
	echo "Loading rcForge configuration..."
	local -a config_files=()

	if command -v FindRcScripts &>/dev/null; then
		mapfile -t config_files < <(FindRcScripts)
	else
		echo "Warning: FindRcScripts function not available." >&2
		return 1
	fi

	if [[ ${#config_files[@]} -gt 0 && "${config_files[0]}" != "No rc files found." ]]; then
		SourceConfigFiles "${config_files[@]}"
		echo "Configuration files loaded."
	else
		echo "No configuration files found."
	fi

	return 0
}

# ============================================================================
# EXECUTION START (When Sourced)
# ============================================================================

# Call the main loader function
main "$@"

# Clean up loader-specific function definitions from the shell environment
unset -f main
unset -f SourceConfigFiles
unset -f ProcessConfiguration
unset -f VerifyBashVersion
# Note: 'rc' function remains exported

# EOF
