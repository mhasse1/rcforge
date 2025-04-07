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

# Colors (self-contained for installer)
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
# Arguments:
#   $1 (required) - The error message text.
# Returns: None. Prints to stderr and exits with code 1.
# Exits: 1
# ============================================================================
ErrorMessage() {
  echo -e "${RED}ERROR:${RESET} $1" >&2
  exit 1
}

# ============================================================================
# Function: WarningMessage
# Description: Display warning message.
# Usage: WarningMessage "Warning description"
# Arguments:
#   $1 (required) - The warning message text.
# Returns: None. Prints to stderr.
# ============================================================================
WarningMessage() {
  echo -e "${YELLOW}WARNING:${RESET} $1" >&2
}

# ============================================================================
# Function: InfoMessage
# Description: Display info message.
# Usage: InfoMessage "Information"
# Arguments:
#   $1 (required) - The informational message text.
# Returns: None. Prints to stdout.
# ============================================================================
InfoMessage() {
  echo -e "${BLUE}INFO:${RESET} $1"
}

# ============================================================================
# Function: SuccessMessage
# Description: Display success message.
# Usage: SuccessMessage "Success details"
# Arguments:
#   $1 (required) - The success message text.
# Returns: None. Prints to stdout.
# ============================================================================
SuccessMessage() {
  echo -e "${GREEN}SUCCESS:${RESET} $1"
}

# ============================================================================
# Function: SectionHeader
# Description: Display formatted section header.
# Usage: SectionHeader "Header Text"
# Arguments:
#   $1 (required) - The header text.
# Returns: None. Prints formatted header to stdout.
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
#   $1 (required) - Boolean ('true' or 'false') indicating verbose mode.
#   $2 (required) - The message text to display.
# Returns: None. Prints to stdout if verbose mode is true.
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
# Description: Check if rcForge appears to be installed based on directory/file existence.
# Usage: if IsInstalled; then ... fi
# Arguments: None
# Returns: 0 (true) if installation detected, 1 (false) otherwise.
# ============================================================================
IsInstalled() {
  [[ -d "$RCFORGE_DIR" && -f "$RCFORGE_DIR/rcforge.sh" ]]
}

# ============================================================================
# Function: CommandExists
# Description: Check if a command exists in the PATH.
# Usage: if CommandExists command_name; then ... fi
# Arguments:
#   $1 (required) - Name of the command to check.
# Returns: 0 (true) if command exists, 1 (false) otherwise.
# ============================================================================
CommandExists() {
  command -v "$1" >/dev/null 2>&1
}

# ============================================================================
# Function: CheckBashVersion
# Description: Check if running Bash version meets minimum requirements (4.0+).
#              Warns and optionally prompts user to continue if check fails or skipped.
# Usage: CheckBashVersion is_skip_check
# Arguments:
#   $1 (required) - Boolean ('true' or 'false') indicating if version check should be skipped.
# Returns: 0 if check passes or user confirms continuation, 1 otherwise (if user aborts). Exits directly if ErrorMessage called.
# Exits: 1 (via ErrorMessage) if user aborts prompt.
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
# Arguments:
#   $1 (required) - Boolean ('true' or 'false') indicating if backup should be skipped.
#   $2 (required) - Boolean ('true' or 'false') indicating verbose mode for tar.
# Returns: 0 on successful backup or if skipped/not needed, 1 on backup failure (via ErrorMessage). Exits directly on failure.
# Exits: 1 (via ErrorMessage) if tar command fails.
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
# Function: DownloadFile
# Description: Download a single file using curl or wget, ensure parent dir exists, set permissions.
# Usage: DownloadFile is_verbose url destination
# Arguments:
#   $1 (required) - Boolean ('true' or 'false') indicating verbose mode.
#   $2 (required) - The URL of the file to download.
#   $3 (required) - The destination path to save the file.
# Returns: 0 on success, 1 on failure (via ErrorMessage). Exits directly on failure.
# Exits: 1 (via ErrorMessage) if directory creation, dependency check, or download fails.
# ============================================================================
DownloadFile() {
    local is_verbose="$1"
    local url="$2"
    local destination="$3"
    local dest_dir
    local download_cmd=""

    VerboseMessage "$is_verbose" "Downloading: $(basename "$destination") to $destination"
    dest_dir=$(dirname "$destination")
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

    # Set permissions based on file type (executable for .sh, read-only otherwise)
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
# Arguments:
#   $1 (required) - Boolean ('true' or 'false') indicating verbose mode.
# Returns: 0 on success, 1 on failure (via ErrorMessage). Exits directly on failure.
# Exits: 1 (via ErrorMessage) if dependency check, download, or file validation fails.
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
    SuccessMessage "Manifest downloaded."
    return 0
}

# ============================================================================
# Function: ProcessManifest
# Description: Reads the downloaded manifest file, creates directories, and downloads files listed within.
# Usage: ProcessManifest is_verbose
# Arguments:
#   $1 (required) - Boolean ('true' or 'false') indicating verbose mode.
# Returns: 0 if files were processed successfully, 1 if manifest not found, directory creation failed, or no files processed. Exits directly on some failures.
# Exits: 1 (via ErrorMessage) if manifest file not found or directory creation fails.
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

    if [[ ! -f "$MANIFEST_TEMP_FILE" ]]; then
         ErrorMessage "Manifest file not found at $MANIFEST_TEMP_FILE. Cannot proceed." # Exits
    fi

    # Ensure base installation directory exists before processing manifest
    # Already done in main flow, but double check is harmless
    if ! mkdir -p "$RCFORGE_DIR"; then
        ErrorMessage "Failed to ensure base directory exists: $RCFORGE_DIR" # Exits
    fi
    if ! chmod 700 "$RCFORGE_DIR"; then
         WarningMessage "Perms fail (700): $RCFORGE_DIR"
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        line_num=$((line_num + 1))
        line=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//') # Trim whitespace

        # Skip empty lines or comment lines
        if [[ -z "$line" || "$line" =~ ^# ]]; then
             continue
        fi

        # Detect section markers
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
                # Expecting format: source_repo_path destination_install_path
                read -r source_suffix dest_suffix <<< "$line"

                if [[ -z "$source_suffix" || -z "$dest_suffix" ]]; then
                    WarningMessage "Manifest line $line_num: Invalid format under FILES section. Skipping: '$line'"
                    continue
                fi

                file_url="${GITHUB_RAW}/${source_suffix}"
                dest_path="${RCFORGE_DIR}/${dest_suffix}"

                # DownloadFile handles errors/exits internally
                DownloadFile "$is_verbose" "$file_url" "$dest_path"
                file_count=$((file_count + 1))
                ;;
            *)
                # Line before first section marker
                VerboseMessage "$is_verbose" "Ignoring line $line_num before section marker: $line"
                ;;
        esac
    done < "$MANIFEST_TEMP_FILE"

    SuccessMessage "Processed $dir_count directories from manifest."
    if [[ $file_count -eq 0 ]]; then
         WarningMessage "No files were processed from the manifest FILES section."
         return 1 # Indicate potential issue if no files downloaded
    else
         SuccessMessage "Processed $file_count files from manifest."
         return 0
    fi
}


# ============================================================================
# Function: UpdateShellRc
# Description: Add the rcForge sourcing line (commented out) to user's shell
#              rc files (.bashrc, .zshrc) if not already present.
# Usage: UpdateShellRc is_skip_integration is_verbose
# Arguments:
#   $1 (required) - Boolean ('true' or 'false') indicating if shell integration
#                   should be skipped.
#   $2 (required) - Boolean ('true' or 'false') indicating verbose mode.
# Returns: 0 (Always returns 0, but may print warnings on failure).
# ============================================================================
UpdateShellRc() {
    local is_skip_integration="$1"
    local is_verbose="$2"
    local source_line_commented_out=""
    local rc_file=""
    local updated_any=false
    # Define the line that will be checked for existence (the uncommented version)
    local check_line="[ -f \"${RCFORGE_DIR}/rcforge.sh\" ] && source \"${RCFORGE_DIR}/rcforge.sh\""

    if [[ "$is_skip_integration" == "true" ]]; then
        VerboseMessage "$is_verbose" "Skipping shell config update."
        return 0
    fi

    SectionHeader "Updating Shell Configuration Files"

    # Define the lines to add, now commented out
    source_line_commented_out="# rcForge Loader (Commented out by installer - uncomment to enable)"$'\n'
    source_line_commented_out+="# [ -f \"${RCFORGE_DIR}/rcforge.sh\" ] && source \"${RCFORGE_DIR}/rcforge.sh\""

    for rc_file in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [[ -f "$rc_file" ]]; then
            # Check if the *uncommented* line already exists
            if ! grep -Fxq "$check_line" "$rc_file"; then
                # Also check if the *commented* line exists to avoid adding duplicates
                if ! grep -Fxq "# ${check_line}" "$rc_file"; then
                    InfoMessage "Adding commented-out rcForge source line to $rc_file..."
                    # Append the commented-out lines
                    if printf "\n%s\n" "$source_line_commented_out" >> "$rc_file"; then
                        SuccessMessage "Added commented-out line to $rc_file."
                        updated_any=true
                    else
                        WarningMessage "Failed to update $rc_file."
                    fi
                else
                     VerboseMessage "$is_verbose" "$rc_file already has the commented-out rcForge line."
                fi
            else
                VerboseMessage "$is_verbose" "$rc_file already has the active (uncommented) rcForge line."
            fi
        else
             VerboseMessage "$is_verbose" "$rc_file not found; skipping."
        fi
    done

    if [[ "$updated_any" == "true" ]]; then
         InfoMessage "Shell config files updated with commented-out source line."
    else
         InfoMessage "No shell config update needed (or skipped)."
    fi
    return 0
}

# ============================================================================
# Function: ShowVersion
# Description: Displays installer version, copyright, and license information.
# Usage: ShowVersion
# Arguments: None
# Returns: None. Prints info to stdout and exits.
# Exits: 0
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
# Exits: 0
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
# Function: CleanInstall
# Description: Performs a fresh installation or reinstallation based on the
#              manifest. Removes existing install if mode is 'reinstall'.
# Usage: CleanInstall mode verbose skip_shell
# Arguments:
#   $1 (required) - Install mode ('install' or 'reinstall').
#   $2 (required) - Boolean ('true' or 'false') indicating verbose mode.
#   $3 (required) - Boolean ('true' or 'false') indicating if shell
#                   integration should be skipped.
# Returns: 0 on success, 1 on failure (e.g., ProcessManifest or UpdateShellRc
#          fails). Exits directly on removal failure.
# Exits: 1 (via ErrorMessage) if removing existing installation fails.
# ============================================================================
CleanInstall() {
    local mode="$1"
    local verbose="$2"
    local skip_shell="$3"

    # Remove existing installation if reinstalling
    if [[ "$mode" == "reinstall" ]] && IsInstalled; then
        InfoMessage "Removing existing installation..."
        if ! rm -rf "$RCFORGE_DIR"; then
             ErrorMessage "Failed to remove existing installation at: $RCFORGE_DIR" # Exits
        fi
        SuccessMessage "Removed existing installation."
    fi

    InfoMessage "Starting clean installation from manifest..."

    # ProcessManifest handles directory creation and file download
    ProcessManifest "$verbose" || return 1 # Return failure if manifest processing fails

    # Update shell config files
    UpdateShellRc "$skip_shell" "$verbose" || return 1 # Return failure (though unlikely as it mostly warns)

    SuccessMessage "Clean install finished."
    return 0
}

# ============================================================================
# Function: UpgradeInstall
# Description: Performs an upgrade using the manifest, overwriting files listed.
# Usage: UpgradeInstall verbose skip_shell
# Arguments:
#   $1 (required) - Boolean ('true' or 'false') indicating verbose mode.
#   $2 (required) - Boolean ('true' or 'false') indicating if shell integration
#                   should be skipped.
# Returns: 0 on success, 1 on failure (e.g., ProcessManifest or UpdateShellRc
#          fails).
# ============================================================================
UpgradeInstall() {
    local verbose="$1"
    local skip_shell="$2"

    InfoMessage "Starting upgrade using manifest..."
    SectionHeader "Upgrading Files via Manifest"

    # ProcessManifest handles directory creation and file download/overwrite
    ProcessManifest "$verbose" || return 1 # Return failure if manifest processing fails

    # Currently, ProcessManifest always overwrites. Add logic here if selective update is needed later.
    WarningMessage "Upgrade process complete. Files listed in the manifest were downloaded/overwritten."

    # Update shell config files
    UpdateShellRc "$skip_shell" "$verbose" || return 1 # Return failure

    SuccessMessage "Upgrade finished."
    return 0
}

# ============================================================================
# Function: VerifyInstallation
# Description: Perform basic checks after installation/upgrade (critical files
#              exist, base dir permissions).
# Usage: VerifyInstallation is_verbose
# Arguments:
#   $1 (required) - Boolean ('true' or 'false') indicating verbose mode.
# Returns: 0 if basic checks pass, 1 if issues are detected.
# ============================================================================
VerifyInstallation() {
    local is_verbose="$1"
    local check_status=0
    local file=""
    local main_perms=""
    # Define critical files expected after manifest processing
    local critical_files=(
        "$RCFORGE_DIR/rcforge.sh"
        "$RCFORGE_DIR/system/lib/shell-colors.sh"
        "$RCFORGE_DIR/system/core/functions.sh"
        # Add more files based on manifest if needed
    )

    SectionHeader "Verifying Installation"
    InfoMessage "Checking critical files and permissions..."

    for file in "${critical_files[@]}"; do
        if [[ ! -f "$file" ]]; then
             WarningMessage "Verify fail: Missing $file"
             check_status=1
        else
             VerboseMessage "$is_verbose" "Verified exists: $file"
             # Check permissions on executables
             if [[ "$file" == *.sh ]]; then
                 local file_perms
                 file_perms=$(stat -c %a "$file" 2>/dev/null || stat -f "%Lp" "$file" 2>/dev/null || echo "ERR")
                 if [[ "$file_perms" != "700" ]]; then
                      WarningMessage "Verify warn: Perms $file (Need: 700, Got: $file_perms)"
                      # Decide if wrong perms should cause failure status
                      # check_status=1
                 else
                      VerboseMessage "$is_verbose" "Verified perms (700): $file"
                 fi
             fi
        fi
    done

    # Check base directory permissions
    main_perms=$(stat -c %a "$RCFORGE_DIR" 2>/dev/null || stat -f "%Lp" "$RCFORGE_DIR" 2>/dev/null || echo "ERR")
    if [[ "$main_perms" != "700" ]]; then
        WarningMessage "Verify warn: Perms $RCFORGE_DIR (Need: 700, Got: $main_perms)"
        # Decide if wrong perms should cause failure status
        # check_status=1
    else
        VerboseMessage "$is_verbose" "Verified perms: $RCFORGE_DIR."
    fi

    echo "" # Add newline for separation
    if [[ $check_status -eq 0 ]]; then
        SuccessMessage "Basic verification passed!"
    else
        WarningMessage "Installation verification detected potential issues."
    fi
    return $check_status
}

# ============================================================================
# Function: ShowInstructions
# Description: Display final post-installation instructions and recommendations.
# Usage: ShowInstructions effective_install_mode
# Arguments:
#   $1 (required) - String indicating the type of installation performed
#                   ('install', 'upgrade', 'reinstall').
# Returns: None. Prints instructions to stdout.
# ============================================================================
ShowInstructions() {
    local effective_install_mode="$1"
    SectionHeader "Installation Complete!"
    SuccessMessage "rcForge v$gc_version successfully ${effective_install_mode}ed to $RCFORGE_DIR!"
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
# Description: Remove temporary files (like the downloaded manifest) on script exit. Intended for use with 'trap'.
# Usage: trap Cleanup EXIT INT TERM
# Arguments: None (implicitly receives signal info from trap)
# Returns: None. Attempts to remove temp file.
# ============================================================================
Cleanup() {
  # Trap commands don't receive arguments in Bash like $1 easily
  # Just clean up unconditionally, ignoring errors
  rm -f "$MANIFEST_TEMP_FILE" &>/dev/null || true
}

# ============================================================================
# Function: main
# Description: Main installation flow controller. Parses arguments, determines install mode, runs backup, downloads/processes manifest, updates shell configs, verifies, and shows instructions.
# Usage: main "$@" (Called at the end of the script)
# Arguments:
#   "$@" - All command-line arguments passed to the script.
# Returns: Exits with 0 on success, 1 on failure.
# Exits: 0 on success, 1 on failure or user abort.
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
    local confirmation_response=""

    # --- Argument Parsing ---
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --reinstall) install_mode="reinstall" ;;
            --force|-f) is_force=true ;;
            --verbose|-v) is_verbose=true ;;
            --no-backup) skip_backup=true ;;
            --no-shell-update) skip_shell_integration=true ;;
            --skip-version-check) skip_version_check=true ;;
            --help|-h) ShowHelp; exit 0 ;; # Calls function which exits
            --version) ShowVersion; exit 0 ;; # Calls function which exits
            *) WarningMessage "Unknown option: $1"; ShowHelp; exit 1 ;; # Calls function which exits
        esac
        shift
    done
    # --- End Argument Parsing ---

    # Set trap for cleanup AFTER args are parsed and temp file defined
    trap Cleanup EXIT INT TERM

    SectionHeader "rcForge Installer v$gc_version (Manifest Mode)"

    InfoMessage "Checking prerequisites..."
    CheckBashVersion "$skip_version_check" # Exits on user abort

    # Determine effective install mode
    effective_install_mode="$install_mode"
    if [[ "$effective_install_mode" == "auto" ]]; then
        if IsInstalled; then
             effective_install_mode="upgrade"
             InfoMessage "Existing installation detected; preparing for upgrade..."
        else
             effective_install_mode="install"
             InfoMessage "Performing fresh installation..."
        fi
    elif [[ "$effective_install_mode" == "reinstall" ]]; then
         InfoMessage "Performing reinstallation..."
         if ! IsInstalled; then
              WarningMessage "No existing installation found to reinstall over."
         fi
    fi

    # Confirmation Prompt
    if [[ "$is_force" != "true" ]]; then
        # Use printf for prompt to avoid issues with echo -n/-e
        printf "%b" "${YELLOW}Continue with ${effective_install_mode}? [Y/n]:${RESET} "
        read -r confirmation_response # Use -r for raw input
        # Default to Yes if empty or starts with Y/y
        if [[ -n "$confirmation_response" && ! "$confirmation_response" =~ ^[Yy] ]]; then
            InfoMessage "Installation aborted by user."
            exit 0
        fi
    else
        WarningMessage "Proceeding non-interactively (--force)."
    fi

    # Backup before potentially destructive operations
    CreateBackup "$skip_backup" "$is_verbose" # Exits on failure

    # --- Main Install/Upgrade Steps ---

    # Download the manifest file first
    DownloadManifest "$is_verbose" # Exits on failure

    # Call appropriate install/upgrade function based on mode
    if [[ "$effective_install_mode" == "install" || "$effective_install_mode" == "reinstall" ]]; then
        CleanInstall "$effective_install_mode" "$is_verbose" "$skip_shell_integration" || exit 1 # Exit if install fails
    elif [[ "$effective_install_mode" == "upgrade" ]]; then
        UpgradeInstall "$is_verbose" "$skip_shell_integration" || exit 1 # Exit if upgrade fails
    else
        ErrorMessage "Internal error: Unknown effective install mode '$effective_install_mode'." # Should not happen
    fi
    # --- End Main Install/Upgrade Steps ---

    # Verify installation
    VerifyInstallation "$is_verbose" # Warns on issues, doesn't exit by default

    # Display final instructions
    ShowInstructions "$effective_install_mode"

    # Cleanup trap will run on exit
    exit 0
}

# Run the installer's main function, passing all arguments
main "$@"

# EOF