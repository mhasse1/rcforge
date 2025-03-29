#!/bin/bash
# rcforge-setup.sh - Setup script for rcForge v0.2.0
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

# Detect script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the Bash version check
if [[ -f "$SCRIPT_DIR/../core/bash-version-check.sh" ]]; then
  source "$SCRIPT_DIR/../core/bash-version-check.sh"

  # Check version and disable include system if requirements not met
  if ! check_bash_version; then
    echo "For now, you can use your existing v0.1.x configuration, or run with a newer version of Bash."
    # Disable include system for older Bash versions
    RCFORGE_DISABLE_INCLUDE=1
    echo "Include system will be disabled due to Bash version requirement."
  fi
fi

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
  )

  for dir in "${possible_roots[@]}"; do
    if [[ -n "$dir" && -d "$dir" && -f "$dir/rcforge.sh" ]]; then
      echo "$dir"
      return 0
    fi
  done

  echo ""
  return 1
}

# Configuration directories
USER_DIR="$HOME/.config/rcforge"
USER_SCRIPTS_DIR="$USER_DIR/scripts"
USER_INCLUDE_DIR="$USER_DIR/include"
USER_EXPORTS_DIR="$USER_DIR/exports"
USER_DOCS_DIR="$USER_DIR/docs"

# Set up system directories based on location
if [[ -n "${RCFORGE_DEV:-}" ]]; then
  # Development mode
  SYS_DIR="$(detect_project_root)"
  if [[ -z "$SYS_DIR" ]]; then
    SYS_DIR="$HOME/src/rcforge"
  fi
  SYS_SCRIPTS_DIR="$SYS_DIR/scripts"
  SYS_INCLUDE_DIR="$SYS_DIR/include"
  SYS_LIB_DIR="$SYS_DIR/src/lib"
else
  # Find system directory
  SYS_DIR="$(detect_project_root)"
  
  if [[ -z "$SYS_DIR" ]]; then
    # Default to user directory if not found elsewhere
    SYS_DIR="$USER_DIR"
  fi
  
  SYS_SCRIPTS_DIR="$SYS_DIR/scripts"
  SYS_INCLUDE_DIR="$SYS_DIR/include"
  SYS_LIB_DIR="$SYS_DIR/src/lib"
fi

# Command line options
interactive=1
minimal=0
with_examples=1
shell_type=""
overwrite=0

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --minimal)
      minimal=1
      with_examples=0
      ;;
    --shell=*)
      shell_type="${1#*=}"
      ;;
    --non-interactive)
      interactive=0
      ;;
    --with-examples)
      with_examples=1
      ;;
    --no-examples)
      with_examples=0
      ;;
    --overwrite)
      overwrite=1
      ;;
    --help)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --minimal           Minimal installation (no examples)"
      echo "  --shell=bash|zsh    Specify shell type (defaults to auto-detect)"
      echo "  --non-interactive   Run without interactive prompts"
      echo "  --with-examples     Include example configurations (default)"
      echo "  --no-examples       Don't include example configurations"
      echo "  --overwrite         Overwrite existing files"
      echo "  --help              Show this help message"
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

# Display header
echo -e "${BLUE}┌──────────────────────────────────────────────────────┐${RESET}"
echo -e "${BLUE}│ rcForge v0.2.0 Setup                                 │${RESET}"
echo -e "${BLUE}└──────────────────────────────────────────────────────┘${RESET}"
echo ""

# Detect shell if not specified
if [[ -z "$shell_type" ]]; then
  if [[ -n "$ZSH_VERSION" ]]; then
    shell_type="zsh"
  elif [[ -n "$BASH_VERSION" ]]; then
    shell_type="bash"
  else
    # Fallback to checking $SHELL
    shell_type=$(basename "$SHELL")
  fi

  echo -e "${CYAN}Auto-detected shell: ${YELLOW}$shell_type${RESET}"
else
  echo -e "${CYAN}Using specified shell: ${YELLOW}$shell_type${RESET}"
fi

# Validate shell
if [[ "$shell_type" != "bash" && "$shell_type" != "zsh" ]]; then
  echo -e "${RED}Error: Unsupported shell: $shell_type${RESET}"
  echo "Supported shells: bash, zsh"
  exit 1
fi

# Get current username
current_user=$(whoami)

# Get current hostname
if command -v hostname >/dev/null 2>&1; then
  current_hostname=$(hostname | cut -d. -f1)
else
  # Fallback if hostname command not available
  current_hostname=${HOSTNAME:-$(uname -n | cut -d. -f1)}
fi

echo -e "${CYAN}Username: ${YELLOW}$current_user${RESET}"
echo -e "${CYAN}Hostname: ${YELLOW}$current_hostname${RESET}"
echo -e "${CYAN}System directory: ${YELLOW}$SYS_DIR${RESET}"
echo ""

# Check for existing installation
if [[ -d "$USER_DIR" ]]; then
  echo -e "${YELLOW}Existing rcForge installation found at $USER_DIR${RESET}"

  if [[ $interactive -eq 1 && $overwrite -eq 0 ]]; then
    echo -e "${YELLOW}Do you want to proceed and update your existing configuration? (y/n)${RESET}"
    read -r proceed

    if [[ ! "$proceed" =~ ^[Yy] ]]; then
      echo -e "${RED}Setup cancelled.${RESET}"
      exit 1
    fi
  fi
fi

# Create user directories
echo -e "${CYAN}Creating user directories...${RESET}"
mkdir -p "$USER_SCRIPTS_DIR"
mkdir -p "$USER_INCLUDE_DIR"
mkdir -p "$USER_EXPORTS_DIR"
mkdir -p "$USER_DOCS_DIR"
echo -e "${GREEN}✓ User directories created${RESET}"

# Set up include directory structure if it doesn't exist
if [[ ! -d "$USER_INCLUDE_DIR/path" ]]; then
  echo -e "${CYAN}Setting up include directory structure...${RESET}"
  
  # Check for include-structure.sh in multiple locations
  INCLUDE_STRUCTURE_SCRIPT=""
  for location in "$SYS_DIR/include-structure.sh" "$SCRIPT_DIR/../include-structure.sh" "$USER_DIR/include-structure.sh"; do
    if [[ -f "$location" ]]; then
      INCLUDE_STRUCTURE_SCRIPT="$location"
      break
    fi
  done
  
  if [[ -n "$INCLUDE_STRUCTURE_SCRIPT" ]]; then
    bash "$INCLUDE_STRUCTURE_SCRIPT"
    echo -e "${GREEN}✓ Include directory structure set up${RESET}"
  else
    echo -e "${YELLOW}Warning: include-structure.sh not found. Setting up basic include structure...${RESET}"
    # Create basic directory structure
    mkdir -p "$USER_INCLUDE_DIR/path"
    mkdir -p "$USER_INCLUDE_DIR/common"
    mkdir -p "$USER_INCLUDE_DIR/git"
    mkdir -p "$USER_INCLUDE_DIR/system"
    mkdir -p "$USER_INCLUDE_DIR/network"
    mkdir -p "$USER_INCLUDE_DIR/text"
    echo -e "${GREEN}✓ Basic include directory structure created${RESET}"
  fi
fi

# Modify shell RC files
update_rc_files() {
  local shell="$1"
  local rc_file="$HOME/.${shell}rc"

  echo -e "${CYAN}Checking ${shell} RC file...${RESET}"

  if [[ ! -f "$rc_file" ]]; then
    echo -e "${YELLOW}${shell}rc file not found, creating it...${RESET}"
    touch "$rc_file"
  fi

  # Check if rcforge already sourced
  if grep -q "rcforge.sh" "$rc_file"; then
    echo -e "${GREEN}✓ rcForge already sourced in ${shell}rc${RESET}"
  else
    echo -e "${CYAN}Adding rcForge to ${shell}rc...${RESET}"

    # Add to the end of file
    cat >> "$rc_file" << EOF

# Source rcForge configuration
if [[ -f "\$HOME/.config/rcforge/rcforge.sh" ]]; then
  source "\$HOME/.config/rcforge/rcforge.sh"
fi
EOF

    echo -e "${GREEN}✓ rcForge added to ${shell}rc${RESET}"
  fi
}

# Update the appropriate RC files
if [[ "$shell_type" == "bash" || "$shell_type" == "both" ]]; then
  update_rc_files "bash"
fi

if [[ "$shell_type" == "zsh" || "$shell_type" == "both" ]]; then
  update_rc_files "zsh"
fi

# Copy main rcforge script if it doesn't exist
if [[ ! -f "$USER_DIR/rcforge.sh" ]]; then
  echo -e "${CYAN}Copying main rcforge.sh script...${RESET}"

  # Look for the script in various locations
  RCFORGE_SCRIPT=""
  for location in "$SYS_DIR/rcforge.sh" "$SCRIPT_DIR/../rcforge.sh"; do
    if [[ -f "$location" ]]; then
      RCFORGE_SCRIPT="$location"
      break
    fi
  done

  if [[ -n "$RCFORGE_SCRIPT" ]]; then
    cp "$RCFORGE_SCRIPT" "$USER_DIR/"
    chmod +x "$USER_DIR/rcforge.sh"
    echo -e "${GREEN}✓ rcforge.sh copied${RESET}"
  else
    echo -e "${RED}Error: rcforge.sh not found in system directory${RESET}"
    echo "Expected locations: $SYS_DIR/rcforge.sh or $SCRIPT_DIR/../rcforge.sh"
    exit 1
  fi
fi

# Create instructions file
cat > "$USER_DOCS_DIR/README.md" << 'EOF'
# rcForge v0.2.0 User Guide

Welcome to rcForge! This guide will help you get started with your shell configuration.

## Directory Structure

```
~/.config/rcforge/
  ├── scripts/                # Your shell configuration scripts
  ├── include/                # Your custom include functions
  ├── rcforge.sh              # Main loader script
  ├── exports/                # Exported configurations for remote servers
  └── docs/                   # Documentation
```

## Configuration Files

Your configuration is organized in numbered script files in the `scripts/` directory.
The naming convention is:

```
###_[hostname|global]_[environment]_[description].sh
```

For example:
- `050_global_common_path.sh` - PATH configuration for all machines
- `300_global_bash_prompt.sh` - Bash prompt for all machines
- `500_laptop_common_vpn.sh` - VPN settings only for your laptop

## Working with rcForge

### Adding a new configuration

1. Create a new script file in the scripts directory following the naming convention
2. Make it executable with `chmod +x`

Example:
```bash
vim ~/.config/rcforge/scripts/400_global_common_functions.sh
chmod +x ~/.config/rcforge/scripts/400_global_common_functions.sh
```

### Using the include system

For frequently used functions, use the include system:

```bash
# Include specific functions
include_function path add_to_path
include_function git git_status

# Include all functions in a category
include_category common
```

### Creating a custom include function

Use the create-include.sh script:

```bash
~/.config/rcforge/utils/create-include.sh
```

### Exporting configuration for remote servers

```bash
~/.config/rcforge/utils/export-config.sh --shell=bash
```

## Updating

When updating rcForge, your user configurations will remain untouched. Only the system files will be updated.

## Further Documentation

For more information, see the full documentation in the docs directory.
EOF

echo -e "${GREEN}✓ Documentation created${RESET}"

echo -e "\n${GREEN}┌──────────────────────────────────────────────────────┐${RESET}"
echo -e "${GREEN}│ rcForge Setup Complete                                │${RESET}"
echo -e "${GREEN}└──────────────────────────────────────────────────────┘${RESET}"
echo ""
echo -e "${YELLOW}To start using rcForge:${RESET}"
echo "1. Start a new shell session"
echo "2. Or source your shell RC file:"
echo "   source ~/.${shell_type}rc"
echo ""
echo -e "${YELLOW}Your configuration files are in:${RESET}"
echo "  $USER_SCRIPTS_DIR"
echo ""
echo -e "${YELLOW}Documentation:${RESET}"
echo "  $USER_DOCS_DIR/README.md"
echo ""
echo -e "${BLUE}Happy scripting! 🚀${RESET}"
# EOF
