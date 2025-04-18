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
readonly gc_config_dir="$HOME/.config/rcforge"
readonly gc_local_dir="$HOME/.local/rcforge"

# Backup configuration
readonly gc_backup_dir="${gc_local_dir}/backups"
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
        if [[ -d "$gc_local_dir" ]]; then
            if rm -rf "$gc_local_dir"; then
                SuccessMessage "Removed partially installed directory: $gc_local_dir"
            else
                WarningMessage "Failed to remove directory: $gc_local_dir. Please remove it manually."
            fi
        fi
    else
        # This was an upgrade attempt
        WarningMessage "Upgrade failed. Attempting to restore from backup..."
        if [[ -f "$gc_backup_file" ]]; then
            InfoMessage "Found backup file: $gc_backup_file"

            # For 0.5.0+ structure, clean up both directories
            InfoMessage "Removing failed upgrade directories before restore..."
            rm -rf "$gc_config_dir" "$gc_local_dir" || {
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
    if [[ -d "$gc_local_dir" && -f "${gc_local_dir}/rcforge.sh" ]]; then
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
    elif [[ -f "${gc_local_dir}/rcforge.sh" ]]; then
        rcforge_sh="${gc_local_dir}/rcforge.sh"
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
        bash_location_file="${gc_local_dir}/config/bash-location"
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
    elif [[ -d "$gc_local_dir" && -f "${gc_local_dir}/rcforge.sh" ]]; then
        # For 0.5.0+ structure, back up both directories
        if ! tar "$tar_opts" "$gc_backup_file" -C "$(dirname "$gc_config_dir")" "$(basename "$gc_config_dir")" -C "$(dirname "$gc_local_dir")" "$(basename "$gc_local_dir")"; then
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

    # Create local directory structure
    mkdir -p "${gc_local_dir}/backups"
    mkdir -p "${gc_local_dir}/config/checksums"
    mkdir -p "${gc_local_dir}/system/core"
    mkdir -p "${gc_local_dir}/system/lib"
    mkdir -p "${gc_local_dir}/system/utils"
    chmod 700 "${gc_local_dir}" "${gc_local_dir}/backups" "${gc_local_dir}/config"
    chmod 700 "${gc_local_dir}/system" "${gc_local_dir}/system/core" "${gc_local_dir}/system/lib" "${gc_local_dir}/system/utils"

    InfoMessage "Migrating files from old structure..."

    # Move rc-scripts to new location
    if [[ -d "${gc_old_rcforge_dir}/rc-scripts" ]]; then
        find "${gc_old_rcforge_dir}/rc-scripts" -type f -name "*.sh" -exec cp -p {} "${gc_config_dir}/rc-scripts/" \;
        SuccessMessage "Migrated custom RC scripts to ${gc_config_dir}/rc-scripts/"
    fi

    # Move user utilities if they exist
    if [[ -d "${gc_old_rcforge_dir}/utils" ]]; then
        mkdir -p "${gc_local_dir}/utils"
        chmod 700 "${gc_local_dir}/utils"
        find "${gc_old_rcforge_dir}/utils" -type f -exec cp -p {} "${gc_local_dir}/utils/" \;
        SuccessMessage "Migrated user utilities to ${gc_local_dir}/utils/"
    fi

    # Move backups if they exist
    if [[ -d "${gc_old_rcforge_dir}/backups" ]]; then
        find "${gc_old_rcforge_dir}/backups" -type f -exec cp -p {} "${gc_local_dir}/backups/" \;
        SuccessMessage "Migrated existing backups to ${gc_local_dir}/backups/"
    fi

    # Move checksums if they exist
    if [[ -d "${gc_old_rcforge_dir}/docs/checksums" ]]; then
        find "${gc_old_rcforge_dir}/docs/checksums" -type f -exec cp -p {} "${gc_local_dir}/config/checksums/" \;
        SuccessMessage "Migrated checksums to ${gc_local_dir}/config/checksums/"
    fi

    # Create initial API key settings file
    mkdir -p "${gc_local_dir}/config"
    touch "${gc_local_dir}/config/api_key_settings"
    chmod 600 "${gc_local_dir}/config/api_key_settings"
    cat >"${gc_local_dir}/config/api_key_settings" <<EOF
# rcForge API Key Settings
# This file contains API keys that will be exported as environment variables.
# Lines starting with # are ignored.
# Format: NAME='value'
#
# Examples:
# GEMINI_API_KEY='your-api-key-here'
# CLAUDE_API_KEY='your-api-key-here'
# AWS_API_KEY='your-api-key-here'
EOF
    SuccessMessage "Created initial API key settings file"

    # Create path.conf in new location
    mkdir -p "${gc_config_dir}/config"
    cat >"${gc_config_dir}/config/path.conf" <<EOF
# rcForge PATH Configuration
# This file configures paths to be added to your PATH environment variable.
# Lines starting with # are ignored.
# Empty lines are ignored.
# Paths are processed in order.
# ${HOME} is expanded automatically.

# User bin directory
${HOME}/bin

# Package manager paths
/opt/homebrew/bin
/usr/local/bin

# System paths
/usr/bin
/bin
/usr/sbin
/sbin
EOF
    SuccessMessage "Created path configuration file"

    # Record bash location if it exists in old structure
    if [[ -f "${gc_old_rcforge_dir}/docs/.bash_location" ]]; then
        mkdir -p "${gc_local_dir}/config"
        cp -p "${gc_old_rcforge_dir}/docs/.bash_location" "${gc_local_dir}/config/bash-location"
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
    local local_dir="${gc_local_dir}"

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
