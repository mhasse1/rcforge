#!/usr/bin/env bash
# rcforge.sh - Universal Shell Configuration Loader
# Author: Mark Hasse
# Date: 2025-04-07 # Updated Date for refactor
# Version: 0.4.2
# Category: core
# Description: Main loader script for rcForge shell configuration system. Meant to be sourced by user's ~/.bashrc or ~/.zshrc.

# export RCFORGE_SKIP_CHECKS=1

# ============================================================================
# CORE SYSTEM INITIALIZATION & ENVIRONMENT SETUP
# ============================================================================

set -o nounset # Keep nounset for safety during init

export RCFORGE_APP_NAME="rcForge"
export RCFORGE_VERSION="0.4.2"

export RCFORGE_ROOT="${RCFORGE_ROOT:-$HOME/.config/rcforge}"

# --- begin prepend bash from installer ---
# Note: we want this as early in the execution as we can make it.

RCFORGE_BASH_LOCATION_FILE="${RCFORGE_ROOT}/docs/.bash_location"
if [[ -f "$RCFORGE_BASH_LOCATION_FILE" && -r "$RCFORGE_BASH_LOCATION_FILE" ]]; then
	RCFORGE_COMPLIANT_BASH_PATH=$(<"$RCFORGE_BASH_LOCATION_FILE")
	# Optional: Basic validation if path is non-empty and looks executable
	if [[ -n "$RCFORGE_COMPLIANT_BASH_PATH" && -x "$RCFORGE_COMPLIANT_BASH_PATH" ]]; then
		RCFORGE_COMPLIANT_BASH_DIR=$(dirname "$RCFORGE_COMPLIANT_BASH_PATH")
		# Prepend the directory if it's not already effectively in PATH
		case ":${PATH}:" in
			*":${RCFORGE_COMPLIANT_BASH_DIR}:"*) : ;; # Already there
			*) export PATH="${RCFORGE_COMPLIANT_BASH_DIR}${PATH:+:${PATH}}" ;;
		esac
		unset RCFORGE_COMPLIANT_BASH_DIR
	fi
	unset RCFORGE_COMPLIANT_BASH_PATH
fi
unset RCFORGE_BASH_LOCATION_FILE

# --- end prepend bash from installer ---

# --- BEGIN Initial PATH Setup from path.txt ---
# Path to the static path definition file

temp_path=""
separator=""
RCFORGE_PATH_FILE="${RCFORGE_ROOT}/docs/path.txt" # Using docs/

if [[ -f "$RCFORGE_PATH_FILE" && -r "$RCFORGE_PATH_FILE" ]]; then
	initial_path_entries=""
	separator="" # Will become ':' after first entry
	temp_path="" # Build new path prefix here

	while IFS= read -r path_line || [[ -n "$path_line" ]]; do
		# Trim leading/trailing whitespace
		path_line="${path_line#"${path_line%%[![:space:]]*}"}"
		path_line="${path_line%"${path_line##*[![:space:]]}"}"

		# Ignore comments and empty lines
		if [[ -z "$path_line" || "$path_line" == \#* ]]; then
			continue
		fi

		# Handle ~ expansion manually and avoid eval
		if [[ "$path_line" == "~"* ]]; then
			path_line="<span class="math-inline">HOME/</span>{path_line#\~}"
		fi

		# Check existence and prevent duplicates in this batch
		if [[ -d "$path_line" && ":${temp_path}:" != *":${path_line}:"* ]]; then
			temp_path+="${separator}${path_line}"
			separator=":"
		fi
	done <"$RCFORGE_PATH_FILE"

	# Prepend the collected paths to the existing PATH if any were found
	if [[ -n "$temp_path" ]]; then
		# Prepend after the compliant bash path (if added)
		export PATH="${temp_path}${PATH:+:${PATH}}"
		# DebugMessage "Prepended paths from '$RCFORGE_PATH_FILE': $temp_path"
	fi
	# Clean up local vars used only in this block
	unset temp_path path_line separator
fi
unset RCFORGE_PATH_FILE # Clean up temp var

# --- END Initial PATH Setup from path.txt ---

# Finish libary variable declarations
export RCFORGE_LIB="${RCFORGE_ROOT}/system/lib"
export RCFORGE_CORE="${RCFORGE_ROOT}/system/core"
export RCFORGE_UTILS="${RCFORGE_ROOT}/system/utils"
export RCFORGE_SCRIPTS="${RCFORGE_ROOT}/rc-scripts"
export RCFORGE_USER_UTILS="${RCFORGE_ROOT}/utils"

# --- source (include) operations ---

# Source utility functions (which will internally source shell-colors)
if [[ -f "${RCFORGE_LIB}/utility-functions.sh" ]]; then
	# shellcheck disable=SC1090
	source "${RCFORGE_LIB}/utility-functions.sh"
else
	# Use ErrorMessage if possible, else fallback echo
	if command -v ErrorMessage &>/dev/null; then
		ErrorMessage "Utility functions file missing: ${RCFORGE_LIB}/utility-functions.sh. Cannot proceed."
	else
		echo -e "\033[0;31mERROR:\033[0m Utility functions file missing: ${RCFORGE_LIB}/utility-functions.sh. Cannot proceed." >&2
	fi
	return 1 # Stop sourcing
fi

#
# --- End Sourcing ---
#

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
			end_time=$(date +%s.%N)
			elapsed=$(echo "$end_time - $start_time" | bc)
			DebugMessage "rcForge configuration loaded in $elapsed seconds."
		elif [[ "$use_seconds" == "true" ]]; then
			local duration=$((SECONDS - start_time))
			[[ $duration -lt 0 ]] && duration=0
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
	local rc_impl_path="${RCFORGE_CORE:-$HOME/.config/rcforge/system/core}/rc.sh"
	if [[ -f "$rc_impl_path" && -x "$rc_impl_path" ]]; then
		bash "$rc_impl_path" "$@" # Use plain bash command
		return $?
	else
		if command -v ErrorMessage &>/dev/null; then
			ErrorMessage "rc command script not found or not executable: $rc_impl_path"
		else
			echo "ERROR: rc command script not found or not executable: $rc_impl_path" >&2
		fi
		return 127
	fi
}
$(IsBash) && export -f rc

# ============================================================================
# Function: main (Loader Main Logic)
# ============================================================================
main() {

	# --- Abort Check (optional) ---
	local user_input=""
	local timeout_seconds=1
	printf "%b" "${BRIGHT_BLUE}[INFO]${RESET} Initializing rcForge v${RCFORGE_VERSION}. ${BRIGHT_WHITE}(Press '.' within ${timeout_seconds}s to abort).${RESET}"
	# if read -s -N 1 -t "$timeout_seconds" user_input; then
	local read_cmd_status=0
	user_input="" # Ensure it's empty beforehand

	if IsZsh; then
		# Zsh: Use -k 1 for one char, -s for silent, -t for timeout
		# Note: Prompt handling with -s might differ slightly
		read -s -t "$timeout_seconds" -k 1 user_input
		read_cmd_status=$?
	else
		# Bash: Use -N 1 for one char, -s for silent, -t for timeout
		read -s -N 1 -t "$timeout_seconds" user_input
		read_cmd_status=$?
	fi

	# Check the status code from the read command
	if [[ $read_cmd_status -eq 0 ]]; then
		echo ""
		if [[ "$user_input" == "." ]]; then
			WarningMessage "rcForge loading aborted by user."
			return 1
		fi
	else
		# if [[ $read_cmd_status -gt 128 || (-n "${ZSH_VERSION:-}" && $read_cmd_status -ne 0) ]]; then
		if [[ $read_cmd_status -gt 128 || (IsZsh && $read_cmd_status -ne 0) ]]; then
			echo " Continuing."
		else
			WarningMessage "Read command failed unexpectedly during abort check. Continuing..."
		fi
	fi
	# --- End Abort Check ---

	# --- Core Loading ---
	if ! CheckRoot --skip-interactive; then return 1; fi # Use sourced CheckRoot

	local current_shell
	current_shell=$(DetectShell) # Use sourced DetectShell
	if [[ "$current_shell" != "bash" && "$current_shell" != "zsh" ]]; then
		WarningMessage "Unsupported shell detected: '$current_shell'. rcForge primarily supports bash and zsh."
	fi

	#

	if [[ -z "${RCFORGE_SKIP_CHECKS:-}" ]]; then
		SectionHeader "rcForge Integrity Checks" # Print header from rcforge.sh
		local check_runner_script="${RCFORGE_CORE}/run-integrity-checks.sh"
		local check_runner_status=0

		if [[ -f "$check_runner_script" && -x "$check_runner_script" ]]; then
			# Execute the check logic script using bash
			bash "$check_runner_script" # Run the new script
			check_runner_status=$?      # Capture its exit status

			if [[ $check_runner_status -ne 0 ]]; then
				# Warnings/Errors should have been printed by the script itself.
				# Prompt user whether to continue if interactive
				if [[ -n "${RCFORGE_NONINTERACTIVE:-}" || ! -t 0 ]]; then
					ErrorMessage "Running in non-interactive mode. Aborting rcForge initialization due to integrity issues."
					return 1
				fi
				local response=""
				printf "%b" "${YELLOW}Integrity checks reported issues. Continue loading rcForge anyway? (y/N):${RESET} "
				read -r response
				if [[ ! "$response" =~ ^[Yy]$ ]]; then
					ErrorMessage "Shell configuration loading aborted by user due to integrity issues."
					return 1
				else
					SuccessMessage "Continuing with rcForge initialization despite integrity warnings..."
				fi
			else
				# Only print overall success if checks passed
				SuccessMessage "All integrity checks passed."
			fi
		else
			WarningMessage "Integrity check runner script not found or not executable: $check_runner_script"
			WarningMessage "Skipping integrity checks."
			# Decide whether to abort here? For now, let's warn and continue.
			# return 1 # Uncomment to make this fatal
		fi
		echo "" # Add a newline after checks section
	else
		InfoMessage "Skipping integrity checks due to RCFORGE_SKIP_CHECKS."
	fi

	#

	SectionHeader "Loading rcForge Configuration"
	InfoMessage "Locating and sourcing configuration files."
	# --- Determine Load Path (FIXED CALL) ---
	local -a config_files_to_load
	# Call FindRcScripts directly (from sourced utility-functions.sh)

	local find_output
	local find_status # Variable to store FindRcScripts status
	find_output=$(FindRcScripts "$current_shell")
	find_status=$? # Capture status IMMEDIATELY after command substitution

	# ... (conditional logic for Zsh/Bash array assignment) ...
	# Example for Zsh block (apply similarly for Bash/fallback if needed):
	if IsZsh; then
		config_files_to_load=()
		local line
		while IFS= read -r line; do
			[[ -n "$line" ]] && config_files_to_load+=("$line")
		done <<<"$find_output"
	elif IsBash; then
		# Bash: Use mapfile
		mapfile -t config_files_to_load <<<"$find_output"
	else
		# Fallback for other shells (less robust)
		config_files_to_load=($(echo "$find_output"))
	fi

	# Check if FindRcScripts itself failed AND we ended up with no files
	if [[ $find_status -ne 0 && ${#config_files_to_load[@]} -eq 0 ]]; then
		WarningMessage "FindRcScripts failed (status: $find_status) and no files were loaded. Aborting load."
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
	SuccessMessage "Configuraton files sourced."

	return 0 # Indicate successful sourcing
}

# ============================================================================
# EXECUTION START
# ============================================================================

main "$@"
_RCFORGE_INIT_STATUS=$?
unset -f main                # Clean up main function definition
return $_RCFORGE_INIT_STATUS # Return final status

# EOF
