#!/usr/bin/env bash
# install.sh - rcForge Installation Script (Dynamic Manifest Version)
# Author: rcForge Team
# Date: 2025-04-08 # Updated Required Bash Version
# Version: 0.4.1 # Installer Version (Keep separate from rcForge Core Version)
# Category: installer
# Description: Installs or upgrades rcForge shell configuration system using a manifest file.
# Runs non-interactively. Requires Bash 4.3+ to run the installer itself.

# Set strict error handling
set -o nounset  # Treat unset variables as errors
set -o errexit  # Exit immediately if a command exits with a non-zero status
set -o pipefail # Ensure pipeline fails on any component failing

# ============================================================================
# CONFIGURATION & GLOBAL CONSTANTS
# ============================================================================

readonly RCFORGE_CORE_VERSION_CONST="0.4.1" # Version being installed
readonly INSTALLER_VERSION="0.4.1"          # Version of this installer script
readonly INSTALLER_REQUIRED_BASH="4.3"      # UPDATED: Installer itself needs 4.3+

readonly RCFORGE_DIR="$HOME/.config/rcforge"
readonly BACKUP_DIR="$RCFORGE_DIR/backups"
readonly TIMESTAMP=$(date +%Y%m%d%H%M%S)
readonly BACKUP_FILE="$BACKUP_DIR/rcforge_backup_$TIMESTAMP.tar.gz"
# Use user's repo based on previous context
readonly GITHUB_REPO="https://github.com/mhasse1/rcforge"
readonly GITHUB_RAW="https://raw.githubusercontent.com/mhasse1/rcforge/main"

# Manifest File Configuration
readonly MANIFEST_FILENAME="file-manifest.txt" # Name of the manifest file in the repo root
readonly MANIFEST_URL="${GITHUB_RAW}/${MANIFEST_FILENAME}"
readonly MANIFEST_TEMP_FILE="/tmp/rcforge_manifest_${TIMESTAMP}_$$" # Temp location for download

# Flag to track if this is a fresh install attempt for cleanup logic
g_is_fresh_install=false

# Colors (self-contained for installer)
if [[ -t 1 ]]; then # Check if stdout is a tty
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
# UTILITY FUNCTIONS (PascalCase)
# ============================================================================

# --- InstallHaltedCleanup, ErrorMessage, WarningMessage, InfoMessage, SuccessMessage ---
# --- SectionHeader, VerboseMessage, IsInstalled, CommandExists functions        ---
# --- remain unchanged from previous version of install-script.sh              ---
# --- Add them back here from the context---

# ============================================================================
# Function: InstallHaltedCleanup
# Description: Performs cleanup if an install/upgrade attempt fails.
# Usage: Called by ErrorMessage before exiting on failure.
# Arguments: None
# Returns: None.
# ============================================================================
InstallHaltedCleanup() {
    if [[ "${g_is_fresh_install:-false}" == "true" ]]; then
        WarningMessage "Installation failed. Cleaning up install directory..."
        if [[ -d "$RCFORGE_DIR" ]]; then
            if rm -rf "$RCFORGE_DIR"; then
                SuccessMessage "Removed partially installed directory: $RCFORGE_DIR"
            else
                WarningMessage "Failed to remove directory: $RCFORGE_DIR. Please remove it manually."
            fi
        else
            InfoMessage "Install directory $RCFORGE_DIR not found, no cleanup needed."
        fi
    else
        WarningMessage "Upgrade failed. Attempting to restore from backup..."
        if [[ -f "$BACKUP_FILE" ]]; then
            InfoMessage "Found backup file: $BACKUP_FILE"
            InfoMessage "Removing failed upgrade directory before restore..."
            if ! rm -rf "$RCFORGE_DIR"; then
                WarningMessage "Failed to remove current directory: $RCFORGE_DIR."
                WarningMessage "Cannot restore backup automatically. Please restore manually from $BACKUP_FILE"
                return
            fi
            InfoMessage "Restoring backup..."
            if tar -xzf "$BACKUP_FILE" -C "$(dirname "$RCFORGE_DIR")"; then
                SuccessMessage "Successfully restored previous state from backup."
                InfoMessage "The failed upgrade attempt has been rolled back."
            else
                WarningMessage "Failed to extract backup file: $BACKUP_FILE"
                WarningMessage "Your previous configuration might be lost. Please check $BACKUP_FILE manually."
            fi
        else
            WarningMessage "Backup file not found: $BACKUP_FILE"
            WarningMessage "Cannot restore automatically. Leaving current state intact."
            InfoMessage "Please review the state of: $RCFORGE_DIR"
        fi
    fi
}

# ============================================================================
# Function: ErrorMessage (Installer Version with Cleanup)
# Description: Display error message, perform cleanup, and exit.
# Usage: ErrorMessage "Error description"
# Exits: 1
# ============================================================================
ErrorMessage() {
    local original_message="${*}"
    if [[ -n "$RED" ]]; then
        echo -e "${RED}ERROR:${RESET} ${original_message}" >&2
    else
        echo -e "ERROR: ${original_message}" >&2
    fi
    InstallHaltedCleanup
    exit 1
}

# ============================================================================
# Function: WarningMessage
# Description: Display warning message.
# Usage: WarningMessage "Warning description"
# ============================================================================
WarningMessage() {
    if [[ -n "$YELLOW" ]]; then
        echo -e "${YELLOW}WARNING:${RESET} ${*}" >&2
    else
        echo -e "WARNING: ${*}" >&2
    fi
}

# ============================================================================
# Function: InfoMessage
# Description: Display info message.
# Usage: InfoMessage "Information"
# ============================================================================
InfoMessage() {
    if [[ -n "$BLUE" ]]; then
        echo -e "${BLUE}INFO:${RESET} ${*}"
    else
        echo -e "INFO: ${*}"
    fi
}

# ============================================================================
# Function: SuccessMessage
# Description: Display success message.
# Usage: SuccessMessage "Success details"
# ============================================================================
SuccessMessage() {
    if [[ -n "$GREEN" ]]; then
        echo -e "${GREEN}SUCCESS:${RESET} ${*}"
    else
        echo -e "SUCCESS: ${*}"
    fi
}

# ============================================================================
# Function: SectionHeader
# Description: Display formatted section header.
# Usage: SectionHeader "Header Text"
# ============================================================================
SectionHeader() {
    if [[ -n "$BOLD" ]]; then
        echo -e "\n${BOLD}${CYAN}$1${RESET}\n${CYAN}$(printf '=%.0s' {1..50})${RESET}\n"
    else
        echo -e "\n## $1 ##\n" # Fallback for non-tty
    fi
}

# ============================================================================
# Function: VerboseMessage
# Description: Print message only if verbose mode is enabled.
# Usage: VerboseMessage is_verbose "Message text"
# ============================================================================
VerboseMessage() {
    local is_verbose="$1"
    shift
    local message="${*}"
    if [[ "$is_verbose" == "true" ]]; then
        if [[ -n "$MAGENTA" ]]; then
            echo -e "${MAGENTA}VERBOSE:${RESET} $message"
        else
            echo -e "VERBOSE: $message"
        fi
    fi
}

# ============================================================================
# Function: IsInstalled
# Description: Check if rcForge appears to be installed.
# Usage: if IsInstalled; then ... fi
# Returns: 0 (true) if installation detected, 1 (false) otherwise.
# ============================================================================
IsInstalled() {
    [[ -d "$RCFORGE_DIR" && -f "$RCFORGE_DIR/rcforge.sh" ]]
}

# ============================================================================
# Function: CommandExists
# Description: Check if a command exists in the PATH.
# Usage: if CommandExists command_name; then ... fi
# Returns: 0 (true) if command exists, 1 (false) otherwise.
# ============================================================================
CommandExists() {
    command -v "$1" >/dev/null 2>&1
}

# ============================================================================
# Function: CheckBashVersion (Installer Specific)
# Description: Check if *this installer script* is running under required Bash version.
#              Also informs user about the rcForge core/utility requirement.
# Usage: CheckBashVersion is_skip_check
# Exits: 1 (via ErrorMessage) if check fails and not skipped.
# ============================================================================
CheckBashVersion() {
    local is_skip_check="$1"
    local min_version_installer="$INSTALLER_REQUIRED_BASH" # Installer needs 4.3+
    local min_version_rcforge="4.3"                        # rcForge itself effectively needs 4.3+

    if [[ -z "${BASH_VERSION:-}" ]]; then
        if [[ "$is_skip_check" != "true" ]]; then
            ErrorMessage "Not running in Bash. rcForge installer requires Bash ${min_version_installer}+ to run." # Exits
        else
            WarningMessage "Not running in Bash, but skipping check as requested."
        fi
        return 0 # Allow continuation if skipped
    fi

    # Check installer requirement first (using sort -V for robustness)
    if ! printf '%s\n' "$min_version_installer" "$BASH_VERSION" | sort -V -C &>/dev/null; then
        if [[ "$is_skip_check" != "true" ]]; then
            WarningMessage "This installer script requires Bash ${min_version_installer}+."
            WarningMessage "Your current Bash version is: $BASH_VERSION"
            # Display upgrade instructions (simplified from the core script)
            if [[ "$(uname)" == "Darwin" ]]; then echo -e "\n${YELLOW}For macOS users, install a newer version with Homebrew: brew install bash${RESET}"; fi
            ErrorMessage "Installer Bash version requirement not met. Aborting." # Exits
        else
            WarningMessage "Skipping installer Bash version check (required: ${min_version_installer}+) as requested."
        fi
    fi

    # Inform user about the rcForge effective requirement (even if skipping check)
    InfoMessage "Note: rcForge utilities require Bash ${min_version_rcforge}+ for full functionality."
    # Don't perform the rcForge check again here, just inform. The installed check script handles it.

    return 0 # If we reach here, the installer check passed or was skipped
}

# --- CreateBackup, DownloadFile, DownloadManifest, ProcessManifest functions ---
# --- remain unchanged from previous version of install-script.sh              ---
# --- Add them back here from the context---

# ============================================================================
# Function: CreateBackup
# Description: Create a gzipped tarball backup of the existing rcForge directory.
# Usage: CreateBackup is_skip_backup is_verbose
# Returns: 0 on success/skipped, 1 on failure (via ErrorMessage).
# ============================================================================
CreateBackup() {
    local is_skip_backup="$1"
    local is_verbose="$2"
    local tar_opts="-czf"

    if [[ "$is_skip_backup" == "true" ]]; then
        VerboseMessage "$is_verbose" "Skipping backup creation as requested."
        return 0
    fi
    if ! IsInstalled; then
        VerboseMessage "$is_verbose" "No existing installation found at $RCFORGE_DIR, skipping backup."
        return 0
    fi
    InfoMessage "Creating backup of existing installation..."
    if ! mkdir -p "$BACKUP_DIR"; then
        WarningMessage "Could not create backup directory: $BACKUP_DIR. Skipping backup."
        return 0
    fi
    if ! chmod 700 "$BACKUP_DIR"; then
        WarningMessage "Could not set permissions (700) on backup directory: $BACKUP_DIR"
    fi
    [[ "$is_verbose" == "true" ]] && tar_opts="-czvf"
    if ! tar "$tar_opts" "$BACKUP_FILE" -C "$(dirname "$RCFORGE_DIR")" "$(basename "$RCFORGE_DIR")"; then
        ErrorMessage "Backup failed: $BACKUP_FILE. Check permissions and available space." # Exits
    fi
    SuccessMessage "Backup created: $BACKUP_FILE"
    return 0
}

# ============================================================================
# Function: DownloadFile
# Description: Download a single file using curl or wget, ensure parent dir exists, set permissions.
# Usage: DownloadFile is_verbose url destination
# Exits: 1 (via ErrorMessage) on failure.
# ============================================================================
DownloadFile() {
    local is_verbose="$1"
    local url="$2"
    local destination="$3"
    local dest_dir
    local download_cmd=""

    VerboseMessage "$is_verbose" "Downloading: $(basename "$destination") to $destination"
    dest_dir=$(dirname "$destination")
    if ! mkdir -p "$dest_dir"; then ErrorMessage "Failed to create directory: $dest_dir"; fi # Exits
    if ! chmod 700 "$dest_dir"; then WarningMessage "Perms fail (700): $dest_dir"; fi
    if CommandExists curl; then
        download_cmd="curl --fail --silent --show-error --location --output \"$destination\" \"$url\""
    elif CommandExists wget; then
        download_cmd="wget --quiet --output-document=\"$destination\" \"$url\""
    else ErrorMessage "'curl' or 'wget' not found."; fi # Exits
    if ! eval "$download_cmd"; then
        rm -f "$destination" &>/dev/null || true
        ErrorMessage "Failed to download: $url" # Exits
    fi
    # Set permissions
    if [[ "$destination" == *.sh ]]; then
        if ! chmod 700 "$destination"; then WarningMessage "Perms fail (700): $destination"; fi
    else
        if ! chmod 600 "$destination"; then WarningMessage "Perms fail (600): $destination"; fi
    fi
}

# ============================================================================
# Function: DownloadManifest
# Description: Downloads the manifest file to a temporary location.
# Usage: DownloadManifest is_verbose
# Exits: 1 (via ErrorMessage) on failure.
# ============================================================================
DownloadManifest() {
    local is_verbose="$1"
    InfoMessage "Downloading file manifest ($MANIFEST_FILENAME)..."
    local download_cmd=""
    if CommandExists curl; then
        download_cmd="curl --fail --silent --show-error --location --output \"$MANIFEST_TEMP_FILE\" \"$MANIFEST_URL\""
    elif CommandExists wget; then
        download_cmd="wget --quiet --output-document=\"$MANIFEST_TEMP_FILE\" \"$MANIFEST_URL\""
    else ErrorMessage "'curl' or 'wget' not found."; fi # Exits
    if ! eval "$download_cmd"; then
        rm -f "$MANIFEST_TEMP_FILE" &>/dev/null || true
        ErrorMessage "Failed to download manifest: $MANIFEST_URL" # Exits
    fi
    if [[ ! -s "$MANIFEST_TEMP_FILE" ]]; then
        rm -f "$MANIFEST_TEMP_FILE" &>/dev/null || true
        ErrorMessage "Manifest is empty: $MANIFEST_TEMP_FILE" # Exits
    fi
    SuccessMessage "Manifest downloaded."
    return 0
}

# ============================================================================
# Function: ProcessManifest
# Description: Reads manifest, creates dirs, downloads files.
# Usage: ProcessManifest is_verbose
# Returns: 0 on success, 1 if no files processed. Exits directly on critical failures.
# ============================================================================
ProcessManifest() {
    local is_verbose="$1"
    local current_section="NONE"
    local line_num=0
    local dir_count=0
    local file_count=0
    local line=""
    local dir_path=""
    local full_dir_path=""
    local source_suffix=""
    local dest_suffix=""
    local file_url=""
    local dest_path=""

    SectionHeader "Processing Manifest"
    if [[ ! -f "$MANIFEST_TEMP_FILE" ]]; then ErrorMessage "Manifest file not found at $MANIFEST_TEMP_FILE."; fi # Exits
    if ! mkdir -p "$RCFORGE_DIR"; then ErrorMessage "Failed to ensure base directory exists: $RCFORGE_DIR"; fi   # Exits
    if ! chmod 700 "$RCFORGE_DIR"; then WarningMessage "Perms fail (700): $RCFORGE_DIR"; fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        line_num=$((line_num + 1))
        line=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        if [[ -z "$line" || "$line" =~ ^# ]]; then continue; fi
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
            full_dir_path="${RCFORGE_DIR}/${dir_path}"
            VerboseMessage "$is_verbose" "Ensuring directory: $full_dir_path"
            if ! mkdir -p "$full_dir_path"; then ErrorMessage "Failed to create directory: $full_dir_path"; fi # Exits
            if ! chmod 700 "$full_dir_path"; then WarningMessage "Perms fail (700): $full_dir_path"; fi
            dir_count=$((dir_count + 1))
            ;;
        "FILES")
            read -r source_suffix dest_suffix <<<"$line"
            if [[ -z "$source_suffix" || -z "$dest_suffix" ]]; then
                WarningMessage "Manifest line $line_num: Invalid format. Skipping: '$line'"
                continue
            fi
            file_url="${GITHUB_RAW}/${source_suffix}"
            dest_path="${RCFORGE_DIR}/${dest_suffix}"
            DownloadFile "$is_verbose" "$file_url" "$dest_path" # Handles errors/exits
            file_count=$((file_count + 1))
            ;;
        *) VerboseMessage "$is_verbose" "Ignoring line $line_num before section marker: $line" ;;
        esac
    done <"$MANIFEST_TEMP_FILE"

    SuccessMessage "Processed $dir_count directories from manifest."
    if [[ $file_count -eq 0 ]]; then
        WarningMessage "No files were processed from the manifest FILES section."
        return 1 # Indicate potential issue
    else
        SuccessMessage "Processed $file_count files from manifest."
        return 0
    fi
}

# --- UpdateShellRc, VerifyInstallation, ShowInstructions, Cleanup functions ---
# --- remain unchanged from previous version of install-script.sh              ---
# --- Add them back here from the context---
# ============================================================================
# Function: UpdateShellRc
# Description: Adds commented-out rcForge source line to shell rc files.
# Usage: UpdateShellRc is_skip_integration is_verbose
# Returns: 0
# ============================================================================
UpdateShellRc() {
    local is_skip_integration="$1"
    local is_verbose="$2"
    local source_line_commented_out=""
    local rc_file=""
    local updated_any=false
    local check_line="[ -f \"${RCFORGE_DIR}/rcforge.sh\" ] && source \"${RCFORGE_DIR}/rcforge.sh\""

    if [[ "$is_skip_integration" == "true" ]]; then
        VerboseMessage "$is_verbose" "Skipping shell config update."
        return 0
    fi
    SectionHeader "Updating Shell Configuration Files"
    source_line_commented_out="# rcForge Loader (Commented out by installer - uncomment to enable)"$'\n'
    source_line_commented_out+="# ${check_line}"

    for rc_file in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [[ -f "$rc_file" ]]; then
            if ! grep -Fxq "$check_line" "$rc_file"; then
                if ! grep -Fxq "# ${check_line}" "$rc_file"; then
                    InfoMessage "Adding commented-out rcForge source line to $rc_file..."
                    if printf "\n%s\n" "$source_line_commented_out" >>"$rc_file"; then
                        SuccessMessage "Added commented-out line to $rc_file."
                        updated_any=true
                    else WarningMessage "Failed to update $rc_file."; fi
                else VerboseMessage "$is_verbose" "$rc_file already has the commented-out rcForge line."; fi
            else VerboseMessage "$is_verbose" "$rc_file already has the active rcForge line."; fi
        else VerboseMessage "$is_verbose" "$rc_file not found; skipping."; fi
    done

    if [[ "$updated_any" == "true" ]]; then
        InfoMessage "Shell config files updated with commented-out source line."
    else InfoMessage "No shell config update needed (or skipped)."; fi
    return 0
}

# ============================================================================
# Function: VerifyInstallation
# Description: Perform basic checks after installation/upgrade.
# Usage: VerifyInstallation is_verbose
# Returns: 0 if basic checks pass, 1 if issues are detected.
# ============================================================================
VerifyInstallation() {
    local is_verbose="$1"
    local check_status=0
    local file=""
    local main_perms=""
    local critical_files=(
        "$RCFORGE_DIR/rcforge.sh"
        "$RCFORGE_DIR/system/lib/shell-colors.sh"
        # Add others if needed, based on manifest guarantees
    )
    SectionHeader "Verifying Installation"
    InfoMessage "Checking critical files and permissions..."
    for file in "${critical_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            WarningMessage "Verify fail: Missing $file"
            check_status=1
        else
            VerboseMessage "$is_verbose" "Verified exists: $file"
            if [[ "$file" == *.sh ]]; then
                local file_perms
                file_perms=$(stat -c %a "$file" 2>/dev/null || stat -f "%Lp" "$file" 2>/dev/null || echo "ERR")
                if [[ "$file_perms" == "ERR" ]]; then
                    WarningMessage "Verify warn: Could not check perms for $file"
                elif [[ "$file_perms" != "700" ]]; then
                    WarningMessage "Verify warn: Perms $file (Need: 700, Got: $file_perms)" # check_status=1 ?
                else VerboseMessage "$is_verbose" "Verified perms (700): $file"; fi
            fi
        fi
    done
    main_perms=$(stat -c %a "$RCFORGE_DIR" 2>/dev/null || stat -f "%Lp" "$RCFORGE_DIR" 2>/dev/null || echo "ERR")
    if [[ "$main_perms" == "ERR" ]]; then
        WarningMessage "Verify warn: Could not check perms for $RCFORGE_DIR"
    elif [[ "$main_perms" != "700" ]]; then
        WarningMessage "Verify warn: Perms $RCFORGE_DIR (Need: 700, Got: $main_perms)" # check_status=1 ?
    else VerboseMessage "$is_verbose" "Verified perms: $RCFORGE_DIR."; fi
    echo ""
    if [[ $check_status -eq 0 ]]; then SuccessMessage "Basic verification passed!"; else WarningMessage "Installation verification detected potential issues."; fi
    return $check_status
}

# ============================================================================
# Function: ShowInstructions
# Description: Display final post-installation instructions.
# Usage: ShowInstructions effective_install_mode
# ============================================================================
ShowInstructions() {
    local effective_install_mode="$1"
    SectionHeader "Installation Complete!"
    SuccessMessage "rcForge Core v$RCFORGE_CORE_VERSION_CONST successfully ${effective_install_mode}ed to $RCFORGE_DIR!"
    echo ""
    InfoMessage "To activate in ${BOLD}current${RESET} shell: ${CYAN}source \"$RCFORGE_DIR/rcforge.sh\"${RESET}"
    echo ""
    WarningMessage "${BOLD}IMPORTANT:${RESET} For safety, the rcForge source line in your ${CYAN}~/.bashrc${RESET} and ${CYAN}~/.zshrc${RESET} has been ${RED}commented out${RESET}."
    InfoMessage "After testing your shell manually (e.g., by running the source command above), you ${BOLD}MUST uncomment${RESET} that line in your RC file(s) for rcForge to load automatically in new shells."
    echo ""
    InfoMessage "Try commands like: ${CYAN}rc help${RESET} or ${CYAN}rc httpheaders example.com${RESET}"
    echo ""
    WarningMessage "${YELLOW}Recommend:${RESET} Use Git! ${CYAN}cd \"$RCFORGE_DIR\" && git init && git add . && git commit -m \"Initial rcForge setup\"${RESET}"
    echo ""
    InfoMessage "Docs: ${BLUE}$GITHUB_REPO${RESET}"
    echo ""
}

# ============================================================================
# Function: Cleanup
# Description: Remove temporary files on script exit.
# Usage: trap Cleanup EXIT INT TERM
# ============================================================================
Cleanup() {
    VerboseMessage "true" "Cleaning up temporary files..."
    rm -f "$MANIFEST_TEMP_FILE" &>/dev/null || true
}

# ============================================================================
# Function: ShowVersion (Installer Version)
# Description: Displays installer version information.
# Exits: 0
# ============================================================================
ShowVersion() {
    echo "rcForge Installer v$INSTALLER_VERSION"
    echo "(Installs rcForge Core v$RCFORGE_CORE_VERSION_CONST)"
    echo "Copyright (c) $(date +%Y) rcForge Team"
    echo "MIT License"
    exit 0
}

# ============================================================================
# Function: ShowHelp (Installer Help)
# Description: Displays help information for the installer script.
# Exits: 0
# ============================================================================
ShowHelp() {
    cat <<EOF
rcForge Installer v$INSTALLER_VERSION (Requires Bash $INSTALLER_REQUIRED_BASH+)

Installs/upgrades rcForge Core v$RCFORGE_CORE_VERSION_CONST using a manifest file.
Usage: $0 [options]

Options:
  --reinstall          Perform a clean reinstall (removes existing installation)
  --force, -f          Currently has no effect (future use for prompts)
  --verbose, -v        Enable verbose output during installation
  --no-backup          Skip creating a backup before installation
  --no-shell-update    Skip adding the source line to shell configuration files
  --skip-version-check Bypass the minimum Bash version check for the installer itself
  --help, -h           Show this help message
  --version            Show installer version information

Example: bash $0 --verbose
EOF
    exit 0
}

# ============================================================================
# MAIN INSTALLATION FLOW
# ============================================================================
main() {
    # --- Local variables for parsed options ---
    local install_mode="auto"
    local is_force=false
    local is_verbose=false
    local skip_backup=false
    local skip_shell_integration=false
    local skip_version_check=false
    local effective_install_mode=""

    # --- Argument Parsing ---
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --reinstall) install_mode="reinstall" ;;
        --force | -f) is_force=true ;;
        --verbose | -v) is_verbose=true ;;
        --no-backup) skip_backup=true ;;
        --no-shell-update) skip_shell_integration=true ;;
        --skip-version-check) skip_version_check=true ;;
        --help | -h) ShowHelp ;;                # Exits
        --version) ShowVersion ;;               # Exits
        *) ErrorMessage "Unknown option: $1" ;; # Exits
        esac
        shift
    done
    # --- End Argument Parsing ---

    # Set trap for cleanup AFTER args are parsed and temp file defined
    trap Cleanup EXIT INT TERM

    SectionHeader "rcForge Installer v$INSTALLER_VERSION (Manifest Mode)"

    InfoMessage "Checking installer prerequisites (Bash ${INSTALLER_REQUIRED_BASH}+)..."
    CheckBashVersion "$skip_version_check" # Exits on failure if not skipped

    # Determine effective install mode & set global flag
    effective_install_mode="$install_mode"
    if [[ "$effective_install_mode" == "auto" ]]; then
        if IsInstalled; then
            effective_install_mode="upgrade"
            InfoMessage "Existing installation detected; preparing for upgrade..."
            g_is_fresh_install=false
        else
            effective_install_mode="install"
            InfoMessage "Performing fresh installation..."
            g_is_fresh_install=true
        fi
    elif [[ "$effective_install_mode" == "reinstall" ]]; then
        InfoMessage "Performing reinstallation..."
        g_is_fresh_install=true
        if ! IsInstalled; then WarningMessage "No existing installation found to reinstall over."; fi
    fi

    # Confirmation Prompt REMOVED (--force currently has no effect)
    VerboseMessage "$is_verbose" "Proceeding with ${effective_install_mode}..."

    # Backup before potentially destructive operations
    CreateBackup "$skip_backup" "$is_verbose" # Exits on failure

    # --- Main Install/Upgrade Steps ---
    DownloadManifest "$is_verbose" # Exits on failure
    if [[ "$effective_install_mode" == "reinstall" ]] && IsInstalled; then
        InfoMessage "Removing existing installation for reinstall..."
        if ! rm -rf "$RCFORGE_DIR"; then ErrorMessage "Failed to remove existing installation at: $RCFORGE_DIR"; fi # Exits
        SuccessMessage "Removed existing installation."
    fi
    InfoMessage "Processing manifest for ${effective_install_mode}..."
    if ! ProcessManifest "$is_verbose"; then ErrorMessage "Failed to process manifest or download files."; fi # Exits
    UpdateShellRc "$skip_shell_integration" "$is_verbose"                                                     # Doesn't exit on failure
    SuccessMessage "File installation/upgrade from manifest complete."
    # --- End Main Install/Upgrade Steps ---

    # Verify installation
    if ! VerifyInstallation "$is_verbose"; then
        WarningMessage "Post-installation verification failed. Please check logs."
        # Decide if this is fatal - currently just warns
    fi

    # Display final instructions
    ShowInstructions "$effective_install_mode"

    # Cleanup trap will run on exit
    exit 0
}

# Run the installer's main function, passing all arguments
main "$@"

# EOF
