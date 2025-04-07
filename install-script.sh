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
readonly BACKUP_DIR="$RCFORGE_DIR/backups" # Still useful for backup logic
readonly TIMESTAMP=$(date +%Y%m%d%H%M%S)
readonly BACKUP_FILE="$BACKUP_DIR/rcforge_backup_$TIMESTAMP.tar.gz"
readonly GITHUB_REPO="https://github.com/mhasse1/rcforge" # Using user's repo
readonly GITHUB_RAW="https://raw.githubusercontent.com/mhasse1/rcforge/main" # Using user's repo raw URL

# Manifest File Configuration
readonly MANIFEST_FILENAME="file-manifest.txt" # Name of the manifest file in the repo root
readonly MANIFEST_URL="${GITHUB_RAW}/${MANIFEST_FILENAME}"
readonly MANIFEST_TEMP_FILE="/tmp/rcforge_manifest_${TIMESTAMP}_$$" # Temp location for download

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
# ============================================================================
VerboseMessage() {
    local is_verbose="$1"
    local message="$2"
    if [[ "$is_verbose" == "true" ]]; then
        echo -e "${MAGENTA}VERBOSE:${RESET} $message"
    fi
}

# ============================================================================
# Function: IsInstalled
# Description: Check if rcForge appears to be installed.
# Usage: IsInstalled
# ============================================================================
IsInstalled() {
  [[ -d "$RCFORGE_DIR" && -f "$RCFORGE_DIR/rcforge.sh" ]]
}

# ============================================================================
# Function: CommandExists
# Description: Check if a command exists in the PATH.
# Usage: CommandExists command_name
# ============================================================================
CommandExists() {
  command -v "$1" >/dev/null 2>&1
}

# ============================================================================
# Function: CheckBashVersion
# Description: Check if running Bash version meets minimum requirements (4.0+).
# Usage: CheckBashVersion is_skip_check
# ============================================================================
CheckBashVersion() {
    local is_skip_check="$1"
    local response=""
    local current_major_version
    local required_major_version=4

    if [[ -z "${BASH_VERSION:-}" ]]; then
        WarningMessage "Not running in Bash. Some rcForge features require Bash 4.0+."
        if [[ "$is_skip_check" != "true" ]]; then
             WarningMessage "Use --skip-version-check to bypass this warning."
             read -p "Continue installation anyway? [y/N] " response
             if ! [[ "$response" =~ ^[Yy]$ ]]; then
                 ErrorMessage "Installation aborted." # Exits
             fi
        fi
        return 0
    fi

    current_major_version="${BASH_VERSION%%.*}"

    if [[ "$current_major_version" -lt "$required_major_version" && "$is_skip_check" != "true" ]]; then
        WarningMessage "rcForge requires Bash 4.0 or higher for full functionality."
        WarningMessage "Your current Bash version is: $BASH_VERSION"
        WarningMessage "Use --skip-version-check to bypass this warning."

        if [[ "$(uname)" == "Darwin" ]]; then
            echo -e "\n${YELLOW}For macOS users, install a newer version with Homebrew:${RESET}"
            echo "  brew install bash"
        fi

        read -p "Continue installation anyway? [y/N] " response
        if ! [[ "$response" =~ ^[Yy]$ ]]; then
            ErrorMessage "Installation aborted." # Exits
        fi
    elif [[ "$is_skip_check" == "true" ]]; then
         WarningMessage "Skipping Bash version check as requested."
    fi
    return 0
}

# ============================================================================
# Function: CreateBackup
# Description: Create a gzipped tarball backup of the existing rcForge directory.
# Usage: CreateBackup is_skip_backup is_verbose
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

    if [[ "$is_verbose" == "true" ]]; then
        tar_opts="-czvf"
    fi

    if ! tar "$tar_opts" "$BACKUP_FILE" -C "$(dirname "$RCFORGE_DIR")" "$(basename "$RCFORGE_DIR")"; then
        ErrorMessage "Backup failed: $BACKUP_FILE. Check permissions and available space." # Exits
    fi

    SuccessMessage "Backup created: $BACKUP_FILE"
    return 0
}

# ============================================================================
# Function: CreateDirectories
# Description: Create the standard rcForge directory structure (now driven by manifest).
# Usage: CreateDirectories is_verbose (Only creates base $RCFORGE_DIR)
# ============================================================================
CreateDirectories() {
    local is_verbose="$1"
    VerboseMessage "$is_verbose" "Ensuring base installation directory exists: $RCFORGE_DIR"

    # Only ensure the main directory and backups exist here. Manifest handles rest.
    if ! mkdir -p "$RCFORGE_DIR"; then
        ErrorMessage "Failed to create base install directory: $RCFORGE_DIR"
    fi
    if ! chmod 700 "$RCFORGE_DIR"; then
        WarningMessage "Could not set permissions (700) on main directory: $RCFORGE_DIR"
    fi

    # Backup dir still useful to create here if needed by backup function early
    if ! mkdir -p "$BACKUP_DIR"; then
        WarningMessage "Could not create backup directory: $BACKUP_DIR"
    fi
     if ! chmod 700 "$BACKUP_DIR"; then
        WarningMessage "Could not set permissions (700) on backup directory: $BACKUP_DIR"
    fi

    # No SuccessMessage here, ProcessManifest will confirm directory creation
    return 0
}

# ============================================================================
# Function: DownloadFile
# Description: Download a single file using curl or wget, ensure parent dir exists, set permissions.
# Usage: DownloadFile is_verbose url destination
# ============================================================================
DownloadFile() {
    local is_verbose="$1"
    local url="$2"
    local destination="$3"
    local dest_dir=""
    local download_cmd=""

    VerboseMessage "$is_verbose" "Downloading: $(basename "$destination") to $destination"
    dest_dir=$(dirname "$destination");

    if ! mkdir -p "$dest_dir"; then
        ErrorMessage "Failed to create directory: $dest_dir" # Exits
    fi
    if ! chmod 700 "$dest_dir"; then
         WarningMessage "Perms fail (700): $dest_dir"
    fi

    if CommandExists curl; then
        download_cmd="curl --fail --silent --show-error --location --output \"$destination\" \"$url\""
    elif CommandExists wget; then
        download_cmd="wget --quiet --output-document=\"$destination\" \"$url\""
    else
        ErrorMessage "'curl' or 'wget' not found." # Exits
    fi

    if ! eval "$download_cmd"; then
        rm -f "$destination" &>/dev/null || true
        ErrorMessage "Failed to download: $url" # Exits
    fi

    if [[ "$destination" == *.sh ]]; then
        if ! chmod 700 "$destination"; then
             WarningMessage "Perms fail (700): $destination"
        fi
    else
        if ! chmod 600 "$destination"; then
             WarningMessage "Perms fail (600): $destination"
        fi
    fi
}

# ============================================================================
# Function: DownloadManifest
# Description: Downloads the manifest file to a temporary location.
# Usage: DownloadManifest is_verbose
# ============================================================================
DownloadManifest() {
    local is_verbose="$1"
    InfoMessage "Downloading file manifest ($MANIFEST_FILENAME)..."
    local download_cmd=""

    if CommandExists curl; then
        download_cmd="curl --fail --silent --show-error --location --output \"$MANIFEST_TEMP_FILE\" \"$MANIFEST_URL\""
    elif CommandExists wget; then
        download_cmd="wget --quiet --output-document=\"$MANIFEST_TEMP_FILE\" \"$MANIFEST_URL\""
    else
        ErrorMessage "'curl' or 'wget' not found." # Exits
    fi

    if ! eval "$download_cmd"; then
        rm -f "$MANIFEST_TEMP_FILE" &>/dev/null || true
        ErrorMessage "Failed to download manifest: $MANIFEST_URL" # Exits
    fi

    if [[ ! -s "$MANIFEST_TEMP_FILE" ]]; then
        rm -f "$MANIFEST_TEMP_FILE" &>/dev/null || true
        ErrorMessage "Manifest is empty: $MANIFEST_TEMP_FILE" # Exits
    fi
    SuccessMessage "Manifest downloaded.";
    return 0;
}

# ============================================================================
# Function: ProcessManifest
# Description: Reads the manifest file, creates directories, and downloads files.
# Usage: ProcessManifest is_verbose
# ============================================================================
ProcessManifest() {
    local is_verbose="$1"
    local current_section="NONE"
    local line_num=0
    local dir_count=0
    local file_count=0
    local line=""
    local dir_path="" ; local full_dir_path=""
    local source_suffix="" ; local dest_suffix="" ; local file_url="" ; local dest_path=""

    SectionHeader "Processing Manifest"

    if [[ ! -f "$MANIFEST_TEMP_FILE" ]]; then
         ErrorMessage "Manifest file not found at $MANIFEST_TEMP_FILE. Cannot proceed." # Exits
    fi

    # Base dir creation moved to main flow before calling this function

    while IFS= read -r line || [[ -n "$line" ]]; do
        line_num=$((line_num + 1))
        line=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//') # Trim whitespace

        # Skip empty lines or comment lines
        if [[ -z "$line" || "$line" =~ ^# ]]; then
             continue
        fi

        # Detect section markers
        if [[ "$line" == "DIRECTORIES:" ]]; then
             current_section="DIRS"; InfoMessage "Processing directories..."; continue;
        fi
        if [[ "$line" == "FILES:" ]]; then
             current_section="FILES"; InfoMessage "Processing files..."; continue;
        fi

        # Process based on current section
        case "$current_section" in
            "DIRS")
                dir_path="${line#./}" # Remove leading ./ if present
                full_dir_path="${RCFORGE_DIR}/${dir_path}"
                VerboseMessage "$is_verbose" "Ensuring directory: $full_dir_path"
                if ! mkdir -p "$full_dir_path"; then
                    ErrorMessage "Failed to create directory from manifest: $full_dir_path" # Exits
                fi
                if ! chmod 700 "$full_dir_path"; then
                    WarningMessage "Perms fail (700): $full_dir_path"
                fi
                dir_count=$((dir_count + 1))
                ;;
            "FILES")
                read -r source_suffix dest_suffix <<< "$line"

                if [[ -z "$source_suffix" || -z "$dest_suffix" ]]; then
                    WarningMessage "Manifest line $line_num: Invalid format under FILES section. Skipping: '$line'"
                    continue
                fi

                file_url="${GITHUB_RAW}/${source_suffix}"
                dest_path="${RCFORGE_DIR}/${dest_suffix}"

                DownloadFile "$is_verbose" "$file_url" "$dest_path" # Handles errors/exit
                file_count=$((file_count + 1))
                ;;
            *)
                VerboseMessage "$is_verbose" "Ignoring line $line_num before section marker: $line"
                ;;
        esac
    done < "$MANIFEST_TEMP_FILE"

    SuccessMessage "Processed $dir_count directories from manifest."
    if [[ $file_count -eq 0 ]]; then
         WarningMessage "No files were processed from the manifest FILES section."
         return 1 # Treat as failure if no files downloaded?
    else
         SuccessMessage "Processed $file_count files from manifest."
         return 0
    fi
}


# ============================================================================
# Function: UpdateShellRc
# Description: Add the rcForge sourcing line to user's shell rc files (.bashrc, .zshrc).
# Usage: UpdateShellRc is_skip_integration is_verbose
# ============================================================================
UpdateShellRc() {
    local is_skip_integration="$1"
    local is_verbose="$2"
    local source_line=""
    local rc_file=""
    local updated_any=false

    if [[ "$is_skip_integration" == "true" ]]; then
        VerboseMessage "$is_verbose" "Skipping shell config update."
        return 0
    fi

    SectionHeader "Updating Shell Configuration Files"

    source_line="# rcForge Loader"$'\n'
    source_line+="[ -f \"${RCFORGE_DIR}/rcforge.sh\" ] && source \"${RCFORGE_DIR}/rcforge.sh\""

    for rc_file in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [[ -f "$rc_file" ]]; then
            if ! grep -Fxq "[ -f \"${RCFORGE_DIR}/rcforge.sh\" ] && source \"${RCFORGE_DIR}/rcforge.sh\"" "$rc_file"; then
                InfoMessage "Adding rcForge source line to $rc_file..."
                if printf "\n%s\n" "$source_line" >> "$rc_file"; then
                    SuccessMessage "Updated $rc_file."
                    updated_any=true
                else
                    WarningMessage "Failed to update $rc_file."
                fi
            else
                VerboseMessage "$is_verbose" "$rc_file already configured."
            fi
        else
             VerboseMessage "$is_verbose" "$rc_file not found; skipping."
        fi
    done

    if [[ "$updated_any" == "true" ]]; then
         InfoMessage "Shell config updated."
    else
         InfoMessage "No shell config update needed."
    fi
    return 0
}

# ============================================================================
# Function: ShowVersion
# Description: Displays installer version, copyright, and license information.
# Usage: ShowVersion
# Arguments: None
# Returns: None. Prints info to stdout and exits.
# ============================================================================
ShowVersion() {
  echo "rcForge Installer v$gc_version"
  echo "Installs rcForge Core v$RCFORGE_VERSION_CONST"
  echo "Copyright (c) $(date +%Y) rcForge Team"
  echo "MIT License"
  exit 0
}

# ============================================================================
# Function: ShowHelp
# Description: Displays help information for the installer script.
# Usage: ShowHelp
# Arguments: None
# Returns: None. Prints help to stdout and exits.
# ============================================================================
ShowHelp() {
  echo "rcForge Installer v$gc_version"
  echo ""
  echo "Installs/upgrades rcForge using a manifest file."
  echo ""
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  --reinstall          Perform a clean reinstall (removes existing installation)"
  echo "  --force, -f          Overwrite existing files without prompting"
  echo "  --verbose, -v        Enable verbose output during installation"
  echo "  --no-backup          Skip creating a backup before installation"
  echo "  --no-shell-update    Skip adding the source line to shell configuration files"
  echo "  --skip-version-check Bypass the minimum Bash version check"
  echo "  --help, -h           Show this help message"
  echo "  --version            Show installer version information"
  echo ""
  echo "Example: bash $0 --verbose"
  exit 0
}

# ============================================================================
# Function: CleanInstall / UpgradeInstall (Simplified wrappers)
# ============================================================================
CleanInstall() {
    local mode="$1"; local verbose="$2"; local skip_shell="$3";
    if [[ "$mode" == "reinstall" ]] && IsInstalled; then
        InfoMessage "Removing existing installation...";
        if ! rm -rf "$RCFORGE_DIR"; then ErrorMessage "Failed removal: $RCFORGE_DIR"; fi;
        SuccessMessage "Removed.";
    fi
    InfoMessage "Starting clean installation from manifest...";
    # ProcessManifest handles directory creation and file download
    ProcessManifest "$verbose" || return 1;
    UpdateShellRc "$skip_shell" "$verbose" || return 1;
    SuccessMessage "Clean install finished.";
    return 0;
}

UpgradeInstall() {
    local verbose="$1"; local skip_shell="$2";
    InfoMessage "Starting upgrade using manifest...";
    SectionHeader "Upgrading Files via Manifest";
    # ProcessManifest handles directory creation and file download/overwrite
    ProcessManifest "$verbose" || return 1;
    WarningMessage "Upgrade complete. Files in manifest were overwritten.";
    UpdateShellRc "$skip_shell" "$verbose" || return 1;
    SuccessMessage "Upgrade finished.";
    return 0;
}

# ============================================================================
# Function: VerifyInstallation
# Description: Perform basic checks after installation/upgrade.
# Usage: VerifyInstallation is_verbose
# ============================================================================
VerifyInstallation() {
    local is_verbose="$1"; local check_status=0; local file=""; local main_perms=""
    SectionHeader "Verifying Installation"
    local critical_files=("$RCFORGE_DIR/rcforge.sh" "$RCFORGE_DIR/system/lib/shell-colors.sh" "$RCFORGE_DIR/system/core/functions.sh") # Basic check
    InfoMessage "Checking critical files and permissions...";
    for file in "${critical_files[@]}"; do
        if [[ ! -f "$file" ]]; then
             WarningMessage "Verify fail: Missing $file"; check_status=1;
        else
             VerboseMessage "$is_verbose" "Verified exists: $file";
        fi;
    done
    main_perms=$(stat -c %a "$RCFORGE_DIR" 2>/dev/null || stat -f "%Lp" "$RCFORGE_DIR" 2>/dev/null || echo "ERR");
    if [[ "$main_perms" != "700" ]]; then
        WarningMessage "Verify warn: Perms $RCFORGE_DIR (Need: 700, Got: $main_perms)";
    else
        VerboseMessage "$is_verbose" "Verified perms: $RCFORGE_DIR.";
    fi
    if [[ $check_status -eq 0 ]]; then
        SuccessMessage "Basic verification passed!";
    else
        WarningMessage "Installation verification detected issues.";
    fi
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
    WarningMessage "${YELLOW}Recommend:${RESET} Use Git! ${CYAN}cd \"$RCFORGE_DIR\" && git init && git add . && git commit -m \"Initial rcForge setup\"${RESET}"; echo "";
    InfoMessage "Docs: ${BLUE}$GITHUB_REPO${RESET}"; echo "";
}

# ============================================================================
# Function: Cleanup
# Description: Remove temporary files on exit.
# Usage: Called via trap.
# ============================================================================
Cleanup() {
  # Trap commands don't receive arguments in Bash like $1 easily
  # Just clean up unconditionally
  rm -f "$MANIFEST_TEMP_FILE" &>/dev/null || true
}

# ============================================================================
# MAIN INSTALLATION FLOW
# ============================================================================
main() {
    # --- Local variables for parsed options ---
    local install_mode="auto"; local is_force=false; local is_verbose=false
    local skip_backup=false; local skip_shell_integration=false; local skip_version_check=false
    local effective_install_mode=""; local confirmation_response=""

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

    # Set trap for cleanup AFTER args are parsed
    trap Cleanup EXIT INT TERM

    SectionHeader "rcForge Installer v$gc_version (Manifest Mode)"

    InfoMessage "Checking prerequisites..."
    CheckBashVersion "$skip_version_check" || exit 1

    # Determine effective install mode
    effective_install_mode="$install_mode"
    if [[ "$effective_install_mode" == "auto" ]]; then
        if IsInstalled; then
             effective_install_mode="upgrade"; InfoMessage "Existing installation detected; preparing for upgrade...";
        else
             effective_install_mode="install"; InfoMessage "Performing fresh installation...";
        fi
    elif [[ "$effective_install_mode" == "reinstall" ]]; then
         InfoMessage "Performing reinstallation...";
         if ! IsInstalled; then
              WarningMessage "No existing installation found to reinstall over.";
         fi
    fi

    # Confirmation Prompt
    if [[ "$is_force" != "true" ]]; then
        printf "%b" "${YELLOW}Continue with ${effective_install_mode}? [Y/n]:${RESET} "
        read -r confirmation_response
        if [[ -n "$confirmation_response" && ! "$confirmation_response" =~ ^[Yy]$ ]]; then
            InfoMessage "Installation aborted by user."; exit 0;
        fi
    else
        WarningMessage "Proceeding non-interactively (--force)."
    fi

    # Backup before proceeding
    CreateBackup "$skip_backup" "$is_verbose" || exit 1

    # --- Main Install/Upgrade Steps ---
    # Ensure base directory exists before manifest download
    # Renamed CreateDirectories to only handle essential base dirs if needed,
    # or just ensure RCFORGE_DIR exists here. Let's ensure RCFORGE_DIR.
    if ! mkdir -p "$RCFORGE_DIR"; then ErrorMessage "Failed to create base install directory: $RCFORGE_DIR"; fi
    if ! chmod 700 "$RCFORGE_DIR"; then WarningMessage "Perms fail: $RCFORGE_DIR"; fi

    # Download the manifest file
    DownloadManifest "$is_verbose" || exit 1

    # Process manifest (creates dirs, downloads files)
    InfoMessage "Processing manifest for ${effective_install_mode}..."
    if ! ProcessManifest "$is_verbose"; then
        ErrorMessage "Failed to process manifest and install files." # Exit if manifest processing fails
    fi

    # Update shell RCs after files are in place
    UpdateShellRc "$skip_shell_integration" "$is_verbose" || WarningMessage "Shell RC update step failed."

    SuccessMessage "File installation/upgrade from manifest complete."
    # --- End Main Install/Upgrade Steps ---

    # Verify installation
    VerifyInstallation "$is_verbose" || exit 1

    # Display final instructions
    ShowInstructions "$effective_install_mode"

    # Cleanup trap will run on exit
    exit 0
}

# Run the installer's main function
main "$@"

# EOF