#!/bin/bash
# check-bash-version.sh - Checks if Bash version meets requirements for rcForge v0.2.0
# Author: Mark Hasse
# Date: March 27, 2025

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'  # Reset color

# Detect script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect project root dynamically
detect_project_root() {
  local possible_roots=(
    "${RCFORGE_ROOT}"                  # Explicitly set environment variable
    "$(dirname "$SCRIPT_DIR")"         # Parent of script directory
    "$HOME/src/rcforge"                # Common developer location
    "$HOME/Projects/rcforge"           # Alternative project location
    "$HOME/Development/rcforge"        # Another alternative
    "/usr/share/rcforge"               # System-wide location (Linux/Debian)
    "/opt/homebrew/share/rcforge"      # Homebrew on Apple Silicon
    "$(brew --prefix 2>/dev/null)/share/rcforge" # Homebrew (generic)
    "/opt/local/share/rcforge"         # MacPorts
    "/usr/local/share/rcforge"         # Alternative system location
    "$HOME/.config/rcforge"            # User configuration directory
  )

  for dir in "${possible_roots[@]}"; do
    if [[ -n "$dir" && -d "$dir" && -f "$dir/rcforge.sh" ]]; then
      echo "$dir"
      return 0
    fi
  done

  # If not found, default to user configuration directory
  echo "$HOME/.config/rcforge"
  return 0
}

# Detect paths
if [[ -n "${RCFORGE_DEV:-}" ]]; then
  # Development mode
  RCFORGE_DIR=$(detect_project_root)
  RCFORGE_CORE="$RCFORGE_DIR/core"
else
  # Production mode
  RCFORGE_DIR=$(detect_project_root)
  RCFORGE_CORE="$RCFORGE_DIR/core"
fi

# Display header
echo -e "${BLUE}┌──────────────────────────────────────────────────────┐${RESET}"
echo -e "${BLUE}│ rcForge v0.2.0 Bash Version Check                    │${RESET}"
echo -e "${BLUE}└──────────────────────────────────────────────────────┘${RESET}"
echo ""

# Source the Bash version check library
if [[ -f "$RCFORGE_CORE/bash-version-check.sh" ]]; then
  source "$RCFORGE_CORE/bash-version-check.sh"
else
  echo -e "${RED}Error: Could not find bash-version-check.sh${RESET}"
  echo "Expected location: $RCFORGE_CORE/bash-version-check.sh"
  exit 1
fi

# Check for Bash
if [[ -z "$BASH_VERSION" ]]; then
  echo -e "${YELLOW}Warning: You're not using Bash. Current shell seems to be: ${CYAN}$(basename "$SHELL")${RESET}"
  echo ""
  echo -e "${YELLOW}rcForge v0.2.0 requires Bash 4.0+ or Zsh 5.0+ for full functionality.${RESET}"
  echo ""
  exit 0
fi

# Parse Bash version for display purposes
bash_major=${BASH_VERSION%%.*}
bash_rest=${BASH_VERSION#*.}
bash_minor=${bash_rest%%.*}

echo -e "${CYAN}Current Bash version: ${YELLOW}$BASH_VERSION${RESET}"
echo -e "${CYAN}Required version:    ${YELLOW}4.0 or higher${RESET}"
echo ""

# Check which bash is being used
current_bash=$(which bash)
echo -e "${CYAN}Current Bash binary: ${YELLOW}$current_bash${RESET}"

# Check for other Bash installations
echo -e "${CYAN}Other Bash installations:${RESET}"
found_other=0

# Check common locations
check_bash() {
  local path="$1"
  if [[ -x "$path" ]]; then
    found_other=1
    local version=$("$path" --version | head -n 1 | sed 's/.*version \([0-9]*\.[0-9]*\).*/\1/')
    echo -e "  ${YELLOW}$path${RESET} - version ${CYAN}$version${RESET}"
  fi
}

check_bash "/opt/homebrew/bin/bash"
check_bash "/usr/local/bin/bash"
check_bash "/bin/bash"
check_bash "/usr/bin/bash"

if [[ $found_other -eq 0 ]]; then
  echo -e "  ${YELLOW}No alternative Bash installations found${RESET}"
fi

echo ""

# Check for Homebrew
if command -v brew >/dev/null 2>&1; then
  echo -e "${CYAN}Homebrew is installed:${RESET} ${GREEN}Yes${RESET}"
  homebrew_bash=$(brew --prefix)/bin/bash
  if [[ -x "$homebrew_bash" ]]; then
    hb_version=$("$homebrew_bash" --version | head -n 1 | sed 's/.*version \([0-9]*\.[0-9]*\).*/\1/')
    echo -e "${CYAN}Homebrew Bash:${RESET} ${YELLOW}$homebrew_bash${RESET} - version ${CYAN}$hb_version${RESET}"
  else
    echo -e "${CYAN}Homebrew Bash:${RESET} ${RED}Not installed${RESET}"
  fi
else
  echo -e "${CYAN}Homebrew is installed:${RESET} ${RED}No${RESET}"
fi

echo ""

# Check if the version meets the requirements
if [[ "$bash_major" -lt 4 ]]; then
  echo -e "${RED}Your Bash version ($BASH_VERSION) does not meet the requirements for rcForge v0.2.0.${RESET}"
  echo -e "${RED}The include system requires Bash 4.0 or higher.${RESET}"
  echo ""
  echo -e "${YELLOW}Recommendations:${RESET}"

  if command -v brew >/dev/null 2>&1; then
    echo -e "1. Install/update Bash via Homebrew:"
    echo "   brew install bash"
    echo ""
  else
    echo -e "1. Install Homebrew (https://brew.sh):"
    echo '   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    echo ""
    echo "   Then install Bash:"
    echo "   brew install bash"
    echo ""
  fi

  echo "2. Add the new Bash to your available shells:"
  echo "   sudo bash -c 'echo $(brew --prefix)/bin/bash >> /etc/shells'"
  echo ""
  echo "3. Change your default shell to the new Bash (optional):"
  echo "   chsh -s $(brew --prefix)/bin/bash"
  echo ""
  echo -e "${YELLOW}For now, you can run rcForge scripts with the newer Bash:${RESET}"

  if [[ -x "/opt/homebrew/bin/bash" ]]; then
    echo "   /opt/homebrew/bin/bash ~/.config/rcforge/rcforge.sh"
  elif [[ -x "/usr/local/bin/bash" ]]; then
    echo "   /usr/local/bin/bash ~/.config/rcforge/rcforge.sh"
  fi
else
  echo -e "${GREEN}✓ Your Bash version meets the requirements for rcForge v0.2.0!${RESET}"
  echo -e "${GREEN}✓ The include system should work properly with your current Bash.${RESET}"
  echo ""
  echo -e "${CYAN}If you encounter any issues, please report them on GitHub.${RESET}"
fi

echo ""
# EOF
