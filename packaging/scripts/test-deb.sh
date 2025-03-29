#!/bin/bash
# test-deb.sh - Build and test the Debian package locally
# This script builds the Debian package and verifies its contents

set -e  # Exit on error

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'  # Reset color

# Determine the project root (where this repo is)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo -e "${BLUE}┌──────────────────────────────────────────────────────┐${RESET}"
echo -e "${BLUE}│ rcForge Debian Package Test                          │${RESET}"
echo -e "${BLUE}└──────────────────────────────────────────────────────┘${RESET}"
echo ""

# Check if debian directory exists
if [[ ! -d "$PROJECT_ROOT/debian" ]]; then
  echo -e "${RED}Error: debian directory not found at $PROJECT_ROOT/debian${RESET}"
  exit 1
fi

# Check for required packages
echo -e "${CYAN}Checking for required packages...${RESET}"
required_packages=("devscripts" "debhelper" "build-essential" "fakeroot")
missing_packages=()

for pkg in "${required_packages[@]}"; do
  if ! dpkg -l | grep -q "ii  $pkg "; then
    missing_packages+=("$pkg")
  fi
done

if [[ ${#missing_packages[@]} -gt 0 ]]; then
  echo -e "${YELLOW}The following packages are required but not installed:${RESET}"
  for pkg in "${missing_packages[@]}"; do
    echo "  - $pkg"
  done
  
  echo -e "${YELLOW}Install them with:${RESET}"
  echo "  sudo apt-get install ${missing_packages[*]}"
  
  read -p "Do you want to install them now? (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo apt-get update
    sudo apt-get install -y "${missing_packages[@]}"
  else
    echo -e "${RED}Aborting as required packages are missing.${RESET}"
    exit 1
  fi
fi

# Change to project root
cd "$PROJECT_ROOT"

# Build the package
echo -e "${CYAN}Building Debian package...${RESET}"
dpkg-buildpackage -us -uc -b

# Check if the package was built
DEB_FILE=$(find .. -maxdepth 1 -name "rcforge_*.deb" | sort -V | tail -n 1)

if [[ -f "$DEB_FILE" ]]; then
  echo -e "${GREEN}✓ Package built successfully: ${YELLOW}$DEB_FILE${RESET}"
  
  # Display package information
  echo -e "${CYAN}Package information:${RESET}"
  dpkg-deb --info "$DEB_FILE"
  
  # Display package contents
  echo -e "${CYAN}Package contents:${RESET}"
  dpkg-deb --contents "$DEB_FILE"
  
  # Offer to install the package
  read -p "Do you want to install the package locally for testing? (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${CYAN}Installing package...${RESET}"
    sudo dpkg -i "$DEB_FILE" || {
      echo -e "${YELLOW}Fixing dependencies...${RESET}"
      sudo apt-get -f install -y
    }
    
    echo -e "${GREEN}✓ Installation completed.${RESET}"
    echo -e "${YELLOW}You can now test the installed package.${RESET}"
    echo ""
    echo -e "${YELLOW}To uninstall:${RESET}"
    echo "  sudo dpkg -r rcforge"
  else
    echo -e "${YELLOW}Package not installed. You can install it manually with:${RESET}"
    echo "  sudo dpkg -i $DEB_FILE"
  fi
else
  echo -e "${RED}Error: Package build failed. See above for errors.${RESET}"
  exit 1
fi

# Cleanup
echo -e "${CYAN}Cleaning build files...${RESET}"
read -p "Do you want to clean up build files? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  rm -f "../rcforge_"*".deb" "../rcforge_"*".buildinfo" "../rcforge_"*".changes"
  echo -e "${GREEN}✓ Build files cleaned up.${RESET}"
else
  echo -e "${YELLOW}Build files kept.${RESET}"
fi

echo ""
echo -e "${GREEN}Debian package test completed.${RESET}"
