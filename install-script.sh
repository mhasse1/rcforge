#!/usr/bin/env bash
# install-script.sh - rcForge Installation Script (Dynamic Manifest Version)
# Author: rcForge Team (AI Refactored)
# Date: 2025-04-18 # Updated Date
# Version: 0.5.0 # Installer Version (Keep separate from rcForge Core Version)
# Category: installer
# Description: Installs or upgrades rcForge shell configuration system using a manifest file
#              downloaded from a specific release tag (passed via --release-tag).
#              Runs non-interactively. Requires Bash 4.3+ to run the installer itself.
#              Now supports migration to XDG-compliant directory structure.

# Set strict error handling
set -o nounset  # Treat unset variables as errors
set -o errexit  # Exit immediately if a command exits with a non-zero status
set -o pipefail # Ensure pipeline fails on any component failing

# ============================================================================
# CONFIGURATION & GLOBAL CONSTANTS (Readonly)
# ============================================================================

readonly gc_rcforge_core_version="0.5.0"  # Version being installed
readonly gc_installer_version="0.5.0"     # Version of this installer script
readonly gc_installer_required_bash="4.3" # Installer itself needs 4.3+

# Old directory structure (pre-0.5.0)
readonly gc_old_rcforge_dir="$HOME/.config/rcforge"

# New XDG directory structure (0.5.0+)
readonly gc_config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
readonly gc_data_home="${XDG_DATA_HOME:-$HOME/.local/share}"

readonly gc_config_dir="$gc_config_home/rcforge"
readonly gc_data_dir="$gc_data_home/rcforge"

# Backup configuration
readonly gc_backup_dir="${gc_data_dir}/backups"
readonly gc_timestamp=$(date +%Y%m%d%H%M%S)
readonly gc_backup_file="${gc_backup_dir}/rcforge_backup_${gc_timestamp}.tar.gz"
readonly gc_repo_base_url="https://raw.githubusercontent.com/mhasse1/rcforge" # Base URL part

# Manifest File Configuration
readonly gc_manifest_filename="file-manifest.txt" # Name in repo root
readonly gc_manifest_temp_file="/tmp/rcforge_manifest_${gc_timestamp}_$$"

# Colors (self-contained for installer)
if [[ -t 1 ]]; then
	readonly RED='\033[0;31m'
	readonly GREEN='\033[0;32m'
	readonly YELLOW='\033[0;33m'
	readonly BLUE='\033[0;34m'
	readonly MAGENTA='\033[0;35m'
	readonly CYAN='\033[0;36m'
	readonly BOLD='\033[1m'
	readonly RESET='\033[0m'
else # Disable colors if not a tty
	readonly RED=""
	readonly GREEN=""
	readonly YELLOW=""
	readonly BLUE=""
	readonly MAGENTA=""
	readonly CYAN=""
	readonly BOLD=""
	readonly RESET=""
fi

# ============================================================================
# UTILITY FUNCTIONS (Messaging, Checks, Backup, Download, etc.)
# ============================================================================

# ============================================================================
# Function: InstallHaltedCleanup
# Description: Performs cleanup if an install/upgrade attempt fails.
# Usage: Called by ErrorMessage before exiting on failure.
# Arguments:
#   $1 (required) - Boolean ('true'/'false') indicating if it was a fresh install attempt.
# Returns: None. Attempts cleanup actions.
# ============================================================================
InstallHaltedCleanup() {
	local is_fresh_install_attempt="$1"

	if [[ "${is_fresh_install_attempt}" == "true" ]]; then
		WarningMessage "Installation failed. Cleaning up install directory..."
		if [[ -d "$gc_config_dir" ]]; then
			if rm -rf "$gc_config_dir"; then
				SuccessMessage "Removed partially installed directory: $gc_config_dir"
			else
				WarningMessage "Failed to remove directory: $gc_config_dir. Please remove it manually."
			fi
		fi
		if [[ -d "$gc_data_dir" ]]; then
			if rm -rf "$gc_data_dir"; then
				SuccessMessage "Removed partially installed directory: $gc_data_dir"
			else
				WarningMessage "Failed to remove directory: $gc_data_dir. Please remove it manually."
			fi
		fi
	else
		# This was an upgrade attempt
		WarningMessage "Upgrade failed. Attempting to restore from backup..."
		if [[ -f "$gc_backup_file" ]]; then
			InfoMessage "Found backup file: $gc_backup_file"

			# For 0.5.0+ structure, clean up both directories
			InfoMessage "Removing failed upgrade directories before restore..."
			rm -rf "$gc_config_dir" "$gc_data_dir" || {
				WarningMessage "Failed to completely remove current directories before restore."
				WarningMessage "Attempting restore anyway, but manual cleanup might be needed."
			}

			InfoMessage "Restoring backup..."
			if tar -xzf "$gc_backup_file" -C "$(dirname "$gc_old_rcforge_dir")"; then
				SuccessMessage "Successfully restored previous state from backup."
				InfoMessage "The failed upgrade attempt has been rolled back."
			else
				WarningMessage "Failed to extract backup file: $gc_backup_file"
				WarningMessage "Your previous configuration might be lost. Please check $gc_backup_file manually."
			fi
		else
			WarningMessage "Backup file not found: $gc_backup_file"
			WarningMessage "Cannot restore automatically. Leaving current state intact."
			InfoMessage "Please review the state of your installation."
		fi
	fi
}

# ============================================================================
# Function: ErrorMessage (Installer Version with Cleanup)
# Description: Display error message, perform cleanup, and exit.
# Usage: ErrorMessage is_fresh_install "Error description"
# Arguments:
#   $1 (required) - Boolean ('true'/'false') indicating if it was a fresh install attempt.
#   $* (required) - The error message text.
# Exits: 1
# ============================================================================
ErrorMessage() {
	local is_fresh_install_attempt="$1"
	shift # Remove the flag from the arguments
	local original_message="${*}"
	printf "%bERROR:%b %s\n" "${RED}" "${RESET}" "${original_message}" >&2
	InstallHaltedCleanup "$is_fresh_install_attempt"
	exit 1
}

# ============================================================================
# Function: WarningMessage
# Description: Display warning message to stderr.
# Usage: WarningMessage "Warning description"
# Arguments: $* (required) - The warning message text.
# ============================================================================
WarningMessage() {
	printf "%bWARNING:%b %s\n" "${YELLOW}" "${RESET}" "${*}" >&2
}

# ============================================================================
# Function: InfoMessage
# Description: Display info message to stdout.
# Usage: InfoMessage "Information"
# Arguments: $* (required) - The informational message text.
# ============================================================================
InfoMessage() {
	printf "%bINFO:%b %s\n" "${BLUE}" "${RESET}" "${*}"
}

# ============================================================================
# Function: SuccessMessage
# Description: Display success message to stdout.
# Usage: SuccessMessage "Success details"
# Arguments: $* (required) - The success message text.
# ============================================================================
SuccessMessage() {
	printf "%bSUCCESS:%b %s\n" "${GREEN}" "${RESET}" "${*}"
}

# ============================================================================
# Function: SectionHeader
# Description: Display formatted section header to stdout.
# Usage: SectionHeader "Header Text"
# Arguments: $1 (required) - The header text.
# ============================================================================
SectionHeader() {
	local text="$1"
	local line_char="="
	local line_len=50
	printf "\n%b%b%s%b\n" "${BOLD}" "${CYAN}" "${text}" "${RESET}"
	printf "%b%s%b\n\n" "${CYAN}" "$(printf '%*s' $line_len '' | tr ' ' "${line_char}")" "${RESET}"
}

# ============================================================================
# Function: VerboseMessage
# Description: Print message to stdout only if verbose mode is enabled.
# Usage: VerboseMessage is_verbose "Message text"
# Arguments:
#   $1 (required) - Boolean ('true'/'false') indicating verbose mode.
#   $* (required) - The message text (all subsequent arguments).
# ============================================================================
VerboseMessage() {
	local is_verbose="$1"
	shift
	local message="${*}"
	if [[ "$is_verbose" == "true" ]]; then
		printf "%bVERBOSE:%b %s\n" "${MAGENTA}" "${RESET}" "$message"
	fi
}

# ============================================================================
# Function: IsInstalled
# Description: Check if rcForge appears to be installed based on key file/dir.
# Usage: if IsInstalled; then ... fi
# Returns: 0 (true) if installation detected, 1 (false) otherwise.
# ============================================================================
IsInstalled() {
	# Check for pre-0.5.0 installation
	if [[ -d "$gc_old_rcforge_dir" && -f "${gc_old_rcforge_dir}/rcforge.sh" ]]; then
		return 0
	fi

	# Check for 0.5.0+ installation
	if [[ -d "$gc_data_dir" && -f "${gc_data_dir}/rcforge.sh" ]]; then
		return 0
	fi

	return 1
}

# ============================================================================
# Function: GetInstalledVersion
# Description: Detect the version of an existing rcForge installation.
# Usage: version=$(GetInstalledVersion)
# Returns: Echo the version string or "unknown" if not found.
# ============================================================================
GetInstalledVersion() {
	local rcforge_sh=""
	local version="unknown"

	# Check for pre-0.5.0 location
	if [[ -f "${gc_old_rcforge_dir}/rcforge.sh" ]]; then
		rcforge_sh="${gc_old_rcforge_dir}/rcforge.sh"
	# Check for 0.5.0+ location
	elif [[ -f "${gc_data_dir}/rcforge.sh" ]]; then
		rcforge_sh="${gc_data_dir}/rcforge.sh"
	else
		echo "unknown"
		return 1
	fi

	# Extract version from rcforge.sh file
	if grep -q "RCFORGE_VERSION=" "$rcforge_sh"; then
		version=$(grep "RCFORGE_VERSION=" "$rcforge_sh" | head -n 1 | sed -e 's/.*="\(.*\)".*/\1/')
	fi

	echo "$version"
	return 0
}

# ============================================================================
# Function: NeedsUpgradeToXDG
# Description: Check if installation needs upgrade to XDG structure.
# Usage: if NeedsUpgradeToXDG; then ... fi
# Returns: 0 (true) if upgrade needed, 1 (false) otherwise.
# ============================================================================
NeedsUpgradeToXDG() {
	# If old structure exists but new doesn't, upgrade is needed
	if [[ -d "$gc_old_rcforge_dir" && -f "${gc_old_rcforge_dir}/rcforge.sh" ]]; then
		# Check if version is less than 0.5.0
		local current_version
		current_version=$(GetInstalledVersion)

		# Use sort -V to compare versions
		if [[ "$(printf '%s\n' "0.5.0" "$current_version" | sort -V | head -n1)" == "$current_version" ]]; then
			return 0 # Upgrade needed
		fi
	fi

	return 1 # No upgrade needed
}

# ============================================================================
# Function: ConfirmUpgradeToXDG
# Description: Show information about the upgrade and request confirmation.
# Usage: if ConfirmUpgradeToXDG; then ... fi
# Returns: 0 if user confirms, 1 if user cancels.
# ============================================================================
ConfirmUpgradeToXDG() {
	cat <<EOF

${BOLD}📣 rcForge 0.5.0 Update Available 📣${RESET}

This update reorganizes your rcForge files to:
- Follow standard directory conventions (XDG compliant)
- Make syncing between machines easier
- Better separate your customizations from system files
- Add API key management

The migration will preserve all your customizations and settings.
EOF

	printf "%bWould you like to proceed with the update? (y/n):%b " "${YELLOW}" "${RESET}"
	read -r response

	if [[ ! "$response" =~ ^[Yy]$ ]]; then
		InfoMessage "Update cancelled by user."
		return 1
	fi

	return 0
}

# ============================================================================
# Function: CommandExists
# Description: Check if a command exists in the current PATH.
# Usage: if CommandExists command_name; then ... fi
# Arguments: $1 (required) - The command name to check.
# Returns: 0 (true) if command exists, 1 (false) otherwise.
# ============================================================================
CommandExists() {
	command -v "$1" >/dev/null 2>&1
}

# ============================================================================
# Function: CheckBashVersion (Installer Specific)
# Description: Checks if installer's Bash AND user's default Bash meet requirements.
# Usage: CheckBashVersion is_fresh_install is_skip_check
# Arguments: $1, $2 (required) - Booleans.
# Returns: 0 if checks passed (or skipped). Exits via ErrorMessage otherwise.
# ============================================================================
CheckBashVersion() {
	local is_fresh_install_attempt="$1"
	local is_skip_check="$2"
	local min_version_required="${gc_installer_required_bash}"

	# Check A: Installer Bash
	InfoMessage "Checking Bash version for the installer script..."
	if [[ -z "${BASH_VERSION:-}" ]]; then
		if [[ "$is_skip_check" != "true" ]]; then
			ErrorMessage "$is_fresh_install_attempt" "Installer requires Bash ${min_version_required}+."
		fi
		WarningMessage "Not running in Bash, skipping installer check."
	elif ! printf '%s\n%s\n' "$min_version_required" "$BASH_VERSION" | sort -V -C &>/dev/null; then
		if [[ "$is_skip_check" != "true" ]]; then
			WarningMessage "Installer requires Bash ${min_version_required}+. Current is ${BASH_VERSION}."
			if [[ "$(uname)" == "Darwin" ]]; then
				printf "\n%bmacOS Hint: brew install bash%b\n" "${YELLOW}" "${RESET}"
			fi
			ErrorMessage "$is_fresh_install_attempt" "Installer Bash version requirement not met."
		fi
		WarningMessage "Skipping installer Bash version check (required: ${min_version_required}+)."
	else
		InfoMessage "Installer Bash version ${BASH_VERSION} meets requirement (>= ${min_version_required})."
	fi

	printf "\n"

	# Check B: User Default Bash
	InfoMessage "Checking user's default Bash in PATH (required for rcForge runtime)..."
	local first_bash_in_path runtime_bash_version bash_location_file docs_dir
	if ! CommandExists bash; then
		ErrorMessage "$is_fresh_install_attempt" "Cannot find 'bash' in PATH."
	fi
	first_bash_in_path=$(command -v bash)
	runtime_bash_version=$("$first_bash_in_path" --version 2>/dev/null | grep -oE 'version [0-9]+\.[0-9]+(\.[0-9]+)?' | awk '{print $2}')

	if [[ -z "$runtime_bash_version" ]]; then
		WarningMessage "Could not determine version for Bash at: ${first_bash_in_path}. Proceeding cautiously."
		return 0
	fi

	InfoMessage "Found default Bash in PATH: ${first_bash_in_path} (Version: ${runtime_bash_version})"

	if printf '%s\n%s\n' "$min_version_required" "$runtime_bash_version" | sort -V -C &>/dev/null; then
		SuccessMessage "Default Bash version ${runtime_bash_version} meets requirement (>= ${min_version_required})."
		# Record Path - updated for 0.5.0 to use new structure
		bash_location_file="${gc_data_dir}/config/bash-location"
		docs_dir="$(dirname "$bash_location_file")"
		InfoMessage "Recording compliant Bash location to ${bash_location_file}..."
		if ! mkdir -p "$docs_dir"; then
			ErrorMessage "$is_fresh_install_attempt" "Failed to create directory: $docs_dir"
		fi
		# Corrected permission check logic:
		if ! chmod 700 "$docs_dir"; then
			WarningMessage "Could not set permissions (700) on: $docs_dir"
		fi
		if echo "$first_bash_in_path" >"$bash_location_file"; then
			# Corrected permission check logic:
			if ! chmod 644 "$bash_location_file"; then
				WarningMessage "Could not set permissions (644) on: $bash_location_file"
			fi
			SuccessMessage "Bash location recorded."
		else
			WarningMessage "Failed to write Bash location to: ${bash_location_file}. Proceeding."
		fi
	else
		ErrorMessage "$is_fresh_install_attempt" "Default Bash ${runtime_bash_version} at '${first_bash_in_path}' is too old (needs v${min_version_required}+)."
	fi
	return 0
}

# ============================================================================
# Function: CreateBackup
# Description: Create a gzipped tarball backup of the existing rcForge installation.
# Usage: CreateBackup is_fresh_install is_skip_backup is_verbose
# Arguments: $1, $2, $3 (required) - Booleans.
# Returns: 0 on success/skipped. Exits via ErrorMessage on critical failure.
# ============================================================================
CreateBackup() {
	local is_fresh_install_attempt="$1"
	local is_skip_backup="$2"
	local is_verbose="$3" # Renamed from RCFORGE_FIX_CHECKSUMS env var
	local tar_opts="-czf"

	if [[ "$is_skip_backup" == "true" ]]; then
		VerboseMessage "$is_verbose" "Skipping backup."
		return 0
	fi

	if ! IsInstalled; then
		VerboseMessage "$is_verbose" "No existing install, skipping backup."
		return 0
	fi

	InfoMessage "Creating backup..."
	# Create backup directory in new structure
	if ! mkdir -p "$gc_backup_dir"; then
		WarningMessage "Cannot create backup dir: ${gc_backup_dir}. Skipping backup."
		return 0
	fi
	if ! chmod 700 "$gc_backup_dir"; then
		WarningMessage "Could not set permissions (700) on backup directory: ${gc_backup_dir}"
	fi

	if [[ "$is_verbose" == "true" ]]; then
		tar_opts="-czvf"
	fi

	# Determine which installation to back up (old or new structure)
	local target_dir=""
	if [[ -d "$gc_old_rcforge_dir" && -f "${gc_old_rcforge_dir}/rcforge.sh" ]]; then
		target_dir="$gc_old_rcforge_dir"
	elif [[ -d "$gc_data_dir" && -f "${gc_data_dir}/rcforge.sh" ]]; then
		# For 0.5.0+ structure, back up both directories
		if ! tar "$tar_opts" "$gc_backup_file" -C "$(dirname "$gc_config_dir")" "$(basename "$gc_config_dir")" -C "$(dirname "$gc_data_dir")" "$(basename "$gc_data_dir")"; then
			ErrorMessage "$is_fresh_install_attempt" "Backup failed: ${gc_backup_file}. Check permissions/space." # Exits
		fi
		SuccessMessage "Backup created: $gc_backup_file"
		return 0
	else
		WarningMessage "Cannot determine installation to back up. Skipping."
		return 0
	fi

	# Create the backup of the old structure
	if ! tar "$tar_opts" "$gc_backup_file" -C "$(dirname "$target_dir")" "$(basename "$target_dir")"; then
		ErrorMessage "$is_fresh_install_attempt" "Backup failed: ${gc_backup_file}. Check permissions/space." # Exits
	fi
	SuccessMessage "Backup created: $gc_backup_file"
	return 0
}

# ============================================================================
# Function: DownloadFile
# Description: Download a single file using curl or wget.
# Usage: DownloadFile is_fresh_install is_verbose url destination
# Arguments: $1, $2 (required) - Booleans. $3, $4 (required) - Strings.
# Exits: 1 (via ErrorMessage) on failure.
# ============================================================================
DownloadFile() {
	local is_fresh_install_attempt="$1"
	local is_verbose="$2"
	local url="$3"
	local destination="$4"
	local dest_dir download_cmd

	VerboseMessage "$is_verbose" "Downloading: $(basename "$destination") from $(dirname "$url")"
	dest_dir=$(dirname "$destination")
	# Corrected permission check logic:
	if ! mkdir -p "$dest_dir"; then
		ErrorMessage "$is_fresh_install_attempt" "Failed create dir: $dest_dir"
	fi
	if ! chmod 700 "$dest_dir"; then
		WarningMessage "Could not set permissions (700) on: $dest_dir"
	fi

	if CommandExists curl; then
		download_cmd="curl --fail --silent --show-error --location --output \"${destination}\" \"${url}\""
	elif CommandExists wget; then
		download_cmd="wget --quiet --output-document=\"${destination}\" \"${url}\""
	else
		ErrorMessage "$is_fresh_install_attempt" "'curl' or 'wget' not found." # Exits
	fi

	if ! eval "$download_cmd"; then
		rm -f "$destination" &>/dev/null || true
		ErrorMessage "$is_fresh_install_attempt" "Failed download: $url" # Exits
	fi

	# Set permissions
	# Corrected permission check logic:
	if [[ "$destination" == *.sh ]]; then
		if ! chmod 700 "$destination"; then
			WarningMessage "Could not set permissions (700) on script: $destination"
		fi
	else
		if ! chmod 600 "$destination"; then
			WarningMessage "Could not set permissions (600) on file: $destination"
		fi
	fi
}

# ============================================================================
# Function: DownloadManifest
# Description: Downloads the manifest file from the specified release URL.
# Usage: DownloadManifest is_fresh_install is_verbose github_raw_url
# Arguments: $1, $2 (required) - Booleans. $3 (required) - Base RAW URL for the release tag.
# Exits: 1 (via ErrorMessage) on failure.
# ============================================================================
DownloadManifest() {
	local is_fresh_install_attempt="$1"
	local is_verbose="$2"
	local github_raw_url="$3"                                           # Pass the base URL
	local manifest_full_url="${github_raw_url}/${gc_manifest_filename}" # Construct full URL
	local download_cmd=""

	InfoMessage "Downloading manifest (${gc_manifest_filename}) from release..."
	VerboseMessage "$is_verbose" "Manifest URL: ${manifest_full_url}"

	if CommandExists curl; then
		download_cmd="curl --fail --silent --show-error --location --output \"${gc_manifest_temp_file}\" \"${manifest_full_url}\""
	elif CommandExists wget; then
		download_cmd="wget --quiet --output-document=\"${gc_manifest_temp_file}\" \"${manifest_full_url}\""
	else
		ErrorMessage "$is_fresh_install_attempt" "'curl' or 'wget' not found." # Exits
	fi

	if ! eval "$download_cmd"; then
		rm -f "$gc_manifest_temp_file" &>/dev/null || true
		ErrorMessage "$is_fresh_install_attempt" "Failed download manifest: ${manifest_full_url}" # Exits
	fi
	if [[ ! -s "$gc_manifest_temp_file" ]]; then
		rm -f "$gc_manifest_temp_file" &>/dev/null || true
		ErrorMessage "$is_fresh_install_attempt" "Downloaded manifest is empty: ${gc_manifest_temp_file}" # Exits
	fi
	SuccessMessage "Manifest downloaded successfully."
}

# ============================================================================
# Function: MigrateToXDGStructure
# Description: Migrates from pre-0.5.0 to 0.5.0+ XDG structure
# Usage: MigrateToXDGStructure is_fresh_install is_verbose
# Arguments:
#   $1 (required) - Boolean indicating if fresh install.
#   $2 (required) - Boolean indicating verbose mode.
# Returns: 0 on success, 1 on failure.
# ============================================================================
MigrateToXDGStructure() {
	local is_fresh_install_attempt="$1"
	local is_verbose="$2"

	SectionHeader "Migrating to XDG-Compliant Directory Structure"

	InfoMessage "Creating new XDG directory structure..."

	# Create config directory structure
	mkdir -p "${gc_config_dir}/config"
	mkdir -p "${gc_config_dir}/rc-scripts"
	chmod 700 "${gc_config_dir}" "${gc_config_dir}/config" "${gc_config_dir}/rc-scripts"

	# Create data directory structure
	mkdir -p "${gc_data_dir}/backups"
	mkdir -p "${gc_data_dir}/config/checksums"
	mkdir -p "${gc_data_dir}/system/core"
	mkdir -p "${gc_data_dir}/system/lib"
	mkdir -p "${gc_data_dir}/system/utils"
	chmod 700 "${gc_data_dir}" "${gc_data_dir}/backups" "${gc_data_dir}/config"
	chmod 700 "${gc_data_dir}/system" "${gc_data_dir}/system/core" "${gc_data_dir}/system/lib" "${gc_data_dir}/system/utils"

	InfoMessage "Migrating files from old structure..."

	# Move rc-scripts to new location
	if [[ -d "${gc_old_rcforge_dir}/rc-scripts" ]]; then
		find "${gc_old_rcforge_dir}/rc-scripts" -type f -name "*.sh" -exec cp -p {} "${gc_config_dir}/rc-scripts/" \;
		SuccessMessage "Migrated custom RC scripts to ${gc_config_dir}/rc-scripts/"
	fi

	# Move user utilities if they exist
	if [[ -d "${gc_old_rcforge_dir}/utils" ]]; then
		mkdir -p "${gc_data_dir}/utils"
		chmod 700 "${gc_data_dir}/utils"
		find "${gc_old_rcforge_dir}/utils" -type f -exec cp -p {} "${gc_data_dir}/utils/" \;
		SuccessMessage "Migrated user utilities to ${gc_data_dir}/utils/"
	fi

	# Move backups if they exist
	if [[ -d "${gc_old_rcforge_dir}/backups" ]]; then
		find "${gc_old_rcforge_dir}/backups" -type f -exec cp -p {} "${gc_data_dir}/backups/" \;
		SuccessMessage "Migrated existing backups to ${gc_data_dir}/backups/"
	fi

	# Move checksums if they exist
	if [[ -d "${gc_old_rcforge_dir}/docs/checksums" ]]; then
		find "${gc_old_rcforge_dir}/docs/checksums" -type f -exec cp -p {} "${gc_data_dir}/config/checksums/" \;
		SuccessMessage "Migrated checksums to ${gc_data_dir}/config/checksums/"
	fi

	# Record bash location if it exists in old structure
	if [[ -f "${gc_old_rcforge_dir}/docs/.bash_location" ]]; then
		mkdir -p "${gc_data_dir}/config"
		cp -p "${gc_old_rcforge_dir}/docs/.bash_location" "${gc_data_dir}/config/bash-location"
		SuccessMessage "Migrated Bash location information"
	fi

	InfoMessage "Migration to XDG structure complete"
	return 0
}

# ============================================================================
# Function: ProcessManifest
# Description: Reads manifest, creates directories, downloads files using the specified release URL.
# Usage: ProcessManifest is_fresh_install is_verbose github_raw_url
# Arguments: $1, $2 (required) - Booleans. $3 (required) - Base RAW URL for the release tag.
# Returns: 0 on success, 1 if no files processed. Exits via ErrorMessage otherwise.
# ============================================================================
ProcessManifest() {
	local is_fresh_install_attempt="$1"
	local is_verbose="$2"
	local github_raw_url="$3" # Use the passed base URL
	local current_section="NONE"
	local line_num=0 dir_count=0 file_count=0
	local line dir_path full_dir_path source_suffix dest_suffix file_url dest_path

	SectionHeader "Processing Manifest File"
	if [[ ! -f "$gc_manifest_temp_file" ]]; then
		ErrorMessage "$is_fresh_install_attempt" "Manifest temp file not found."
	fi

	# In 0.5.0+, we have two root directories to handle
	local config_dir="${gc_config_dir}"
	local local_dir="${gc_data_dir}"

	# Ensure both root directories exist
	if ! mkdir -p "$config_dir" "$local_dir"; then
		ErrorMessage "$is_fresh_install_attempt" "Failed to ensure base dirs: $config_dir and $local_dir"
	fi
	if ! chmod 700 "$config_dir" "$local_dir"; then
		WarningMessage "Could not set permissions (700) on base directories"
	fi

	while IFS= read -r line || [[ -n "$line" ]]; do
		line_num=$((line_num + 1))
		line="${line#"${line%%[![:space:]]*}"}"
		line="${line%"${line##*[![:space:]]}"}" # Trim
		if [[ -z "$line" || "$line" =~ ^# ]]; then
			continue
		fi
		if [[ "$line" == "DIRECTORIES:" ]]; then
			current_section="DIRS"
			InfoMessage "Processing directories..."
			continue
		fi
		if [[ "$line" == "FILES:" ]]; then
			current_section="FILES"
			InfoMessage "Processing files..."
			continue
		fi

		case "$current_section" in
			"DIRS")
				dir_path="${line#./}"

				# Determine target directory based on path
				# .config/rcforge paths
				if [[ "$dir_path" == rc-scripts* || "$dir_path" == config* ]]; then
					full_dir_path="${config_dir}/${dir_path}"
				# .local/rcforge paths (everything else)
				else
					full_dir_path="${local_dir}/${dir_path}"
				fi

				VerboseMessage "$is_verbose" "Ensuring directory: $full_dir_path"
				if ! mkdir -p "$full_dir_path"; then
					ErrorMessage "$is_fresh_install_attempt" "Failed create dir: $full_dir_path"
				fi
				if ! chmod 700 "$full_dir_path"; then
					WarningMessage "Could not set permissions (700) on: $full_dir_path"
				fi
				dir_count=$((dir_count + 1))
				;;
			"FILES")
				read -r source_suffix dest_suffix <<<"$line"
				if [[ -z "$source_suffix" || -z "$dest_suffix" ]]; then
					WarningMessage "Line $line_num: Invalid format. Skip: '$line'"
					continue
				fi
				file_url="${github_raw_url}/${source_suffix}" # Use passed URL base

				# Determine target location based on path
				# .config/rcforge paths
				if [[ "$dest_suffix" == rc-scripts/* || "$dest_suffix" == config/* ]]; then
					dest_path="${config_dir}/${dest_suffix}"
				# .local/rcforge paths (everything else)
				else
					dest_path="${local_dir}/${dest_suffix}"
				fi

				DownloadFile "$is_fresh_install_attempt" "$is_verbose" "$file_url" "$dest_path" # Exits on fail
				file_count=$((file_count + 1))
				;;
			*) VerboseMessage "$is_verbose" "Ignoring line $line_num before section: $line" ;;
		esac
	done <"$gc_manifest_temp_file"

	SuccessMessage "Processed ${dir_count} directories."
	if [[ $file_count -eq 0 ]]; then
		WarningMessage "No files processed from manifest FILES section."
		return 1
	fi
	SuccessMessage "Processed ${file_count} files."
	return 0
}

# ============================================================================
# Function: ProcessManifest
# Description: Reads manifest, creates directories, downloads files using the specified release URL.
# Usage: ProcessManifest is_fresh_install is_verbose github_raw_url
# Arguments: $1, $2 (required) - Booleans. $3 (required) - Base RAW URL for the release tag.
# Returns: 0 on success, 1 if no files processed. Exits via ErrorMessage otherwise.
# ============================================================================
ProcessManifest() {
	local is_fresh_install_attempt="$1"
	local is_verbose="$2"
	local github_raw_url="$3" # Use the passed base URL
	local current_section="NONE"
	local line_num=0 dir_count=0 file_count=0
	local line dir_path full_dir_path source_suffix dest_suffix file_url dest_path

	SectionHeader "Processing Manifest File"
	if [[ ! -f "$gc_manifest_temp_file" ]]; then
		ErrorMessage "$is_fresh_install_attempt" "Manifest temp file not found."
	fi

	# In 0.5.0+, we have two root directories to handle
	local config_dir="${gc_config_dir}"
	local local_dir="${gc_data_dir}"

	# Ensure both root directories exist
	if ! mkdir -p "$config_dir" "$local_dir"; then
		ErrorMessage "$is_fresh_install_attempt" "Failed to ensure base dirs: $config_dir and $local_dir"
	fi
	if ! chmod 700 "$config_dir" "$local_dir"; then
		WarningMessage "Could not set permissions (700) on base directories"
	fi

	while IFS= read -r line || [[ -n "$line" ]]; do
		line_num=$((line_num + 1))
		line="${line#"${line%%[![:space:]]*}"}"
		line="${line%"${line##*[![:space:]]}"}" # Trim
		if [[ -z "$line" || "$line" =~ ^# ]]; then
			continue
		fi
		if [[ "$line" == "DIRECTORIES:" ]]; then
			current_section="DIRS"
			InfoMessage "Processing directories..."
			continue
		fi
		if [[ "$line" == "FILES:" ]]; then
			current_section="FILES"
			InfoMessage "Processing files..."
			continue
		fi

		case "$current_section" in
			"DIRS")
				dir_path="${line#./}"

				# Determine target directory based on path
				# .config/rcforge paths
				if [[ "$dir_path" == rc-scripts* || "$dir_path" == config* ]]; then
					full_dir_path="${config_dir}/${dir_path}"
				# .local/rcforge paths (everything else)
				else
					full_dir_path="${local_dir}/${dir_path}"
				fi

				VerboseMessage "$is_verbose" "Ensuring directory: $full_dir_path"
				if ! mkdir -p "$full_dir_path"; then
					ErrorMessage "$is_fresh_install_attempt" "Failed create dir: $full_dir_path"
				fi
				if ! chmod 700 "$full_dir_path"; then
					WarningMessage "Could not set permissions (700) on: $full_dir_path"
				fi
				dir_count=$((dir_count + 1))
				;;
			"FILES")
				read -r source_suffix dest_suffix <<<"$line"
				if [[ -z "$source_suffix" || -z "$dest_suffix" ]]; then
					WarningMessage "Line $line_num: Invalid format. Skip: '$line'"
					continue
				fi
				file_url="${github_raw_url}/${source_suffix}" # Use passed URL base

				# Determine target location based on path
				# .config/rcforge paths
				if [[ "$dest_suffix" == rc-scripts/* || "$dest_suffix" == config/* ]]; then
					dest_path="${config_dir}/${dest_suffix}"
				# .local/rcforge paths (everything else)
				else
					dest_path="${local_dir}/${dest_suffix}"
				fi

				DownloadFile "$is_fresh_install_attempt" "$is_verbose" "$file_url" "$dest_path" # Exits on fail
				file_count=$((file_count + 1))
				;;
			*) VerboseMessage "$is_verbose" "Ignoring line $line_num before section: $line" ;;
		esac
	done <"$gc_manifest_temp_file"

	SuccessMessage "Processed ${dir_count} directories."
	if [[ $file_count -eq 0 ]]; then
		WarningMessage "No files processed from manifest FILES section."
		return 1
	fi
	SuccessMessage "Processed ${file_count} files."
	return 0
}

# ============================================================================
# Function: AddRcFileLines
# Description: Adds the source line to the user's shell RC files.
# Usage: AddRcFileLines is_fresh_install
# Arguments:
#   $1 (required) - Boolean indicating if fresh install.
# Returns: 0 on success, 1 on failure.
# ============================================================================
AddRcFileLines() {
	local is_fresh_install_attempt="$1"
	local source_line="source \"\${XDG_DATA_HOME:-\$HOME/.local/share}/rcforge/rcforge.sh\""
	local bashrc_path="$HOME/.bashrc"
	local zshrc_path="$HOME/.zshrc"
	local status=0

	InfoMessage "Checking shell RC files..."

	# Check for .bashrc
	if [[ -f "$bashrc_path" ]]; then
		# Check if line already exists
		if ! grep -q "rcforge/rcforge.sh" "$bashrc_path"; then
			InfoMessage "Adding source line to $bashrc_path"

			# Add the source line directly (no comment)
			echo "" >>"$bashrc_path"
			echo "# rcForge - Shell Configuration Manager" >>"$bashrc_path"
			echo "$source_line" >>"$bashrc_path"

			SuccessMessage "Added source line to $bashrc_path"
		else
			# Update older style lines to new XDG path if needed
			if grep -q "\.config/rcforge/rcforge.sh" "$bashrc_path"; then
				InfoMessage "Updating rcForge path in $bashrc_path to use XDG structure"
				sed -i.bak 's|source.*\.config/rcforge/rcforge.sh.*|'"$source_line"'|' "$bashrc_path"
				SuccessMessage "Updated source line in $bashrc_path"
			else
				InfoMessage "rcForge source line already exists in $bashrc_path"
			fi
		fi
	else
		WarningMessage "$bashrc_path not found. Create it and add: $source_line"
		status=1
	fi

	# Check for .zshrc
	if [[ -f "$zshrc_path" ]]; then
		# Check if line already exists
		if ! grep -q "rcforge/rcforge.sh" "$zshrc_path"; then
			InfoMessage "Adding source line to $zshrc_path"

			# Add the source line directly (no comment)
			echo "" >>"$zshrc_path"
			echo "# rcForge - Shell Configuration Manager" >>"$zshrc_path"
			echo "$source_line" >>"$zshrc_path"

			SuccessMessage "Added source line to $zshrc_path"
		else
			# Update older style lines to new XDG path if needed
			if grep -q "\.config/rcforge/rcforge.sh" "$zshrc_path"; then
				InfoMessage "Updating rcForge path in $zshrc_path to use XDG structure"
				sed -i.bak 's|source.*\.config/rcforge/rcforge.sh.*|'"$source_line"'|' "$zshrc_path"
				SuccessMessage "Updated source line in $zshrc_path"
			else
				InfoMessage "rcForge source line already exists in $zshrc_path"
			fi
		fi
	else
		WarningMessage "$zshrc_path not found. Create it and add: $source_line"
		status=1
	fi

	return $status
}

# ============================================================================
# Function: CleanupInstall
# Description: Performs final cleanup after successful installation.
# Usage: CleanupInstall
# Returns: 0 on success.
# ============================================================================
CleanupInstall() {
	# Remove temporary files
	if [[ -f "$gc_manifest_temp_file" ]]; then
		rm -f "$gc_manifest_temp_file"
	fi

	# Perform any other cleanup needed
	return 0
}

# ============================================================================
# Function: ParseArguments
# Description: Parse command-line arguments for the installation script.
# Usage: ParseArguments "$@"
# Arguments: $@ - Command line arguments passed to the script.
# Returns: Sets global option variables. Returns 0 on success, 1 on error.
# ============================================================================
ParseArguments() {
	# Global option variables - used across functions
	RELEASE_TAG=""
	SKIP_BACKUP=false
	SKIP_BASH_CHECK=false
	SKIP_RC_FILE_MODS=false
	FORCE_INSTALL=false
	VERBOSE_MODE=false

	# Process arguments
	while [[ $# -gt 0 ]]; do
		case "$1" in
			--release-tag=*)
				RELEASE_TAG="${1#*=}"
				shift
				;;
			--release-tag)
				shift
				if [[ -z "${1:-}" || "$1" == -* ]]; then
					WarningMessage "--release-tag requires a value"
					return 1
				fi
				RELEASE_TAG="$1"
				shift
				;;
			--skip-backup)
				SKIP_BACKUP=true
				shift
				;;
			--skip-bash-check)
				SKIP_BASH_CHECK=true
				shift
				;;
			--skip-rc-mods)
				SKIP_RC_FILE_MODS=true
				shift
				;;
			--force)
				FORCE_INSTALL=true
				shift
				;;
			-v | --verbose)
				VERBOSE_MODE=true
				shift
				;;
			--help)
				ShowHelp
				exit 0
				;;
			*)
				WarningMessage "Unknown option: $1"
				ShowHelp
				return 1
				;;
		esac
	done

	# Validate required arguments
	if [[ -z "$RELEASE_TAG" ]]; then
		WarningMessage "No release tag specified. Required: --release-tag=TAG"
		ShowHelp
		return 1
	fi

	# Calculate the base GitHub raw URL for the specified tag
	GITHUB_RAW_URL="${gc_repo_base_url}/${RELEASE_TAG}"

	return 0
}

# ============================================================================
# Function: ShowHelp
# Description: Display help information for the installation script.
# Usage: ShowHelp
# Arguments: None
# Exits: 0
# ============================================================================
ShowHelp() {
	cat <<EOF
rcForge Installer (v${gc_installer_version})

Usage: $(basename "$0") [OPTIONS]

Options:
  --release-tag=TAG      Specify the release tag to install (required)
  --skip-backup          Skip creating a backup (not recommended)
  --skip-bash-check      Skip checking Bash version compatibility
  --skip-rc-mods         Skip modifying shell RC files
  --force                Force installation even if version is the same
  --verbose, -v          Show more detailed output
  --help                 Show this help message

Examples:
  $(basename "$0") --release-tag=v0.5.0
  $(basename "$0") --release-tag=v0.5.0 --verbose --skip-backup
EOF
}

# ============================================================================
# Function: main
# Description: Main installation function orchestrating the install process.
# Usage: main "$@"
# Arguments: $@ - Command line arguments passed to the script.
# Returns: 0 on success, >0 on failure.
# ============================================================================
main() {
	# Parse arguments
	if ! ParseArguments "$@"; then
		return 1
	fi

	SectionHeader "rcForge Installation (v${gc_installer_version})"
	InfoMessage "Target version: ${gc_rcforge_core_version} (Tag: ${RELEASE_TAG})"
	InfoMessage "Base URL: ${GITHUB_RAW_URL}"

	# Check if running in bash and if bash meets version requirements
	if [[ "${SKIP_BASH_CHECK}" != "true" ]]; then
		# Determine if this is a fresh install
		IS_FRESH_INSTALL=false
		if ! IsInstalled; then
			IS_FRESH_INSTALL=true
		fi

		CheckBashVersion "$IS_FRESH_INSTALL" "false"
	else
		InfoMessage "Skipping Bash version check (--skip-bash-check)"
	fi

	# Detect installation state
	if IsInstalled; then
		local current_version
		current_version=$(GetInstalledVersion)

		if [[ "$current_version" == "unknown" ]]; then
			InfoMessage "Existing installation detected, but version could not be determined."
			InfoMessage "Proceeding with installation/upgrade."
		else
			InfoMessage "Existing installation detected (Version: ${current_version})."

			# Check if it's the same version
			if [[ "$current_version" == "$gc_rcforge_core_version" && "$FORCE_INSTALL" != "true" ]]; then
				WarningMessage "Installed version ($current_version) matches target version ($gc_rcforge_core_version)."
				InfoMessage "Use --force to reinstall anyway."
				return 0
			fi

			InfoMessage "Will upgrade from v${current_version} to v${gc_rcforge_core_version}"
		fi

		# Check if XDG upgrade is needed
		if NeedsUpgradeToXDG; then
			if ConfirmUpgradeToXDG; then
				CreateBackup "false" "$SKIP_BACKUP" "$VERBOSE_MODE"
				MigrateToXDGStructure "false" "$VERBOSE_MODE"
			else
				return 1 # User cancelled
			fi
		else
			# Standard upgrade, take backup
			CreateBackup "false" "$SKIP_BACKUP" "$VERBOSE_MODE"
		fi

		# Download and process manifest
		DownloadManifest "false" "$VERBOSE_MODE" "$GITHUB_RAW_URL"
		ProcessManifest "false" "$VERBOSE_MODE" "$GITHUB_RAW_URL"

		# Update RC files if needed
		if [[ "$SKIP_RC_FILE_MODS" != "true" ]]; then
			AddRcFileLines "false"
		else
			InfoMessage "Skipping RC file modifications (--skip-rc-mods)"
		fi

		InfoMessage "Upgrade complete to rcForge v${gc_rcforge_core_version}"
	else
		# Fresh installation
		InfoMessage "No existing installation detected. Performing fresh install."

		# Create structure, download and process manifest
		DownloadManifest "true" "$VERBOSE_MODE" "$GITHUB_RAW_URL"
		ProcessManifest "true" "$VERBOSE_MODE" "$GITHUB_RAW_URL"

		# Add source lines to RC files
		if [[ "$SKIP_RC_FILE_MODS" != "true" ]]; then
			AddRcFileLines "true"
		else
			InfoMessage "Skipping RC file modifications (--skip-rc-mods)"
		fi

		InfoMessage "Fresh installation complete of rcForge v${gc_rcforge_core_version}"
	fi

	# Cleanup
	CleanupInstall

	# Final messages
	SuccessMessage "rcForge v${gc_rcforge_core_version} has been successfully installed!"
	InfoMessage "To start using rcForge in your current shell session:"
	InfoMessage "  source \"\${XDG_DATA_HOME:-\$HOME/.local/share}/rcforge/rcforge.sh\""
	InfoMessage "Or open a new terminal window."
	echo ""
	InfoMessage "Remember: You can press '.' during initialization to abort rcForge loading if needed."

	return 0
}

# Call the main function with all script arguments
main "$@"
exit $?

# EOF
