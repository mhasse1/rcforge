#!/bin/bash
# check-checksums.sh - Verifies checksums of shell RC files

set -e  # Exit on error

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'  # Reset color

# Detect script directory and parent
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# Detect project root dynamically
detect_project_root() {
  local possible_roots=(
    "${RCFORGE_ROOT}"                  # Explicitly set environment variable
    "${PARENT_DIR}"                    # Parent of script directory
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

# Detect if we're running in development mode
if [[ -n "${RCFORGE_DEV:-}" ]]; then
  # Development mode
  RCFORGE_DIR=$(detect_project_root)
else 
  # Production mode - Default to user configuration directory
  RCFORGE_DIR="$HOME/.config/rcforge"
  
  # Check if running from system installation
  if [[ "$SCRIPT_DIR" == "/usr/share/rcforge/core" || 
        "$SCRIPT_DIR" == "/opt/homebrew/share/rcforge/core" || 
        "$SCRIPT_DIR" == "/opt/local/share/rcforge/core" || 
        "$SCRIPT_DIR" == "/usr/local/share/rcforge/core" ]]; then
    # Still use user's config directory for checksums
    RCFORGE_DIR="$HOME/.config/rcforge"
  fi
fi

CHECKSUM_DIR="${RCFORGE_DIR}/checksums"

# Define the paths for shell RC files and their checksums
BASHRC="${HOME}/.bashrc"
ZSHRC="${HOME}/.zshrc"
BASH_CHECKSUM="${CHECKSUM_DIR}/bashrc.md5"
ZSH_CHECKSUM="${CHECKSUM_DIR}/zshrc.md5"

# Parse command line arguments
fix_checksums=0

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --fix)
      fix_checksums=1
      ;;
    --help)
      echo "Usage: $0 [--fix]"
      echo ""
      echo "Options:"
      echo "  --fix    Update checksum files to match current RC files"
      echo "  --help   Show this help message"
      echo ""
      exit 0
      ;;
    *)
      echo "Unknown parameter: $1"
      echo "Use --help for usage information."
      exit 1
      ;;
  esac
  shift
done

# Create checksum directory if it doesn't exist
mkdir -p "$CHECKSUM_DIR"

# Function to detect current shell
detect_shell() {
  if [[ -n "$ZSH_VERSION" ]]; then
    echo "zsh"
  elif [[ -n "$BASH_VERSION" ]]; then
    echo "bash"
  else
    # Fallback to checking $SHELL
    basename "$SHELL"
  fi
}

# Function to calculate checksum of a file
calculate_checksum() {
  local file="$1"
  
  if [[ ! -f "$file" ]]; then
    echo "NONE"
    return 1
  fi
  
  if [[ "$(uname -s)" == "Darwin" ]]; then
    # macOS uses md5 instead of md5sum
    md5 -q "$file" 2>/dev/null
  else
    # Linux and other Unix-like systems
    md5sum "$file" 2>/dev/null | awk '{ print $1 }'
  fi
}

# Function to display a nice warning header
display_warning_header() {
  echo
  echo -e "${YELLOW}██████╗  █████╗ ██████╗      ██████╗██╗  ██╗██╗  ██╗███████╗██╗   ██╗███╗   ███╗${RESET}"
  echo -e "${YELLOW}██╔══██╗██╔══██╗██╔══██╗    ██╔════╝██║  ██║██║ ██╔╝██╔════╝██║   ██║████╗ ████║${RESET}"
  echo -e "${YELLOW}██████╔╝███████║██║  ██║    ██║     ███████║█████╔╝ ███████╗██║   ██║██╔████╔██║${RESET}"
  echo -e "${YELLOW}██╔══██╗██╔══██║██║  ██║    ██║     ██╔══██║██╔═██╗ ╚════██║██║   ██║██║╚██╔╝██║${RESET}"
  echo -e "${YELLOW}██████╔╝██║  ██║██████╔╝    ╚██████╗██║  ██║██║  ██╗███████║╚██████╔╝██║ ╚═╝ ██║${RESET}"
  echo -e "${YELLOW}╚═════╝ ╚═╝  ╚═╝╚═════╝      ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═╝     ╚═╝${RESET}"
  echo
}

# Function to verify a checksum and handle any mismatch
verify_checksum() {
  local rc_file="$1"
  local sum_file="$2"
  local rc_name="$3"
  
  # Skip if the RC file doesn't exist
  if [[ ! -f "$rc_file" ]]; then
    return 0
  fi
  
  # Initialize checksums if they don't exist
  if [[ ! -f "$sum_file" ]]; then
    # Create initial checksum file
    current_sum=$(calculate_checksum "$rc_file")
    echo "$current_sum" > "$sum_file"
    return 0
  fi
  
  # Get stored and current checksums
  stored_sum=$(cat "$sum_file")
  current_sum=$(calculate_checksum "$rc_file")
  
  # Compare checksums
  if [[ "$stored_sum" != "$current_sum" ]]; then
    display_warning_header
    echo -e "${YELLOW}File changed: $rc_name${RESET}"
    echo -e "${YELLOW}Current shell: $(detect_shell)${RESET}"
    echo -e "${YELLOW}Expected checksum: $stored_sum${RESET}"
    echo -e "${YELLOW}Actual checksum: $current_sum${RESET}"
    echo

    # Update the checksum if requested
    if [[ $fix_checksums -eq 1 ]]; then
      echo "$current_sum" > "$sum_file"
      echo -e "${GREEN}✓ Updated checksum for $rc_name${RESET}"
    else
      echo -e "${YELLOW}To update the checksum, run:${RESET}"
      echo "  $0 --fix"
    fi
    
    return 1
  fi
  
  return 0
}

# Verify both RC files
any_mismatch=0

verify_checksum "$BASHRC" "$BASH_CHECKSUM" ".bashrc"
if [[ $? -eq 1 ]]; then
  any_mismatch=1
fi

verify_checksum "$ZSHRC" "$ZSH_CHECKSUM" ".zshrc"
if [[ $? -eq 1 ]]; then
  any_mismatch=1
fi

# Exit with status code
exit $any_mismatch
# EOF
