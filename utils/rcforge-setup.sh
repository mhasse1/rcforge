#!/bin/bash
# install-rcforge.sh - Installs the rcForge system

set -e  # Exit on error

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'  # Reset color

# Source and destination directories
RCFORGE_DIR="$HOME/.config/rcforge"
BACKUP_DIR="$HOME/.config/rcforge-backup-$(date +%Y%m%d%H%M%S)"

# Command line options
MINIMAL=0
WITH_EXAMPLES=1
SHELL_TYPE=""
OVERWRITE=0
INTERACTIVE=1

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --minimal)
      MINIMAL=1
      WITH_EXAMPLES=0
      ;;
    --shell=*)
      SHELL_TYPE="${1#*=}"
      ;;
    --non-interactive)
      INTERACTIVE=0
      ;;
    --with-examples)
      WITH_EXAMPLES=1
      ;;
    --no-examples)
      WITH_EXAMPLES=0
      ;;
    --overwrite)
      OVERWRITE=1
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

echo -e "${BLUE}┌──────────────────────────────────────────────────────┐${RESET}"
echo -e "${BLUE}│ rcForge v0.2.0 Installation                          │${RESET}"
echo -e "${BLUE}└──────────────────────────────────────────────────────┘${RESET}"
echo ""

# Detect shell if not specified
if [[ -z "$SHELL_TYPE" ]]; then
  if [[ -n "$ZSH_VERSION" ]]; then
    SHELL_TYPE="zsh"
  elif [[ -n "$BASH_VERSION" ]]; then
    SHELL_TYPE="bash"
  else
    # Fallback to checking $SHELL
    SHELL_TYPE=$(basename "$SHELL")
  fi

  echo -e "${CYAN}Auto-detected shell: ${YELLOW}$SHELL_TYPE${RESET}"
else
  echo -e "${CYAN}Using specified shell: ${YELLOW}$SHELL_TYPE${RESET}"
fi

# Validate shell
if [[ "$SHELL_TYPE" != "bash" && "$SHELL_TYPE" != "zsh" ]]; then
  echo -e "${RED}Error: Unsupported shell: $SHELL_TYPE${RESET}"
  echo "Supported shells: bash, zsh"
  exit 1
fi

# Detect project root dynamically
detect_project_root() {
  local possible_roots=(
    "${RCFORGE_ROOT}"                  # Explicitly set environment variable
    "$(dirname "$(dirname "$0")")"     # Assuming script is in utils/ directory
    "$HOME/src/rcforge"                # Common developer location
    "$HOME/Projects/rcforge"           # Alternative project location
    "/usr/share/rcforge"               # System installation (Linux/Debian)
    "/opt/homebrew/share/rcforge"      # Homebrew on Apple Silicon
    "$(brew --prefix 2>/dev/null)/share/rcforge" # Homebrew (generic)
    "/opt/local/share/rcforge"         # MacPorts
    "/usr/local/share/rcforge"         # Alternative system location
    "."                                # Current directory (fallback)
  )

  for dir in "${possible_roots[@]}"; do
    if [[ -n "$dir" && -f "$dir/rcforge.sh" ]]; then
      echo "$dir"
      return 0
    fi
  done

  echo ""
  return 1
}

# Check if the source directory exists locally or in a standard package location
SOURCE_DIR=$(detect_project_root)

if [[ -z "$SOURCE_DIR" ]]; then
  echo -e "${RED}Error: Could not find rcForge source files in standard locations.${RESET}"
  
  if [[ $INTERACTIVE -eq 1 ]]; then
    echo "Please enter the path to your rcForge source directory:"
    read -r SOURCE_DIR
    
    if [[ ! -f "$SOURCE_DIR/rcforge.sh" ]]; then
      echo -e "${RED}Error: rcforge.sh not found in the specified directory.${RESET}"
      exit 1
    fi
  else
    echo "Please make sure you have the rcForge repository cloned or the package installed."
    exit 1
  fi
fi

echo -e "${CYAN}Found rcForge source files at: ${YELLOW}$SOURCE_DIR${RESET}"

# Create rcForge directory structure
mkdir -p "$RCFORGE_DIR"
mkdir -p "$RCFORGE_DIR/scripts"
mkdir -p "$RCFORGE_DIR/checksums"
mkdir -p "$RCFORGE_DIR/docs"
mkdir -p "$RCFORGE_DIR/exports"
mkdir -p "$RCFORGE_DIR/include"

echo -e "${GREEN}✓ Created directory structure${RESET}"

# Backup existing installation if it exists
if [[ -f "$RCFORGE_DIR/rcforge.sh" && "$OVERWRITE" -ne 1 ]]; then
  echo -e "${YELLOW}Existing rcForge installation found. Creating backup...${RESET}"
  mkdir -p "$BACKUP_DIR"
  cp -r "$RCFORGE_DIR"/* "$BACKUP_DIR"
  echo -e "${GREEN}✓ Backed up existing installation to $BACKUP_DIR${RESET}"
fi

# Copy core files
echo -e "${CYAN}Installing core files...${RESET}"
# Copy directories
if [[ -d "$SOURCE_DIR/core" ]]; then
  cp -r "$SOURCE_DIR/core" "$RCFORGE_DIR/"
  echo -e "${GREEN}✓ Installed core directory${RESET}"
fi

if [[ -d "$SOURCE_DIR/utils" ]]; then
  cp -r "$SOURCE_DIR/utils" "$RCFORGE_DIR/"
  echo -e "${GREEN}✓ Installed utils directory${RESET}"
fi

if [[ -d "$SOURCE_DIR/src" ]]; then
  cp -r "$SOURCE_DIR/src" "$RCFORGE_DIR/"
  echo -e "${GREEN}✓ Installed src directory${RESET}"
fi

# Copy individual files
if [[ -f "$SOURCE_DIR/rcforge.sh" ]]; then
  cp "$SOURCE_DIR/rcforge.sh" "$RCFORGE_DIR/"
  chmod +x "$RCFORGE_DIR/rcforge.sh"
  echo -e "${GREEN}✓ Installed rcforge.sh${RESET}"
fi

if [[ -f "$SOURCE_DIR/include-structure.sh" ]]; then
  cp "$SOURCE_DIR/include-structure.sh" "$RCFORGE_DIR/"
  chmod +x "$RCFORGE_DIR/include-structure.sh"
  echo -e "${GREEN}✓ Installed include-structure.sh${RESET}"
fi

# Copy documentation
if [[ -d "$SOURCE_DIR/docs" ]]; then
  cp -r "$SOURCE_DIR/docs"/* "$RCFORGE_DIR/docs/"
  echo -e "${GREEN}✓ Installed documentation${RESET}"
fi

# Set up include directory structure if it doesn't exist and not in minimal mode
if [[ ! -d "$RCFORGE_DIR/include/path" && "$MINIMAL" -ne 1 ]]; then
  echo -e "${CYAN}Setting up include directory structure...${RESET}"
  if [[ -f "$RCFORGE_DIR/include-structure.sh" ]]; then
    bash "$RCFORGE_DIR/include-structure.sh"
    echo -e "${GREEN}✓ Include directory structure set up${RESET}"
  else
    echo -e "${YELLOW}Warning: include-structure.sh not found. Skipping include setup.${RESET}"
    # Create basic directory structure
    mkdir -p "$RCFORGE_DIR/include/path"
    mkdir -p "$RCFORGE_DIR/include/common"
    mkdir -p "$RCFORGE_DIR/include/git"
    mkdir -p "$RCFORGE_DIR/include/system"
  fi
fi

# Create sample configuration files
if [[ "$WITH_EXAMPLES" -eq 1 ]]; then
  echo -e "${CYAN}Creating sample configuration files...${RESET}"

  # Sample environment file
  cat > "$RCFORGE_DIR/scripts/100_global_common_environment.sh" << 'EOF'
#!/bin/bash
# Global environment variables

# Include required functions 
include_function common is_macos
include_function common is_linux

# Set default editor based on what's available
if command -v vim >/dev/null 2>&1; then
  export EDITOR="vim"
  export VISUAL="vim"
elif command -v nano >/dev/null 2>&1; then
  export EDITOR="nano"
  export VISUAL="nano"
fi

# Set terminal type and colors
export TERM="xterm-256color"
export CLICOLOR=1

# Set locale
export LC_ALL="en_US.UTF-8"
export LANG="en_US.UTF-8"

# Set history settings
export HISTSIZE=10000
export HISTFILESIZE=10000
export HISTCONTROL=ignoreboth:erasedups

# OS-specific settings
if is_macos; then
  # macOS specific environment variables
  export COPYFILE_DISABLE=true  # Prevent ._ files on external drives
elif is_linux; then
  # Linux specific environment variables
  export LS_COLORS='rs=0:di=01;34:ln=01;36:mh=00:pi=40;33'
fi
EOF
  chmod +x "$RCFORGE_DIR/scripts/100_global_common_environment.sh"
  echo -e "${GREEN}✓ Created sample environment configuration${RESET}"

  # Sample aliases file
  cat > "$RCFORGE_DIR/scripts/200_global_common_aliases.sh" << 'EOF'
#!/bin/bash
# Common aliases

# Include required functions
include_function common is_macos
include_function common is_linux

# Navigation aliases
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."

# List directory aliases
if command -v exa >/dev/null 2>&1; then
  alias ls="exa"
  alias ll="exa -la"
  alias lt="exa -T"
else
  # Use standard ls with colors
  if is_macos; then
    alias ls="ls -G"
  else
    alias ls="ls --color=auto"
  fi
  alias ll="ls -lah"
fi

# Grep with color
alias grep="grep --color=auto"
alias fgrep="fgrep --color=auto"
alias egrep="egrep --color=auto"
EOF
  chmod +x "$RCFORGE_DIR/scripts/200_global_common_aliases.sh"
  echo -e "${GREEN}✓ Created sample aliases configuration${RESET}"

  # Sample path management
  cat > "$RCFORGE_DIR/scripts/050_global_common_path.sh" << 'EOF'
#!/bin/bash
# Path management

# Include path management functions
include_function path add_to_path
include_function path append_to_path
include_function common is_macos

# User bin directories
add_to_path "$HOME/bin"
add_to_path "$HOME/.local/bin"

# Homebrew paths if installed
if is_macos; then
  if [[ -d "/opt/homebrew" ]]; then
    # Homebrew on Apple Silicon Mac
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -d "/usr/local/Homebrew" ]]; then
    # Homebrew on Intel Mac
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi

# Development environments
# Python - pyenv
if [[ -d "$HOME/.pyenv" ]]; then
  export PYENV_ROOT="$HOME/.pyenv"
  add_to_path "$PYENV_ROOT/bin"

  # Initialize pyenv if available
  if command -v pyenv >/dev/null 2>&1; then
    eval "$(pyenv init -)"
  fi
fi

# Node.js - nvm
if [[ -d "$HOME/.nvm" ]]; then
  export NVM_DIR="$HOME/.nvm"
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    source "$NVM_DIR/nvm.sh"
  fi
fi
EOF
  chmod +x "$RCFORGE_DIR/scripts/050_global_common_path.sh"
  echo -e "${GREEN}✓ Created sample PATH configuration${RESET}"

  # Shell-specific prompt file
  if [[ "$SHELL_TYPE" == "bash" ]]; then
    # Sample bash prompt
    cat > "$RCFORGE_DIR/scripts/300_global_bash_prompt.sh" << 'EOF'
#!/bin/bash
# Bash prompt configuration

# Only configure if running in bash
if [[ -z "$BASH_VERSION" ]]; then
  return 0
fi

# Define colors if terminal supports them
if [[ -x /usr/bin/tput ]] && tput setaf 1 >/dev/null 2>&1; then
  # Define colors
  RESET="\[\033[0m\]"
  BOLD="\[\033[1m\]"
  BLUE="\[\033[38;5;27m\]"
  GREEN="\[\033[38;5;35m\]"
  YELLOW="\[\033[38;5;214m\]"
  RED="\[\033[38;5;196m\]"
  PURPLE="\[\033[38;5;92m\]"
  CYAN="\[\033[38;5;45m\]"
  GRAY="\[\033[38;5;245m\]"
else
  # No color support
  RESET=""
  BOLD=""
  BLUE=""
  GREEN=""
  YELLOW=""
  RED=""
  PURPLE=""
  CYAN=""
  GRAY=""
fi

# Git status function
get_git_status() {
  # Check if git is available
  if ! command -v git >/dev/null 2>&1; then
    return
  fi

  # Check if we're in a git repo
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return
  fi

  local branch=$(git symbolic-ref --short HEAD 2>/dev/null || git describe --tags --always 2>/dev/null)
  local git_status=$(git status --porcelain 2>/dev/null)

  # Check for changes
  if [[ -z "$git_status" ]]; then
    echo " ${GREEN}(${branch})${RESET}"
  else
    echo " ${YELLOW}(${branch})${RESET}"
  fi
}

# Show virtualenv if activated
get_virtualenv() {
  if [[ -n "$VIRTUAL_ENV" ]]; then
    echo " ${BLUE}($(basename "$VIRTUAL_ENV"))${RESET}"
  fi
}

# Show hostname in red if this is an SSH session
get_hostname_colored() {
  if [[ -n "$SSH_CLIENT" || -n "$SSH_TTY" ]]; then
    echo "${RED}\h${RESET}"
  else
    echo "${GREEN}\h${RESET}"
  fi
}

# Define the main prompt
PS1="\n${GRAY}[\t]${RESET} ${BOLD}\u@$(get_hostname_colored)${RESET} ${BLUE}\w${RESET}\$(get_git_status)\$(get_virtualenv)\n\$ "

# Set secondary prompt
PS2="${GRAY}→ ${RESET}"
EOF
    chmod +x "$RCFORGE_DIR/scripts/300_global_bash_prompt.sh"
    echo -e "${GREEN}✓ Created sample Bash prompt configuration${RESET}"
  elif [[ "$SHELL_TYPE" == "zsh" ]]; then
    # Sample zsh prompt
    cat > "$RCFORGE_DIR/scripts/500_global_zsh_prompt.sh" << 'EOF'
#!/bin/zsh
# Zsh prompt configuration

# Only configure if running in zsh
if [[ -z "$ZSH_VERSION" ]]; then
  return 0
fi

# Load colors
autoload -U colors && colors

# Git status function
function git_prompt_info() {
  # Check if git is available
  if ! command -v git >/dev/null 2>&1; then
    return
  fi

  # Check if we're in a git repo
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return
  fi

  local branch=$(git symbolic-ref --short HEAD 2>/dev/null || git describe --tags --always 2>/dev/null)
  local git_status=$(git status --porcelain 2>/dev/null)

  # Check for changes
  if [[ -z "$git_status" ]]; then
    echo " %F{green}(${branch})%f"
  else
    echo " %F{yellow}(${branch})%f"
  fi
}

# Virtualenv function
function virtualenv_info() {
  if [[ -n "$VIRTUAL_ENV" ]]; then
    echo " %F{blue}($(basename "$VIRTUAL_ENV"))%f"
  fi
}

# Show hostname in red if this is an SSH session
function ssh_hostname() {
  if [[ -n "$SSH_CLIENT" || -n "$SSH_TTY" ]]; then
    echo "%F{red}%m%f"
  else
    echo "%F{green}%m%f"
  fi
}

# Set the prompt
setopt PROMPT_SUBST
PROMPT=\n%F{245}[%*]%f %B%n@$(ssh_hostname)%b %F{blue}%~%f$(git_prompt_info)$(virtualenv_info)\n%# '
RPROMPT=''
EOF
    chmod +x "$RCFORGE_DIR/scripts/500_global_zsh_prompt.sh"
    echo -e "${GREEN}✓ Created sample Zsh prompt configuration${RESET}"
  fi

  # Get current hostname
  if command -v hostname >/dev/null 2>&1; then
    CURRENT_HOSTNAME=$(hostname | cut -d. -f1)
  else
    CURRENT_HOSTNAME=${HOSTNAME:-$(uname -n | cut -d. -f1)}
  fi

  # Create hostname-specific example
  cat > "$RCFORGE_DIR/scripts/500_${CURRENT_HOSTNAME}_common_settings.sh" << EOF
#!/bin/bash
# 500_${CURRENT_HOSTNAME}_common_settings.sh - Host-specific settings

# This file is specific to this machine (${CURRENT_HOSTNAME})
# Add your host-specific configurations here

# Example: Set up proxy settings for this machine only
# export http_proxy="http://proxy.example.com:8080"
# export https_proxy="http://proxy.example.com:8080"
# export no_proxy="localhost,127.0.0.1"

# Example: Add machine-specific paths
# include_function path add_to_path
# add_to_path "/path/specific/to/${CURRENT_HOSTNAME}"

# Example: Set up environment variables for this machine
# export SPECIFIC_VAR="value"

# Example: Set up aliases specific to this machine
# alias backup="rsync -avz ~/Documents user@backup-server:/backups/${CURRENT_HOSTNAME}"
EOF
  chmod +x "$RCFORGE_DIR/scripts/500_${CURRENT_HOSTNAME}_common_settings.sh"
  echo -e "${GREEN}✓ Created sample hostname-specific configuration${RESET}"
fi

# Create README file
cat > "$RCFORGE_DIR/README.md" << 'EOF'
# rcForge User Configuration

This directory contains your personal rcForge shell configuration.

## Directory Structure

- `scripts/` - Your shell configuration scripts
- `include/` - Your custom include functions
- `checksums/` - Checksums for RC files to detect changes
- `exports/` - Exported configurations for remote servers
- `docs/` - Documentation

## Getting Started

Your shell configuration has been set up with some sample files.
Feel free to customize these files or add new ones following the naming convention:

```
###_[hostname|global]_[environment]_[description].sh
```

For more information, see the documentation in the `docs/` directory.
EOF

# Update shell RC files
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
if [[ "$SHELL_TYPE" == "bash" || "$SHELL_TYPE" == "both" ]]; then
  update_rc_files "bash"
fi

if [[ "$SHELL_TYPE" == "zsh" || "$SHELL_TYPE" == "both" ]]; then
  update_rc_files "zsh"
fi

echo -e "\n${GREEN}┌──────────────────────────────────────────────────────┐${RESET}"
echo -e "${GREEN}│ rcForge v0.2.0 Installation Complete                  │${RESET}"
echo -e "${GREEN}└──────────────────────────────────────────────────────┘${RESET}"
echo ""
echo -e "${YELLOW}To start using rcForge:${RESET}"
echo "1. Start a new shell session"
echo "2. Or source your shell RC file:"
echo "   source ~/.${SHELL_TYPE}rc"
echo ""
echo -e "${YELLOW}Your configuration files are in:${RESET}"
echo "  $RCFORGE_DIR/scripts"
echo ""
echo -e "${YELLOW}Documentation:${RESET}"
echo "  $RCFORGE_DIR/docs"
echo ""
echo -e "${BLUE}Happy scripting! 🚀${RESET}"
# EOF