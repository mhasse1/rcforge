# Function to check if script is being run as root
# Usage: check_root [--skip-interactive]
# Returns: 0 if not root, 1 if root
check_root() {
  # Check if UID is 0 (root)
  if [[ $EUID -eq 0 || $(id -u) -eq 0 ]]; then
    # Check if we're running with sudo
    local sudo_user="${SUDO_USER:-}"
    local username="${sudo_user:-$USER}"
    
    # Allow skipping the interactive prompt with --skip-interactive
    if [[ "$1" != "--skip-interactive" ]]; then
      display_warning_header
      echo -e "${RED}Error: This script should not be run as root or with sudo.${RESET}"
      echo -e "${YELLOW}Running shell configuration tools as root can create files with"
      echo -e "incorrect permissions and cause security issues.${RESET}"
      echo
      echo -e "Please run this script as a regular user: ${CYAN}${username}${RESET}"
      echo
      echo -e "${YELLOW}If you understand the risks and still want to proceed,"
      echo -e "set the RCFORGE_ALLOW_ROOT=1 environment variable:${RESET}"
      echo
      echo -e "  ${CYAN}RCFORGE_ALLOW_ROOT=1 $0 $*${RESET}"
      echo
    fi
    
    # Check for override environment variable
    if [[ -n "${RCFORGE_ALLOW_ROOT:-}" ]]; then
      echo -e "${YELLOW}Warning: Running as root due to RCFORGE_ALLOW_ROOT override.${RESET}"
      echo -e "${YELLOW}This is not recommended for security reasons.${RESET}"
      echo
      return 0  # Allow execution to continue
    fi
    
    # Exit with error status if root
    return 1
  fi
  
  # Not root, allow execution to continue
  return 0
}

export -f check_root
