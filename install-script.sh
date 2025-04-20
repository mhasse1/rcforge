#!/usr/bin/env bash
# install-script.sh - rcForge Installation Script (v0.5.2 - Corrected)
# Author: rcForge Team (AI Refactored & Corrected)
# Date: {datetime.date.today().isoformat()}
# Version: 0.5.2 # Installer Version (Corrected)
# Category: installer
# Description: Installs or upgrades rcForge using a manifest file downloaded
#              from a specific release tag. Handles XDG migration.
# Requires Bash 4.3+

# ============================================================================
# Strict Mode & Error Handling
# ============================================================================

set -o nounset  # Treat unset variables as errors
set -o errexit  # Exit immediately on non-zero status
set -o pipefail # Ensure pipeline fails on any component failing

# ============================================================================
# CONFIGURATION & GLOBAL CONSTANTS (Readonly)
# ============================================================================

# Core version being installed
readonly gc_rcforge_core_version="0.5.0pre2" # (Update as needed for new releases)
# Version of this specific installer script
readonly gc_installer_version="0.5.2"
# Bash version required to RUN this installer script
readonly gc_installer_required_bash="4.3"

# Directory structure paths (Using standard Bash expansion)
readonly gc_config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
readonly gc_data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
readonly gc_config_dir="${gc_config_home}/rcforge"
readonly gc_data_dir="${gc_data_home}/rcforge"
# Pre-0.5.0 path used only for detecting old installations
readonly gc_old_rcforge_dir="$HOME/.config/rcforge"

# Backup configuration
readonly gc_backup_dir="${gc_data_dir}/backups"
readonly gc_timestamp=$(date +%Y%m%d%H%M%S)
# Define backup file path using the timestamp
readonly gc_backup_file="${gc_backup_dir}/rcforge_backup_${gc_timestamp}.tar.gz"

# Manifest File Configuration
readonly gc_repo_base_url="https://raw.githubusercontent.com/mhasse1/rcforge"
readonly gc_manifest_filename="file-manifest.txt"
# Temporary file locations using timestamp and PID for uniqueness
readonly gc_manifest_temp_file="/tmp/rcforge_manifest_${gc_timestamp}_$$"
readonly gc_processed_manifest_file="/tmp/rcforge_manifest_processed_${gc_timestamp}_$$"

# Colors (self-contained) - Standard color definitions
# Check if stdout is a terminal (-t 1) before defining colors
if [[ -t 1 ]]; then
    readonly RED='\\033[0;31m'
    readonly GREEN='\\033[0;32m'
    readonly YELLOW='\\033[0;33m'
    readonly BLUE='\\033[0;34m'
    readonly MAGENTA='\\033[0;35m'
    readonly CYAN='\\033[0;36m'
    readonly BOLD='\\033[1m'
    readonly RESET='\\033[0m'
else # Disable colors if not a tty
    readonly RED="" GREEN="" YELLOW="" BLUE="" MAGENTA="" CYAN="" BOLD="" RESET=""
fi

# Global options set by ParseArguments - initialized here for script clarity
RELEASE_TAG=""
SKIP_BACKUP=false
SKIP_BASH_CHECK=false
SKIP_RC_FILE_MODS=false
FORCE_INSTALL=false
VERBOSE_MODE=false
GITHUB_RAW_URL="" # Calculated in ParseArguments after RELEASE_TAG is set

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# ============================================================================
# Function: InfoMessage
# Description: Display info message to stdout, correctly handling colors.
# Usage: InfoMessage "Information text"
# Arguments: $* (required) - The message text.
# Returns: None
# ============================================================================
InfoMessage() {
    # Use printf for reliable formatting and color code interpretation
    printf "%b[INFO]%b %s\\n" "${BLUE:-}" "${RESET:-}" "${*}"
}

# ============================================================================
# Function: WarningMessage
# Description: Display warning message to stderr, correctly handling colors.
# Usage: WarningMessage "Warning text"
# Arguments: $* (required) - The message text.
# Returns: None
# ============================================================================
WarningMessage() {
    printf "%b[WARNING]%b %s\\n" "${YELLOW:-}" "${RESET:-}" "${*}" >&2
}

# ============================================================================
# Function: SuccessMessage
# Description: Display success message to stdout, correctly handling colors.
# Usage: SuccessMessage "Success text"
# Arguments: $* (required) - The message text.
# Returns: None
# ============================================================================
SuccessMessage() {
    printf "%b[SUCCESS]%b %s\\n" "${GREEN:-}" "${RESET:-}" "${*}"
}

# ============================================================================
# Function: ErrorMessage (Installer Version with Cleanup)
# Description: Display error message to stderr, perform cleanup, and exit with status 1.
# Usage: ErrorMessage "Error description text"
# Arguments: $* (required) - The message text.
# Exits: 1
# ============================================================================
ErrorMessage() {
    printf "%b[ERROR]%b %s\\n" "${RED:-}" "${RESET:-}" "${*}" >&2
    # Call cleanup function before exiting
    InstallHaltedCleanup
    exit 1
}

# ============================================================================
# Function: VerboseMessage
# Description: Print message to stdout only if VERBOSE_MODE is true.
# Usage: VerboseMessage "Verbose debug text"
# Arguments: $* (required) - The message text. Relies on global VERBOSE_MODE.
# Returns: 0
# ============================================================================
VerboseMessage() {
    # Check the global VERBOSE_MODE flag
    [[ "${VERBOSE_MODE:-false}" != "true" ]] && return 0
    # Print message with Magenta color if verbose
    printf "%b[VERBOSE]%b %s\\n" "${MAGENTA:-}" "${RESET:-}" "${*}"
}

# ============================================================================
# Function: SectionHeader
# Description: Display formatted section header to stdout for better visual structure.
# Usage: SectionHeader "Descriptive Header Text"
# Arguments: $1 (required) - The header text.
# Returns: None
# ============================================================================
SectionHeader() {
    local text="${1:-}" # Ensure text is captured
    local line_char="="
    local line_len=60 # Standard line length for the header

    # Print the header text in Bold Cyan, surrounded by lines of '='
    printf "\\n%b%b%s%b\\n" "${BOLD:-}" "${CYAN:-}" "${text}" "${RESET:-}"
    # Generate the line using printf and tr
    printf "%b%s%b\\n\\n" "${CYAN:-}" "$(printf '%*s' $line_len '' | tr ' ' "${line_char}")" "${RESET:-}"
}

# ============================================================================
# Function: InstallHaltedCleanup
# Description: Performs cleanup if install/upgrade fails. Attempts restore
#              from backup if present, otherwise cleans install directories.
# Usage: Called by ErrorMessage or trap.
# Returns: None. Attempts cleanup actions.
# ============================================================================
InstallHaltedCleanup() {
    # Use a subshell to isolate errexit if needed for cleanup steps
    (
        set +o errexit # Temporarily disable errexit for cleanup attempts

        WarningMessage "Install/Upgrade process failed. Attempting cleanup..."

        # Check if a backup file was created during this run
        if [[ -f "$gc_backup_file" ]]; then
            WarningMessage "Attempting to restore from backup: $gc_backup_file"
            InfoMessage "Removing potentially incomplete directories before restore..."

            # Use rm -rf cautiously, check return codes individually
            rm -rf "$gc_config_dir" || WarningMessage "Problem removing config dir: $gc_config_dir"
            rm -rf "$gc_data_dir" || WarningMessage "Problem removing data dir: $gc_data_dir"

            InfoMessage "Restoring backup relative to $HOME ..."
            # Restore backup; tar will exit non-zero on error, caught by initial errexit if not disabled
            if tar -xzf "$gc_backup_file" -C "$HOME"; then
                SuccessMessage "Successfully restored previous state from backup."
                InfoMessage "The failed upgrade attempt has been rolled back."
            else
                # This block might not be reached if errexit is on for the tar command
                WarningMessage "Failed to extract backup file: $gc_backup_file"
                WarningMessage "Your previous configuration might be lost or incomplete."
                WarningMessage "Please check $gc_backup_file and directories manually."
            fi
        else
            # No backup file found, assume it was a failed fresh install attempt
            WarningMessage "No backup file found. Cleaning up potentially incomplete installation directories..."
            if [[ -d "$gc_config_dir" ]]; then
                rm -rf "$gc_config_dir" && SuccessMessage "Removed directory: $gc_config_dir" || WarningMessage "Failed to remove directory: $gc_config_dir"
            fi
            if [[ -d "$gc_data_dir" ]]; then
                rm -rf "$gc_data_dir" && SuccessMessage "Removed directory: $gc_data_dir" || WarningMessage "Failed to remove directory: $gc_data_dir"
            fi
        fi

        # Clean up temporary manifest files regardless of backup status
        InfoMessage "Removing temporary files..."
        rm -f "$gc_manifest_temp_file" "$gc_processed_manifest_file" &>/dev/null || true

        InfoMessage "Cleanup attempt finished."
    ) # End of subshell
}

# ============================================================================
# Function: CommandExists
# Description: Check if a command exists in PATH and is executable.
# Usage: if CommandExists "command-name"; then ... fi
# Arguments: $1 (required) - Command name.
# Returns: 0 (true) if command exists, 1 (false) otherwise.
# ============================================================================
CommandExists() {
    # Use standard command -v for portability and reliability
    command -v "$1" >/dev/null 2>&1
}

# ============================================================================
# Function: IsInstalled
# Description: Check if rcForge appears to be installed by looking for the
#              core rcforge.sh script in expected locations.
# Usage: if IsInstalled; then ... fi
# Returns: 0 (true) if installed, 1 (false) otherwise.
# ============================================================================
IsInstalled() {
    # Check for 0.5.0+ location first (most likely for future checks)
    [[ -f "${gc_data_dir}/rcforge.sh" ]] && return 0
    # Check for pre-0.5.0 location
    [[ -f "${gc_old_rcforge_dir}/rcforge.sh" ]] && return 0
    # Not found in either location
    return 1
}

# ============================================================================
# Function: GetInstalledVersion
# Description: Detect version from an existing rcforge.sh file.
# Usage: local version; version=$(GetInstalledVersion)
# Returns: Echoes version string ("x.y.z") or "unknown". Returns 1 if not found.
# ============================================================================
GetInstalledVersion() {
    local rcforge_sh_path=""
    local version="unknown"

    # Determine path to rcforge.sh based on possible locations
    if [[ -f "${gc_data_dir}/rcforge.sh" ]]; then
        rcforge_sh_path="${gc_data_dir}/rcforge.sh" # Check new location first
    elif [[ -f "${gc_old_rcforge_dir}/rcforge.sh" ]]; then
        rcforge_sh_path="${gc_old_rcforge_dir}/rcforge.sh" # Check old location
    else
        echo "unknown"
        return 1 # Indicate not found
    fi

   # Extract version using grep and sed (safer than direct source)
   # Handles variations like RCFORGE_VERSION="x.y.z" or export RCFORGE_VERSION='x.y.z'
   version=$(grep -m 1 'RCFORGE_VERSION=' "$rcforge_sh_path" | sed -e 's/^.*RCFORGE_VERSION=["\']\([^"\']\+\)["\'].*$/\1/' || echo "unknown")
   # Handle case where grep fails or sed doesn't match
   if [[ -z "$version" || "$version" == *"RCFORGE_VERSION="* ]]; then
       version="unknown"
   fi

   echo "$version"
   # Return 0 if version was found (even if unknown), 1 if script wasn't found initially
   [[ "$rcforge_sh_path" != "" ]] && return 0 || return 1
}

# ============================================================================
# Function: NeedsUpgradeToXDG
# Description: Check if installation is pre-0.5.0 and needs XDG migration.
# Usage: if NeedsUpgradeToXDG; then ... fi
# Returns: 0 (true) if migration needed, 1 (false) otherwise.
# ============================================================================
NeedsUpgradeToXDG() {
    VerboseMessage "Checking if XDG migration is needed..."
    # Condition 1: Old script exists
    if [[ -f "${gc_old_rcforge_dir}/rcforge.sh" ]]; then
        VerboseMessage "  Old rcforge.sh found at ${gc_old_rcforge_dir}/rcforge.sh"
        # Condition 2: New script DOES NOT exist
        if [[ ! -f "${gc_data_dir}/rcforge.sh" ]]; then
            VerboseMessage "  New rcforge.sh not found at ${gc_data_dir}/rcforge.sh"
            # Optional Condition 3: Verify version is indeed < 0.5.0 (handles failed past migrations)
            local current_version; current_version=$(GetInstalledVersion) # Checks old location now
            if [[ "$current_version" != "unknown" ]] && \\
               [[ "$(printf '%s\\n' "0.5.0" "$current_version" | sort -V | head -n1)" == "$current_version" ]]; then
                 VerboseMessage "  Detected version ($current_version) is < 0.5.0. Migration required."
                 return 0 # Needs migration
             else
                 VerboseMessage "  Detected version ($current_version) is >= 0.5.0 or unknown. Migration not required."
             fi
        else
             VerboseMessage "  New rcforge.sh found. Migration not required."
        fi
    else
         VerboseMessage "  Old rcforge.sh not found. Migration not required."
    fi
    # Default: No migration needed
    return 1
}

# ============================================================================
# Function: ConfirmUpgradeToXDG
# Description: Prompt user to confirm the XDG migration process.
# Usage: ConfirmUpgradeToXDG || exit 1 # Exit if user cancels
# Returns: 0 if user confirms (y/Y), 1 otherwise.
# ============================================================================
ConfirmUpgradeToXDG() {
    printf "\\n%b📣 rcForge 0.5.0 Structure Migration 📣%b\\n\\n" "${BOLD:-}" "${RESET:-}"
    printf "This update reorganizes your rcForge files into standard XDG directories:\\n"
    printf "  - Config: %s\\n" "${gc_config_dir}"
    printf "  - Data:   %s\\n\\n" "${gc_data_dir}"
    printf "Benefits include easier syncing and better separation of customizations.\\n"
    printf "Your existing scripts and utilities WILL BE MOVED to the new locations.\\n\\n"
    printf "%bWould you like to proceed with the migration? (y/N):%b " "${YELLOW:-}" "${RESET:-}"

    local response=""
    # Read user input directly
    read -r response

    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        InfoMessage "Migration cancelled by user."
        return 1 # Indicate cancellation
    fi
    InfoMessage "User confirmed migration."
    return 0 # Indicate confirmation
}

# ============================================================================
# Function: CheckBashVersion
# Description: Checks Bash versions (installer & runtime) and records runtime path.
# Usage: CheckBashVersion
# Returns: 0 if checks passed. Exits via ErrorMessage otherwise (if not skipped).
# ============================================================================
CheckBashVersion() {
    local min_version_required="${gc_installer_required_bash}"

    SectionHeader "Checking Bash Version Compatibility"

    # 1. Check Bash running this installer script
    # ------------------------------------------
    InfoMessage "Checking installer Bash version..."
    if [[ -z "${BASH_VERSION:-}" ]]; then
        # Not running Bash, cannot guarantee installer functions
        [[ "${SKIP_BASH_CHECK}" != "true" ]] && ErrorMessage "Installer requires Bash ${min_version_required}+ to run."
        WarningMessage "Installer not running in Bash, skipping installer version check (--skip-bash-check)."
    # Use printf and sort for reliable version comparison
    elif ! printf '%s\\n%s\\n' "$min_version_required" "$BASH_VERSION" | sort -V -C &>/dev/null; then
        # Installer Bash version is too old
        [[ "${SKIP_BASH_CHECK}" != "true" ]] && ErrorMessage "Installer Bash version (${BASH_VERSION}) is too old (Requires v${min_version_required}+)."
        WarningMessage "Skipping installer Bash version check (--skip-bash-check)."
    else
        # Installer Bash version is sufficient
        SuccessMessage "Installer Bash version (${BASH_VERSION}) meets requirement (>= ${min_version_required})."
    fi
    echo "" # Whitespace

    # 2. Check user's default Bash (needed for rcForge runtime)
    # ----------------------------------------------------------
    InfoMessage "Checking user's default Bash in PATH..."
    local first_bash_in_path=""
    local runtime_bash_version=""
    local bash_location_file=""
    local config_dir="" # Renamed from docs_dir

    # Ensure 'bash' command exists in PATH
    CommandExists bash || ErrorMessage "Command 'bash' not found in PATH. Please install Bash >= ${min_version_required}."

    first_bash_in_path=$(command -v bash)
    # Robustly get version, handle potential errors from --version command
    runtime_bash_version=$("$first_bash_in_path" --version 2>/dev/null | grep -m 1 -oE 'version [0-9]+\\.[0-9]+(\\.[0-9]+)?' | awk '{print $2}' || echo "")

    if [[ -z "$runtime_bash_version" ]]; then
        # If version couldn't be determined, warn but don't necessarily fail
        WarningMessage "Could not determine version for Bash found at: ${first_bash_in_path}"
        WarningMessage "rcForge runtime might fail if this version is < ${min_version_required}."
        # Do not record path if version unknown
        return 0 # Allow install to proceed, but user is warned
    fi

    InfoMessage "Found default Bash in PATH: ${first_bash_in_path} (Version: ${runtime_bash_version})"

    # Compare runtime bash version with requirement
    if printf '%s\\n%s\\n' "$min_version_required" "$runtime_bash_version" | sort -V -C &>/dev/null; then
        SuccessMessage "Default Bash version (${runtime_bash_version}) meets runtime requirement (>= ${min_version_required})."

        # Record Path to the *new* XDG location
        bash_location_file="${gc_data_dir}/config/bash-location"
        config_dir="$(dirname "$bash_location_file")" # Correctly get parent dir path

        InfoMessage "Recording compliant Bash location to ${bash_location_file}"

        # Create directory if it doesn't exist
        mkdir -p "$config_dir" || ErrorMessage "Failed to create directory: $config_dir"
        # Set directory permissions
        chmod 700 "$config_dir" || WarningMessage "Could not set permissions (700) on: $config_dir"

        # Write path to file and set permissions
        if echo "$first_bash_in_path" > "$bash_location_file"; then
            chmod 644 "$bash_location_file" || WarningMessage "Could not set permissions (644) on: $bash_location_file"
            SuccessMessage "Bash location recorded."
        else
            # If errexit is on, this won't be reached, but good practice to handle potential write failure
            ErrorMessage "Failed to write Bash location to: ${bash_location_file}"
        fi
    else
        # Runtime Bash version is too old
        [[ "${SKIP_BASH_CHECK}" != "true" ]] && ErrorMessage "Default Bash (${runtime_bash_version}) at '${first_bash_in_path}' is too old (Needs v${min_version_required}+ for rcForge runtime)."
        WarningMessage "Skipping check of user's default Bash version (--skip-bash-check)."
    fi
    # Function completes successfully if not exited by ErrorMessage
}

# ============================================================================
# Function: CreateBackup
# Description: Creates backup tarball of existing installation (old or new structure).
# Usage: CreateBackup
# Returns: 0 on success/skipped. Exits via ErrorMessage on critical failure.
# ============================================================================
CreateBackup() {
    # Skip if requested or if no prior installation exists
    [[ "${SKIP_BACKUP}" == "true" ]] && { VerboseMessage "Skipping backup (--skip-backup)."; return 0; }
    IsInstalled || { VerboseMessage "No existing install detected, skipping backup."; return 0; }

    SectionHeader "Creating Backup"

    # Ensure backup directory exists and has correct permissions
    mkdir -p "$gc_backup_dir" || ErrorMessage "Cannot create backup directory: ${gc_backup_dir}"
    chmod 700 "$gc_backup_dir" || WarningMessage "Could not set permissions (700) on backup directory: ${gc_backup_dir}"

    # Set tar options (use array for safety)
    local -a tar_opts=("-czf") # Default: create, gzip, file
    [[ "${VERBOSE_MODE}" == "true" ]] && tar_opts=("-czvf") # Add verbose if requested

    local backup_target_msg=""
    local backup_successful=false
    local tar_exit_code=0

    # Determine what structure to back up
    if [[ -f "${gc_data_dir}/rcforge.sh" ]]; then
        # Backup new XDG structure (both config and data dirs)
        # Need to handle paths relative to their parent dirs for tar -C
        backup_target_msg="Backing up XDG structure (${gc_config_dir}, ${gc_data_dir})"
        VerboseMessage "$backup_target_msg"
        # Execute tar, capture exit code manually as pipefail might not catch -C errors robustly
        tar "${tar_opts[@]}" "$gc_backup_file" \\
             -C "$(dirname "$gc_config_dir")" "$(basename "$gc_config_dir")" \\
             -C "$(dirname "$gc_data_dir")" "$(basename "$gc_data_dir")"
        tar_exit_code=$?
        [[ $tar_exit_code -eq 0 ]] && backup_successful=true

    elif [[ -f "${gc_old_rcforge_dir}/rcforge.sh" ]]; then
        # Backup old legacy structure relative to its parent ($HOME)
        backup_target_msg="Backing up legacy structure (${gc_old_rcforge_dir})"
        VerboseMessage "$backup_target_msg"
        tar "${tar_opts[@]}" "$gc_backup_file" -C "$(dirname "$gc_old_rcforge_dir")" "$(basename "$gc_old_rcforge_dir")"
        tar_exit_code=$?
        [[ $tar_exit_code -eq 0 ]] && backup_successful=true
    else
        # Should not happen if IsInstalled passed, but handle defensively
        WarningMessage "Cannot determine existing structure to back up. Skipping backup."
        return 0
    fi

    # Check tar result
    if [[ "$backup_successful" == "true" ]]; then
        SuccessMessage "Backup created: $gc_backup_file"
        # Set backup file permissions
        chmod 600 "$gc_backup_file" || WarningMessage "Could not set permissions (600) on backup file."
    else
        # Tar command failed
        ErrorMessage "Backup command failed with exit code ${tar_exit_code}. Check output, permissions, and disk space."
    fi
}

# ============================================================================
# Function: DownloadFile
# Description: Downloads a file using curl or wget, sets permissions.
# Usage: DownloadFile "url" "destination_path"
# Arguments: $1 (url), $2 (destination_path)
# Exits: Via ErrorMessage on critical failure.
# ============================================================================
DownloadFile() {
    local url="$1"
    local destination="$2"
    local dest_dir=""
    # Use arrays for command options for safer handling of paths/args
    local -a curl_opts=()
    local -a wget_opts=()
    local download_rc=0

    # Extract directory from destination path
    dest_dir=$(dirname "$destination")

    VerboseMessage "Downloading: $(basename "$destination")"
    VerboseMessage "  Source URL: $url"
    VerboseMessage "  Destination: $destination"

    # Ensure destination directory exists
    mkdir -p "$dest_dir" || ErrorMessage "Failed to create directory: $dest_dir"
    chmod 700 "$dest_dir" || WarningMessage "Could not set permissions (700) on directory: $dest_dir"

    # Define options for curl/wget
    curl_opts=(--fail --silent --show-error --location --output "$destination")
    wget_opts=(--quiet "--output-document=$destination")

    # Attempt download with curl first, then wget
    if CommandExists curl; then
        VerboseMessage "Attempting download with curl..."
        # Execute curl directly with options array
        if curl "${curl_opts[@]}" "$url"; then
            download_rc=0 # Success
        else
            download_rc=$?
            WarningMessage "curl download failed (Exit code: $download_rc)."
        fi
    fi

    # If curl failed or wasn't available, try wget
    if [[ $download_rc -ne 0 || ! CommandExists curl ]]; then
        if CommandExists wget; then
            VerboseMessage "Attempting download with wget..."
            # Execute wget directly with options array
            if wget "${wget_opts[@]}" "$url"; then
                download_rc=0 # Success
            else
                download_rc=$?
                WarningMessage "wget download failed (Exit code: $download_rc)."
            fi
        else
            # Neither curl nor wget is available
            [[ $download_rc -ne 0 ]] || download_rc=1 # Ensure non-zero if curl wasn't present
            ErrorMessage "'curl' or 'wget' command not found. Please install one."
        fi
    fi

    # Check final download result
    if [[ $download_rc -ne 0 ]]; then
        rm -f "$destination" &>/dev/null || true # Clean up potentially partial download
        ErrorMessage "Failed to download file: $url"
    fi

    # Set permissions on successfully downloaded file
    if [[ "$destination" == *.sh ]]; then
        # Executable permissions for shell scripts
        chmod 700 "$destination" || WarningMessage "Could not set permissions (700) on script: $destination"
    else
        # Read-only for user for other files (configs, docs, etc.)
        chmod 600 "$destination" || WarningMessage "Could not set permissions (600) on file: $destination"
    fi
    SuccessMessage "Downloaded: $(basename "$destination")"
}

# ============================================================================
# Function: AddRcFileLines
# Description: Adds/Updates the rcForge source line in ~/.bashrc and ~/.zshrc.
#              Uses a portable method for inline replacement.
# Usage: AddRcFileLines
# Returns: 0 if successful or skipped, 1 if errors occurred.
# ============================================================================
AddRcFileLines() {
    # Skip if requested
    [[ "${SKIP_RC_FILE_MODS}" == "true" ]] && { InfoMessage "Skipping RC file modifications (--skip-rc-mods)."; return 0; }

    # Define the standard source line using the XDG data directory variable
    # Ensure variables inside the string are escaped for the target shell, not expanded here
    local source_line="source \\"\${XDG_DATA_HOME:-\\$HOME/.local/share}/rcforge/rcforge.sh\\""
    # Define the files to check
    local rc_files=("$HOME/.bashrc" "$HOME/.zshrc")
    local file_path=""
    local rc_name=""
    local overall_status=0 # Track if any errors occur

    SectionHeader "Updating Shell Configuration Files"

    for file_path in "${rc_files[@]}"; do
        rc_name=$(basename "$file_path")

        if [[ -f "$file_path" && -w "$file_path" ]]; then # Check if file exists and is writable
            VerboseMessage "Checking $rc_name ..."

            # Check if the correct line *already* exists verbatim
            if grep -Fq "$source_line" "$file_path"; then
                InfoMessage "Correct rcForge source line already exists in $rc_name."
                continue # Skip to the next file
            fi

            # Check if *any* line sourcing rcforge.sh exists
            if grep -q 'rcforge/rcforge.sh' "$file_path"; then
                InfoMessage "Found existing rcForge line in $rc_name. Attempting update..."
                local temp_file # Declare temp file var locally
                # Create temp file securely
                temp_file=$(mktemp "${file_path}.tmp.XXXXXX") || {
                    WarningMessage "Failed to create temp file for updating $rc_name. Skipping update for this file."
                    overall_status=1
                    continue # Skip to next file
                }

                # Use sed to replace *any* line containing 'rcforge/rcforge.sh' with the correct line
                # Using a simple pattern, assumes only one such line should exist
                # Write output to temp file
                if sed "s|^.*rcforge/rcforge\\.sh.*$|${source_line}|" "$file_path" > "$temp_file"; then
                    # Verify the replacement worked by checking the temp file
                    if grep -Fq "$source_line" "$temp_file"; then
                        # Move temp file over original file
                        if mv "$temp_file" "$file_path"; then
                            SuccessMessage "Updated rcForge source line in $rc_name."
                        else
                            WarningMessage "Failed to replace $rc_name with updated version (mv failed)."
                            rm -f "$temp_file" # Clean up temp file on error
                            overall_status=1
                        fi
                    else
                        # Sed command ran but didn't insert the new line (pattern didn't match?)
                        WarningMessage "Update pattern did not match expected line in $rc_name. Adding line instead."
                        rm -f "$temp_file" # Remove unused temp file
                        # Fall through to add the line
                        if printf "\\n# rcForge - Shell Configuration Manager (Added %s)\\n%s\\n" "$(date +%Y-%m-%d)" "$source_line" >> "$file_path"; then
                            SuccessMessage "Added rcForge source line to $rc_name."
                        else
                            WarningMessage "Failed to append source line to $rc_name after update attempt failed."
                            overall_status=1
                        fi
                    fi
                else
                     # Sed command itself failed
                     WarningMessage "Sed command failed while trying to update $rc_name."
                     rm -f "$temp_file" # Clean up temp file
                     overall_status=1
                fi
                # Ensure temp file is removed if mv failed but sed worked
                [[ -f "$temp_file" ]] && rm -f "$temp_file"
            else
                # No existing rcforge line found, add the new one
                 InfoMessage "Adding rcForge source line to $rc_name..."
                 # Add a newline, a comment header, and the source line
                 if printf "\\n# rcForge - Shell Configuration Manager (Added %s)\\n%s\\n" "$(date +%Y-%m-%d)" "$source_line" >> "$file_path"; then
                      SuccessMessage "Added source line to $rc_name."
                 else
                      WarningMessage "Failed to append source line to $rc_name."
                      overall_status=1
                 fi
            fi
        elif [[ -f "$file_path" ]]; then
            # File exists but is not writable
            WarningMessage "$rc_name exists but is not writable. Cannot modify."
            InfoMessage "Please add the following line manually:"
            InfoMessage "  $source_line"
            overall_status=1 # Consider this a failure to modify
        else
            # File does not exist
            VerboseMessage "$rc_name not found. Skipping."
            # Optionally, provide info on how to create it
            # InfoMessage "If you use this shell, create $rc_name and add the following line:"
            # InfoMessage "  $source_line"
        fi
        echo "" # Add whitespace between processing each file
    done

    if [[ $overall_status -eq 0 ]]; then
         SuccessMessage "Shell configuration file check/update complete."
    else
         WarningMessage "Shell configuration file update completed with issues."
    fi
    return $overall_status
}

# ============================================================================
# Function: CleanupInstall
# Description: Performs final cleanup by removing temporary manifest files.
# Usage: CleanupInstall
# Returns: None
# ============================================================================
CleanupInstall() {
    VerboseMessage "Performing final cleanup..."
    # Remove temporary manifest files, suppress errors if they don't exist
    rm -f "$gc_manifest_temp_file" "$gc_processed_manifest_file" &>/dev/null || true
    InfoMessage "Temporary installation files removed."
}

# ============================================================================
# Function: ShowHelp
# Description: Displays help text for the installer script.
# Usage: ShowHelp
# Exits: 0
# ============================================================================
ShowHelp() {
    # Using cat with HERE document for easy multi-line help text
    cat <<EOF
rcForge Installer (v${gc_installer_version}) - Installs rcForge Core v${gc_rcforge_core_version}

Usage: $(basename "$0") --release-tag=TAG [OPTIONS]

Installs or upgrades the rcForge shell configuration system from a specified GitHub release tag.
Downloads files based on the manifest within that tag and handles migration to the
XDG Base Directory structure introduced in v0.5.0 if necessary.

Required Argument:
  --release-tag=TAG      Specify the release tag (e.g., v0.5.0, v0.5.1) from the
                         mhasse1/rcforge repository to install.

Optional Arguments:
  --skip-backup          Do not create a backup of the existing installation before
                         upgrading. Use with caution.
  --skip-bash-check      Skip checking if the system's Bash version meets the
                         runtime requirements (v${gc_installer_required_bash}+). Useful if you manage Bash
                         versions separately, but rcForge might fail at runtime.
  --skip-rc-mods         Do not attempt to add or update the rcForge source line
                         in ~/.bashrc or ~/.zshrc. Manual configuration will be required.
  --force                Force reinstallation of files even if the target version
                         appears to be already installed. Useful for repair.
  --verbose, -v          Enable more detailed output during the installation process.
                         Helpful for troubleshooting.
  --help                 Show this help message and exit.

Examples:
  # Install/Upgrade to latest v0.5.x (replace tag as needed)
  $(basename "$0") --release-tag=v0.5.1

  # Install v0.5.1 verbosely, skipping the backup
  $(basename "$0") --release-tag=v0.5.1 --verbose --skip-backup

  # Force reinstall v0.5.1 without modifying shell rc files
  $(basename "$0") --release-tag=v0.5.1 --force --skip-rc-mods
EOF
    exit 0 # Exit successfully after showing help
}

# ============================================================================
# Function: ParseArguments
# Description: Parses command-line arguments and sets global option variables.
# Usage: ParseArguments "$@" || exit 1 # Exit script if parsing fails
# Returns: 0 on success, 1 on error. Sets global vars: RELEASE_TAG,
#          SKIP_*, FORCE_INSTALL, VERBOSE_MODE, GITHUB_RAW_URL.
# ============================================================================
ParseArguments() {
    # Reset global vars to defaults before parsing
    RELEASE_TAG="" SKIP_BACKUP=false SKIP_BASH_CHECK=false SKIP_RC_FILE_MODS=false
    FORCE_INSTALL=false VERBOSE_MODE=false GITHUB_RAW_URL=""

    # Use a standard while loop and case statement for argument parsing
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --release-tag=*)
                RELEASE_TAG="${1#*=}" # Extract value after '='
                shift ;;                # Move past the argument=value
            --release-tag)
                shift # Move past the flag name (--release-tag)
                # Check if the next argument exists and is not another option
                if [[ -z "${1:-}" || "$1" == -* ]]; then
                    # Use WarningMessage and return 1 for parse errors
                    WarningMessage "--release-tag requires a value (e.g., --release-tag=v0.5.0)"
                    return 1
                fi
                RELEASE_TAG="$1" # Assign the value
                shift ;;         # Move past the value
            --skip-backup)
                SKIP_BACKUP=true
                shift ;;
            --skip-bash-check)
                SKIP_BASH_CHECK=true
                shift ;;
            --skip-rc-mods)
                SKIP_RC_FILE_MODS=true
                shift ;;
            --force)
                FORCE_INSTALL=true
                shift ;;
            -v|--verbose)
                VERBOSE_MODE=true
                shift ;;
            --help)
                ShowHelp # Exits the script
                ;;
            # Handle unknown options
            *)
                WarningMessage "Unknown option: $1"
                ShowHelp # Show help and exit
                ;;
        esac
    done

    # --- Validate required arguments ---
    if [[ -z "$RELEASE_TAG" ]]; then
        # Use WarningMessage before returning error code
        WarningMessage "Required argument --release-tag=TAG is missing."
        ShowHelp # Show help before returning error
        return 1
    fi

    # --- Post-parsing setup ---
    # Calculate the base GitHub raw URL for the specified tag
    # Simple validation for tag format (optional but good practice)
    if [[ ! "$RELEASE_TAG" =~ ^v?[0-9]+\.[0-9]+(\.[0-9]+)?([a-zA-Z0-9.-]*)?$ ]]; then
         WarningMessage "Release tag format '$RELEASE_TAG' looks unusual. Proceeding anyway."
    fi
    # Set the global variable for the URL base
    GITHUB_RAW_URL="${gc_repo_base_url}/${RELEASE_TAG}"

    # Output parsed options if verbose mode is enabled
    if [[ "$VERBOSE_MODE" == "true" ]]; then
        SectionHeader "Parsed Options"
        InfoMessage "Release Tag:       $RELEASE_TAG"
        InfoMessage "Skip Backup:       $SKIP_BACKUP"
        InfoMessage "Skip Bash Check:   $SKIP_BASH_CHECK"
        InfoMessage "Skip RC Mods:      $SKIP_RC_FILE_MODS"
        InfoMessage "Force Install:     $FORCE_INSTALL"
        InfoMessage "Verbose Mode:      $VERBOSE_MODE"
        InfoMessage "GitHub Raw URL:    $GITHUB_RAW_URL"
        echo "" # Add whitespace
    fi

    # Return success if all checks passed
    return 0
}

# ============================================================================
# Function: MigrateToXDGStructure
# Description: Migrates files from pre-0.5.0 location to XDG standard dirs.
#              Assumes backup is done and processed manifest exists.
# Usage: MigrateToXDGStructure
# Returns: 0 on success. Exits via ErrorMessage on critical failure.
# ============================================================================
MigrateToXDGStructure() {
    SectionHeader "Migrating to XDG-Compliant Directory Structure"

    # 1. Ensure target directory structure exists based on manifest DIRS section
    # --------------------------------------------------------------------------
    InfoMessage "Ensuring new XDG directory structure exists..."
    local dir_path=""
    local in_dirs_section=false
    local line=""
    local dir_created_count=0

    # Read the DIRS section from the processed manifest
    while IFS= read -r line; do
        # Trim leading/trailing whitespace
        line="${line#"${line%%[![:space:]]*}"}"; line="${line%"${line##*[![:space:]]}"}"
        # Skip comments and empty lines
        [[ -z "$line" || "$line" =~ ^# ]] && continue

        # Detect start of DIRS section
        [[ "$line" == "DIRECTORIES:" ]] && { in_dirs_section=true; InfoMessage "Creating directories listed in manifest..."; continue; }
        # Stop processing when FILES section is reached
        [[ "$line" == "FILES:" ]] && break

        # Process lines within the DIRS section
        if [[ "$in_dirs_section" == "true" ]]; then
            dir_path="$line" # Path is already the absolute XDG path
            if [[ ! -d "$dir_path" ]]; then
                 VerboseMessage "Creating directory from manifest: $dir_path"
                 # Create directory and set permissions
                 mkdir -p "$dir_path" || ErrorMessage "Failed to create directory: $dir_path"
                 chmod 700 "$dir_path" || WarningMessage "Could not set permissions (700) on: $dir_path"
                 ((dir_created_count++))
            else
                 VerboseMessage "Directory already exists: $dir_path"
                 # Ensure permissions are correct even if it exists
                 chmod 700 "$dir_path" || WarningMessage "Could not ensure permissions (700) on existing dir: $dir_path"
            fi
        fi
    done < "$gc_processed_manifest_file" # Read from the processed manifest

    if [[ $dir_created_count -gt 0 ]]; then
        SuccessMessage "Created $dir_created_count directories for XDG structure."
    else
        InfoMessage "Required XDG directories already exist."
    fi
    echo "" # Whitespace

    # 2. Migrate user files from old location to new XDG locations
    # -------------------------------------------------------------
    InfoMessage "Migrating user files from old structure (${gc_old_rcforge_dir})..."
    local migrated_files_count=0
    local old_path=""
    local new_path=""
    local copy_failed=false

    # Helper function to copy files, preserving attributes, handling errors
    CopyIfExists() {
        local src_dir="$1" dest_dir="$2" pattern="${3:-*}" msg="$4"
        local found_any=false
        local src_file=""

        # Check if source directory exists
        if [[ -d "$src_dir" ]]; then
             VerboseMessage "Checking migration source: $src_dir"
             # Destination directory should exist from previous step, ensure perms again
             mkdir -p "$dest_dir" && chmod 700 "$dest_dir" || { WarningMessage "Cannot ensure migration destination directory: $dest_dir"; return; }

             # Use find to locate files safely and loop through them
             while IFS= read -r -d '' src_file; do
                found_any=true # Mark that we found at least one file
                VerboseMessage "  Copying $(basename "$src_file") to $dest_dir/"
                # Copy preserving attributes (-p)
                if cp -p "$src_file" "$dest_dir/"; then
                     : # Success, no output needed unless verbose
                else
                     WarningMessage "  Failed to copy $(basename "$src_file") from $src_dir to $dest_dir"
                     copy_failed=true # Flag that at least one copy failed
                fi
             done < <(find "$src_dir" -maxdepth 1 -type f -name "$pattern" -print0 2>/dev/null) # Suppress find errors if dir empty

             # Report outcome for this directory
             if [[ "$found_any" == "true" ]]; then
                  InfoMessage "Finished migrating $msg."
                  ((migrated_files_count++)) # Count directories with successful copies
             else
                  VerboseMessage "No files matching '$pattern' found in $src_dir to migrate."
             fi
        else
             VerboseMessage "Migration source directory not found, skipping: $src_dir"
        fi
    }

    # Define source and destination pairs for migration
    # User Config files
    CopyIfExists "${gc_old_rcforge_dir}/rc-scripts" "${gc_config_dir}/rc-scripts" "*.sh" "custom RC scripts"
    CopyIfExists "${gc_old_rcforge_dir}/utils" "${gc_config_dir}/utils" "*" "user utilities"
    # Data files
    CopyIfExists "${gc_old_rcforge_dir}/backups" "${gc_data_dir}/backups" "*" "backups"
    CopyIfExists "${gc_old_rcforge_dir}/docs/checksums" "${gc_data_dir}/config/checksums" "*" "checksums"

    # Handle bash location file specifically
    old_path="${gc_old_rcforge_dir}/docs/.bash_location" # Old path
    new_path="${gc_data_dir}/config/bash-location"      # New path
    if [[ -f "$old_path" ]]; then
         # Ensure destination directory exists
         mkdir -p "$(dirname "$new_path")" || WarningMessage "Failed create dir for bash location"
         if cp -p "$old_path" "$new_path"; then
            SuccessMessage "Migrated Bash location information to $new_path"
            ((migrated_files_count++))
         else
            WarningMessage "Failed to migrate Bash location info from $old_path"
            copy_failed=true
         fi
    fi

    # Final migration summary
    if [[ "$copy_failed" == "true" ]]; then
         WarningMessage "Migration file copy process completed with errors. Please review output."
    elif [[ $migrated_files_count -gt 0 ]]; then
        SuccessMessage "Migration file copy process complete."
    else
        InfoMessage "No user files found in old structure (${gc_old_rcforge_dir}) that needed migration."
    fi

    # Suggest manual removal of old directory
    InfoMessage "The old directory at '${gc_old_rcforge_dir}' is no longer needed."
    InfoMessage "${BOLD}Recommendation:${RESET} Please review its contents and remove it manually when ready."
    echo "" # Add whitespace

    # Return success even if some copies failed (non-fatal warnings issued)
    return 0
}

# ============================================================================
# Function: ProcessManifest
# Description: Reads processed manifest and downloads/updates system files.
#              Skips existing user config files to preserve customizations.
# Usage: ProcessManifest
# Returns: 0 on success. Exits via ErrorMessage on critical download failure.
# ============================================================================
ProcessManifest() {
    SectionHeader "Processing Manifest (Install/Update Files)"

    # Ensure the processed manifest file exists
    [[ ! -f "$gc_processed_manifest_file" ]] && ErrorMessage "Processed manifest file not found: $gc_processed_manifest_file"

    local current_section="NONE" # Track which section of the manifest we are in
    local line_num=0
    local file_download_count=0 # Count files actually downloaded/updated
    local file_skip_count=0     # Count user files skipped
    local line=""
    local source_repo_path=""   # Path relative to repo root (e.g., system/core/rc.sh)
    local dest_abs_path=""      # Absolute destination path (e.g., /home/user/.local/share/rcforge/...)
    local file_url=""

    # Read the processed manifest file line by line
    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_num++))
        # Trim leading/trailing whitespace
        line="${line#"${line%%[![:space:]]*}"}"; line="${line%"${line##*[![:space:]]}"}"

        # Skip comments and empty lines
        [[ -z "$line" || "$line" =~ ^# ]] && continue

        # Track current section (only care about FILES section here)
        [[ "$line" == "DIRECTORIES:" ]] && { current_section="DIRS"; continue; }
        [[ "$line" == "FILES:" ]] && { current_section="FILES"; InfoMessage "Processing files list..."; continue; }

        # Skip lines until the FILES section is reached
        [[ "$current_section" != "FILES" ]] && continue

        # --- Processing a line in the FILES section ---
        # Assumes format: source_repo_path dest_abs_path
        read -r source_repo_path dest_abs_path <<<"$line"
        if [[ -z "$source_repo_path" || -z "$dest_abs_path" ]]; then
            WarningMessage "Manifest Line $line_num: Invalid format. Skipping: '$line'"
            continue
        fi

        # Construct the full download URL
        file_url="${GITHUB_RAW_URL}/${source_repo_path}" # Use global URL base

        # --- Overwrite Logic: Skip existing user files, overwrite system files ---
        local should_download=true # Assume download unless skipped

        # Check if the destination path is within the user config directory
        if [[ "$dest_abs_path" == ${gc_config_dir}/* ]]; then
            # It's a user config file/directory path
            local final_dest_name=$(basename "$dest_abs_path")

            # Handle template files (e.g., path.conf.template)
            if [[ "$final_dest_name" == *.template ]]; then
                 # Destination is the actual config file name (without .template)
                 local actual_dest="${dest_abs_path%.template}"
                 if [[ -f "$actual_dest" ]]; then
                      # Actual config file already exists, skip downloading template
                      VerboseMessage "Skipping template download (destination exists): $actual_dest"
                      should_download=false
                 else
                      # Actual config file doesn't exist, download template to actual name
                      dest_abs_path="$actual_dest" # Update destination for DownloadFile call
                      VerboseMessage "Downloading template as initial config: $dest_abs_path"
                      # Proceed with download
                 fi
            # Handle non-template user files (e.g., rc-scripts/README.md)
            elif [[ -f "$dest_abs_path" ]]; then
                 # File exists in user config, skip download to preserve user changes
                 VerboseMessage "Skipping user file (already exists): $dest_abs_path"
                 should_download=false
            fi
        fi
        # If destination is not in user config dir (i.e., it's in data dir), should_download remains true

        # Perform download only if not skipped
        if [[ "$should_download" == "true" ]]; then
            DownloadFile "$file_url" "$dest_abs_path" # Exits on critical failure
            ((file_download_count++))
        else
            ((file_skip_count++))
        fi

    done < "$gc_processed_manifest_file" # Read from the processed manifest

    # Report final counts
    if [[ $file_download_count -eq 0 && $file_skip_count -eq 0 ]]; then
        WarningMessage "No files were processed from manifest FILES section."
        # Consider if this should be an error? If manifest is valid, should have files.
        return 1 # Indicate nothing was done or manifest might be empty
    fi
    SuccessMessage "File processing complete."
    [[ $file_download_count -gt 0 ]] && InfoMessage "Downloaded/Updated: $file_download_count system/template files."
    [[ $file_skip_count -gt 0 ]] && InfoMessage "Skipped $file_skip_count user files that already existed."

    return 0 # Success
}


# ============================================================================
# MAIN INSTALLATION FUNCTION
# ============================================================================
main() {
    # Ensure errexit is enabled for the main logic flow
    # This helps catch errors from commands like mkdir, sed, mv, tar, etc.
    set -o errexit

    # 1. Parse Command Line Arguments
    # ------------------------------------------------------------------------
    # ParseArguments exits on error or if --help is used
    ParseArguments "$@"

    SectionHeader "rcForge Installation (v${gc_installer_version})"
    InfoMessage "Target rcForge Version: ${gc_rcforge_core_version} (Tag: ${RELEASE_TAG})"
    InfoMessage "Repository Base URL: ${gc_repo_base_url}"
    VerboseMessage "Verbose mode enabled."

    # 2. Check Bash Version (unless skipped)
    # ------------------------------------------------------------------------
    if [[ "${SKIP_BASH_CHECK}" != "true" ]]; then
        CheckBashVersion # Exits on critical failure if not skipped
    else
        InfoMessage "Skipping Bash version check (--skip-bash-check)."
    fi

    # 3. Download and Process Manifest
    # ------------------------------------------------------------------------
    local manifest_full_url="${GITHUB_RAW_URL}/${gc_manifest_filename}"
    SectionHeader "Downloading Manifest"
    # Download the manifest file to a temporary location
    DownloadFile "$manifest_full_url" "$gc_manifest_temp_file" # Exits on failure
    # Basic check: ensure downloaded manifest is not empty
    [[ ! -s "$gc_manifest_temp_file" ]] && ErrorMessage "Downloaded manifest file is empty!"

    InfoMessage "Processing XDG placeholders in manifest..."
    # Use a temporary file for sed output for safety and portability
    local sed_temp_file; sed_temp_file=$(mktemp "${gc_processed_manifest_file}.tmp.XXXXXX") || ErrorMessage "Failed create temp file for sed"
    # Perform sed replacement and write to temp file
    if sed -e "s|{xdg-home}|${gc_config_dir}|g" \\
           -e "s|{xdg-data}|${gc_data_dir}|g" \\
           "$gc_manifest_temp_file" > "$sed_temp_file"; then
        # Move processed content to final processed manifest location
        mv "$sed_temp_file" "$gc_processed_manifest_file" || ErrorMessage "Failed to move processed manifest"
    else
        rm -f "$sed_temp_file" # Clean up temp file on sed error
        ErrorMessage "Failed to process XDG placeholders in manifest (sed failed)."
    fi
    # Check that the processed manifest file exists and is not empty
    [[ ! -s "$gc_processed_manifest_file" ]] && ErrorMessage "Processed manifest file is empty after sed!"
    SuccessMessage "Manifest downloaded and processed successfully."

    # 4. Determine Install Path (Upgrade or Fresh)
    # ------------------------------------------------------------------------
    if IsInstalled; then
        # --- UPGRADE PATH ---
        local current_version; current_version=$(GetInstalledVersion)
        SectionHeader "Upgrade Detected"
        InfoMessage "Existing installation detected (Version: ${current_version:-unknown})."

        # Check if versions match and --force is not used
        if [[ "$current_version" == "$gc_rcforge_core_version" && "$FORCE_INSTALL" != "true" ]]; then
             SuccessMessage "Installed version matches target. Installation is up-to-date."
             InfoMessage "Use --force to reinstall anyway."
             CleanupInstall # Still cleanup temp files
             return 0 # Successful exit, nothing more to do
        fi

        InfoMessage "Proceeding with upgrade from v${current_version:-unknown} to v${gc_rcforge_core_version}..."

        # Create backup before making changes
        CreateBackup # Exits on critical backup failure

        # Check if migration to XDG structure is needed and perform it
        if NeedsUpgradeToXDG; then
            ConfirmUpgradeToXDG || exit 1 # Exit if user cancels confirmation
            MigrateToXDGStructure # Migrate files first; exits on critical failure
        fi

        # Process manifest to download/update system files (skips existing user files)
        ProcessManifest # Exits on critical failure

        # Update RC file links/lines if not skipped
        AddRcFileLines

        SuccessMessage "Upgrade to rcForge v${gc_rcforge_core_version} complete!"

    else
        # --- FRESH INSTALL PATH ---
        SectionHeader "Fresh Installation"
        InfoMessage "No existing installation detected."

        # Ensure base directories exist (ProcessManifest might create subdirs, but ensure roots)
        mkdir -p "$gc_config_dir" "$gc_data_dir" || ErrorMessage "Failed create base XDG dirs"
        chmod 700 "$gc_config_dir" "$gc_data_dir" || WarningMessage "Perms fail on base XDG dirs"

        # Process manifest to download all defined files
        ProcessManifest # Exits on critical failure

        # Add source lines to RC files if not skipped
        AddRcFileLines

        SuccessMessage "Fresh installation of rcForge v${gc_rcforge_core_version} complete!"
    fi

    # 5. Final Cleanup & Messages
    # ------------------------------------------------------------------------
    CleanupInstall

    SectionHeader "Post-Installation Instructions"
    InfoMessage "To activate rcForge in your CURRENT shell session, run:"
    # Note: Using \$HOME and \$XDG_DATA_HOME inside the string to prevent expansion here
    InfoMessage "  source \\"\${XDG_DATA_HOME:-\\$HOME/.local/share}/rcforge/rcforge.sh\\""
    InfoMessage "For automatic loading in new sessions, ensure the line above is present and uncommented"
    InfoMessage "in your ~/.bashrc or ~/.zshrc file (the installer attempts to add/update this)."
    InfoMessage "Remember the emergency abort: Press '.' during initialization if needed."
    echo ""
    SuccessMessage "Installation Finished Successfully."

    return 0 # Explicitly return 0 on success
}

# ============================================================================
# SCRIPT EXECUTION START
# ============================================================================

# Setup cleanup trap for temporary files on exit, interrupt, termination, hangup
# Ensures temp files are removed even if script exits unexpectedly
trap 'rm -f "$gc_manifest_temp_file" "$gc_processed_manifest_file" &>/dev/null; InfoMessage "Exiting installer script."' EXIT INT TERM HUP

# Call the main function, passing all script arguments received by this script
# The exit code of the script will be the exit code of the main function
main "$@"

# EOF
