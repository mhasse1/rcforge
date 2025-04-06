#!/usr/bin/env bash
# install.sh - rcForge Installation Script (Dynamic Manifest Version)
# Author: rcForge Team
# Date: 2025-04-06
# Version: 0.3.0
# Category: installer
# Description: Installs or upgrades rcForge shell configuration system using a manifest file.

# Set strict error handling
set -o nounset  # Treat unset variables as errors
set -o errexit  # Exit immediately if a command exits with a non-zero status
set -o pipefail # Ensure pipeline fails on any component failing

# ============================================================================
# CONFIGURATION & GLOBAL CONSTANTS
# ============================================================================

readonly RCFORGE_VERSION_CONST="0.3.0"
readonly gc_version="$RCFORGE_VERSION_CONST"
readonly RCFORGE_DIR="$HOME/.config/rcforge"
readonly BACKUP_DIR="$RCFORGE_DIR/backups"
readonly TIMESTAMP=$(date +%Y%m%d%H%M%S)
readonly BACKUP_FILE="$BACKUP_DIR/rcforge_backup_$TIMESTAMP.tar.gz"
readonly GITHUB_REPO="https://github.com/mhasse1/rcforge" # Using user's repo
readonly GITHUB_RAW="https://raw.githubusercontent.com/mhasse1/rcforge/main" # Using user's repo raw URL

# Manifest File Configuration
readonly MANIFEST_FILENAME="file-manifest.txt" # Name of the manifest file in the repo root
readonly MANIFEST_URL="${GITHUB_RAW}/${MANIFEST_FILENAME}"
readonly MANIFEST_TEMP_FILE="/tmp/rcforge_manifest_${TIMESTAMP}_$$" # Temp location for download

# Colors (self-contained)
if [[ -t 1 ]]; then
  readonly RED='\033[0;31m'; readonly GREEN='\033[0;32m'; readonly YELLOW='\033[0;33m';
  readonly BLUE='\033[0;34m'; readonly MAGENTA='\033[0;35m'; readonly CYAN='\033[0;36m';
  readonly BOLD='\033[1m'; readonly RESET='\033[0m';
else
  readonly RED=""; readonly GREEN=""; readonly YELLOW=""; readonly BLUE="";
  readonly MAGENTA=""; readonly CYAN=""; readonly BOLD=""; readonly RESET="";
fi

# ============================================================================
# UTILITY FUNCTIONS (PascalCase)
# ============================================================================

# --- Messaging Functions ---
ErrorMessage() { echo -e "${RED}ERROR:${RESET} $1" >&2; exit 1; }
WarningMessage() { echo -e "${YELLOW}WARNING:${RESET} $1" >&2; }
InfoMessage() { echo -e "${BLUE}INFO:${RESET} $1"; }
SuccessMessage() { echo -e "${GREEN}SUCCESS:${RESET} $1"; }
SectionHeader() { if [[ -n "$BOLD" ]]; then echo -e "\n${BOLD}${CYAN}$1${RESET}\n${CYAN}$(printf '=%.0s' {1..50})${RESET}\n"; else echo -e "\n## $1 ##\n"; fi; }
VerboseMessage() { local v="$1"; local m="$2"; if [[ "$v" == "true" ]]; then echo -e "${MAGENTA}VERBOSE:${RESET} $m"; fi; }

# --- System Check Functions ---
IsInstalled() { [[ -d "$RCFORGE_DIR" && -f "$RCFORGE_DIR/rcforge.sh" ]]; }
CommandExists() { command -v "$1" >/dev/null 2>&1; }

# ============================================================================
# Function: CheckBashVersion
# Description: Check if running Bash version meets minimum requirements (4.0+).
# Usage: CheckBashVersion is_skip_check
# ============================================================================
CheckBashVersion() {
    local is_skip_check="$1"; local response=""; local current_major_version; local required_major_version=4
    if [[ -z "${BASH_VERSION:-}" ]]; then
        WarningMessage "Not running in Bash. Some rcForge features require Bash 4.0+.";
        if [[ "$is_skip_check" != "true" ]]; then read -p "Continue anyway? [y/N] " response; [[ "$response" =~ ^[Yy]$ ]] || ErrorMessage "Installation aborted."; fi; return 0;
    fi; current_major_version="${BASH_VERSION%%.*}";
    if [[ "$current_major_version" -lt "$required_major_version" && "$is_skip_check" != "true" ]]; then
        WarningMessage "rcForge requires Bash 4.0+; your version is $BASH_VERSION."; WarningMessage "Use --skip-version-check to bypass.";
        if [[ "$(uname)" == "Darwin" ]]; then echo -e "\n${YELLOW}macOS users: install newer Bash with Homebrew ('brew install bash').${RESET}"; fi;
        read -p "Continue anyway? [y/N] " response; [[ "$response" =~ ^[Yy]$ ]] || ErrorMessage "Installation aborted.";
    elif [[ "$is_skip_check" == "true" ]]; then WarningMessage "Skipping Bash version check."; fi; return 0;
}

# ============================================================================
# Function: CreateBackup
# Description: Create a backup of the existing rcForge directory.
# Usage: CreateBackup is_skip_backup is_verbose
# ============================================================================
CreateBackup() {
    local is_skip_backup="$1"; local is_verbose="$2"; local tar_opts="-czf"
    if [[ "$is_skip_backup" == "true" ]]; then VerboseMessage "$is_verbose" "Skipping backup."; return 0; fi
    if ! IsInstalled; then VerboseMessage "$is_verbose" "No existing installation found; skipping backup."; return 0; fi
    InfoMessage "Creating backup..."; if ! mkdir -p "$BACKUP_DIR"; then WarningMessage "Cannot create backup dir; skipping backup."; return 0; fi
    if [[ "$is_verbose" == "true" ]]; then tar_opts="-czvf"; fi
    if ! tar "$tar_opts" "$BACKUP_FILE" -C "$(dirname "$RCFORGE_DIR")" "$(basename "$RCFORGE_DIR")"; then ErrorMessage "Backup failed: $BACKUP_FILE."; fi
    SuccessMessage "Backup created: $BACKUP_FILE"; return 0;
}

# ============================================================================
# Function: CreateDirectories
# Description: Create the standard rcForge directory structure.
# Usage: CreateDirectories is_verbose
# ============================================================================
CreateDirectories() {
    local is_verbose="$1"; InfoMessage "Creating/verifying directory structure...";
    local -a dirs=("$RCFORGE_DIR/rc-scripts" "$RCFORGE_DIR/utils" "$RCFORGE_DIR/backups" "$RCFORGE_DIR/docs" "$RCFORGE_DIR/system/lib" "$RCFORGE_DIR/system/core" "$RCFORGE_DIR/system/include" "$RCFORGE_DIR/system/utils"); local dir=""
    for dir in "${dirs[@]}"; do if ! mkdir -p "$dir"; then ErrorMessage "Failed to create dir: $dir"; fi; if ! chmod 700 "$dir"; then WarningMessage "Perms fail: $dir"; fi; done
    if [[ -d "$RCFORGE_DIR" ]]; then if ! chmod 700 "$RCFORGE_DIR"; then WarningMessage "Perms fail: $RCFORGE_DIR"; fi; fi
    SuccessMessage "Directory structure verified."; return 0;
}

# ============================================================================
# Function: DownloadFile
# Description: Download a single file using curl or wget, set permissions.
# Usage: DownloadFile is_verbose url destination
# ============================================================================
DownloadFile() {
    local is_verbose="$1"; local url="$2"; local destination="$3"; local dest_dir=""; local download_cmd=""
    VerboseMessage "$is_verbose" "Downloading: $(basename "$destination")"
    dest_dir=$(dirname "$destination"); if ! mkdir -p "$dest_dir"; then ErrorMessage "Failed to create dir for: $dest_dir"; fi
    if CommandExists curl; then download_cmd="curl --fail --silent --show-error --location --output \"$destination\" \"$url\"";
    elif CommandExists wget; then download_cmd="wget --quiet --output-document=\"$destination\" \"$url\"";
    else ErrorMessage "'curl' or 'wget' not found."; fi
    if ! eval "$download_cmd"; then rm -f "$destination" &>/dev/null || true; ErrorMessage "Failed to download: $url"; fi
    if [[ "$destination" == *.sh ]]; then if ! chmod 700 "$destination"; then WarningMessage "Perms fail (700): $destination"; fi
    else if ! chmod 600 "$destination"; then WarningMessage "Perms fail (600): $destination"; fi; fi
}

# ============================================================================
# Function: DownloadManifest
# Description: Downloads the manifest file to a temporary location.
# Usage: DownloadManifest is_verbose
# Returns: 0 on success, calls ErrorMessage on failure.
# ============================================================================
DownloadManifest() {
    local is_verbose="$1"
    InfoMessage "Downloading file manifest..."
    # Use DownloadFile to get the manifest
    DownloadFile "$is_verbose" "$MANIFEST_URL" "$MANIFEST_TEMP_FILE" || {
        ErrorMessage "Failed to download manifest file from $MANIFEST_URL" # Exits
    }
    # Verify manifest downloaded and is not empty
    if [[ ! -s "$MANIFEST_TEMP_FILE" ]]; then
         rm -f "$MANIFEST_TEMP_FILE" &>/dev/null || true
         ErrorMessage "Downloaded manifest file is empty or missing: $MANIFEST_TEMP_FILE" # Exits
    fi
    SuccessMessage "Manifest downloaded."
    return 0
}

# ============================================================================
# Function: DownloadFilesFromManifest
# Description: Reads the manifest file and downloads all listed files.
# Usage: DownloadFilesFromManifest is_verbose
# Arguments:
#   is_verbose (required) - Boolean (true or false).
# Returns: 0 on success, calls ErrorMessage on failure within DownloadFile.
# ============================================================================
DownloadFilesFromManifest() {
    local is_verbose="$1"
    local source_suffix=""
    local dest_suffix=""
    local file_url=""
    local dest_path=""
    local line_num=0
    local download_count=0

    SectionHeader "Downloading rcForge Files via Manifest"

    if [[ ! -f "$MANIFEST_TEMP_FILE" ]]; then
        ErrorMessage "Manifest file not found at $MANIFEST_TEMP_FILE. Cannot proceed." # Exits
    fi

    # Read the manifest file line by line
    while IFS=$' \t' read -r source_suffix dest_suffix || [[ -n "$source_suffix" ]]; do # Handle lines with spaces/tabs, ensure last line is read
        line_num=$((line_num + 1))
        # Skip empty lines or lines starting with #
        [[ -z "$source_suffix" || "$source_suffix" =~ ^# ]] && continue

        # Basic validation
        if [[ -z "$dest_suffix" ]]; then
            WarningMessage "Manifest line $line_num: Missing destination path for source '$source_suffix'. Skipping."
            continue
        fi

        file_url="${GITHUB_RAW}/${source_suffix}"
        dest_path="${RCFORGE_DIR}/${dest_suffix}"

        # Download the file
        DownloadFile "$is_verbose" "$file_url" "$dest_path" # DownloadFile handles errors/exit
        download_count=$((download_count + 1))

    done < "$MANIFEST_TEMP_FILE"

    if [[ $download_count -eq 0 ]]; then
         WarningMessage "No files were specified or downloaded from the manifest."
         # Consider if this should be an error
         return 1 # Treat as failure if nothing downloaded
    fi

    SuccessMessage "Downloaded $download_count files specified in manifest."
    return 0
}


# ============================================================================
# Function: UpdateShellRc
# Description: Add the rcForge sourcing line to user's shell rc files (.bashrc, .zshrc).
# Usage: UpdateShellRc is_skip_integration is_verbose
# ============================================================================
UpdateShellRc() {
    local is_skip_integration="$1"; local is_verbose="$2"; local source_line=""; local rc_file=""; local updated_any=false
    if [[ "$is_skip_integration" == "true" ]]; then VerboseMessage "$is_verbose" "Skipping shell config update."; return 0; fi
    SectionHeader "Updating Shell Configuration Files";
    source_line="# rcForge Loader"$'\n'; source_line+="[ -f \"${RCFORGE_DIR}/rcforge.sh\" ] && source \"${RCFORGE_DIR}/rcforge.sh\"";
    for rc_file in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [[ -f "$rc_file" ]]; then
            if ! grep -Fxq "[ -f \"${RCFORGE_DIR}/rcforge.sh\" ] && source \"${RCFORGE_DIR}/rcforge.sh\"" "$rc_file"; then
                InfoMessage "Adding rcForge source line to $rc_file...";
                if printf "\n%s\n" "$source_line" >> "$rc_file"; then SuccessMessage "Updated $rc_file."; updated_any=true;
                else WarningMessage "Failed to update $rc_file."; fi
            else VerboseMessage "$is_verbose" "$rc_file already configured."; fi
        else VerboseMessage "$is_verbose" "$rc_file not found; skipping."; fi
    done; if [[ "$updated_any" == "true" ]]; then InfoMessage "Shell config updated."; else InfoMessage "No shell config update needed."; fi; return 0;
}

# ============================================================================
# Function: ShowVersion / ShowHelp (No changes needed)
# ============================================================================
ShowVersion() { echo "rcForge Installer v$gc_version"; echo "Installs rcForge Core v$RCFORGE_VERSION_CONST"; echo "Copyright (c) $(date +%Y) rcForge Team"; echo "MIT License"; exit 0; }
ShowHelp() { echo "rcForge Installer v$gc_version"; echo ""; echo "Installs/upgrades rcForge using a manifest file."; echo ""; echo "Usage: $0 [options]"; echo ""; echo "Options:"; echo " --reinstall"; echo " --force, -f"; echo " --verbose, -v"; echo " --no-backup"; echo " --no-shell-update"; echo " --skip-version-check"; echo " --help, -h"; echo " --version"; echo ""; echo "Example: bash $0 --verbose"; exit 0; }


# ============================================================================
# Function: CleanInstall
# Description: Perform a fresh installation or reinstallation using the manifest.
# Usage: CleanInstall install_mode is_verbose is_skip_integration
# ============================================================================
CleanInstall() {
    local install_mode="$1"; local is_verbose="$2"; local is_skip_integration="$3"
    if [[ "$install_mode" == "reinstall" ]] && IsInstalled; then
        InfoMessage "Removing existing installation...";
        if ! rm -rf "$RCFORGE_DIR"; then ErrorMessage "Failed removal: $RCFORGE_DIR"; fi
        SuccessMessage "Existing installation removed.";
    fi
    InfoMessage "Starting clean installation process...";
    CreateDirectories "$is_verbose" || return 1
    # DownloadFilesFromManifest replaced DownloadStandardFiles
    DownloadFilesFromManifest "$is_verbose" || return 1
    UpdateShellRc "$is_skip_integration" "$is_verbose" || return 1
    SuccessMessage "Clean installation finished."; return 0;
}

# ============================================================================
# Function: UpgradeInstall
# Description: Perform an upgrade using the manifest (overwrites manifest files).
# Usage: UpgradeInstall is_verbose is_skip_integration
# ============================================================================
UpgradeInstall() {
    local is_verbose="$1"; local is_skip_integration="$2"
    InfoMessage "Starting upgrade process...";
    CreateDirectories "$is_verbose" || return 1 # Ensure structure exists

    SectionHeader "Upgrading rcForge System Files via Manifest"
    # Download all files listed in the manifest, overwriting existing ones
    DownloadFilesFromManifest "$is_verbose" || return 1
    SuccessMessage "System file download complete."

    # Note: This simplified upgrade overwrites *all* files in the manifest.
    # User modifications to example rc-scripts listed in manifest will be lost.
    WarningMessage "Upgrade complete. Files listed in manifest were overwritten."

    UpdateShellRc "$is_skip_integration" "$is_verbose" || return 1
    SuccessMessage "Upgrade process finished."; return 0;
}

# ============================================================================
# Function: VerifyInstallation
# Description: Perform basic checks after installation/upgrade.
# Usage: VerifyInstallation is_verbose
# ============================================================================
VerifyInstallation() {
    local is_verbose="$1"; local check_status=0; local file=""; local main_perms=""
    SectionHeader "Verifying Installation"
    local critical_files=("$RCFORGE_DIR/rcforge.sh" "$RCFORGE_DIR/system/lib/shell-colors.sh" "$RCFORGE_DIR/system/core/functions.sh")
    InfoMessage "Checking critical files and permissions...";
    for file in "${critical_files[@]}"; do if [[ ! -f "$file" ]]; then WarningMessage "Verify fail: Missing $file"; check_status=1; else VerboseMessage "$is_verbose" "Verified exists: $file"; fi; done
    main_perms=$(stat -c %a "$RCFORGE_DIR" 2>/dev/null || stat -f "%Lp" "$RCFORGE_DIR" 2>/dev/null || echo "ERR");
    if [[ "$main_perms" != "700" ]]; then WarningMessage "Verify warn: Perms $RCFORGE_DIR (Need: 700, Got: $main_perms)"; else VerboseMessage "$is_verbose" "Verified perms: $RCFORGE_DIR."; fi
    if [[ $check_status -eq 0 ]]; then SuccessMessage "Basic verification passed!"; else WarningMessage "Verification detected issues."; fi
    return $check_status;
}

# ============================================================================
# Function: ShowInstructions
# Description: Display final post-installation instructions.
# Usage: ShowInstructions effective_install_mode
# ============================================================================
ShowInstructions() {
    local effective_install_mode="$1"; SectionHeader "Installation Complete!";
    SuccessMessage "rcForge v$gc_version successfully ${effective_install_mode}ed to $RCFORGE_DIR!"; echo "";
    InfoMessage "To activate in ${BOLD}current${RESET} shell: ${CYAN}source \"$RCFORGE_DIR/rcforge.sh\"${RESET}"; echo "";
    InfoMessage "${BOLD}New${RESET} shells should load automatically if shell integration was successful."; echo "";
    InfoMessage "Try: ${CYAN}rc help${RESET} or ${CYAN}rc httpheaders example.com${RESET}"; echo "";
    WarningMessage "${YELLOW}Recommend:${RESET} Use Git! ${CYAN}cd \"$RCFORGE_DIR\" && git init && git add . && git commit -m \"Initial setup\"${RESET}"; echo "";
    InfoMessage "Docs: ${BLUE}$GITHUB_REPO${RESET}"; echo "";
}

# ============================================================================
# Function: Cleanup
# Description: Remove temporary files.
# Usage: Cleanup
# ============================================================================
Cleanup() {
    VerboseMessage "${1:-false}" "Cleaning up temporary manifest file..." # Assume first arg might be verbose flag if passed via trap
    rm -f "$MANIFEST_TEMP_FILE" &>/dev/null || true
}

# ============================================================================
# MAIN INSTALLATION FLOW
# ============================================================================

# ============================================================================
# Function: main
# Description: Main execution logic for the installer script.
# Usage: main "$@"
# Returns: Exits with 0 on success, 1 on failure.
# ============================================================================
main() {
    # --- Local variables for parsed options ---
    local install_mode="auto"; local is_force=false; local is_verbose=false
    local skip_backup=false; local skip_shell_integration=false; local skip_version_check=false
    local effective_install_mode="" # Will be set after check
    local confirmation_response=""  # For user prompt

    # --- Argument Parsing ---
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --reinstall) install_mode="reinstall" ;;
            --force|-f) is_force=true ;;
            --verbose|-v) is_verbose=true ;;
            --no-backup) skip_backup=true ;;
            --no-shell-update) skip_shell_integration=true ;;
            --skip-version-check) skip_version_check=true ;;
            --help|-h) ShowHelp; exit 0 ;;
            --version) ShowVersion; exit 0 ;;
            *) WarningMessage "Unknown option: $1"; ShowHelp; exit 1 ;;
        esac
        shift
    done
    # --- End Argument Parsing ---

    # Set trap for cleanup
    trap Cleanup EXIT

    SectionHeader "rcForge Installer v$gc_version (Manifest Mode)"

    InfoMessage "Checking prerequisites..."
    CheckBashVersion "$skip_version_check" || exit 1

    # Determine effective install mode
    effective_install_mode="$install_mode"
    if [[ "$effective_install_mode" == "auto" ]]; then
        if IsInstalled; then effective_install_mode="upgrade"; InfoMessage "Existing installation detected; preparing for upgrade...";
        else effective_install_mode="install"; InfoMessage "Performing fresh installation..."; fi
    elif [[ "$effective_install_mode" == "reinstall" ]]; then
         InfoMessage "Performing reinstallation...";
         if ! IsInstalled; then WarningMessage "No existing installation found to reinstall over."; fi
    fi

    # Confirmation Prompt
    if [[ "$is_force" != "true" ]]; then
        printf "%b" "${YELLOW}Continue with ${effective_install_mode}? [Y/n]:${RESET} "
        read -r confirmation_response
        if [[ -n "$confirmation_response" && ! "$confirmation_response" =~ ^[Yy]$ ]]; then
            InfoMessage "Installation aborted by user."; exit 0; fi
    else
        WarningMessage "Proceeding non-interactively (--force)."
    fi

    # Backup before proceeding (unless skipped)
    CreateBackup "$skip_backup" "$is_verbose" || exit 1

    # Ensure base directories exist BEFORE manifest download
    CreateDirectories "$is_verbose" || exit 1

    # Download the manifest file
    DownloadManifest "$is_verbose" || exit 1

    # Perform installation/upgrade using the manifest
    InfoMessage "Starting ${effective_install_mode} using manifest..."
    if [[ "$effective_install_mode" == "upgrade" ]]; then
        UpgradeInstall "$is_verbose" "$skip_shell_integration" || exit 1
    else # install or reinstall
        CleanInstall "$effective_install_mode" "$is_verbose" "$skip_shell_integration" || exit 1
    fi
    SuccessMessage "File installation from manifest complete."

    # Verify installation
    VerifyInstallation "$is_verbose" || exit 1 # Exit if basic verification fails

    # Display final instructions
    ShowInstructions "$effective_install_mode"

    # Cleanup trap will run on exit
    exit 0
}

# Run the installer's main function
main "$@"

# EOF