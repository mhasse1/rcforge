#!/usr/bin/env bash
# sync-links.sh - Create hard links from rcForge source to ~/.config/rcforge based on manifest
# Author: rcForge Team (modified by AI)
# Date: 2025-04-08 # Correct sourcing order based on source-paths-include.sh content
# Version: 0.4.1 # Script version
# Category: tools/developer
# Description: Cleans and recreates ~/.config/rcforge structure and hard links
#              source files from the project repository according to file-manifest.txt.
#              Assumes script is run from the project root directory.

# Source the development paths first to define PROJECT_ROOT, RCFORGE_LIB etc.
# Determine location relative to this script file.
SCRIPT_DIR_SYNC=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
if [[ -f "${SCRIPT_DIR_SYNC}/source-paths-include.sh" ]]; then
	# shellcheck disable=SC1090
	source "${SCRIPT_DIR_SYNC}/source-paths-include.sh" # Defines PROJECT_ROOT, RCFORGE_LIB etc.
else
	echo "ERROR: Cannot source required include file: ${SCRIPT_DIR_SYNC}/source-paths-include.sh" >&2
	exit 1
fi

# Now source utility functions using RCFORGE_LIB defined in the include
if [[ -n "${RCFORGE_LIB:-}" && -f "${RCFORGE_LIB}/utility-functions.sh" ]]; then
	# shellcheck disable=SC1090
	source "${RCFORGE_LIB}/utility-functions.sh"
else
	echo "ERROR: Cannot source required library: ${RCFORGE_LIB}/utility-functions.sh" >&2
	echo "       (RCFORGE_LIB evaluated to: '${RCFORGE_LIB:-}')" >&2
	exit 1
fi

# Set strict error handling
set -o nounset
set -o pipefail
# errexit disabled as errors are checked explicitly

# ============================================================================
# GLOBAL CONSTANTS (Not Exported)
# ============================================================================
# Use constants sourced from utility-functions.sh if available, else provide fallback
[[ -v gc_version ]] || readonly gc_version="${RCFORGE_VERSION:-0.4.1}" # Script version might differ
[[ -v gc_app_name ]] || readonly gc_app_name="${RCFORGE_APP_NAME:-rcForge}"

# MANIFEST_FILE is relative to PROJECT_ROOT (which is now pwd assumption)
readonly MANIFEST_FILE_BASENAME="file-manifest.txt"
readonly MANIFEST_FILE="./${MANIFEST_FILE_BASENAME}"

# ============================================================================
# LOCAL HELPER FUNCTIONS
# ============================================================================

# --- ShowHelp, ParseArguments remain unchanged ---
# ============================================================================
# Function: ShowHelp
# Description: Display detailed help information for this utility.
# Usage: ShowHelp
# Exits: 0
# ============================================================================
ShowHelp() {
	local script_name
	script_name=$(basename "$0")
	# PROJECT_ROOT is now defined by the sourced include file
	if command -v _rcforge_show_help &>/dev/null; then
		_rcforge_show_help <<EOF
  Synchronizes hard links from the project source (${PROJECT_ROOT:-~/src/rcforge}) to the
  runtime/test directory (${TARGET_BASE_DIR}) based on ${MANIFEST_FILE}.
  WARNING: This script will delete and recreate ${TARGET_BASE_DIR}.

Usage:
  bash tools/${script_name} [options] # Run from project root

Options:
  -f, --force      Perform cleanup and linking without prompting.
  --manifest=FILE  Specify path to manifest file (default: ${MANIFEST_FILE}).
  --verbose, -v    Enable verbose output.
EOF
	else
		# Fallback basic help
		echo "${script_name} - rcForge Source Link Synchronizer"
		echo "Usage: bash tools/${script_name} [options]"
		echo "Options:"
		echo "  -f, --force      Perform cleanup and linking without prompting."
		echo "  --manifest=FILE  Specify path to manifest file (default: ${MANIFEST_FILE})."
		echo "  --verbose, -v    Enable verbose output."
		echo "  -h, --help       Show this help message."
		echo "  --version        Show version information."
	fi
	exit 0
}

# ============================================================================
# Function: ParseArguments
# Description: Parse command-line arguments.
# Usage: declare -A options; ParseArguments options "$@"
# Returns: Populates associative array. Returns 0 on success, 1 on error. Exits on help/version.
# ============================================================================
ParseArguments() {
	local -n options_ref="$1"
	shift
	if [[ "${BASH_VERSINFO[0]}" -lt 4 || ("${BASH_VERSINFO[0]}" -eq 4 && "${BASH_VERSINFO[1]}" -lt 3) ]]; then
		ErrorMessage "Internal script error. Requires Bash 4.3+."
		return 1
	fi

	# Defaults
	options_ref["force_run"]=false
	options_ref["manifest_path"]="${MANIFEST_FILE}" # Default relative to PWD (project root)
	options_ref["verbose_mode"]=false

	while [[ $# -gt 0 ]]; do
		local key="$1"
		case "$key" in
			-h | --help) ShowHelp ;; # Exits
			--version)
				_rcforge_show_version "$0"
				exit 0
				;; # Exits
			-f | --force)
				options_ref["force_run"]=true
				shift
				;;
			--manifest=*)
				options_ref["manifest_path"]="${key#*=}"
				shift
				;;
			-v | --verbose)
				options_ref["verbose_mode"]=true
				shift
				;;
			--)
				shift
				break
				;; # End of options
			-*)
				ErrorMessage "Unknown option: $key"
				ShowHelp
				return 1
				;;
			*)
				ErrorMessage "Unexpected positional argument: $key"
				ShowHelp
				return 1
				;;
		esac
	done

	# Validate manifest path post-parsing
	if [[ ! -f "${options_ref["manifest_path"]}" ]]; then
		ErrorMessage "Manifest file specified or defaulted does not exist: ${options_ref["manifest_path"]}"
		return 1
	fi
	if [[ ! -r "${options_ref["manifest_path"]}" ]]; then
		ErrorMessage "Manifest file not readable: ${options_ref["manifest_path"]}"
		return 1
	fi

	return 0
}

# ============================================================================
# Function: main
# Description: Main execution logic.
# Usage: main "$@"
# Returns: 0 on success, 1 on failure.
# ============================================================================
main() {
	declare -A options
	ParseArguments options "$@" || exit 1

	local manifest_path="${options[manifest_path]}"
	local force_run="${options[force_run]}"
	local is_verbose="${options[verbose_mode]}" # Capture the boolean string "true" or "false"
	local overall_status=0
	local link_count=0
	local dir_count=0

	# PROJECT_ROOT is now defined by the sourced include file
	# Assume script is run from PROJECT_ROOT

	SectionHeader "rcForge Source Link Synchronizer"

	# --- Safety Prompt ---
	if [[ "$force_run" == "false" ]]; then
		WarningMessage "This script will DELETE the directory: ${TARGET_BASE_DIR}"
		printf "%b" "${YELLOW}Are you sure you want to continue? (y/N): ${RESET}"
		local response=""
		read -r response
		if [[ ! "$response" =~ ^[Yy]$ ]]; then
			InfoMessage "Operation cancelled by user."
			exit 0
		fi
	else
		InfoMessage "Running with --force. Proceeding without prompt."
	fi

	# --- Cleanup Target Directory ---
	SectionHeader "Cleaning Target Directory"
	if [[ -d "$TARGET_BASE_DIR" ]]; then
		InfoMessage "Removing existing target directory: $TARGET_BASE_DIR"
		if ! rm -rf "$TARGET_BASE_DIR"; then
			ErrorMessage "Failed to remove target directory: $TARGET_BASE_DIR"
			return 1
		fi
		SuccessMessage "Target directory removed."
	else
		InfoMessage "Target directory does not exist, no removal needed: $TARGET_BASE_DIR"
	fi

	# --- Recreate Base Directory ---
	InfoMessage "Creating base target directory: $TARGET_BASE_DIR"
	if ! mkdir -p "$TARGET_BASE_DIR"; then
		ErrorMessage "Failed to create base target directory: $TARGET_BASE_DIR"
		return 1
	fi
	if ! chmod 700 "$TARGET_BASE_DIR"; then
		WarningMessage "Could not set permissions (700) on $TARGET_BASE_DIR"
	fi
	SuccessMessage "Base target directory created."

	# --- Process Manifest ---
	SectionHeader "Processing Manifest and Creating Links"

	local line=""
	local in_dirs_section=false
	local in_files_section=false
	local line_num=0

	while IFS= read -r line || [[ -n "$line" ]]; do
		line_num=$((line_num + 1))
		line=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//') # Trim

		# Section handling
		if [[ "$line" == "DIRECTORIES:" ]]; then
			in_dirs_section=true
			in_files_section=false
			VerboseMessage "$is_verbose" "Processing DIRECTORIES section..."
			continue
		fi
		if [[ "$line" == "FILES:" ]]; then
			in_dirs_section=false
			in_files_section=true
			VerboseMessage "$is_verbose" "Processing FILES section..."
			continue
		fi

		# Skip blank lines and comments
		if [[ -z "$line" || "$line" =~ ^# ]]; then continue; fi

		# Process based on section
		if [[ "$in_dirs_section" == "true" ]]; then
			local dir_rel_path="${line#./}"
			local dir_abs_path="${TARGET_BASE_DIR}/${dir_rel_path}"
			VerboseMessage "$is_verbose" "Creating directory: $dir_abs_path"
			if ! mkdir -p "$dir_abs_path"; then
				ErrorMessage "Failed to create directory from manifest: $dir_abs_path (line $line_num)"
				overall_status=1
				continue
			fi
			if ! chmod 700 "$dir_abs_path"; then WarningMessage "Perms fail (700): $dir_abs_path"; fi
			dir_count=$((dir_count + 1))

		elif [[ "$in_files_section" == "true" ]]; then
			local source_repo_path=""
			local dest_install_path=""
			read -r source_repo_path dest_install_path <<<"$line"

			if [[ -z "$source_repo_path" || -z "$dest_install_path" ]]; then
				WarningMessage "Manifest line ${line_num}: Invalid format. Skipping: '$line'"
				overall_status=1
				continue
			fi

			# source_repo_path is relative to PROJECT_ROOT (which is assumed PWD)
			local source_file="./${source_repo_path}" # Use relative path for source
			local target_file="${TARGET_BASE_DIR}/${dest_install_path}"
			local target_link_dir
			target_link_dir=$(dirname "$target_file")

			if [[ ! -f "$source_file" ]]; then
				WarningMessage "Source file missing: $source_file (line $line_num). Skipping."
				overall_status=1
				continue
			fi
			if [[ ! -r "$source_file" ]]; then
				WarningMessage "Source file unreadable: $source_file (line $line_num). Skipping."
				overall_status=1
				continue
			fi
			if [[ ! -d "$target_link_dir" ]]; then
				VerboseMessage "$is_verbose" "Target dir missing, creating: $target_link_dir"
				if ! mkdir -p "$target_link_dir"; then
					ErrorMessage "Failed create target dir: $target_link_dir (line $line_num)"
					overall_status=1
					continue
				fi
				if ! chmod 700 "$target_link_dir"; then WarningMessage "Perms fail (700): $target_link_dir"; fi
			fi

			VerboseMessage "$is_verbose" "Linking ${source_repo_path} -> ${dest_install_path}"
			# Use relative source path, absolute target path for ln
			if ln "${source_file}" "${target_file}"; then
				link_count=$((link_count + 1))
			else
				ErrorMessage "Failed link: '$source_file' -> '$target_file'"
				overall_status=1
			fi
		fi
	done <"$manifest_path"

	# --- Final Summary ---
	SectionHeader "Synchronization Summary"
	InfoMessage "Directories created in target: $dir_count"
	InfoMessage "Hard links created: $link_count"
	if [[ $overall_status -eq 0 ]]; then
		SuccessMessage "Synchronization complete."
	else WarningMessage "Synchronization finished with errors."; fi

	return $overall_status
}

# ============================================================================
# Script Execution Block
# ============================================================================
# Check if manifest exists in current dir (running from project root is assumed)
if [[ ! -f "${MANIFEST_FILE}" ]]; then
	ErrorMessage "Script must be run from the project root directory (containing '${MANIFEST_FILE_BASENAME}'). Current dir: '$(pwd)'"
	exit 1
fi

# Execute main
if command -v IsExecutedDirectly &>/dev/null; then
	# Use IsExecutedDirectly if available from sourced library
	if IsExecutedDirectly || [[ "$0" == *"rc"* ]]; then
		main "$@"
		exit $?
	fi
else
	# Fallback check if library sourcing failed or IsExecutedDirectly isn't exported/available
	if [[ "${BASH_SOURCE[0]}" == "${0}" ]] || [[ "$0" == *"rc"* ]]; then
		main "$@"
		exit $?
	fi
fi

# EOF
