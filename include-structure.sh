#!/bin/bash
# include-structure.sh - Sets up the include file structure for rcForge v2
# Author: Mark Hasse
# Date: March 27, 2025

set -e  # Exit on error

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'  # Reset color

if [[ -f "$RCFORGE_CORE/bash-version-check.sh" ]]; then
  source "$RCFORGE_CORE/bash-version-check.sh"

  # Exit if requirements not met
  if ! check_bash_version; then
    echo -e "${YELLOW}For now, you can run this script with a newer version of Bash:${RESET}"
    echo "  /opt/homebrew/bin/bash $(basename "$0")"
    exit 1
  fi
else
  echo "Warning: Could not find bash-version-check.sh"
  # Add fallback check here if needed
fi

# Call the function to check Bash version
check_bash_version

# Detect project root dynamically
# Prioritize environment variable, then common locations
detect_project_root() {
  local possible_roots=(
    "$RCFORGE_ROOT"                  # Explicitly set environment variable
    "$HOME/src/rcforge"              # Common developer location (macOS/Linux)
    "$HOME/Projects/rcforge"         # Alternative project location
    "$HOME/Development/rcforge"      # Another alternative
    "/opt/src/rcforge"               # System-wide location
  )

  for root in "${possible_roots[@]}"; do
    if [[ -d "$root" && -f "$root/rcforge.sh" ]]; then
      echo "$root"
      return 0
    fi
  done

  # If no known location found, ask user
  echo -e "${YELLOW}Could not automatically detect project root.${RESET}"
  echo -e "${YELLOW}Please specify the rcForge project root directory:${RESET}"
  read -r user_root

  if [[ -d "$user_root" && -f "$user_root/rcforge.sh" ]]; then
    echo "$user_root"
    return 0
  else
    echo -e "${RED}Invalid project root. Please check the directory.${RESET}"
    return 1
  fi
}

# Detect if we're running in development mode
if [[ -n "${RCFORGE_DEV}" ]]; then
  # Development mode
  RCFORGE_DIR=$(detect_project_root)
  if [[ -z "$RCFORGE_DIR" ]]; then
    echo -e "${RED}Failed to detect project root in development mode.${RESET}"
    exit 1
  fi

  SYS_INCLUDE_DIR="$RCFORGE_DIR/include"
  SYS_LIB_DIR="$RCFORGE_DIR/src/lib"
else
  # Production mode - System level
  if [[ -d "/usr/share/rcforge" ]]; then
    RCFORGE_SYS_DIR="/usr/share/rcforge"
  else
    # Fallback to user config directory
    RCFORGE_SYS_DIR="$HOME/.config/rcforge"
  fi

  SYS_INCLUDE_DIR="$RCFORGE_SYS_DIR/include"
  SYS_LIB_DIR="$RCFORGE_SYS_DIR/lib"
fi

# User level directories
USER_DIR="$HOME/.config/rcforge"
USER_INCLUDE_DIR="$USER_DIR/include"

# Display header
echo -e "${BLUE}┌──────────────────────────────────────────────────────┐${RESET}"
echo -e "${BLUE}│ rcForge Include System Setup                         │${RESET}"
echo -e "${BLUE}└──────────────────────────────────────────────────────┘${RESET}"
echo ""

echo -e "${CYAN}Setting up include directory structure...${RESET}"
echo -e "${CYAN}System include directory: ${YELLOW}$SYS_INCLUDE_DIR${RESET}"
echo -e "${CYAN}User include directory: ${YELLOW}$USER_INCLUDE_DIR${RESET}"
echo ""

# Create system include directory if it doesn't exist
if [[ ! -d "$SYS_INCLUDE_DIR" ]]; then
  mkdir -p "$SYS_INCLUDE_DIR"
  echo -e "${GREEN}✓ Created system include directory${RESET}"
else
  echo -e "${GREEN}✓ System include directory already exists${RESET}"
fi

# Create user include directory if it doesn't exist
if [[ ! -d "$USER_INCLUDE_DIR" ]]; then
  mkdir -p "$USER_INCLUDE_DIR"
  echo -e "${GREEN}✓ Created user include directory${RESET}"
else
  echo -e "${GREEN}✓ User include directory already exists${RESET}"
fi

# Create system lib directory if it doesn't exist
if [[ ! -d "$SYS_LIB_DIR" ]]; then
  mkdir -p "$SYS_LIB_DIR"
  echo -e "${GREEN}✓ Created system lib directory${RESET}"
else
  echo -e "${GREEN}✓ System lib directory already exists${RESET}"
fi

# Define include categories with priority for system organization
include_categories=(
  "path"       # Path manipulation
  "common"     # Common utility functions
  "git"        # Git-related functions
  "network"    # Network utilities
  "system"     # System information
  "text"       # Text processing
  "web"        # Web-related functions
  "dev"        # Development tools
  "security"   # Security-related functions
  "tools"      # Miscellaneous tools
)

echo -e "\n${CYAN}Creating include categories...${RESET}"
for category in "${include_categories[@]}"; do
  category_dir="$SYS_INCLUDE_DIR/$category"
  if [[ ! -d "$category_dir" ]]; then
    mkdir -p "$category_dir"
    echo -e "${GREEN}✓ Created category: $category${RESET}"
  else
    echo -e "${GREEN}✓ Category already exists: $category${RESET}"
  fi
done

# (Rest of the script remains the same as in the previous version)
# ... [include the rest of the original script content]
