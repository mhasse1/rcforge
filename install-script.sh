#!/usr/bin/env bash
# install-script.sh - rcForge Installation Script (Dynamic Manifest Version)
# Author: rcForge Team (AI Refactored)
# Date: 2025-04-16 # Updated Date
# Version: 0.4.3 # Installer Version (Keep separate from rcForge Core Version)
# Category: installer
# Description: Installs or upgrades rcForge shell configuration system using a manifest file
#              downloaded from a specific release tag (passed via --release-tag).
#              Runs non-interactively. Requires Bash 4.3+ to run the installer itself.

# Set strict error handling
set -o nounset  # Treat unset variables as errors
set -o errexit  # Exit immediately if a command exits with a non-zero status
set -o pipefail # Ensure pipeline fails on any component failing

# ============================================================================
# CONFIGURATION & GLOBAL CONSTANTS (Readonly)
# ============================================================================

readonly gc_rcforge_core_version="0.4.2"  # Version being installed
readonly gc_installer_version="0.4.3"     # Version of this installer script
readonly gc_installer_required_bash="4.3" # Installer itself needs 4.3+

readonly gc_rcforge_dir="$HOME/.config/rcforge"
readonly gc_backup_dir="${gc_rcforge_dir}/backups"
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
        if [[ -d "$gc_rcforge_dir" ]]; then
            if rm -rf "$gc_rcforge_dir"; then
                SuccessMessage "Removed partially installed directory: $gc_rcforge_dir"
            else
                WarningMessage "Failed to remove directory: $gc_rcforge_dir. Please remove it manually."
            fi
        else
            InfoMessage "Install directory $gc_rcforge_dir not found, no cleanup needed."
        fi
    else
        # This was an upgrade attempt
        WarningMessage "Upgrade failed. Attempting to restore from backup..."
        if [[ -f "$gc_backup_file" ]]; then
            InfoMessage "Found backup file: $gc_backup_file"
            InfoMessage "Removing failed upgrade directory before restore..."
            if ! rm -rf "$gc_rcforge_dir"; then
                WarningMessage "Failed to completely remove current directory: $gc_rcforge_dir."
                WarningMessage "Attempting restore anyway, but manual cleanup might be needed."
            fi
            InfoMessage "Restoring backup..."
            if tar -xzf "$gc_backup_file" -C "$(dirname "$gc_rcforge_dir")"; then
                SuccessMessage "Successfully restored previous state from backup."
                InfoMessage "The failed upgrade attempt has been rolled back."
            else
                WarningMessage "Failed to extract backup file: $gc_backup_file"
                WarningMessage "Your previous configuration might be lost. Please check $gc_backup_file manually."
            fi
        else
            WarningMessage "Backup file not found: $gc_backup_file"
            WarningMessage "Cannot restore automatically. Leaving current state intact."
            InfoMessage "Please review the state of: $gc_rcforge_dir"
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
    [[ -d "$gc_rcforge_dir" && -f "${gc_rcforge_dir}/rcforge.sh" ]]
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
        # Record Path
        bash_location_file="${gc_rcforge_dir}/docs/.bash_location"
        docs_dir="${gc_rcforge_dir}/docs"
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
# Description: Create a gzipped tarball backup of the existing rcForge directory.
# Usage: CreateBackup is_fresh_install is_skip_backup is_verbose
# Arguments: $1, $2, $3 (required) - Booleans.
# Returns: 0 on success/skipped. Exits via ErrorMessage on critical failure.
# ============================================================================
CreateBackup() {
    local is_fresh_install_attempt="$1"
    local is_skip_backup="$2"
    local is_verbose="$3"
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
    # Corrected permission check logic:
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

    if ! tar "$tar_opts" "$gc_backup_file" -C "$(dirname "$gc_rcforge_dir")" "$(basename "$gc_rcforge_dir")"; then
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
    # Corrected permission check logic:
    if ! mkdir -p "$gc_rcforge_dir"; then
        ErrorMessage "$is_fresh_install_attempt" "Failed ensure base dir: $gc_rcforge_dir"
    fi
    if ! chmod 700 "$gc_rcforge_dir"; then
        WarningMessage "Could not set permissions (700) on: $gc_rcforge_dir"
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
                full_dir_path="${gc_rcforge_dir}/${dir_path}"
                VerboseMessage "$is_verbose" "Ensuring directory: $full_dir_path"
                # Corrected permission check logic:
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
                dest_path="${gc_rcforge_dir}/${dest_suffix}"
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
# Function: UpdateShellRc
# Description: Adds commented-out rcForge source line to standard shell rc files.
# Usage: UpdateShellRc is_skip_integration is_verbose
# Arguments: $1, $2 (required) - Booleans.
# Returns: 0.
# ============================================================================
UpdateShellRc() {
    local is_skip_integration="$1"
    local is_verbose="$2"
    local source_line_active source_line_commented rc_file updated_any=false add_block
    local -a shell_rc_files=("$HOME/.bashrc" "$HOME/.zshrc")

    if [[ "$is_skip_integration" == "true" ]]; then
        VerboseMessage "$is_verbose" "Skipping shell config update."
        return 0
    fi
    SectionHeader "Updating Shell Configuration Files"
    source_line_active="[ -f \"${gc_rcforge_dir}/rcforge.sh\" ] && source \"${gc_rcforge_dir}/rcforge.sh\""
    source_line_commented="# ${source_line_active}"
    add_block="# rcForge Loader (Commented out by installer - uncomment to enable)\n${source_line_commented}"

    for rc_file in "${shell_rc_files[@]}"; do
        VerboseMessage "$is_verbose" "Checking: ${rc_file}"
        if [[ -f "$rc_file" ]]; then
            if grep -Fxq "$source_line_active" "$rc_file"; then
                VerboseMessage "$is_verbose" "'${rc_file}' has active line."
            elif grep -Fxq "$source_line_commented" "$rc_file"; then
                VerboseMessage "$is_verbose" "'${rc_file}' has commented line."
            else
                InfoMessage "Adding commented line to '${rc_file}'..."
                if printf "\n%b\n" "$add_block" >>"$rc_file"; then
                    SuccessMessage "Added line to '${rc_file}'."
                    updated_any=true
                else
                    WarningMessage "Failed to update '${rc_file}'. Manual add needed."
                fi
            fi
        else
            VerboseMessage "$is_verbose" "Skip missing: ${rc_file}"
        fi
    done
    if [[ "$updated_any" == "true" ]]; then
        InfoMessage "Shell files checked/updated."
    else
        InfoMessage "No shell file updates needed."
    fi
    return 0
}

# ============================================================================
# Function: VerifyInstallation
# Description: Perform basic checks after installation/upgrade.
# Usage: VerifyInstallation is_verbose
# Arguments: $1 (required) - Boolean.
# Returns: 0 if basic checks pass, 1 if critical issues detected.
# ============================================================================
VerifyInstallation() {
    local is_verbose="$1"
    local check_status=0
    local file main_perms file_perms
    local -a critical_files=(
        "${gc_rcforge_dir}/rcforge.sh"
        "${gc_rcforge_dir}/system/lib/utility-functions.sh"
        "${gc_rcforge_dir}/system/lib/shell-colors.sh"
        "${gc_rcforge_dir}/system/core/rc.sh"
    )
    SectionHeader "Verifying Installation Integrity"
    InfoMessage "Checking critical files and permissions..."
    main_perms=$(stat -c %a "$gc_rcforge_dir" 2>/dev/null || stat -f "%Lp" "$gc_rcforge_dir" 2>/dev/null || echo "ERR")
    if [[ "$main_perms" == "ERR" ]]; then
        WarningMessage "Verify Warn: Cannot check perms: ${gc_rcforge_dir}"
    elif [[ "$main_perms" != "700" ]]; then
        WarningMessage "Verify Warn: Base dir perms ${gc_rcforge_dir} (Need: 700, Got: ${main_perms})"
    else
        VerboseMessage "$is_verbose" "Verified base dir perms (700): ${gc_rcforge_dir}"
    fi

    for file in "${critical_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            WarningMessage "Verify FAIL: Missing: ${file}"
            check_status=1
            continue
        fi
        VerboseMessage "$is_verbose" "Verified exists: ${file}"
        file_perms=$(stat -c %a "$file" 2>/dev/null || stat -f "%Lp" "$file" 2>/dev/null || echo "ERR")
        if [[ "$file_perms" == "ERR" ]]; then
            WarningMessage "Verify Warn: Cannot check perms: ${file}"
            continue
        fi
        # Corrected permission check logic:
        if [[ "$file" == *.sh ]]; then # Scripts need 700
            if [[ "$file_perms" != "700" ]]; then
                WarningMessage "Verify Warn: Script perms ${file} (Need: 700, Got: ${file_perms})"
            else
                VerboseMessage "$is_verbose" "Verified script perms (700): ${file}"
            fi
        else # Other files expect 600/644
            if [[ "$file_perms" != "600" && "$file_perms" != "644" ]]; then
                WarningMessage "Verify Warn: File perms ${file} (Need: 600/644, Got: ${file_perms})"
            else
                VerboseMessage "$is_verbose" "Verified file perms (${file_perms}): ${file}"
            fi
        fi
    done
    printf "\n"
    if [[ $check_status -eq 0 ]]; then
        SuccessMessage "Basic verification passed!"
    else
        WarningMessage "Verification failed (missing files)."
    fi
    return $check_status
}

# ============================================================================
# Function: ShowInstructions
# Description: Display final post-installation instructions.
# Usage: ShowInstructions effective_install_mode
# Arguments: $1 (required) - String ('install' or 'upgrade').
# ============================================================================
ShowInstructions() {
    local effective_install_mode="$1"
    SectionHeader "Installation Complete!"
    SuccessMessage "rcForge Core v${gc_rcforge_core_version} successfully ${effective_install_mode}ed to ${gc_rcforge_dir}!"
    printf "\n"
    InfoMessage "To activate in your ${BOLD}current${RESET} shell session, run:"
    printf "  %bsource \"%s/rcforge.sh\"%b\n" "${CYAN}" "${gc_rcforge_dir}" "${RESET}"
    printf "\n"
    WarningMessage "${BOLD}ACTION REQUIRED:${RESET} Loader line in ${CYAN}~/.bashrc${RESET}/${CYAN}~/.zshrc${RESET} is ${RED}COMMENTED OUT${RESET}."
    printf "\n"
    InfoMessage "1. ${BOLD}Test Manually:${RESET} Open a ${GREEN}new${RESET} terminal or run the source command above."
    InfoMessage "2. ${BOLD}Enable Auto-Load:${RESET} If OK, ${GREEN}uncomment${RESET} line in your RC file(s):"
    printf "   %b# [ -f \"%s/rcforge.sh\" ] && source \"%s/rcforge.sh\"%b\n" "${YELLOW}" "${gc_rcforge_dir}" "${gc_rcforge_dir}" "${RESET}"
    printf "   (Remove the leading '#')\n\n"
    InfoMessage "Once active, try: %brc help%b, %brc diag%b" "${CYAN}" "${RESET}" "${CYAN}" "${RESET}"
    printf "\n"
    WarningMessage "${YELLOW}Optional:${RESET} Use Git for your config (${GREEN}${gc_rcforge_dir}/rc-scripts/${RESET})."
    InfoMessage "Example: ${CYAN}cd \"${gc_rcforge_dir}\" && git init && git add . && git commit -m \"Initial setup\"${RESET}"
    printf "\n"
    # Construct URL dynamically based on potential tag (gc_rcforge_core_version might not be a tag name)
    # It's safer to just point to the main repo URL here.
    InfoMessage "Project Link: ${BLUE}${gc_repo_base_url/.git/}${RESET}"
    printf "\n"
}

# ============================================================================
# Function: Cleanup
# Description: Remove temporary files.
# Usage: trap Cleanup EXIT INT TERM HUP
# ============================================================================
Cleanup() {
    if [[ -n "${gc_manifest_temp_file:-}" ]]; then
        VerboseMessage "true" "Cleaning up temp manifest: ${gc_manifest_temp_file}"
        rm -f "$gc_manifest_temp_file" &>/dev/null || true
    fi
}

# ============================================================================
# Function: ShowVersion (Installer Version)
# Description: Displays installer version information and exits.
# Exits: 0
# ============================================================================
ShowVersion() {
    echo "rcForge Installer v${gc_installer_version} (Installs Core v${gc_rcforge_core_version})"
    echo "Copyright (c) $(date +%Y) rcForge Team"
    echo "Released under the MIT License"
    exit 0
}

# ============================================================================
# Function: ShowHelp (Installer Help)
# Description: Displays help information for the installer script and exits.
# Exits: 0
# ============================================================================
ShowHelp() {
    cat <<EOF
rcForge Installer v${gc_installer_version} (Requires Bash ${gc_installer_required_bash}+)

Installs/upgrades rcForge Core v${gc_rcforge_core_version} using manifest from a specified release tag.

Usage: $0 [options]

Options:
  --release-tag=TAG    Specify the release tag to install from (Required when run directly).
  --reinstall          Perform a clean reinstall (removes existing installation).
  --force, -f          Currently unused placeholder.
  --verbose, -v        Enable verbose output during installation.
  --no-backup          Skip creating a backup before installation/upgrade.
  --no-shell-update    Skip adding/checking commented source line in shell RC files.
  --skip-version-check Bypass the minimum Bash version check for the installer.
  --help, -h           Show this help message and exit.
  --version            Show installer version information and exit.

Example:
  # Typically run via the install.sh stub, which provides --release-tag
  bash $0 --release-tag=v0.4.3 --verbose
EOF
    exit 0
}

# ============================================================================
# Function: ParseArguments (Installer Specific)
# Description: Parse command-line arguments for the main installer script.
# Usage: declare -A options; ParseArguments options "$@"
# Returns: Populates associative array by reference. 0 on success, 1 on error.
# Exits: Directly for --help, --version.
# ============================================================================
ParseArguments() {
    local -n options_ref="$1" # Nameref (Bash 4.3+)
    shift

    # Defaults
    options_ref["install_mode"]="auto"
    options_ref["is_force"]=false
    options_ref["is_verbose"]=false
    options_ref["skip_backup"]=false
    options_ref["skip_shell_integration"]=false
    options_ref["skip_version_check"]=false
    options_ref["release_tag"]="" # Must be provided

    # Argument parsing loop
    while [[ $# -gt 0 ]]; do
        local key="$1"
        case "$key" in
            --release-tag=*)
                options_ref["release_tag"]="${key#*=}"
                shift
                ;;
            --release-tag)
                if [[ -z "${2:-}" || "$2" == -* ]]; then
                    echo "ERROR: --release-tag requires a value." >&2
                    return 1
                fi
                options_ref["release_tag"]="$2"
                shift 2
                ;;
            --reinstall)
                options_ref["install_mode"]="reinstall"
                shift
                ;;
            --force | -f)
                options_ref["is_force"]=true
                shift
                ;;
            --verbose | -v)
                options_ref["is_verbose"]=true
                shift
                ;;
            --no-backup)
                options_ref["skip_backup"]=true
                shift
                ;;
            --no-shell-update)
                options_ref["skip_shell_integration"]=true
                shift
                ;;
            --skip-version-check)
                options_ref["skip_version_check"]=true
                shift
                ;;
            --help | -h) ShowHelp ;;  # Exits
            --version) ShowVersion ;; # Exits
            --)
                shift
                break
                ;; # End of options
            -*)
                echo "ERROR: Unknown option: $key" >&2
                ShowHelp
                ;; # Exits
            *)
                echo "ERROR: Unexpected positional argument: $key" >&2
                ShowHelp
                ;; # Exits
        esac
    done

    # --- Post-parsing validation ---
    if [[ -z "${options_ref["release_tag"]:-}" ]]; then
        echo "ERROR: --release-tag=<tag> is required." >&2
        ShowHelp # Exits
        return 1 # Return error (though ShowHelp likely exited)
    fi
    return 0
}

# ============================================================================
# MAIN INSTALLATION FLOW FUNCTION
# ============================================================================
# ============================================================================
# Function: main
# Description: Main execution logic for the installer script.
# Usage: main "$@"
# Returns: 0 on success. Exits non-zero on failure via ErrorMessage.
# ============================================================================
main() {
    # Use associative array for options (requires Bash 4.3+)
    declare -A options
    local effective_install_mode=""
    local is_fresh_install_attempt=false
    local github_raw_url="" # Will be constructed based on tag

    # Parse arguments, exit if returns non-zero (includes handling --help/--version/missing tag)
    ParseArguments options "$@" || exit $?

    # Assign parsed options to local variables for easier access
    local install_mode="${options[install_mode]}"
    local is_force="${options[is_force]}"
    local is_verbose="${options[is_verbose]}"
    local skip_backup="${options[skip_backup]}"
    local skip_shell_integration="${options[skip_shell_integration]}"
    local skip_version_check="${options[skip_version_check]}"
    local release_tag="${options[release_tag]}" # Guaranteed non-empty

    # Set trap now that variables are defined
    trap Cleanup EXIT INT TERM HUP

    SectionHeader "rcForge Installer v${gc_installer_version} (Manifest Mode)"
    InfoMessage "Targeting release: ${release_tag}"

    # Determine effective install mode
    if [[ "$install_mode" == "auto" ]]; then
        if IsInstalled; then
            effective_install_mode="upgrade"
            InfoMessage "Existing install detected; preparing upgrade..."
            is_fresh_install_attempt=false
        else
            effective_install_mode="install"
            InfoMessage "Performing fresh installation..."
            is_fresh_install_attempt=true
        fi
    elif [[ "$install_mode" == "reinstall" ]]; then
        effective_install_mode="reinstall"
        InfoMessage "Performing reinstallation..."
        is_fresh_install_attempt=true
        if ! IsInstalled; then
            WarningMessage "Note: No existing installation found to reinstall over."
        fi
    else
        ShowHelp # Exit for invalid mode (shouldn't happen)
    fi

    # --- Prerequisites Checks ---
    InfoMessage "Checking prerequisites..."
    CheckBashVersion "$is_fresh_install_attempt" "$skip_version_check" # Exits on failure
    if ! CommandExists curl && ! CommandExists wget; then
        ErrorMessage "$is_fresh_install_attempt" "Requires 'curl' or 'wget'." # Exits
    fi
    SuccessMessage "Prerequisites met."

    # --- Backup ---
    CreateBackup "$is_fresh_install_attempt" "$skip_backup" "$is_verbose" # Exits on critical failure

    # --- Remove existing install if reinstalling ---
    if [[ "$effective_install_mode" == "reinstall" ]] && IsInstalled; then
        InfoMessage "Removing existing installation for reinstall..."
        if ! rm -rf "$gc_rcforge_dir"; then
            ErrorMessage "$is_fresh_install_attempt" "Failed remove existing install: $gc_rcforge_dir" # Exits
        fi
        SuccessMessage "Removed existing installation."
    fi

    # --- Construct Base URL for this Release ---
    github_raw_url="${gc_repo_base_url}/${release_tag}"

    # --- Download and Process Manifest ---
    DownloadManifest "$is_fresh_install_attempt" "$is_verbose" "$github_raw_url" # Exits on failure
    if ! ProcessManifest "$is_fresh_install_attempt" "$is_verbose" "$github_raw_url"; then
        WarningMessage "Manifest processing completed, but potential issues occurred. Check logs."
    else
        SuccessMessage "File installation/upgrade from manifest complete."
    fi

    # --- Post-Install Steps ---
    UpdateShellRc "$skip_shell_integration" "$is_verbose" # Doesn't exit

    # --- Verification ---
    if ! VerifyInstallation "$is_verbose"; then
        WarningMessage "Post-installation verification detected issues."
    fi

    # --- Final Instructions ---
    ShowInstructions "$effective_install_mode"

    exit 0 # Explicit success exit
}

# ============================================================================
# SCRIPT EXECUTION START
# ============================================================================
# Early Bash version check before main logic
if [[ "${BASH_VERSINFO[0]:-0}" -lt 4 || ("${BASH_VERSINFO[0]:-0}" -eq 4 && "${BASH_VERSINFO[1]:-0}" -lt 3) ]]; then
    printf "%bERROR:%b Installer needs Bash v4.3+. Your version: %s%b\n" "${RED}" "${RESET}" "${BASH_VERSION:-N/A}" "${RESET}" >&2
    exit 1
fi

# Run main installer function, passing all script arguments
main "$@"

# EOF
