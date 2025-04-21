#!/usr/bin/env bash
# chkseq.sh - Detect and resolve sequence number conflicts in rcForge configurations
# Author: rcForge Team
# Date: 2025-04-21 # Updated for XDG compliance
# Version: 0.5.0
# Category: system/utility
# RC Summary: Checks for sequence number conflicts in rcForge configuration scripts
# Description: Identifies and offers to resolve sequence number conflicts in shell configuration scripts

# Source necessary libraries (utility-functions sources shell-colors)
source "${RCFORGE_LIB:-${XDG_DATA_HOME:-$HOME/.local/share}/rcforge/system/lib}/utility-functions.sh"

# Set strict error handling
set -o nounset
set -o pipefail
# set -o errexit # Let functions handle errors

# ============================================================================
# GLOBAL CONSTANTS
# ============================================================================
readonly GC_SUPPORTED_SHELLS=("bash" "zsh")
# Use sourced constants, provide fallback just in case
[[ -v gc_version ]] || readonly gc_version="${RCFORGE_VERSION:-0.5.0}"
[[ -v gc_app_name ]] || readonly gc_app_name="${RCFORGE_APP_NAME:-rcForge}"

# ============================================================================
# LOCAL HELPER FUNCTIONS
# ============================================================================

# ============================================================================
# Function: ShowHelp
# Description: Display detailed help information for the chkseq command.
# Usage: ShowHelp
# Exits: 0
# ============================================================================
ShowHelp() {
	local script_name
	script_name=$(basename "$0")

	echo "chkseq - ${gc_app_name} Sequence Conflict Detection Utility (v${gc_version})"
	echo ""
	echo "Description:"
	echo "  Identifies and offers to resolve sequence number conflicts in"
	echo "  shell configuration scripts based on hostname and shell."
	echo ""
	echo "Usage:"
	echo "  rc chkseq [options]"
	echo "  ${script_name} [options]"
	echo ""
	echo "Options:"
	echo "  --hostname=NAME   Check conflicts for specific hostname (default: current)"
	echo "  --shell=bash|zsh  Check conflicts for specific shell (default: current)"
	echo "  --all             Check all detected hostnames and both shells"
	echo "  --fix             Interactively offer to fix detected conflicts"
	echo "  --non-interactive Run checks without user interaction (no fixing)"
	echo "  --dry-run         Show what fixing would do without making changes"
	echo "  --help, -h        Show this help message"
	echo "  --summary         Show a one-line description (for rc help)"
	echo "  --version         Show version information"
	echo ""
	echo "Examples:"
	echo "  rc chkseq                    # Check current hostname and shell"
	echo "  rc chkseq --hostname=laptop  # Check conflicts for 'laptop'"
	echo "  rc chkseq --shell=bash       # Check Bash configuration conflicts"
	echo "  rc chkseq --all              # Check all possible execution paths"
	echo "  rc chkseq --fix              # Interactively fix conflicts for current context"
	echo "  rc chkseq --all --dry-run    # Show potential conflicts everywhere"
	exit 0
}

# ============================================================================
# Function: ValidateShell
# Description: Validate if the provided shell name is supported.
# Usage: ValidateShell shell_name
# Returns: 0 if valid, 1 if invalid.
# ============================================================================
ValidateShell() {
	local shell_to_check="${1:-}"
	local supported_shell=""

	for supported_shell in "${GC_SUPPORTED_SHELLS[@]}"; do
		if [[ "$shell_to_check" == "$supported_shell" ]]; then
			return 0
		fi
	done

	ErrorMessage "Invalid shell specified: '$shell_to_check'. Supported are: ${GC_SUPPORTED_SHELLS[*]}"
	return 1
}

# ============================================================================
# Function: GetSequenceNumber
# Description: Extract the 3-digit sequence number prefix from a filename.
# Usage: GetSequenceNumber filename
# Returns: Echoes the sequence number (e.g., "050") or "INVALID".
# ============================================================================
GetSequenceNumber() {
	local filename="${1:-}"
	local seq="${filename%%_*}"

	# Validate it's 3 digits
	if [[ "$seq" =~ ^[0-9]{3}$ ]]; then
		echo "$seq"
	else
		echo "INVALID"
	fi
}

# ============================================================================
# Function: SuggestNewSeqNum
# Description: Suggest the next available 3-digit sequence number.
# Usage: SuggestNewSeqNum current_seq_str all_used_seqs_str
# Returns: Echoes suggested 3-digit sequence number or "ERR".
# ============================================================================
SuggestNewSeqNum() {
	local current_seq_str="${1:-}"
	local all_used_seqs_str="${2:-}"

	# Validate input format
	if ! [[ "$current_seq_str" =~ ^[0-9]{3}$ ]]; then
		ErrorMessage "Invalid current sequence '$current_seq_str' passed to SuggestNewSeqNum."
		echo "ERR"
		return 1
	fi

	local current_seq_num=$((10#$current_seq_str)) # Force base 10
	local suggestion=""
	local range_start=$(((current_seq_num / 100) * 100))
	local range_end=$((range_start + 99))
	local formatted_seq=""

	# First try the same range block
	for ((i = current_seq_num + 1; i <= range_end; i++)); do
		printf -v formatted_seq "%03d" "$i"
		if [[ ! ",${all_used_seqs_str}," =~ ",${formatted_seq}," ]]; then
			echo "$formatted_seq"
			return 0
		fi
	done

	# Try earlier in the same block
	for ((i = range_start; i < current_seq_num; i++)); do
		printf -v formatted_seq "%03d" "$i"
		if [[ ! ",${all_used_seqs_str}," =~ ",${formatted_seq}," ]]; then
			echo "$formatted_seq"
			return 0
		fi
	done

	# Try in other blocks
	for block in {0..9}; do
		if [[ $block -eq $((range_start / 100)) ]]; then
			continue # Skip the block we already checked
		fi

		for ((i = block * 100; i < (block + 1) * 100; i++)); do
			printf -v formatted_seq "%03d" "$i"
			if [[ ! ",${all_used_seqs_str}," =~ ",${formatted_seq}," ]]; then
				echo "$formatted_seq"
				return 0
			fi
		done
	done

	# If we get here, couldn't find any available sequence
	ErrorMessage "Could not find an available sequence number (000-999)."
	echo "ERR"
	return 1
}

# ============================================================================
# Function: RenameConflictingFile
# Description: Rename a single conflicting file with a new sequence number.
# Usage: RenameConflictingFile file_to_rename new_seq_num scripts_dir all_used_seqs_ref is_dry_run
# Arguments:
#   file_to_rename - Filename to be renamed
#   new_seq_num - New sequence number to use
#   scripts_dir - Directory containing the scripts
#   all_used_seqs_ref - Reference to string of used sequences
#   is_dry_run - Whether to actually perform the rename
# Returns: 0 on success, 1 on failure
# ============================================================================
RenameConflictingFile() {
	local file_to_rename="$1"
	local new_seq_num="$2"
	local scripts_dir="$3"
	local -n used_seqs_ref="$4"
	local is_dry_run="$5"

	# Calculate new filename
	local suffix="${file_to_rename#*_}"
	local new_filename="${new_seq_num}_${suffix}"
	local current_path="${scripts_dir}/${file_to_rename}"
	local new_path="${scripts_dir}/${new_filename}"

	InfoMessage "    Renaming: '${file_to_rename}' → '${new_filename}'"

	if [[ "$is_dry_run" == "true" ]]; then
		InfoMessage "    [DRY RUN] Would rename file."
		used_seqs_ref+=",${new_seq_num}"
		return 0
	fi

	# Actually perform the rename
	if mv -v "$current_path" "$new_path"; then
		SuccessMessage "    File renamed successfully."
		used_seqs_ref+=",${new_seq_num}"
		return 0
	else
		local mv_status=$?
		ErrorMessage "    Failed to rename file (mv exit status: $mv_status)."
		return 1
	fi
}

# ============================================================================
# Function: PromptForNewSequence
# Description: Prompt user for a new sequence number or use suggestion.
# Usage: PromptForNewSequence suggested_seq_num all_used_seqs
# Returns: Echoes the chosen sequence number or "skip" for skipping.
# ============================================================================
PromptForNewSequence() {
	local suggested_seq="$1"
	local all_used_seqs="$2"
	local response=""

	# Prompt user for input
	printf "%s" "    Enter new sequence (3 digits), 's' to skip, or Enter for suggestion [${suggested_seq}]: "
	read -r response
	response="${response:-$suggested_seq}" # Default to suggestion

	if [[ "$response" =~ ^[Ss]$ ]]; then
		echo "skip"
		return 0
	fi

	# Validate user input
	if ! [[ "$response" =~ ^[0-9]{3}$ ]]; then
		WarningMessage "    Invalid input '$response'. Must be 3 digits. Using suggestion '$suggested_seq'."
		echo "$suggested_seq"
		return 0
	fi

	if [[ ",${all_used_seqs}," =~ ",${response}," ]]; then
		WarningMessage "    Sequence '$response' is already in use. Using suggestion '$suggested_seq'."
		echo "$suggested_seq"
		return 0
	fi

	echo "$response"
	return 0
}

# ============================================================================
# Function: FixSeqConflicts
# Description: Interactively guides user to fix sequence number conflicts.
# Usage: FixSeqConflicts rcforge_dir shell hostname sequence_map is_interactive is_dry_run
# Arguments: Requires Bash 4.3+ for namerefs.
# Returns: 0 if all conflicts addressed/dry-run, 1 otherwise.
# ============================================================================
FixSeqConflicts() {
	local scripts_dir="${RCFORGE_SCRIPTS:-${1}/rc-scripts}"
	local shell="${2:-}"
	local hostname="${3:-}"
	local -n seq_map_ref="$4" # Nameref (Bash 4.3+)
	local is_interactive="${5:-false}"
	local is_dry_run="${6:-false}"

	local all_fixed_or_skipped=true
	local all_used_seqs_str="" # Comma-separated list of all sequence numbers in use

	# Ensure Bash 4.3+ for namerefs
	if [[ "${BASH_VERSINFO[0]}" -lt 4 || ("${BASH_VERSINFO[0]}" -eq 4 && "${BASH_VERSINFO[1]}" -lt 3) ]]; then
		ErrorMessage "Internal Error: FixSeqConflicts requires Bash 4.3+ for namerefs."
		return 1
	fi

	if [[ "$is_interactive" == "false" ]]; then
		WarningMessage "Non-interactive conflict fixing is not supported."
		WarningMessage "Conflicts remain for ${hostname}/${shell}."
		return 1
	fi

	# Build string of all used sequence numbers
	all_used_seqs_str=$(
		IFS=,
		echo "${!seq_map_ref[*]}"
	)

	# Sort the conflicting sequence numbers
	local sorted_conflicting_seqs=()
	for seq_num in "${!seq_map_ref[@]}"; do
		# Only process if it's a conflict (multiple files)
		if [[ "${seq_map_ref[$seq_num]}" == *,* ]]; then
			sorted_conflicting_seqs+=("$seq_num")
		fi
	done
	sorted_conflicting_seqs=($(printf '%s\n' "${sorted_conflicting_seqs[@]}" | sort -n))

	# Process each conflicting sequence
	for seq_num in "${sorted_conflicting_seqs[@]}"; do
		local files_string="${seq_map_ref[$seq_num]}"
		local conflict_files=()

		echo # Blank line for spacing
		InfoMessage "${CYAN}Resolving conflict for sequence ${BOLD}${seq_num}${RESET}${CYAN}:${RESET}"
		IFS=',' read -r -a conflict_files <<<"$files_string"

		# Keep first file at current sequence
		InfoMessage "  Keeping: '${conflict_files[0]}'"

		# Process other conflicting files
		for ((i = 1; i < ${#conflict_files[@]}; i++)); do
			local file_to_rename="${conflict_files[$i]}"
			local suggested_seq=$(SuggestNewSeqNum "$seq_num" "$all_used_seqs_str")

			if [[ "$suggested_seq" == "ERR" ]]; then
				ErrorMessage "  Cannot suggest a new number for '$file_to_rename'. Skipping."
				all_fixed_or_skipped=false
				continue
			fi

			echo
			InfoMessage "  File to renumber: ${CYAN}${file_to_rename}${RESET}"
			InfoMessage "    Current sequence: ${RED}${seq_num}${RESET}"
			InfoMessage "    Suggested sequence: ${GREEN}${suggested_seq}${RESET}"

			if [[ "$is_dry_run" == "true" ]]; then
				InfoMessage "    [DRY RUN] Would rename to sequence ${suggested_seq}."
				all_used_seqs_str+=",${suggested_seq}" # Add for subsequent suggestions
				continue
			fi

			# Get new sequence number from user or use suggestion
			local new_seq_num_str=$(PromptForNewSequence "$suggested_seq" "$all_used_seqs_str")

			if [[ "$new_seq_num_str" == "skip" ]]; then
				WarningMessage "    Skipping rename for '$file_to_rename'."
				all_fixed_or_skipped=false
				continue
			fi

			# Perform the rename
			if ! RenameConflictingFile "$file_to_rename" "$new_seq_num_str" "$scripts_dir" all_used_seqs_str "$is_dry_run"; then
				all_fixed_or_skipped=false
			fi
		done
	done

	echo "" # Add final newline
	if [[ "$all_fixed_or_skipped" == "true" ]]; then
		if [[ "$is_dry_run" == "true" ]]; then
			SuccessMessage "[DRY RUN] Conflict resolution simulation complete."
		else
			SuccessMessage "Conflict resolution process complete for ${hostname}/${shell}."
		fi
		return 0
	else
		WarningMessage "Some conflicts were skipped or failed to resolve for ${hostname}/${shell}."
		return 1
	fi
}

# ============================================================================
# Function: FindConfigFiles
# Description: Find configuration files for a specific shell/hostname
# Usage: FindConfigFiles shell hostname
# Returns: Array of matching files
# ============================================================================
FindConfigFiles() {
	local shell="$1"
	local hostname="$2"
	local config_files=()

	# Use the rcForge function to find scripts
	mapfile -t config_files < <(FindRcScripts "$shell" "$hostname")

	if [[ ${#config_files[@]} -eq 0 || "${config_files[0]}" == "No rc files found." ]]; then
		return 1
	fi

	printf '%s\n' "${config_files[@]}"
	return 0
}

# ============================================================================
# Function: BuildSequenceMap
# Description: Build a map of sequence numbers to filenames
# Usage: declare -A sequence_map; BuildSequenceMap sequence_map config_files
# Returns: Populates sequence_map, returns 0 if conflicts found, 1 if none
# ============================================================================
BuildSequenceMap() {
	local -n seq_map="$1"
	shift
	local -a files=("$@")
	local has_conflicts=false

	# Clear the map
	seq_map=()

	# Process each file
	for file in "${files[@]}"; do
		[[ -z "$file" ]] && continue

		local filename=$(basename "$file")
		local seq_num=$(GetSequenceNumber "$filename")

		if [[ "$seq_num" == "INVALID" ]]; then
			WarningMessage "Skipping file with invalid sequence format: $filename"
			continue
		fi

		# Check for conflicts
		if [[ -v "seq_map[$seq_num]" ]]; then
			seq_map["$seq_num"]+=",${filename}"
			has_conflicts=true
		else
			seq_map["$seq_num"]="$filename"
		fi
	done

	if [[ "$has_conflicts" == "true" ]]; then
		return 0
	else
		return 1
	fi
}

# ============================================================================
# Function: DisplayConflicts
# Description: Display detected conflicts in a clear format
# Usage: DisplayConflicts sequence_map shell hostname
# Returns: 0 if displayed successfully
# ============================================================================
DisplayConflicts() {
	local -n seq_map="$1"
	local shell="$2"
	local hostname="$3"

	# Use sourced TextBlock
	TextBlock "Sequence Conflicts Detected for ${hostname}/${shell}" "$RED" "${BG_WHITE:-$BG_RED}"
	echo ""

	# Sort sequence numbers for display
	local sorted_seqs=($(printf '%s\n' "${!seq_map[@]}" | sort -n))

	for seq_num in "${sorted_seqs[@]}"; do
		local files_string="${seq_map[$seq_num]}"

		# Only display if it's actually a conflict (multiple files)
		if [[ "$files_string" == *,* ]]; then
			echo -e "${RED}Conflict at sequence ${BOLD}${seq_num}${RESET}${RED}:${RESET}"

			# Indent list for consistency
			echo "$files_string" | tr ',' '\n' | sed 's/^/  /'
			echo ""
		fi
	done

	return 0
}

# ============================================================================
# Function: CheckSeqConflicts
# Description: Check for sequence number conflicts for a specific shell/hostname pair.
# Usage: CheckSeqConflicts shell hostname is_fix_mode is_interactive is_dry_run
# Returns: 0 if no conflicts, 1 if conflicts found (or fix attempt failed).
# ============================================================================
CheckSeqConflicts() {
	local shell="${1:-}"
	local hostname="${2:-}"
	local is_fix_mode="${3:-false}"
	local is_interactive="${4:-true}"
	local is_dry_run="${5:-false}"
	local rcforge_dir="${RCFORGE_CONFIG_ROOT}"

	local -a config_files=()
	local has_conflicts=false
	declare -A sequence_map

	InfoMessage "Checking sequence conflicts for ${hostname}/${shell}..."

	# Find all matching config files
	mapfile -t config_files < <(FindConfigFiles "$shell" "$hostname")
	if [[ $? -ne 0 || ${#config_files[@]} -eq 0 ]]; then
		InfoMessage "No configuration files found for ${hostname}/${shell}. Skipping check."
		return 0
	fi

	# Build sequence map
	if ! BuildSequenceMap sequence_map "${config_files[@]}"; then
		SuccessMessage "No sequence conflicts found for ${hostname}/${shell}."
		return 0
	fi

	# Display conflicts
	DisplayConflicts sequence_map "$shell" "$hostname"

	# Fix conflicts if requested
	if [[ "$is_fix_mode" == "true" ]]; then
		if FixSeqConflicts "$rcforge_dir" "$shell" "$hostname" sequence_map "$is_interactive" "$is_dry_run"; then
			return 0
		else
			return 1
		fi
	else
		WarningMessage "Run with --fix to attempt interactive resolution."
		return 1
	fi
}

# ============================================================================
# Function: DetectHostnames
# Description: Detect all hostnames used in rc-scripts
# Usage: DetectHostnames
# Returns: List of hostnames
# ============================================================================
DetectHostnames() {
	local scripts_dir="${RCFORGE_SCRIPTS}"
	local -a detected_hosts=("global") # Always include global
	local current_hostname=$(DetectHostname)

	# Add current hostname
	detected_hosts+=("$current_hostname")

	# Find other hostnames from script files
	if [[ -d "$scripts_dir" ]]; then
		while IFS= read -r hostname; do
			[[ -n "$hostname" && "$hostname" != "global" ]] && detected_hosts+=("$hostname")
		done < <(find "$scripts_dir" -maxdepth 1 -type f -name "[0-9][0-9][0-9]_*_*_*.sh" |
			xargs -r basename |
			cut -d '_' -f 2 |
			grep -v '^global$' |
			sort -u)
	fi

	# Return unique list
	printf '%s\n' "${detected_hosts[@]}" | sort -u
}

# ============================================================================
# Function: CheckAllSeqConflicts
# Description: Check sequence conflicts across all detected hostnames and supported shells.
# Usage: CheckAllSeqConflicts is_fix_mode is_interactive is_dry_run
# Returns: 0 if no conflicts found anywhere, 1 otherwise.
# ============================================================================
CheckAllSeqConflicts() {
	local is_fix_mode="${1:-false}"
	local is_interactive="${2:-true}"
	local is_dry_run="${3:-false}"

	local any_conflicts_found=false

	# Get all hostnames
	local -a hostnames=()
	mapfile -t hostnames < <(DetectHostnames)

	InfoMessage "Checking combinations for shells: ${GC_SUPPORTED_SHELLS[*]}"
	InfoMessage "Checking combinations for hostnames: ${hostnames[*]}"
	echo ""

	# Iterate through all combinations
	for shell in "${GC_SUPPORTED_SHELLS[@]}"; do
		for hostname in "${hostnames[@]}"; do
			if ! CheckSeqConflicts "$shell" "$hostname" "$is_fix_mode" "$is_interactive" "$is_dry_run"; then
				any_conflicts_found=true
			fi
			echo # Add separator line
		done
	done

	# Report final overall status
	if [[ "$any_conflicts_found" == "true" ]]; then
		if [[ "$is_fix_mode" == "true" && "$is_dry_run" == "false" ]]; then
			WarningMessage "Sequence conflicts were detected. Some may not have been resolved."
		elif [[ "$is_dry_run" == "true" ]]; then
			WarningMessage "[DRY RUN] Sequence conflicts were detected in one or more execution paths."
		else
			WarningMessage "Sequence conflicts were detected in one or more execution paths. Use --fix to resolve."
		fi
		return 1
	else
		SuccessMessage "No sequence conflicts found in any detected execution paths."
		return 0
	fi
}

# ============================================================================
# Function: ParseArguments
# Description: Parse command-line arguments for chkseq script.
# Usage: declare -A options; ParseArguments options "$@"
# Returns: Populates associative array by reference.
# ============================================================================
ParseArguments() {
	local -n options_ref="$1"
	shift

	# Ensure Bash 4.3+ for namerefs
	if [[ "${BASH_VERSINFO[0]}" -lt 4 || ("${BASH_VERSINFO[0]}" -eq 4 && "${BASH_VERSINFO[1]}" -lt 3) ]]; then
		ErrorMessage "Internal Error: ParseArguments requires Bash 4.3+ for namerefs."
		return 1
	fi

	# Set defaults using sourced functions
	options_ref["target_hostname"]=$(DetectHostname)
	options_ref["target_shell"]=$(DetectShell)
	options_ref["check_all"]=false
	options_ref["fix_conflicts"]=false
	options_ref["is_interactive"]=true
	options_ref["is_dry_run"]=false

	# Process arguments
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
				ShowVersionInfo "$0"
				exit 0
				;;
			--hostname=*)
				options_ref["target_hostname"]="${key#*=}"
				shift
				;;
			--hostname)
				shift
				if [[ -z "${1:-}" || "$1" == -* ]]; then
					ErrorMessage "--hostname requires a value."
					return 1
				fi
				options_ref["target_hostname"]="$1"
				shift
				;;
			--shell=*)
				options_ref["target_shell"]="${key#*=}"
				if ! ValidateShell "${options_ref["target_shell"]}"; then return 1; fi
				shift
				;;
			--shell)
				shift
				if [[ -z "${1:-}" || "$1" == -* ]]; then
					ErrorMessage "--shell requires a value (bash or zsh)."
					return 1
				fi
				options_ref["target_shell"]="$1"
				if ! ValidateShell "${options_ref["target_shell"]}"; then return 1; fi
				shift
				;;
			--all)
				options_ref["check_all"]=true
				shift
				;;
			--fix)
				options_ref["fix_conflicts"]=true
				shift
				;;
			--non-interactive)
				options_ref["is_interactive"]=false
				shift
				;;
			--dry-run)
				options_ref["is_dry_run"]=true
				shift
				;;
			--) # End of options
				shift
				break
				;;
			-*) # Unknown option
				ErrorMessage "Unknown option: $key"
				ShowHelp
				return 1
				;;
			*) # Positional argument (none expected)
				ErrorMessage "Unexpected positional argument: $key"
				ShowHelp
				return 1
				;;
		esac
	done

	# Post-parsing validation
	if ! ValidateShell "${options_ref["target_shell"]}"; then
		return 1
	fi

	# Handle interaction between --fix and --non-interactive
	if [[ "${options_ref["fix_conflicts"]}" == "true" && "${options_ref["is_interactive"]}" == "false" ]]; then
		WarningMessage "--fix requires interactive mode. Disabling fix mode."
		options_ref["fix_conflicts"]=false
	fi

	if [[ "${options_ref["is_dry_run"]}" == "true" ]]; then
		InfoMessage "Running with --dry-run. No changes will be made."
	fi

	return 0
}

# ============================================================================
# Function: main
# Description: Main execution logic for the chkseq script.
# Usage: main "$@"
# Returns: 0 on success/no conflicts, 1 on failure/conflicts found.
# ============================================================================
main() {
	# Use associative array for options
	declare -A options
	local overall_status=0

	# Parse Arguments
	ParseArguments options "$@" || exit $?

	# Determine whether to check all or specific context
	if [[ "${options[check_all]}" == "true" ]]; then
		CheckAllSeqConflicts \
			"${options[fix_conflicts]}" \
			"${options[is_interactive]}" \
			"${options[is_dry_run]}"
		overall_status=$?
	else
		CheckSeqConflicts \
			"${options[target_shell]}" \
			"${options[target_hostname]}" \
			"${options[fix_conflicts]}" \
			"${options[is_interactive]}" \
			"${options[is_dry_run]}"
		overall_status=$?
	fi

	return $overall_status
}

# ============================================================================
# Script Execution
# ============================================================================
# Execute main function if run directly or via rc command wrapper
if IsExecutedDirectly || [[ "$0" == *"rc"* ]]; then
	main "$@"
	exit $? # Exit with status from main
fi

# EOF
