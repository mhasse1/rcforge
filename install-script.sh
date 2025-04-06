#!/usr/bin/env bash
# install.sh - rcForge Installation Script
# Author: rcForge Team
# Date: 2025-04-05
# Version: 0.3.0
# Description: Installs or upgrades rcForge shell configuration system

# Set strict error handling
set -o nounset  # Treat unset variables as errors
set -o errexit  # Exit immediately if a command exits with a non-zero status
set -o pipefail # Ensure pipeline fails on any component failing

# ============================================================================
# CONFIGURATION
# ============================================================================

# Global variables
readonly RCFORGE_VERSION="0.3.0"
readonly RCFORGE_DIR="$HOME/.config/rcforge"
readonly BACKUP_DIR="$RCFORGE_DIR/backups"
readonly TIMESTAMP=$(date +%Y%m%d%H%M%S)
readonly BACKUP_FILE="$BACKUP_DIR/rcforge_backup_$TIMESTAMP.tar.gz"
readonly GITHUB_REPO="https://github.com/rcforge/rcforge"
readonly GITHUB_RAW="https://raw.githubusercontent.com/rcforge/rcforge/main"

# Colors and formatting
if [[ -t 1 ]]; then
  readonly RED='\033[0;31m'
  readonly GREEN='\033[0;32m'
  readonly YELLOW='\033[0;33m'
  readonly BLUE='\033[0;34m'
  readonly MAGENTA='\033[0;35m'
  readonly CYAN='\033[0;36m'
  readonly BOLD='\033[1m'
  readonly RESET='\033[0m'
else
  readonly RED=""
  readonly GREEN=""
  readonly YELLOW=""
  readonly BLUE=""
  readonly MAGENTA=""
  readonly CYAN=""
  readonly BOLD=""
  readonly RESET=""
fi

# Installation flags
INSTALL_MODE="install"  # install, upgrade, or reinstall
VERBOSE=false
FORCE=false
SKIP_BACKUP=false
SKIP_SHELL_INTEGRATION=false
SKIP_VERSION_CHECK=false

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Display error message and exit
error() {
  echo -e "${RED}ERROR:${RESET} $1" >&2
  exit 1
}

# Display warning message
warning() {
  echo -e "${YELLOW}WARNING:${RESET} $1" >&2
}

# Display info message
info() {
  echo -e "${BLUE}INFO:${RESET} $1"
}

# Display success message
success() {
  echo -e "${GREEN}SUCCESS:${RESET} $1"
}

# Display section header
section() {
  echo -e "\n${BOLD}${CYAN}$1${RESET}\n${CYAN}$(printf '=%.0s' {1..50})${RESET}\n"
}

# Print verbose message if verbose mode is enabled
verbose() {
  if [[ "$VERBOSE" == "true" ]]; then
    echo -e "${CYAN}VERBOSE:${RESET} $1"
  fi
}

# Check if rcForge is already installed
is_installed() {
  [[ -d "$RCFORGE_DIR" && -f "$RCFORGE_DIR/rcforge.sh" ]]
}

# Check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check if running Bash 4.0 or higher
check_bash_version() {
  if [[ -z "${BASH_VERSION:-}" ]]; then
    warning "Not running in Bash. Some features may not work correctly."
    if [[ "$SKIP_VERSION_CHECK" != "true" ]]; then
      warning "Use --skip-version-check to bypass this warning."
      read -p "Continue anyway? [y/N] " response
      [[ "$response" =~ ^[Yy]$ ]] || exit 1
    fi
    return 0
  fi

  local major_version=${BASH_VERSION%%.*}
  if [[ "$major_version" -lt 4 && "$SKIP_VERSION_CHECK" != "true" ]]; then
    warning "rcForge requires Bash 4.0 or higher for full functionality."
    warning "Your current Bash version is: $BASH_VERSION"
    warning "Use --skip-version-check to bypass this warning."
    
    if [[ "$(uname)" == "Darwin" ]]; then
      echo -e "\n${YELLOW}For macOS users, install a newer version with Homebrew:${RESET}"
      echo "  brew install bash"
      echo "  sudo bash -c 'echo \$(brew --prefix)/bin/bash >> /etc/shells'"
      echo "  chsh -s \$(brew --prefix)/bin/bash"
    fi
    
    read -p "Continue anyway? [y/N] " response
    [[ "$response" =~ ^[Yy]$ ]] || exit 1
  fi
}

# Create backup of existing installation
create_backup() {
  if [[ "$SKIP_BACKUP" == "true" || ! -d "$RCFORGE_DIR" ]]; then
    verbose "Skipping backup creation"
    return 0
  fi
  
  info "Creating backup of existing installation..."
  mkdir -p "$BACKUP_DIR"
  
  # Create tarball of current installation
  tar -czf "$BACKUP_FILE" -C "$(dirname "$RCFORGE_DIR")" "$(basename "$RCFORGE_DIR")" >/dev/null 2>&1 || {
    error "Failed to create backup file: $BACKUP_FILE"
  }
  
  success "Backup created: $BACKUP_FILE"
}

# Create directory structure
create_directories() {
  verbose "Creating directory structure..."
  
  # Main directories
  mkdir -p "$RCFORGE_DIR/rc-scripts"
  mkdir -p "$RCFORGE_DIR/utils"
  mkdir -p "$RCFORGE_DIR/backups"
  mkdir -p "$RCFORGE_DIR/docs"
  
  # System directories
  mkdir -p "$RCFORGE_DIR/system/lib"
  mkdir -p "$RCFORGE_DIR/system/core"
  mkdir -p "$RCFORGE_DIR/system/include"
  mkdir -p "$RCFORGE_DIR/system/utils"
  
  # Set permissions
  chmod 700 "$RCFORGE_DIR"
  find "$RCFORGE_DIR" -type d -exec chmod 700 {} \;
  
  verbose "Directory structure created"
}

# Download a file from GitHub
download_file() {
  local url="$1"
  local destination="$2"
  
  verbose "Downloading: $url -> $destination"
  
  # Create directory if it doesn't exist
  mkdir -p "$(dirname "$destination")"
  
  # Download the file
  if command_exists curl; then
    curl -sSL -o "$destination" "$url" || error "Failed to download: $url"
  elif command_exists wget; then
    wget -q -O "$destination" "$url" || error "Failed to download: $url"
  else
    error "Neither curl nor wget found. Please install one of them and try again."
  fi
  
  # Make executable if it's a script
  if [[ "$destination" == *.sh ]]; then
    chmod 700 "$destination"
  else
    chmod 600 "$destination"
  fi
}

# Download standard set of files
download_standard_files() {
  section "Downloading rcForge Files"
  
  # Core files
  info "Downloading core files..."
  download_file "$GITHUB_RAW/rcforge.sh" "$RCFORGE_DIR/rcforge.sh"
  download_file "$GITHUB_RAW/system/lib/shell-colors.sh" "$RCFORGE_DIR/system/lib/shell-colors.sh"
  download_file "$GITHUB_RAW/system/lib/utility-functions.sh" "$RCFORGE_DIR/system/lib/utility-functions.sh"
  download_file "$GITHUB_RAW/system/core/bash-version-check.sh" "$RCFORGE_DIR/system/core/bash-version-check.sh"
  
  # RC scripts
  info "Downloading configuration scripts..."
  download_file "$GITHUB_RAW/rc-scripts/050_global_common_path.sh" "$RCFORGE_DIR/rc-scripts/050_global_common_path.sh"
  download_file "$GITHUB_RAW/rc-scripts/210_global_bash_config.sh" "$RCFORGE_DIR/rc-scripts/210_global_bash_config.sh"
  download_file "$GITHUB_RAW/rc-scripts/210_global_zsh_config.sh" "$RCFORGE_DIR/rc-scripts/210_global_zsh_config.sh"
  download_file "$GITHUB_RAW/rc-scripts/350_global_bash_prompt.sh" "$RCFORGE_DIR/rc-scripts/350_global_bash_prompt.sh"
  download_file "$GITHUB_RAW/rc-scripts/350_global_zsh_prompt.sh" "$RCFORGE_DIR/rc-scripts/350_global_zsh_prompt.sh"
  download_file "$GITHUB_RAW/rc-scripts/400_global_common_aliases.sh" "$RCFORGE_DIR/rc-scripts/400_global_common_aliases.sh"
  
  # Utilities
  info "Downloading utility scripts..."
  download_file "$GITHUB_RAW/system/utils/httpheaders.sh" "$RCFORGE_DIR/system/utils/httpheaders.sh"
  
  # Documentation
  info "Downloading documentation..."
  download_file "$GITHUB_RAW/docs/README.md" "$RCFORGE_DIR/docs/README.md"
  
  success "All files downloaded successfully!"
}

# Update shell RC files
update_shell_rc() {
  if [[ "$SKIP_SHELL_INTEGRATION" == "true" ]]; then
    verbose "Skipping shell integration"
    return 0
  }
  
  section "Updating Shell Configuration"
  
  # Source line to add
  local source_line="# rcForge Shell Configuration"$'\n'"[ -f \"\$HOME/.config/rcforge/rcforge.sh\" ] && source \"\$HOME/.config/rcforge/rcforge.sh\""
  
  # Update .bashrc if it exists
  if [[ -f "$HOME/.bashrc" ]]; then
    if ! grep -q "rcforge/rcforge.sh" "$HOME/.bashrc"; then
      info "Adding rcForge to .bashrc..."
      echo -e "\n$source_line" >> "$HOME/.bashrc"
      success "Updated .bashrc successfully!"
    else
      verbose ".bashrc already contains rcForge source line"
    fi
  fi
  
  # Update .zshrc if it exists
  if [[ -f "$HOME/.zshrc" ]]; then
    if ! grep -q "rcforge/rcforge.sh" "$HOME/.zshrc"; then
      info "Adding rcForge to .zshrc..."
      echo -e "\n$source_line" >> "$HOME/.zshrc"
      success "Updated .zshrc successfully!"
    else
      verbose ".zshrc already contains rcForge source line"
    fi
  fi
}

# Display version information
show_version() {
  echo "rcForge Installer v$RCFORGE_VERSION"
  echo "Copyright (c) 2025 rcForge Team"
  echo "Released under the MIT License"
  exit 0
}

# Display help information
show_help() {
  echo "rcForge Installer - v$RCFORGE_VERSION"
  echo ""
  echo "Description:"
  echo "  Installs or upgrades the rcForge shell configuration system"
  echo ""
  echo "Usage:"
  echo "  ./install.sh [options]"
  echo ""
  echo "Options:"
  echo "  --reinstall         Force reinstallation even if already installed"
  echo "  --force, -f         Skip all confirmations"
  echo "  --verbose, -v       Enable verbose output"
  echo "  --no-backup         Skip backup creation (not recommended)"
  echo "  --no-shell-update   Don't update shell RC files"
  echo "  --skip-version-check Skip Bash version check"
  echo "  --help, -h          Show this help message"
  echo "  --version           Show version information"
  echo ""
  echo "Examples:"
  echo "  ./install.sh                   # Standard installation"
  echo "  ./install.sh --reinstall -v    # Verbose reinstallation"
  echo "  ./install.sh --no-shell-update # Install without updating RC files"
  echo ""
  echo "Note: Run this script with bash, NOT sh"
  exit 0
}

# Process command-line arguments
process_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --reinstall)
        INSTALL_MODE="reinstall"
        ;;
      --force|-f)
        FORCE=true
        ;;
      --verbose|-v)
        VERBOSE=true
        ;;
      --no-backup)
        SKIP_BACKUP=true
        ;;
      --no-shell-update)
        SKIP_SHELL_INTEGRATION=true
        ;;
      --skip-version-check)
        SKIP_VERSION_CHECK=true
        ;;
      --help|-h)
        show_help
        ;;
      --version)
        show_version
        ;;
      *)
        error "Unknown option: $1"
        ;;
    esac
    shift
  done
}

# Clean installation for fresh installs or reinstalls
clean_install() {
  # Create directory structure
  create_directories
  
  # Download standard files
  download_standard_files
  
  # Update shell RC files
  update_shell_rc
}

# Upgrade existing installation
upgrade_install() {
  # Create backup first
  create_backup
  
  # Create any missing directories
  create_directories
  
  # Download new system files but preserve user configs
  section "Upgrading rcForge Files"
  
  # Core files
  info "Upgrading core files..."
  download_file "$GITHUB_RAW/rcforge.sh" "$RCFORGE_DIR/rcforge.sh"
  download_file "$GITHUB_RAW/system/lib/shell-colors.sh" "$RCFORGE_DIR/system/lib/shell-colors.sh"
  download_file "$GITHUB_RAW/system/lib/utility-functions.sh" "$RCFORGE_DIR/system/lib/utility-functions.sh"
  download_file "$GITHUB_RAW/system/core/bash-version-check.sh" "$RCFORGE_DIR/system/core/bash-version-check.sh"
  
  # Only add example RC scripts if not already present
  info "Checking configuration scripts..."
  
  # Function to check and download if missing
  download_if_missing() {
    local url="$1"
    local destination="$2"
    
    if [[ ! -f "$destination" ]]; then
      verbose "Adding missing script: $destination"
      download_file "$url" "$destination"
    else
      verbose "Preserving existing script: $destination"
    fi
  }
  
  # Check for standard RC scripts
  download_if_missing "$GITHUB_RAW/rc-scripts/050_global_common_path.sh" "$RCFORGE_DIR/rc-scripts/050_global_common_path.sh"
  download_if_missing "$GITHUB_RAW/rc-scripts/210_global_bash_config.sh" "$RCFORGE_DIR/rc-scripts/210_global_bash_config.sh"
  download_if_missing "$GITHUB_RAW/rc-scripts/210_global_zsh_config.sh" "$RCFORGE_DIR/rc-scripts/210_global_zsh_config.sh"
  download_if_missing "$GITHUB_RAW/rc-scripts/350_global_bash_prompt.sh" "$RCFORGE_DIR/rc-scripts/350_global_bash_prompt.sh"
  download_if_missing "$GITHUB_RAW/rc-scripts/350_global_zsh_prompt.sh" "$RCFORGE_DIR/rc-scripts/350_global_zsh_prompt.sh"
  download_if_missing "$GITHUB_RAW/rc-scripts/400_global_common_aliases.sh" "$RCFORGE_DIR/rc-scripts/400_global_common_aliases.sh"
  
  # Upgrade system utilities but preserve user utilities
  info "Upgrading utility scripts..."
  download_file "$GITHUB_RAW/system/utils/httpheaders.sh" "$RCFORGE_DIR/system/utils/httpheaders.sh"
  
  # Update documentation
  info "Updating documentation..."
  download_file "$GITHUB_RAW/docs/README.md" "$RCFORGE_DIR/docs/README.md"
  
  # Update shell RC files if needed
  update_shell_rc
  
  success "Upgrade completed successfully!"
}

# Verify the installation
verify_installation() {
  section "Verifying Installation"
  
  # Check for critical files
  local missing_files=false
  
  # Define critical files
  local critical_files=(
    "$RCFORGE_DIR/rcforge.sh"
    "$RCFORGE_DIR/system/lib/shell-colors.sh"
    "$RCFORGE_DIR/system/lib/utility-functions.sh"
  )
  
  # Check each file
  for file in "${critical_files[@]}"; do
    if [[ ! -f "$file" ]]; then
      warning "Missing critical file: $file"
      missing_files=true
    else
      verbose "Verified file: $file"
    fi
  done
  
  # Check permissions
  if [[ "$(stat -c %a "$RCFORGE_DIR" 2>/dev/null || stat -f "%Lp" "$RCFORGE_DIR" 2>/dev/null)" != "700" ]]; then
    warning "Incorrect permissions on $RCFORGE_DIR. Expected: 700"
  else
    verbose "Correct permissions on main directory"
  fi
  
  # Final verdict
  if [[ "$missing_files" == "true" ]]; then
    warning "Installation verification detected issues."
    return 1
  else
    success "Installation verification passed!"
    return 0
  fi
}

# Display final instructions
show_instructions() {
  section "Installation Complete!"
  
  echo -e "${GREEN}rcForge v$RCFORGE_VERSION has been successfully installed!${RESET}"
  echo ""
  echo "To start using rcForge in your current shell session:"
  echo -e "  ${CYAN}source ~/.config/rcforge/rcforge.sh${RESET}"
  echo ""
  echo "For new shell sessions, rcForge will be loaded automatically."
  echo ""
  echo "Try these commands to get started:"
  echo -e "  ${CYAN}rc help${RESET}              # Show available commands"
  echo -e "  ${CYAN}rc httpheaders example.com${RESET}  # Test the HTTP headers utility"
  echo ""
  
  # Recommend version control
  echo -e "${YELLOW}Recommendation:${RESET} Consider storing your configurations in version control:"
  echo -e "  ${CYAN}git init ~/.config/rcforge${RESET}"
  echo -e "  ${CYAN}cd ~/.config/rcforge && git add . && git commit -m \"Initial setup\"${RESET}"
  echo ""
  
  echo -e "For more information, visit: ${BLUE}$GITHUB_REPO${RESET}"
  echo ""
}

# ============================================================================
# MAIN INSTALLATION FLOW
# ============================================================================

main() {
  # Process command-line arguments
  process_args "$@"
  
  # Display header
  section "rcForge Installer v$RCFORGE_VERSION"
  
  # Check Bash version
  check_bash_version
  
  # Determine installation mode
  if is_installed; then
    if [[ "$INSTALL_MODE" == "reinstall" ]]; then
      info "Performing reinstallation of rcForge..."
    else
      INSTALL_MODE="upgrade"
      info "Existing installation detected. Performing upgrade..."
    fi
  else
    info "Performing fresh installation of rcForge..."
  fi
  
  # Confirm installation unless --force is used
  if [[ "$FORCE" != "true" ]]; then
    read -p "Continue with $INSTALL_MODE? [Y/n] " response
    if [[ -n "$response" && ! "$response" =~ ^[Yy]$ ]]; then
      echo "Installation aborted by user."
      exit 0
    fi
  fi
  
  # Perform installation
  if [[ "$INSTALL_MODE" == "upgrade" ]]; then
    upgrade_install
  else
    # For fresh install or reinstall
    create_backup  # This will be skipped for fresh install automatically
    clean_install
  fi
  
  # Verify installation
  verify_installation
  
  # Display final instructions
  show_instructions
}

# Run the installer
main "$@"

# EOF
