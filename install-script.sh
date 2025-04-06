#!/usr/bin/env bash
# install.sh - rcForge Installation Script
# Author: rcForge Team
# Date: 2025-04-06 # Updated Date
# Version: 0.3.0
# Category: installer
# Description: Installs or upgrades rcForge shell configuration system

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

# Colors (self-contained)
if [[ -t 1 ]]; then # Check if stdout is a tty
  readonly RED='\033[0;31m'; readonly GREEN='\033[0;32m'; readonly YELLOW='\033[0;33m';
  readonly BLUE='\033[0;34m'; readonly MAGENTA='\033[0;35m'; readonly CYAN='\033[0;36m';
  readonly BOLD='\033[1m'; readonly RESET='\033[0m';
else # Disable colors if not a tty
  readonly RED=""; readonly GREEN=""; readonly YELLOW=""; readonly BLUE="";
  readonly MAGENTA=""; readonly CYAN=""; readonly BOLD=""; readonly RESET="";
fi

# ============================================================================
# UTILITY FUNCTIONS (PascalCase)
# ============================================================================

# ============================================================================
# Function: ErrorMessage
# Description: Display error message and exit.
# Usage: ErrorMessage "Error description"
# ============================================================================
ErrorMessage() {
  echo -e "${RED}ERROR:${RESET} $1" >&2
  exit 1
}

# ============================================================================
# Function: WarningMessage
# Description: Display warning message.
# Usage: WarningMessage "Warning description"
# ============================================================================
WarningMessage() {
  echo -e "${YELLOW}WARNING:${RESET} $1" >&2
}

# ============================================================================
# Function: InfoMessage
# Description: Display info message.
# Usage: InfoMessage "Information"
# ============================================================================
InfoMessage() {
  echo -e "${BLUE}INFO:${RESET} $1"
}

# ============================================================================
# Function: SuccessMessage
# Description: Display success message.
# Usage: SuccessMessage "Success details"
# ============================================================================
SuccessMessage() {
  echo -e "${GREEN}SUCCESS:${RESET} $1"
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
# Arguments:
#   is_verbose (required) - Boolean (true or false) indicating if verbose mode is on.
#   message (required) - Text to display.
# ============================================================================
VerboseMessage() {
    local is_verbose="$1"
    local message="$2"
    # Check the boolean value directly
    if [[ "$is_verbose" == "true" ]]; then
        echo -e "${MAGENTA}VERBOSE:${RESET} $message"
    fi
}

# ============================================================================
# Function: IsInstalled
# Description: Check if rcForge appears to be installed.
# Usage: IsInstalled
# Returns: 0 if installed, 1 otherwise.
# ============================================================================
IsInstalled() {
  [[ -d "$RCFORGE_DIR" && -f "$RCFORGE_DIR/rcforge.sh" ]]
}

# ============================================================================
# Function: CommandExists
# Description: Check if a command exists in the PATH.
# Usage: CommandExists command_name
# Returns: 0 if command exists, 1 otherwise.
# ============================================================================
CommandExists() {
  command -v "$1" >/dev/null 2>&1
}

# ============================================================================
# Function: CheckBashVersion
# Description: Check if running Bash version meets minimum requirements (4.0+).
# Usage: CheckBashVersion is_skip_check
# Arguments:
#   is_skip_check (required) - Boolean (true or false).
# Returns: 0 if compatible or skipped, exits 1 if incompatible and user aborts.
# ============================================================================
CheckBashVersion() {
    local is_skip_check="$1"
    local response=""

    if [[ -z "${BASH_VERSION:-}" ]]; then
        WarningMessage "Not running in Bash. Some rcForge features require Bash 4.0+."
        if [[ "$is_skip_check" != "true" ]]; then
             WarningMessage "Use --skip-version-check to bypass this warning."
             read -p "Continue installation anyway? [y/N] " response
             [[ "$response" =~ ^[Yy]$ ]] || ErrorMessage "Installation aborted." # Exits
        fi
        return 0
    fi

    local current_major_version="${BASH_VERSION%%.*}"
    local required_major_version=4

    if [[ "$current_major_version" -lt "$required_major_version" && "$is_skip_check" != "true" ]]; then
        WarningMessage "rcForge requires Bash 4.0 or higher for full functionality."
        WarningMessage "Your current Bash version is: $BASH_VERSION"
        WarningMessage "Use --skip-version-check to bypass this warning."

        if [[ "$(uname)" == "Darwin" ]]; then
            echo -e "\n${YELLOW}For macOS users, install a newer version with Homebrew:${RESET}"
            echo "  brew install bash"
        fi

        read -p "Continue installation anyway? [y/N] " response
        [[ "$response" =~ ^[Yy]$ ]] || ErrorMessage "Installation aborted." # Exits
    elif [[ "$is_skip_check" == "true" ]]; then
         WarningMessage "Skipping Bash version check as requested."
    # else implicitly means version is okay
    fi
    return 0
}

# ============================================================================
# Function: CreateBackup
# Description: Create a gzipped tarball backup of the existing rcForge directory.
# Usage: CreateBackup is_skip_backup is_verbose
# Arguments:
#   is_skip_backup (required) - Boolean (true or false).
#   is_verbose (required) - Boolean (true or false).
# Returns: 0 on success or if skipped, calls ErrorMessage on failure.
# ============================================================================
CreateBackup() {
    local is_skip_backup="$1"
    local is_verbose="$2"

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

    # Use verbose flag for tar if is_verbose is true
    local tar_opts="-czf"
    if [[ "$is_verbose" == "true" ]]; then tar_opts="-czvf"; fi

    if ! tar "$tar_opts" "$BACKUP_FILE" -C "$(dirname "$RCFORGE_DIR")" "$(basename "$RCFORGE_DIR")"; then
        ErrorMessage "Failed to create backup file: $BACKUP_FILE. Check permissions and available space." # Exits
    fi

    SuccessMessage "Backup created: $BACKUP_FILE"
    return 0
}

# ============================================================================
# Function: CreateDirectories
# Description: Create the standard rcForge directory structure.
# Usage: CreateDirectories is_verbose
# Arguments:
#   is_verbose (required) - Boolean (true or false).
# Returns: 0 on success, calls ErrorMessage on failure.
# ============================================================================
CreateDirectories() {
    local is_verbose="$1"
    VerboseMessage "$is_verbose" "Creating directory structure in $RCFORGE_DIR..."

    local -a dirs_to_create=(
        "$RCFORGE_DIR/rc-scripts" "$RCFORGE_DIR/utils" "$RCFORGE_DIR/backups"
        "$RCFORGE_DIR/docs" "$RCFORGE_DIR/system/lib" "$RCFORGE_DIR/system/core"
        "$RCFORGE_DIR/system/include" "$RCFORGE_DIR/system/utils"
    )
    local dir=""

    for dir in "${dirs_to_create[@]}"; do
        if ! mkdir -p "$dir"; then ErrorMessage "Failed to create directory: $dir"; fi # Exits
        if ! chmod 700 "$dir"; then WarningMessage "Could not set permissions (700) on directory: $dir"; fi
    done

    if [[ -d "$RCFORGE_DIR" ]]; then
         if ! chmod 700 "$RCFORGE_DIR"; then WarningMessage "Could not set permissions (700) on main directory: $RCFORGE_DIR"; fi
    fi

    VerboseMessage "$is_verbose" "Directory structure created/verified."
    return 0
}

# ============================================================================
# Function: DownloadFile
# Description: Download a file using curl or wget, set permissions.
# Usage: DownloadFile is_verbose url destination
# Arguments:
#   is_verbose (required) - Boolean (true or false).
#   url (required) - URL to download from.
#   destination (required) - Path to save the file.
# Returns: 0 on success, calls ErrorMessage on failure.
# ============================================================================
DownloadFile() {
    local is_verbose="$1"
    local url="$2"
    local destination="$3"
    local dest_dir=""
    local download_cmd=""

    VerboseMessage "$is_verbose" "Downloading: $(basename "$destination")"

    dest_dir=$(dirname "$destination")
    if ! mkdir -p "$dest_dir"; then ErrorMessage "Failed to create directory for download: $dest_dir"; fi # Exits

    if CommandExists curl; then
        download_cmd="curl --fail --silent --show-error --location --output \"$destination\" \"$url\"" # Use standard flags
    elif CommandExists wget; then
        download_cmd="wget --quiet --output-document=\"$destination\" \"$url\""
    else
        ErrorMessage "Cannot download files: 'curl' or 'wget' command not found. Please install one." # Exits
    fi

    if ! eval "$download_cmd"; then
        rm -f "$destination" &>/dev/null || true
        ErrorMessage "Failed to download file: $url" # Exits
    fi

    if [[ "$destination" == *.sh ]]; then
        if ! chmod 700 "$destination"; then WarningMessage "Could not set permissions (700) on script: $destination"; fi
    else
        if ! chmod 600 "$destination"; then WarningMessage "Could not set permissions (600) on file: $destination"; fi
    fi
}

# ============================================================================
# Function: DownloadStandardFiles
# Description: Download the standard set of rcForge system files.
# Usage: DownloadStandardFiles is_verbose
# Arguments:
#   is_verbose (required) - Boolean (true or false).
# Returns: 0 on success, calls ErrorMessage on failure within DownloadFile.
# ============================================================================
DownloadStandardFiles() {
    local is_verbose="$1"
    local file_url=""
    local dest_path=""
    local dest_suffix=""

    SectionHeader "Downloading rcForge System Files"

    # Using associative array simplifies adding/removing files
    declare -A files_to_download=(
        ["rcforge.sh"]="rcforge.sh"
        ["system/lib/shell-colors.sh"]="system/lib/shell-colors.sh"
        ["system/lib/utility-functions.sh"]="system/lib/utility-functions.sh"
        ["system/core/functions.sh"]="system/core/functions.sh"
        ["system/core/bash-version-check.sh"]="system/core/bash-version-check.sh"
        ["system/core/check-checksums.sh"]="system/core/check-checksums.sh"
        ["system/core/integrity.sh"]="system/core/integrity.sh"
        ["system/utils/httpheaders.sh"]="system/utils/httpheaders.sh"
        ["system/utils/seqcheck.sh"]="system/utils/seqcheck.sh"
        ["system/utils/diag.sh"]="system/utils/diag.sh"
        ["system/utils/export.sh"]="system/utils/export.sh"
        ["rc-scripts/050_global_common_path.sh"]="rc-scripts/050_global_common_path.sh"
        ["rc-scripts/210_global_bash_config.sh"]="rc-scripts/210_global_bash_config.sh"
        ["rc-scripts/210_global_zsh_config.sh"]="rc-scripts/210_global_zsh_config.sh"
        ["rc-scripts/350_global_bash_prompt.sh"]="rc-scripts/350_global_bash_prompt.sh"
        ["rc-scripts/350_global_zsh_prompt.sh"]="rc-scripts/350_global_zsh_prompt.sh"
        ["rc-scripts/400_global_common_aliases.sh"]="rc-scripts/400_global_common_aliases.sh"
        ["docs/README.md"]="docs/README.md"
        ["docs/STYLE_GUIDE.md"]="docs/STYLE_GUIDE.md"
        ["docs/FILE_STRUCTURE_GUIDE.md"]="docs/FILE_STRUCTURE_GUIDE.md"
        ["LICENSE"]="LICENSE"
        [".gitignore"]=".gitignore"
    )

    InfoMessage "Downloading files from $GITHUB_REPO..."
    for dest_suffix in "${!files_to_download[@]}"; do
        file_url="${GITHUB_RAW}/${files_to_download[$dest_suffix]}"
        dest_path="${RCFORGE_DIR}/${dest_suffix}"
        DownloadFile "$is_verbose" "$file_url" "$dest_path" # Pass verbose flag
    done

    SuccessMessage "All required files downloaded successfully!"
    return 0
}

# ============================================================================
# Function: UpdateShellRc
# Description: Add the rcForge sourcing line to user's shell rc files (.bashrc, .zshrc).
# Usage: UpdateShellRc is_skip_integration is_verbose
# Arguments:
#   is_skip_integration (required) - Boolean (true or false).
#   is_verbose (required) - Boolean (true or false).
# Returns: 0, prints warnings if files cannot be updated.
# ============================================================================
UpdateShellRc() {
    local is_skip_integration="$1"
    local is_verbose="$2"
    local source_line=""
    local rc_file=""

    if [[ "$is_skip_integration" == "true" ]]; then
        VerboseMessage "$is_verbose" "Skipping shell configuration update as requested."
        return 0
    fi

    SectionHeader "Updating Shell Configuration Files"

    source_line="# rcForge Shell Configuration Loader (added by installer)"$'\n'
    # Use full path for robustness
    source_line+="[ -f \"${RCFORGE_DIR}/rcforge.sh\" ] && source \"${RCFORGE_DIR}/rcforge.sh\""

    for rc_file in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [[ -f "$rc_file" ]]; then
            # Check more specifically for the source line to avoid false positives
            if ! grep -Fxq "[ -f \"${RCFORGE_DIR}/rcforge.sh\" ] && source \"${RCFORGE_DIR}/rcforge.sh\"" "$rc_file"; then
                InfoMessage "Adding rcForge source line to $rc_file..."
                if printf "\n%s\n" "$source_line" >> "$rc_file"; then
                     SuccessMessage "Successfully updated $rc_file."
                else
                     WarningMessage "Failed to update $rc_file. Please add the source line manually."
                fi
            else
                VerboseMessage "$is_verbose" "$rc_file already contains rcForge source line."
            fi
        else
             VerboseMessage "$is_verbose" "Shell configuration file not found: $rc_file. Skipping update."
        fi
    done
    return 0
}

# ============================================================================
# Function: ShowVersion
# Description: Display version information and exit.
# Usage: ShowVersion
# ============================================================================
ShowVersion() {
  echo "rcForge Installer v$gc_version"
  echo "Installs rcForge Core v$RCFORGE_VERSION_CONST"
  echo "Copyright (c) $(date +%Y) rcForge Team"
  echo "Released under the MIT License"
  exit 0
}

# ============================================================================
# Function: ShowHelp
# Description: Display help information and exit.
# Usage: ShowHelp
# ============================================================================
ShowHelp() {
  echo "rcForge Installer - v$gc_version"
  echo ""
  echo "Description:"
  echo "  Installs or upgrades the rcForge shell configuration system to v$RCFORGE_VERSION_CONST"
  echo ""
  echo "Usage:"
  echo "  $0 [options]"
  echo ""
  echo "Options:"
  echo "  --reinstall           Force reinstallation (removes existing configuration!)"
  echo "  --force, -f           Skip all confirmations (use with caution)"
  echo "  --verbose, -v         Enable verbose output for debugging"
  echo "  --no-backup           Skip backup of existing installation (not recommended)"
  echo "  --no-shell-update     Do not attempt to modify ~/.bashrc or ~/.zshrc"
  echo "  --skip-version-check  Skip the check for minimum Bash version (4.0+)"
  echo "  --help, -h            Show this help message and exit"
  echo "  --version             Show installer version information and exit"
  echo ""
  echo "Examples:"
  echo "  $0                   # Standard installation or upgrade"
  echo "  $0 --reinstall -v    # Verbose reinstallation"
  echo "  $0 --no-shell-update # Install/upgrade without modifying RC files"
  echo ""
  echo "Note: This script should be run directly using bash:"
  echo "  bash $0 [options]"
  exit 0
}

# ============================================================================
# Function: CleanInstall
# Description: Perform a fresh installation or reinstallation.
# Usage: CleanInstall install_mode is_verbose is_skip_integration
# Returns: 0 on success, 1 on failure.
# ============================================================================
CleanInstall() {
    local install_mode="$1"
    local is_verbose="$2"
    local is_skip_integration="$3" # Pass shell integration flag

    if [[ "$install_mode" == "reinstall" ]]; then
         if IsInstalled; then
             InfoMessage "Removing existing installation for reinstall..."
             if ! rm -rf "$RCFORGE_DIR"; then ErrorMessage "Failed to remove existing directory: $RCFORGE_DIR"; fi
             SuccessMessage "Existing installation removed."
         fi
    fi

    CreateDirectories "$is_verbose" || return 1
    DownloadStandardFiles "$is_verbose" || return 1
    UpdateShellRc "$is_skip_integration" "$is_verbose" || return 1 # Call here for clean install

    return 0
}

# ============================================================================
# Function: UpgradeInstall
# Description: Perform an upgrade, preserving user files where possible.
# Usage: UpgradeInstall is_verbose is_skip_integration
# Returns: 0 on success, 1 on failure.
# ============================================================================
UpgradeInstall() {
    local is_verbose="$1"
    local is_skip_integration="$2" # Pass shell integration flag
    local file_url=""
    local dest_path=""
    local dest_suffix=""

    # Backup happens in main flow before calling this
    CreateDirectories "$is_verbose" || return 1 # Ensure structure exists

    SectionHeader "Upgrading rcForge System Files"

    declare -A system_files_to_overwrite=(
        ["rcforge.sh"]="rcforge.sh"
        ["system/lib/shell-colors.sh"]="system/lib/shell-colors.sh"
        ["system/lib/utility-functions.sh"]="system/lib/utility-functions.sh"
        ["system/core/functions.sh"]="system/core/functions.sh"
        ["system/core/bash-version-check.sh"]="system/core/bash-version-check.sh"
        ["system/core/check-checksums.sh"]="system/core/check-checksums.sh"
        ["system/core/integrity.sh"]="system/core/integrity.sh"
        ["system/utils/httpheaders.sh"]="system/utils/httpheaders.sh"
        ["system/utils/seqcheck.sh"]="system/utils/seqcheck.sh"
        ["system/utils/diag.sh"]="system/utils/diag.sh"
        ["system/utils/export.sh"]="system/utils/export.sh"
        ["docs/README.md"]="docs/README.md"
        ["docs/STYLE_GUIDE.md"]="docs/STYLE_GUIDE.md"
        ["docs/FILE_STRUCTURE_GUIDE.md"]="docs/FILE_STRUCTURE_GUIDE.md"
        ["LICENSE"]="LICENSE"
        [".gitignore"]=".gitignore"
    )

    InfoMessage "Downloading latest system files (overwrite)..."
    for dest_suffix in "${!system_files_to_overwrite[@]}"; do
        file_url="${GITHUB_RAW}/${system_files_to_overwrite[$dest_suffix]}"
        dest_path="${RCFORGE_DIR}/${dest_suffix}"
        DownloadFile "$is_verbose" "$file_url" "$dest_path" || return 1
    done

    InfoMessage "Checking for missing example configuration scripts..."
    declare -A example_rc_scripts=(
        ["rc-scripts/050_global_common_path.sh"]="rc-scripts/050_global_common_path.sh"
        ["rc-scripts/210_global_bash_config.sh"]="rc-scripts/210_global_bash_config.sh"
        ["rc-scripts/210_global_zsh_config.sh"]="rc-scripts/210_global_zsh_config.sh"
        ["rc-scripts/350_global_bash_prompt.sh"]="rc-scripts/350_global_bash_prompt.sh"
        ["rc-scripts/350_global_zsh_prompt.sh"]="rc-scripts/350_global_zsh_prompt.sh"
        ["rc-scripts/400_global_common_aliases.sh"]="rc-scripts/400_global_common_aliases.sh"
    )

    for dest_suffix in "${!example_rc_scripts[@]}"; do
        dest_path="${RCFORGE_DIR}/${dest_suffix}"
        if [[ ! -f "$dest_path" ]]; then
            VerboseMessage "$is_verbose" "Adding missing example script: $(basename "$dest_path")"
            file_url="${GITHUB_RAW}/${example_rc_scripts[$dest_suffix]}"
            DownloadFile "$is_verbose" "$file_url" "$dest_path" || return 1
        else
            VerboseMessage "$is_verbose" "Existing script found: $(basename "$dest_path") (preserved)"
        fi
    done

    UpdateShellRc "$is_skip_integration" "$is_verbose" || return 1 # Call here for upgrade

    SuccessMessage "System files upgrade completed successfully!"
    return 0
}

# ============================================================================
# Function: VerifyInstallation
# Description: Perform basic checks to verify installation seems okay.
# Usage: VerifyInstallation is_verbose
# Arguments:
#   is_verbose (required) - Boolean (true or false).
# Returns: 0 if basic checks pass, 1 otherwise.
# ============================================================================
VerifyInstallation() {
    local is_verbose="$1"
    local check_status=0
    local file=""
    local main_perms=""

    SectionHeader "Verifying Installation"

    local critical_files=(
        "$RCFORGE_DIR/rcforge.sh"
        "$RCFORGE_DIR/system/lib/shell-colors.sh"
        "$RCFORGE_DIR/system/core/functions.sh"
    )

    for file in "${critical_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            WarningMessage "Verification failed: Missing critical file: $file"
            check_status=1
        else
            VerboseMessage "$is_verbose" "Verified file exists: $file"
        fi
    done

    main_perms=$(stat -c %a "$RCFORGE_DIR" 2>/dev/null || stat -f "%Lp" "$RCFORGE_DIR" 2>/dev/null || echo "ERR")
    if [[ "$main_perms" != "700" ]]; then
        WarningMessage "Verification warning: Incorrect permissions on $RCFORGE_DIR (Expected: 700, Found: $main_perms)"
    else
        VerboseMessage "$is_verbose" "Verified permissions on main directory ($RCFORGE_DIR)."
    fi

    if [[ $check_status -eq 0 ]]; then
        SuccessMessage "Basic installation verification passed!"
    else
        WarningMessage "Installation verification detected issues." # Changed from ErrorMessage
    fi
    return $check_status
}

# ============================================================================
# Function: ShowInstructions
# Description: Display final post-installation instructions and recommendations.
# Usage: ShowInstructions effective_install_mode
# Arguments:
#   effective_install_mode (required) - 'install', 'upgrade', or 'reinstall'.
# Returns: None.
# ============================================================================
ShowInstructions() {
    local effective_install_mode="$1"

    SectionHeader "Installation Complete!"

    SuccessMessage "rcForge v$gc_version has been successfully ${effective_install_mode}ed to $RCFORGE_DIR!"
    echo ""
    InfoMessage "To activate rcForge in your ${BOLD}current${RESET} shell session:"
    echo -e "  ${CYAN}source \"$RCFORGE_DIR/rcforge.sh\"${RESET}"
    echo ""
    InfoMessage "For ${BOLD}new${RESET} shell sessions, rcForge should load automatically if shell integration was enabled and successful."
    echo ""
    InfoMessage "Try these commands to get started:"
    echo -e "  ${CYAN}rc help${RESET}                 # Show available rcForge commands"
    echo -e "  ${CYAN}rc httpheaders example.com${RESET} # Test an included utility"
    echo ""

    WarningMessage "${YELLOW}Recommendation:${RESET} Store your configurations in Git!"
    echo -e "  ${CYAN}cd \"$RCFORGE_DIR\" && git init && git add . && git commit -m \"Initial rcForge setup\"${RESET}"
    echo -e "  ${CYAN}# Then add a remote (e.g., private GitHub repo) and push.${RESET}"
    echo ""

    InfoMessage "For support and documentation, visit: ${BLUE}$GITHUB_REPO${RESET}"
    echo ""
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
    local install_mode="auto"
    local is_force=false
    local is_verbose=false
    local skip_backup=false
    local skip_shell_integration=false
    local skip_version_check=false
    # --- End Option Variables ---

    # --- Argument Parsing ---
    # Moved parsing logic directly into main for Bash 4.0 compatibility
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

    SectionHeader "rcForge Installer v$gc_version"

    CheckBashVersion "$skip_version_check" || exit 1 # Pass boolean flag

    # Determine effective install mode
    local effective_install_mode="$install_mode"
    if [[ "$effective_install_mode" == "auto" ]]; then
        if IsInstalled; then
             effective_install_mode="upgrade"
             InfoMessage "Existing installation detected. Performing upgrade..."
        else
             effective_install_mode="install"
             InfoMessage "Performing fresh installation of rcForge..."
        fi
    elif [[ "$effective_install_mode" == "reinstall" ]]; then
         InfoMessage "Performing reinstallation of rcForge..."
         if ! IsInstalled; then WarningMessage "No existing installation found to reinstall over."; fi
    fi

    # Confirmation Prompt
    if [[ "$is_force" != "true" ]]; then
        local confirmation_response=""
        printf "%b" "${YELLOW}Continue with ${effective_install_mode}? [Y/n]:${RESET} "
        read -r confirmation_response
        if [[ -n "$confirmation_response" && ! "$confirmation_response" =~ ^[Yy]$ ]]; then
            InfoMessage "Installation aborted by user."
            exit 0
        fi
    fi

    # Backup before install/reinstall/upgrade (unless skipped)
    # CreateBackup handles skipping internally based on flag and if install exists
    CreateBackup "$skip_backup" "$is_verbose" || exit 1

    # Perform installation/upgrade
    if [[ "$effective_install_mode" == "upgrade" ]]; then
        # Pass necessary flags to UpgradeInstall
        UpgradeInstall "$is_verbose" "$skip_shell_integration" || exit 1
    else
        # Pass necessary flags to CleanInstall
        CleanInstall "$effective_install_mode" "$is_verbose" "$skip_shell_integration" || exit 1
    fi

    # Verify installation
    VerifyInstallation "$is_verbose" || exit 1 # Exit if basic verification fails

    # Display final instructions
    ShowInstructions "$effective_install_mode"

    exit 0 # Explicit success exit
}

# Run the installer's main function
main "$@"

# EOF