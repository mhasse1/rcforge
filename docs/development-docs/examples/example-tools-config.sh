#!/bin/bash
# 800_laptop_common_dev_tools.sh - Developer tools and environments
# Author: Mark Hasse
# Copyright: Analog Edge LLC
# Date: 2025-03-20

# Only run this on the laptop
if [[ "$current_hostname" != "laptop" ]]; then
  debug_echo "Skipping developer tools on non-laptop machine: $current_hostname"
  return 0
fi

debug_echo "Setting up developer tools for laptop"

#------------------------------------------------
# Local helper functions
#------------------------------------------------

# Initialize a tool if it exists
init_tool() {
  local tool_name="$1"
  local init_command="$2"

  if cmd_exists "$tool_name"; then
    debug_echo "Initializing $tool_name"
    # Execute the command
    eval "$init_command"
    return 0
  else
    debug_echo "Tool not found: $tool_name"
    return 1
  fi
}

# Initialize NVM (Node Version Manager) if installed
init_nvm() {
  local nvm_dir="$HOME/.nvm"
  if [[ -d "$nvm_dir" ]]; then
    debug_echo "Initializing NVM"
    export NVM_DIR="$nvm_dir"
    # This is slow, so we'll source it only if we're not debugging
    if [[ -z "$SHELL_DEBUG" ]]; then
      [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
      [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    else
      debug_echo "Skipping NVM source in debug mode (slow operation)"
    fi
    return 0
  else
    debug_echo "NVM not installed"
    return 1
  fi
}

#------------------------------------------------
# Main configuration
#------------------------------------------------

# Add development directories to path
add_to_path "$HOME/bin"
add_to_path "$HOME/.local/bin"

# Language-specific directories
if [[ -d "$HOME/.cargo/bin" ]]; then
  debug_echo "Adding Rust to PATH"
  add_to_path "$HOME/.cargo/bin"
  export CARGO_HOME="$HOME/.cargo"
fi

if [[ -d "$HOME/go/bin" ]]; then
  debug_echo "Adding Go to PATH"
  add_to_path "$HOME/go/bin"
  export GOPATH="$HOME/go"
fi

# Initialize language environments
init_tool "pyenv" 'eval "$(pyenv init -)"'
init_tool "rbenv" 'eval "$(rbenv init -)"'
init_nvm

# Check for required development tools
required_tools=("git" "make" "gcc" "python" "docker")

# Check for required tools and show warnings if missing
for tool in "${required_tools[@]}"; do
  if ! cmd_exists "$tool"; then
    warn_echo "Required development tool not found: $tool"
    # Add to missing tools list
    missing_tools="$missing_tools $tool"
  fi
done

# Show message if tools are missing
if [[ -n "$missing_tools" ]]; then
  echo "Some development tools are missing:$missing_tools"
  if is_macos; then
    echo "You can install them with: brew install$missing_tools"
  elif is_linux; then
    echo "You can install them with: sudo apt install$missing_tools"
  fi
fi

#------------------------------------------------
# Development project shortcuts
#------------------------------------------------

# Create projects directory if it doesn't exist
if [[ ! -d "$HOME/Projects" ]]; then
  debug_echo "Creating Projects directory"
  mkdir -p "$HOME/Projects"
fi

# Development aliases
alias cdev="cd $HOME/Projects"
alias cdwork="cd $HOME/Projects/work"
alias cdpers="cd $HOME/Projects/personal"

# Git aliases
alias gs="git status"
alias ga="git add"
alias gc="git commit"
alias gd="git diff"
alias gp="git push"
alias gl="git log --oneline --graph --decorate"

# Docker aliases
if cmd_exists docker; then
  alias dps="docker ps"
  alias dcp="docker-compose"
  alias dimg="docker images"
  alias dcup="docker-compose up -d"
  alias dcdown="docker-compose down"
fi

#------------------------------------------------
# Editor configuration
#------------------------------------------------

# Configure preferred editor based on availability
if cmd_exists code; then
  debug_echo "Setting Visual Studio Code as preferred editor"
  export EDITOR="code --wait"
  export VISUAL="code --wait"
  # Add VS Code alias
  alias c="code"
elif cmd_exists vim; then
  debug_echo "Setting Vim as preferred editor"
  export EDITOR="vim"
  export VISUAL="vim"
fi

#------------------------------------------------
# SSH config and agent setup
#------------------------------------------------

# Start SSH agent if not already running
start_ssh_agent() {
  if [[ -z "$SSH_AGENT_PID" || ! -e "/proc/$SSH_AGENT_PID" ]]; then
    debug_echo "Starting SSH agent"
    eval "$(ssh-agent -s)" > /dev/null

    # Add common SSH keys
    if [[ -f "$HOME/.ssh/id_rsa" ]]; then
      ssh-add "$HOME/.ssh/id_rsa" > /dev/null 2>&1
    fi
    if [[ -f "$HOME/.ssh/id_ed25519" ]]; then
      ssh-add "$HOME/.ssh/id_ed25519" > /dev/null 2>&1
    fi
  else
    debug_echo "SSH agent already running: $SSH_AGENT_PID"
  fi
}

# Only start SSH agent if not in debug mode (to speed up debugging)
if [[ -z "$SHELL_DEBUG" ]]; then
  start_ssh_agent
else
  debug_echo "Skipping SSH agent start in debug mode"
fi

debug_echo "Developer tools configuration complete"