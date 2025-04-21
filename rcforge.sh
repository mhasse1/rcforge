#!/usr/bin/env bash
# rcforge.sh - Universal Shell Configuration Loader
# Author: Mark Hasse
# Version: v0.5.0pre2
# Category: core
# Description: Main loader script for rcForge shell configuration system.
#              Meant to be sourced by user's ~/.bashrc or ~/.zshrc.
#              Now supports XDG structure and API key management.

# ============================================================================
# CORE SYSTEM INITIALIZATION & ENVIRONMENT SETUP
# ============================================================================

# --- Abort Check (optional) ---
# Locate immediately after comment block
_rcf_key=""
_timeout=3
_fg='\033[0;31m'
_bg='\033[47m'
_reset='\033[0m'

printf "%b%bInitializing rcForge. Press '.' to abort or 'd' to turn on debug within %is.%b\r" $_fg $_bg $_timeout $_reset

# Read user input with timeout
if [[ -n "${ZSH_VERSION:-}" ]]; then
	read -s -t "$_timeout" -k 1 _rcf_key
else
	read -s -N 1 -t "$_timeout" _rcf_key
fi

printf "%79s\r" "" # remove the previous line

if [[ -n "${_rcf_key:-}" ]]; then
	case "$_rcf_key" in
		".")
			printf "rcForge aborted by user."
			return 1
			;;
		"d")
			printf "DEBUG_MODE turned on."
			DEBUG_MODE=true
			;;
	esac
fi

echo ""
unset _rcf_key _timeout _fg _bg _reset
# --- End Abort Check ---

# Set strict modes early for initialization safety
set -o nounset

# Source rcForge environment variabls
source "${XDG_DATA_HOME:-$HOME/.local/share}/rcforge/system/lib/set-rcforge-environment.sh"

# Process path.conf to set PATH environment variable
ProcessPathConfiguration() {
	local path_file="${RCFORGE_CONFIG}/path.conf"
	local new_path=""
	local separator=""

	# Process path file line by line
	while IFS= read -r line; do
		# Skip comments and empty lines
		if [[ "$line" =~ ^# || -z "$line" ]]; then
			continue
		fi

		# Expand variables like ${HOME}
		line=$(eval echo "$line")

		# Add path if directory exists and not already in new_path
		if [[ -d "$line" && ":$new_path:" != *":$line:"* ]]; then
			new_path+="${separator}${line}"
			separator=":"
		fi
	done <"$path_file"

	# Set PATH environment variable
	if [[ -n "$new_path" ]]; then
		export PATH="$new_path"
	fi
}

# Process API key settings to export environment variables
ProcessApiKeys() {
	local api_key_file="${RCFORGE_DATA_ROOT}/config/api-keys.conf"

	# Process API key file line by line
	while IFS= read -r line; do
		# Skip comments and empty lines
		if [[ "$line" =~ ^# || -z "$line" ]]; then
			continue
		fi

		# Export API key environment variable
		export "$line"
	done <"$api_key_file"
}

# Process PATH configuration (0.5.0+ feature)
ProcessPathConfiguration

# --- Source Core Utility Library ---
# This needs to happen *after* PATH is set up
if [[ -f "${RCFORGE_LIB}/utility-functions.sh" ]]; then
	# shellcheck disable=SC1090
	source "${RCFORGE_LIB}/utility-functions.sh"
else
	# Cannot use ErrorMessage if sourcing failed, use basic echo
	echo -e "\033[0;31mERROR:\033[0m Critical library missing: ${RCFORGE_LIB}/utility-functions.sh. Cannot proceed." >&2
	return 1 # Stop sourcing this script
fi
# --- End Library Sourcing ---

# ============================================================================
# INTERNAL LOADER FUNCTIONS
# ============================================================================

# ============================================================================
# Function: SourceConfigFiles
# Description: Sources an array of configuration files, handling errors and optionally timing.
# Usage: SourceConfigFiles "file1" "file2" ...
# Arguments:
#   $@ - Array of absolute paths to configuration files to source.
# Returns: None. Sources files into the current shell environment.
# ============================================================================
SourceConfigFiles() {
	local -a files_to_source=("$@")
	local file=""
	local start_time=""
	local end_time=""
	local elapsed=""
	local have_bc=false
	local use_seconds=true # Default to using SECONDS fallback

	# Setup for optional timing
	if [[ "${DEBUG_MODE:-false}" == "true" ]]; then
		if CommandExists bc; then
			have_bc=true
		fi
		# Check if sub-second precision is available via date
		if date +%s.%N &>/dev/null; then
			use_seconds=false
		fi
		# Record start time
		if [[ "$use_seconds" == "false" ]]; then
			start_time=$(date +%s.%N)
		else
			start_time=$SECONDS
		fi
		DebugMessage "Starting rcForge configuration loading..."
	fi

	# Loop through and source files
	for file in "${files_to_source[@]}"; do
		if [[ -r "$file" ]]; then
			InfoMessage "Sourcing $file"
			# shellcheck disable=SC1090
			source "$file"
		else
			WarningMessage "Cannot read configuration file: $file. Skipping."
		fi
	done

	# Report timing if debug enabled
	if [[ "${DEBUG_MODE:-false}" == "true" ]]; then
		if [[ "$use_seconds" == "false" ]] && [[ "$have_bc" == "true" ]]; then
			end_time=$(date +%s.%N)
			elapsed=$(echo "$end_time - $start_time" | bc)
			DebugMessage "rcForge configuration loaded in $elapsed seconds."
		elif [[ "$use_seconds" == "true" ]]; then
			local duration=$((SECONDS - start_time))
			# Handle potential wrap-around or slight negative if start was near 0
			[[ $duration -lt 0 ]] && duration=0
			DebugMessage "rcForge configuration loaded in $duration seconds."
		else
			DebugMessage "rcForge configuration loading complete (precise timing unavailable)."
		fi
	fi
}

# ============================================================================
# RC COMMAND WRAPPER FUNCTION (Exported)
# ============================================================================
# ============================================================================
# Function: rc
# Description: Wrapper function to find and execute rcForge utility scripts.
#              Handles user overrides and dispatches to the core implementation.
# Usage: rc <command> [options] [arguments]
# Arguments:
#   $@ - Command name, options, and arguments passed to the utility script.
# Returns: Exit status of the executed utility script, or error status.
# ============================================================================
rc() {
	local rc_impl_path="${RCFORGE_CORE}/rc.sh"

	if [[ -f "$rc_impl_path" && -x "$rc_impl_path" ]]; then
		# Execute using bash to ensure consistency
		bash "$rc_impl_path" "$@"
		return $? # Return the exit status of the rc.sh script
	else
		# Use ErrorMessage if available (sourced from utility-functions)
		if CommandExists ErrorMessage; then
			ErrorMessage "rc command core script not found or not executable: $rc_impl_path" 127 # Provide exit code
		else
			# Fallback if ErrorMessage failed to load
			echo "ERROR: rc command core script not found or not executable: $rc_impl_path" >&2
		fi
		return 127 # Command not found status
	fi
}
# Export the 'rc' function for the current shell if possible (Bash requires -f)
if IsBash; then
	export -f rc
fi
# Zsh exports functions sourced by default, no explicit export needed

# ============================================================================
# MAIN LOADER FUNCTION
# ============================================================================
# ============================================================================
# Function: main (rcForge Loader)
# Description: Main entry point for the rcForge loader script. Performs checks,
#              finds relevant rc-scripts, and sources them.
# Usage: Called at the end of this script.
# Arguments:
#   $@ - Arguments passed when sourcing (usually none).
# Returns: 0 on successful loading, 1 on abort or critical failure.
# ============================================================================
main() {
	# --- Core Loading Steps ---
	# Check root execution (uses sourced CheckRoot)
	if ! CheckRoot --skip-interactive; then
		if IsZsh; then
			export PS1="%{$(tput setaf 226)%}%n%{$(tput setaf 220)%}@%{$(tput setaf 214)%}%m %{$(tput setaf 14)%}%1~ %{$(tput sgr0)%}# "
		else
			export PS1="\[$(tput setaf 226)\]\u\[$(tput setaf 220)\]@\[$(tput setaf 214)\]\h \[$(tput setaf 14)\]\w \[$(tput sgr0)\]# "
		fi
		return 1
	fi

	# --- Process API Keys (v0.5.0+ feature) ---
	ProcessApiKeys

	local current_shell=$(DetectShell)
	if [[ "$current_shell" != "bash" && "$current_shell" != "zsh" ]]; then
		WarningMessage "Unsupported shell detected: '$current_shell'. rcForge primarily supports bash and zsh."
		# Continue anyway, maybe common scripts work
	fi

	# Perform integrity checks unless skipped
	if [[ -z "${RCFORGE_SKIP_CHECKS:-}" ]]; then
		SectionHeader "rcForge Integrity Checks"
		local check_runner_script="${RCFORGE_CORE}/run-integrity-checks.sh"
		local check_runner_status=0

		if [[ -f "$check_runner_script" && -x "$check_runner_script" ]]; then
			# Execute using bash to ensure correct environment for checks
			bash "$check_runner_script"
			check_runner_status=$?

			if [[ $check_runner_status -ne 0 ]]; then
				# Warnings already printed by runner script
				# Ask user whether to proceed if interactive
				if [[ -n "${RCFORGE_NONINTERACTIVE:-}" || ! -t 0 ]]; then
					ErrorMessage "Running non-interactive. Aborting due to integrity issues." 1 # Use ErrorMessage to exit
				fi
				local response=""
				printf "%b" "${YELLOW}Integrity checks reported issues. Continue loading? (y/N):${RESET} "
				read -r response
				if [[ ! "$response" =~ ^[Yy]$ ]]; then
					ErrorMessage "Aborted by user due to integrity issues." 1 # Use ErrorMessage
				else
					SuccessMessage "Continuing despite integrity warnings..."
				fi
			else
				SuccessMessage "All integrity checks passed."
			fi
		else
			WarningMessage "Integrity check runner not found/executable: $check_runner_script"
			WarningMessage "Skipping integrity checks."
			# Consider if this should be fatal? For now, just warn.
		fi
		echo "" # Add newline after checks section
	else
		InfoMessage "Skipping integrity checks due to RCFORGE_SKIP_CHECKS."
	fi

	# --- Find and Source Configuration Files ---
	SectionHeader "Loading rcForge Configuration"
	InfoMessage "Locating and sourcing configuration files."

	local -a config_files_to_load=$(FindRcScripts)
	local find_status=$?

	# Check if find failed *and* no files were loaded
	if [[ $find_status -ne 0 && ${#config_files_to_load[@]} -eq 0 ]]; then
		WarningMessage "FindRcScripts failed (status: $find_status) and no files loaded. Aborting load."
		return 1
	fi

	# Source the files
	InfoMessage "Staring rc-script sourcing for ${current_shell} on $(DetectHostname)."
	if [[ ${#config_files_to_load[@]} -gt 0 ]]; then
		SourceConfigFiles "${config_files_to_load[@]}" # Call local function
	else
		InfoMessage "No specific rcForge configuration files found for ${current_shell} on $(DetectHostname)."
	fi
	SuccessMessage "Configuration files sourced."

	return 0 # Indicate successful loading
}

# ============================================================================
# EXECUTION START (When Sourced)
# ============================================================================

# Call the main loader function, capturing its status
main "$@"
_RCFORGE_INIT_STATUS=$?

# Clean up loader-specific function definitions from the shell environment
unset -f main
unset -f SourceConfigFiles
unset -f ProcessPathConfiguration
unset -f ProcessApiKeys
# Note: 'rc' function remains exported

# Return the final status of the main loader function
exit $_RCFORGE_INIT_STATUS

# EOF
