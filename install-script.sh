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

# Global constants
readonly RCFORGE_VERSION_CONST="0.3.0" # Use different name to avoid conflict if sourced
readonly gc_version="$RCFORGE_VERSION_CONST" # For internal use
readonly RCFORGE_DIR="$HOME/.config/rcforge"
readonly BACKUP_DIR="$RCFORGE_DIR/backups"
readonly TIMESTAMP=$(date +%Y%m%d%H%M%S)
readonly BACKUP_FILE="$BACKUP_DIR/rcforge_backup_$TIMESTAMP.tar.gz"
readonly GITHUB_REPO="https://github.com/rcforge/rcforge"
readonly GITHUB_RAW="https://raw.githubusercontent.com/rcforge/rcforge/main"

# Colors and formatting (self-contained for installer)
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
  # Check if BOLD and CYAN are set (i.e., TTY is active)
  if [[ -n "$BOLD" ]]; then
      echo -e "\n${BOLD}${CYAN}$1${RESET}\n${CYAN}$(printf '=%.0s' {1..50})${RESET}\n"
  else
      echo -e "\n## $1 ##\n" # Fallback for non-tty
  fi
}

# ============================================================================
# Function: VerboseMessage
# Description: Print message only if verbose mode is enabled.
# Usage: VerboseMessage options_array "Message text"
# ============================================================================
VerboseMessage() {
    local -n _options_ref="$1" # Pass options array by nameref (Bash 4.3+)
    local message="$2"
    if [[ "${_options_ref[is_verbose]}" == "true" ]]; then
        # Use different color/prefix for verbose messages
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
# Usage: CheckBashVersion options_array
# Returns: 0 if compatible or skipped, exits 1 if incompatible and user aborts.
# ============================================================================
CheckBashVersion() {
    local -n _options_ref="$1" # Nameref (Bash 4.3+)
    local response="" # For user prompt

    if [[ -z "${BASH_VERSION:-}" ]]; then
        WarningMessage "Not running in Bash. Some rcForge features require Bash 4.0+."
        if [[ "${_options_ref[skip_version_check]}" != "true" ]]; then
             WarningMessage "Use --skip-version-check to bypass this warning."
             read -p "Continue installation anyway? [y/N] " response
             [[ "$response" =~ ^[Yy]$ ]] || ErrorMessage "Installation aborted." # Exits
        fi
        return 0 # Allow continuation if skipped or user agreed
    fi

    local current_major_version="${BASH_VERSION%%.*}"
    local required_major_version=4 # Hardcoded based on requirement

    if [[ "$current_major_version" -lt "$required_major_version" && "${_options_ref[skip_version_check]}" != "true" ]]; then
        WarningMessage "rcForge requires Bash 4.0 or higher for full functionality."
        WarningMessage "Your current Bash version is: $BASH_VERSION"
        WarningMessage "Use --skip-version-check to bypass this warning."

        if [[ "$(uname)" == "Darwin" ]]; then
            echo -e "\n${YELLOW}For macOS users, install a newer version with Homebrew:${RESET}"
            echo "  brew install bash"
            # Instructions for adding to /etc/shells and chsh are complex and may require sudo,
            # better handled in documentation than enforced by installer?
            # echo "  sudo bash -c 'echo \$(brew --prefix)/bin/bash >> /etc/shells'"
            # echo "  chsh -s \$(brew --prefix)/bin/bash"
        fi

        read -p "Continue installation anyway? [y/N] " response
        [[ "$response" =~ ^[Yy]$ ]] || ErrorMessage "Installation aborted." # Exits
    elif [[ "${_options_ref[skip_version_check]}" == "true" ]]; then
         WarningMessage "Skipping Bash version check as requested."
    else
         VerboseMessage _options_ref "Bash version $BASH_VERSION meets requirement (4.0+)."
    fi
    return 0 # Return success if check passed, was skipped, or user overrode warning
}

# ============================================================================
# Function: CreateBackup
# Description: Create a gzipped tarball backup of the existing rcForge directory.
# Usage: CreateBackup options_array
# Returns: 0 on success or if skipped, calls ErrorMessage on failure.
# ============================================================================
CreateBackup() {
    local -n _options_ref="$1" # Nameref (Bash 4.3+)

    if [[ "${_options_ref[skip_backup]}" == "true" ]]; then
        VerboseMessage _options_ref "Skipping backup creation as requested."
        return 0
    fi

    # Check if directory exists before trying backup
    if ! IsInstalled; then
        VerboseMessage _options_ref "No existing installation found at $RCFORGE_DIR, skipping backup."
        return 0
    fi

    InfoMessage "Creating backup of existing installation..."
    if ! mkdir -p "$BACKUP_DIR"; then
         WarningMessage "Could not create backup directory: $BACKUP_DIR. Skipping backup."
         return 0 # Don't error out, just skip backup
    fi

    if ! tar -czf "$BACKUP_FILE" -C "$(dirname "$RCFORGE_DIR")" "$(basename "$RCFORGE_DIR")"; then
        # Provide more context on error
        ErrorMessage "Failed to create backup file: $BACKUP_FILE. Check permissions and available space." # Exits
    fi

    SuccessMessage "Backup created: $BACKUP_FILE"
    return 0
}

# ============================================================================
# Function: CreateDirectories
# Description: Create the standard rcForge directory structure.
# Usage: CreateDirectories options_array
# Returns: 0 on success, calls ErrorMessage on failure.
# ============================================================================
CreateDirectories() {
    local -n _options_ref="$1" # Nameref (Bash 4.3+)
    VerboseMessage _options_ref "Creating directory structure in $RCFORGE_DIR..."

    # List of directories to create
    local -a dirs_to_create=(
        "$RCFORGE_DIR/rc-scripts"
        "$RCFORGE_DIR/utils"
        "$RCFORGE_DIR/backups"
        "$RCFORGE_DIR/docs"
        "$RCFORGE_DIR/system/lib"
        "$RCFORGE_DIR/system/core"
        "$RCFORGE_DIR/system/include"
        "$RCFORGE_DIR/system/utils"
    )

    local dir="" # Loop variable
    for dir in "${dirs_to_create[@]}"; do
        if ! mkdir -p "$dir"; then
             ErrorMessage "Failed to create directory: $dir" # Exits
        fi
        if ! chmod 700 "$dir"; then # Ensure correct permissions
             WarningMessage "Could not set permissions (700) on directory: $dir"
        fi
    done

    # Ensure top-level dir has correct permissions too
    if [[ -d "$RCFORGE_DIR" ]]; then
         if ! chmod 700 "$RCFORGE_DIR"; then
             WarningMessage "Could not set permissions (700) on main directory: $RCFORGE_DIR"
         fi
    fi


    VerboseMessage _options_ref "Directory structure created/verified."
    return 0
}

# ============================================================================
# Function: DownloadFile
# Description: Download a file using curl or wget, set permissions.
# Usage: DownloadFile options_array url destination
# Returns: 0 on success, calls ErrorMessage on failure.
# ============================================================================
DownloadFile() {
    local -n _options_ref="$1" # Nameref (Bash 4.3+)
    local url="$2"
    local destination="$3"

    VerboseMessage _options_ref "Downloading: $(basename "$destination")"
    # VerboseMessage _options_ref "  From: $url"
    # VerboseMessage _options_ref "  To:   $destination"


    # Ensure destination directory exists
    local dest_dir
    dest_dir=$(dirname "$destination")
    if ! mkdir -p "$dest_dir"; then
        ErrorMessage "Failed to create directory for download: $dest_dir" # Exits
    fi

    # Attempt download with curl first, then wget
    local download_cmd=""
    if CommandExists curl; then
        # -f: fail silently on server errors, -L: follow redirects, -s: silent, -S: show error
        download_cmd="curl -fsSL -o \"$destination\" \"$url\""
    elif CommandExists wget; then
        # -q: quiet, -O: output file
        download_cmd="wget -q -O \"$destination\" \"$url\""
    else
        ErrorMessage "Cannot download files: 'curl' or 'wget' command not found. Please install one." # Exits
    fi

    # Execute download command
    if ! eval "$download_cmd"; then
        # Attempt to delete potentially incomplete file
        rm -f "$destination" &>/dev/null || true
        ErrorMessage "Failed to download file: $url" # Exits
    fi

    # Set permissions based on file type (simple check for .sh)
    if [[ "$destination" == *.sh ]]; then
        if ! chmod 700 "$destination"; then WarningMessage "Could not set permissions (700) on script: $destination"; fi
    else
        if ! chmod 600 "$destination"; then WarningMessage "Could not set permissions (600) on file: $destination"; fi
    fi
}

# ============================================================================
# Function: DownloadStandardFiles
# Description: Download the standard set of rcForge system files.
# Usage: DownloadStandardFiles options_array
# Returns: 0 on success, calls ErrorMessage on failure within DownloadFile.
# ============================================================================
DownloadStandardFiles() {
    local -n _options_ref="$1" # Nameref (Bash 4.3+)
    local file_url="" # Temp var
    local dest_path="" # Temp var

    SectionHeader "Downloading rcForge System Files"

    # Define files to download relative to GITHUB_RAW and RCFORGE_DIR
    # Using an associative array for better structure: path -> url_suffix
    declare -A files_to_download=(
        ["rcforge.sh"]="rcforge.sh"
        ["system/lib/shell-colors.sh"]="system/lib/shell-colors.sh"
        ["system/lib/utility-functions.sh"]="system/lib/utility-functions.sh"
        ["system/core/functions.sh"]="system/core/functions.sh" # Added core functions
        ["system/core/bash-version-check.sh"]="system/core/bash-version-check.sh"
        ["system/core/check-checksums.sh"]="system/core/check-checksums.sh" # Added checksum check
        # Utilities
        ["system/utils/httpheaders.sh"]="system/utils/httpheaders.sh"
        ["system/utils/seqcheck.sh"]="system/utils/seqcheck.sh" # Added seq check
        ["system/utils/diag.sh"]="system/utils/diag.sh"       # Added diag
        ["system/utils/export.sh"]="system/utils/export.sh"     # Added export
        # Base RC scripts (examples)
        ["rc-scripts/050_global_common_path.sh"]="rc-scripts/050_global_common_path.sh"
        ["rc-scripts/210_global_bash_config.sh"]="rc-scripts/210_global_bash_config.sh"
        ["rc-scripts/210_global_zsh_config.sh"]="rc-scripts/210_global_zsh_config.sh"
        ["rc-scripts/350_global_bash_prompt.sh"]="rc-scripts/350_global_bash_prompt.sh"
        ["rc-scripts/350_global_zsh_prompt.sh"]="rc-scripts/350_global_zsh_prompt.sh"
        ["rc-scripts/400_global_common_aliases.sh"]="rc-scripts/400_global_common_aliases.sh"
        # Documentation
        ["docs/README.md"]="docs/README.md"
        ["docs/STYLE_GUIDE.md"]="docs/STYLE_GUIDE.md" # Adding reference docs
        ["docs/FILE_STRUCTURE_GUIDE.md"]="docs/FILE_STRUCTURE_GUIDE.md"
        # Root files
        ["LICENSE"]="LICENSE"
        [".gitignore"]=".gitignore" # Good practice to include
    )

    InfoMessage "Downloading files from $GITHUB_REPO..."
    for dest_suffix in "${!files_to_download[@]}"; do
        file_url="${GITHUB_RAW}/${files_to_download[$dest_suffix]}"
        dest_path="${RCFORGE_DIR}/${dest_suffix}"
        # Call PascalCase function
        DownloadFile _options_ref "$file_url" "$dest_path" # Will exit via ErrorMessage on failure
    done

    SuccessMessage "All required files downloaded successfully!"
    return 0
}

# ============================================================================
# Function: UpdateShellRc
# Description: Add the rcForge sourcing line to user's shell rc files (.bashrc, .zshrc).
# Usage: UpdateShellRc options_array
# Returns: 0, prints warnings if files cannot be updated.
# ============================================================================
UpdateShellRc() {
    local -n _options_ref="$1" # Nameref (Bash 4.3+)

    if [[ "${_options_ref[skip_shell_integration]}" == "true" ]]; then
        VerboseMessage _options_ref "Skipping shell configuration update as requested."
        return 0
    fi

    SectionHeader "Updating Shell Configuration Files"

    local source_line="# rcForge Shell Configuration Loader (added by installer)"$'\n'
    source_line+="[ -f \"\$HOME/.config/rcforge/rcforge.sh\" ] && source \"\$HOME/.config/rcforge/rcforge.sh\""
    local rc_file="" # Loop variable

    for rc_file in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [[ -f "$rc_file" ]]; then # Check if the rc file exists
            # Check if rcforge source line already exists
            if ! grep -q 'source "\$HOME/.config/rcforge/rcforge.sh"' "$rc_file"; then
                InfoMessage "Adding rcForge source line to $rc_file..."
                # Append the source line with surrounding newlines for separation
                if printf "\n%s\n" "$source_line" >> "$rc_file"; then
                     SuccessMessage "Successfully updated $rc_file."
                else
                     WarningMessage "Failed to update $rc_file. Please add the source line manually."
                fi
            else
                VerboseMessage _options_ref "$rc_file already contains rcForge source line."
            fi
        else
             VerboseMessage _options_ref "Shell configuration file not found: $rc_file. Skipping update."
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
  echo "Installs rcForge Core v$RCFORGE_VERSION_CONST" # Distinguish installer vs core version maybe
  echo "Copyright (c) $(date +%Y) rcForge Team" # Dynamic year
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
  echo "  $0 [options]" # Use $0 for script name
  echo ""
  echo "Options:"
  echo "  --reinstall           Force reinstallation (removes user scripts if not backed up!)" # Clarify risk
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
# Function: ProcessArgs
# Description: Process command-line arguments.
# Usage: declare -A options; ProcessArgs options "$@"
# Returns: Populates associative array. Returns 0 on success, 1 on error or if help/version shown.
# ============================================================================
ProcessArgs() {
    local -n _options_ref="$1" # Nameref (Bash 4.3+)
    shift # Remove array name

    # Set defaults
    _options_ref["install_mode"]="auto" # auto, reinstall
    _options_ref["is_force"]=false
    _options_ref["is_verbose"]=false
    _options_ref["skip_backup"]=false
    _options_ref["skip_shell_integration"]=false
    _options_ref["skip_version_check"]=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --reinstall) _options_ref["install_mode"]="reinstall" ;;
            --force|-f) _options_ref["is_force"]=true ;;
            --verbose|-v) _options_ref["is_verbose"]=true ;;
            --no-backup) _options_ref["skip_backup"]=true ;;
            --no-shell-update) _options_ref["skip_shell_integration"]=true ;;
            --skip-version-check) _options_ref["skip_version_check"]=true ;;
            --help|-h) ShowHelp; return 1 ;; # Call PascalCase; Return 1 indicates exit needed
            --version) ShowVersion; return 1 ;; # Call PascalCase; Return 1 indicates exit needed
            *)
                # Use WarningMessage + ShowHelp for unknown option
                WarningMessage "Unknown option: $1"
                ShowHelp # Call PascalCase
                return 1 ;;
        esac
        shift
    done
    return 0 # Success
}

# ============================================================================
# Function: CleanInstall
# Description: Perform a fresh installation (after backup if applicable).
# Usage: CleanInstall options_array
# Returns: 0 on success, 1 on failure.
# ============================================================================
CleanInstall() {
    local -n _options_ref="$1" # Nameref (Bash 4.3+)

    # If reinstalling, remove existing directory after backup
    if [[ "${_options_ref[install_mode]}" == "reinstall" ]]; then
         if IsInstalled; then # Call PascalCase
             InfoMessage "Removing existing installation for reinstall..."
             if ! rm -rf "$RCFORGE_DIR"; then
                  ErrorMessage "Failed to remove existing directory: $RCFORGE_DIR" # Exits
             fi
             SuccessMessage "Existing installation removed."
         fi
    fi

    # Create directory structure
    CreateDirectories _options_ref || return 1 # Call PascalCase

    # Download standard files
    DownloadStandardFiles _options_ref || return 1 # Call PascalCase

    # Update shell RC files
    UpdateShellRc _options_ref || return 1 # Call PascalCase

    return 0
}

# ============================================================================
# Function: UpgradeInstall
# Description: Perform an upgrade, preserving user files where possible.
# Usage: UpgradeInstall options_array
# Returns: 0 on success, 1 on failure.
# ============================================================================
UpgradeInstall() {
    local -n _options_ref="$1" # Nameref (Bash 4.3+)
    local file_url="" # Temp vars
    local dest_path=""

    # Create backup first
    CreateBackup _options_ref || return 1 # Call PascalCase

    # Ensure directory structure exists
    CreateDirectories _options_ref || return 1 # Call PascalCase

    # Download new system files OVERWRITING existing ones
    SectionHeader "Upgrading rcForge System Files"

    # Reusing files_to_download definition logic from DownloadStandardFiles
    # We only need to overwrite system files and add missing example files
    declare -A system_files_to_overwrite=(
        ["rcforge.sh"]="rcforge.sh"
        ["system/lib/shell-colors.sh"]="system/lib/shell-colors.sh"
        ["system/lib/utility-functions.sh"]="system/lib/utility-functions.sh"
        ["system/core/functions.sh"]="system/core/functions.sh"
        ["system/core/bash-version-check.sh"]="system/core/bash-version-check.sh"
        ["system/core/check-checksums.sh"]="system/core/check-checksums.sh"
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
    local dest_suffix="" # Loop variable
    for dest_suffix in "${!system_files_to_overwrite[@]}"; do
        file_url="${GITHUB_RAW}/${system_files_to_overwrite[$dest_suffix]}"
        dest_path="${RCFORGE_DIR}/${dest_suffix}"
        DownloadFile _options_ref "$file_url" "$dest_path" || return 1 # Call PascalCase
    done

    # Add example RC scripts ONLY if they don't exist (preserve user changes)
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
            VerboseMessage _options_ref "Adding missing example script: $(basename "$dest_path")"
            file_url="${GITHUB_RAW}/${example_rc_scripts[$dest_suffix]}"
            DownloadFile _options_ref "$file_url" "$dest_path" || return 1 # Call PascalCase
        else
            VerboseMessage _options_ref "Existing script found: $(basename "$dest_path") (preserved)"
        fi
    done


    # Update shell RC files if needed
    UpdateShellRc _options_ref || return 1 # Call PascalCase

    SuccessMessage "Upgrade completed successfully!"
    return 0
}

# ============================================================================
# Function: VerifyInstallation
# Description: Perform basic checks to verify installation seems okay.
# Usage: VerifyInstallation options_array
# Returns: 0 if basic checks pass, 1 otherwise.
# ============================================================================
VerifyInstallation() {
    local -n _options_ref="$1" # Nameref (Bash 4.3+)
    local check_status=0 # Track status

    SectionHeader "Verifying Installation"

    # Check for critical files existence
    local critical_files=(
        "$RCFORGE_DIR/rcforge.sh"
        "$RCFORGE_DIR/system/lib/shell-colors.sh"
        "$RCFORGE_DIR/system/core/functions.sh"
    )
    local file="" # Loop variable
    for file in "${critical_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            WarningMessage "Verification failed: Missing critical file: $file"
            check_status=1
        else
            VerboseMessage _options_ref "Verified file exists: $file"
        fi
    done

    # Check permissions on main directory
    local main_perms=""
    main_perms=$(stat -c %a "$RCFORGE_DIR" 2>/dev/null || stat -f "%Lp" "$RCFORGE_DIR" 2>/dev/null || echo "ERR")
    if [[ "$main_perms" != "700" ]]; then
        WarningMessage "Verification warning: Incorrect permissions on $RCFORGE_DIR (Expected: 700, Found: $main_perms)"
        # Don't fail verification just for permissions warning, but notify user.
        # check_status=1
    else
        VerboseMessage _options_ref "Verified permissions on main directory ($RCFORGE_DIR)."
    fi

    # Final verdict
    if [[ $check_status -eq 0 ]]; then
        SuccessMessage "Basic installation verification passed!"
    else
        ErrorMessage "Installation verification detected critical issues."
    fi
    return $check_status
}

# ============================================================================
# Function: ShowInstructions
# Description: Display final post-installation instructions and recommendations.
# Usage: ShowInstructions
# Returns: None.
# ============================================================================
ShowInstructions() {
    SectionHeader "Installation Complete!"

    SuccessMessage "rcForge v$gc_version has been successfully installed to $RCFORGE_DIR!"
    echo ""
    InfoMessage "To start using rcForge in your ${BOLD}current${RESET} shell session:"
    echo -e "  ${CYAN}source \"$RCFORGE_DIR/rcforge.sh\"${RESET}"
    echo ""
    InfoMessage "For ${BOLD}new${RESET} shell sessions, rcForge should load automatically if shell integration was successful."
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
    # Associative array to hold parsed options
    declare -A options

    # Process arguments. Exit if parsing fails or help/version shown.
    # Call PascalCase function
    if ! ProcessArgs options "$@"; then
        exit 1 # Exit based on ProcessArgs return code
    fi

    SectionHeader "rcForge Installer v$gc_version" # Call PascalCase

    # Pass options array by name to functions that need it (requires Bash 4.3+)
    CheckBashVersion options || exit 1 # Call PascalCase

    # Determine effective install mode (auto -> install or upgrade)
    local effective_install_mode="${options[install_mode]}"
    if [[ "$effective_install_mode" == "auto" ]]; then
        if IsInstalled; then # Call PascalCase
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
    # Update the mode in the options array if it was auto-detected
    options["install_mode"]="$effective_install_mode"

    # Confirm installation unless --force is used
    if [[ "${options[is_force]}" != "true" ]]; then
        local confirmation_response=""
        printf "%b" "${YELLOW}Continue with ${options[install_mode]}? [Y/n]:${RESET} "
        read -r confirmation_response
        if [[ -n "$confirmation_response" && ! "$confirmation_response" =~ ^[Yy]$ ]]; then
            InfoMessage "Installation aborted by user."
            exit 0 # Not an error state
        fi
    fi

    # Perform installation based on mode
    if [[ "${options[install_mode]}" == "upgrade" ]]; then
        UpgradeInstall options || exit 1 # Call PascalCase
    else
        # For fresh install or reinstall
        CreateBackup options || exit 1 # Call PascalCase (will skip if not needed)
        CleanInstall options || exit 1 # Call PascalCase
    fi

    # Verify installation
    VerifyInstallation options || exit 1 # Call PascalCase

    # Display final instructions
    ShowInstructions # Call PascalCase

    exit 0 # Explicit success exit
}

# Run the installer's main function
main "$@"

# EOF