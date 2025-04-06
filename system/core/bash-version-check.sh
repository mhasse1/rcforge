#!/usr/bin/env bash
# bash-version-check.sh - Check Bash version compatibility for rcForge
# Author: rcForge Team
# Date: 2025-04-05
# Version: 0.3.0
# RC Summary: Check if Bash version meets system requirements
# Description: Validates Bash version compatibility for rcForge and provides upgrade instructions

# Source required libraries
if [[ -f "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/shell-colors.sh" ]]; then
  source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/shell-colors.sh"
else
  # Minimal color definitions if shell-colors.sh is not available
  export RED='\033[0;31m'
  export GREEN='\033[0;32m'
  export YELLOW='\033[0;33m'
  export BLUE='\033[0;34m'
  export CYAN='\033[0;36m'
  export RESET='\033[0m'
  
  # Minimal message functions
  ErrorMessage() { echo -e "${RED}ERROR:${RESET} $1" >&2; }
  WarningMessage() { echo -e "${YELLOW}WARNING:${RESET} $1" >&2; }
  InfoMessage() { echo -e "${BLUE}INFO:${RESET} $1"; }
  SuccessMessage() { echo -e "${GREEN}SUCCESS:${RESET} $1"; }
fi

# Set strict error handling
set -o nounset  # Treat unset variables as errors
set -o errexit  # Exit immediately if a command exits with a non-zero status

# Global constants
readonly gc_required_bash_version="4.0"
readonly gc_app_name="rcForge"
readonly gc_version="${RCFORGE_VERSION:-0.3.0}"

# ============================================================================
# VERSION CHECKING FUNCTIONS
# ============================================================================

# Function: CheckBashVersion
# Description: Validate Bash version compatibility
# Usage: CheckBashVersion [optional_minimum_version]
# Returns: 0 if version meets requirements, 1 if not
CheckBashVersion() {
  local min_version="${1:-$gc_required_bash_version}"
  
  # Check if using Bash
  if [[ -z "${BASH_VERSION:-}" ]]; then
    WarningMessage "Not running in Bash shell. Current shell: $(basename "$SHELL")"
    return 1
  fi

  # Extract major version number
  local major_version=${BASH_VERSION%%.*}
  local minor_version
  minor_version=$(echo "$BASH_VERSION" | sed -n 's/^[0-9]*\.\([0-9]*\).*/\1/p')
  
  # Log information if debug mode is on
  if [[ "${UTILITY_DEBUG_MODE:-false}" == "true" ]]; then
    echo "Checking Bash version:"
    echo "  Required: $min_version+"
    echo "  Current:  $BASH_VERSION (Major: $major_version, Minor: $minor_version)"
  fi
  
  # Compare versions (simple major version check)
  local min_major
  min_major=$(echo "$min_version" | cut -d. -f1)
  
  if [[ "$major_version" -lt "$min_major" ]]; then
    return 1
  fi
  
  return 0
}

# Function: DisplayUpgradeInstructions
# Description: Provide OS-specific instructions for upgrading Bash
# Usage: DisplayUpgradeInstructions
DisplayUpgradeInstructions() {
  local os
  if [[ "$(uname)" == "Darwin" ]]; then
    os="macOS"
  elif [[ "$(uname)" == "Linux" ]]; then
    os="Linux"
  else
    os="Unknown"
  fi
  
  echo "Upgrade instructions for $os:"
  echo ""
  
  case "$os" in
    macOS)
      echo "1. Install Homebrew if not already installed:"
      echo '   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
      echo ""
      echo "2. Install Bash with Homebrew:"
      echo "   brew install bash"
      echo ""
      echo "3. Add the new Bash to allowed shells:"
      echo "   sudo bash -c 'echo $(brew --prefix)/bin/bash >> /etc/shells'"
      echo ""
      echo "4. Change your default shell (optional):"
      echo "   chsh -s $(brew --prefix)/bin/bash"
      ;;
    Linux)
      echo "Most Linux distributions have Bash 4.0+ available in their package repositories."
      echo ""
      echo "For Debian/Ubuntu:"
      echo "   sudo apt update && sudo apt install bash"
      echo ""
      echo "For Fedora/RHEL/CentOS:"
      echo "   sudo dnf install bash"
      echo ""
      echo "For Arch Linux:"
      echo "   sudo pacman -S bash"
      ;;
    *)
      echo "Please check your system's package manager or build from source:"
      echo "https://www.gnu.org/software/bash/"
      ;;
  esac
}

# Function: FindBashInstallations
# Description: Look for existing Bash installations on the system
# Usage: FindBashInstallations
# Returns: List of Bash executables with their versions
FindBashInstallations() {
  local common_paths=(
    "/bin/bash"
    "/usr/bin/bash"
    "/usr/local/bin/bash"
    "/opt/homebrew/bin/bash"
    "$(brew --prefix 2>/dev/null)/bin/bash"
  )
  
  echo "Looking for Bash installations on your system:"
  echo ""
  
  local found_compatible=false
  
  for path in "${common_paths[@]}"; do
    if [[ -x "$path" ]]; then
      local version
      version=$("$path" --version | head -n 1 | sed 's/.*version \([0-9]*\.[0-9]*\).*/\1/')
      
      printf "%-25s: %s" "$path" "$version"
      
      # Check if this version is compatible
      if [[ "$(echo "$version" | cut -d. -f1)" -ge "$(echo "$gc_required_bash_version" | cut -d. -f1)" ]]; then
        echo " ✓ (compatible)"
        found_compatible=true
      else
        echo " ✗ (not compatible)"
      fi
    fi
  done
  
  if [[ "$found_compatible" == "true" ]]; then
    echo ""
    echo "You have at least one compatible Bash installation."
    echo "If it's not your default shell, you can use it with rcForge by setting SHELL to the path."
  else
    echo ""
    echo "No compatible Bash installations found. Please upgrade."
  fi
}

# ============================================================================
# COMMAND LINE INTERFACE
# ============================================================================

# Function: ShowSummary
# Description: Display one-line summary for rc help
# Usage: ShowSummary
ShowSummary() {
  echo "Check if Bash version meets system requirements"
}

# Function: ShowHelp
# Description: Display help information
# Usage: ShowHelp
ShowHelp() {
  echo "bash-version-check - Check Bash version compatibility for ${gc_app_name}"
  echo ""
  echo "Description:"
  echo "  Validates if your Bash version is compatible with ${gc_app_name} v${gc_version}"
  echo "  and provides upgrade instructions if needed."
  echo ""
  echo "Usage:"
  echo "  rc bash-version-check [options]"
  echo ""
  echo "Options:"
  echo "  --help, -h     Show this help message"
  echo "  --summary      Show a one-line description (for rc help)"
  echo "  --list         List all Bash installations found on system"
  echo "  --verbose, -v  Show detailed output"
  echo ""
  echo "Examples:"
  echo "  rc bash-version-check       # Check if current Bash is compatible"
  echo "  rc bash-version-check --list # List all Bash installations"
}

# ============================================================================
# MAIN FUNCTIONALITY
# ============================================================================

# Main function to execute when script is run
main() {
  local verbose=false
  local list_bash=false
  
  # Process command-line arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        ShowHelp
        return 0
        ;;
      --summary)
        ShowSummary
        return 0
        ;;
      --verbose|-v)
        verbose=true
        ;;
      --list)
        list_bash=true
        ;;
      *)
        ErrorMessage "Unknown option: $1"
        echo "Use --help to see available options."
        return 1
        ;;
    esac
    shift
  done
  
  # Display header
  SectionHeader "Bash Version Compatibility Check"
  
  # List Bash installations if requested
  if [[ "$list_bash" == "true" ]]; then
    FindBashInstallations
    return 0
  fi
  
  # Display current Bash information
  echo "Current Bash version: ${BASH_VERSION:-Not running Bash}"
  echo "Required version:     ${gc_required_bash_version}+"
  echo ""
  
  # Check Bash version compatibility
  if CheckBashVersion "${gc_required_bash_version}"; then
    SuccessMessage "Your Bash version is compatible with ${gc_app_name} v${gc_version}!"
    return 0
  else
    ErrorMessage "Your Bash version is not compatible with ${gc_app_name} v${gc_version}"
    echo ""
    echo "While rcForge will attempt to function with limited capabilities,"
    echo "many advanced features require Bash ${gc_required_bash_version} or higher."
    echo ""
    
    # Display upgrade instructions
    DisplayUpgradeInstructions
    
    # List existing Bash installations if verbose mode
    if [[ "$verbose" == "true" ]]; then
      echo ""
      FindBashInstallations
    else
      echo ""
      echo "Use --list to see all Bash installations on your system."
    fi
    
    return 1
  fi
}

# Execute main function if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
  exit $?
elif [[ "${BASH_SOURCE[0]}" != "${0}" && "$0" == *"rc"* ]]; then
  # Also execute if called via the rc command
  main "$@"
  exit $?
fi

# Export functions for sourcing
export -f CheckBashVersion
export -f DisplayUpgradeInstructions
export -f FindBashInstallations
export -f ShowSummary
export -f ShowHelp

# EOF
