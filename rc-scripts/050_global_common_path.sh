#!/usr/bin/env bash
# 050_global_common_path.sh - Smart PATH management
# Author: rcForge Team
# Date: 2025-04-05
# Version: 0.3.0
# Description: Conditionally adds directories to PATH if they exist

# ============================================================================
# PATH UTILITY FUNCTIONS
# ============================================================================

# Function: add_to_path
# Description: Add directory to PATH if it exists and isn't already there
# Usage: add_to_path directory [prepend|append]
add_to_path() {
  local dir="$1"
  local position="${2:-prepend}"
  
  # Skip if directory doesn't exist
  if [[ ! -d "$dir" ]]; then
    return 0
  fi
  
  # Skip if already in PATH
  if [[ ":$PATH:" == *":$dir:"* ]]; then
    return 0
  fi
  
  # Add to PATH based on position
  if [[ "$position" == "append" ]]; then
    export PATH="$PATH:$dir"
  else
    export PATH="$dir:$PATH"
  fi
}

# Function: append_to_path
# Description: Add directory to end of PATH if it exists
# Usage: append_to_path directory
append_to_path() {
  add_to_path "$1" "append"
}

# Function: show_path
# Description: Display PATH entries one per line
# Usage: show_path
show_path() {
  echo "$PATH" | tr ':' '\n'
}

# ============================================================================
# PATH CONFIGURATION
# ============================================================================

# Start with a clean PATH that includes essential system directories
# This ensures your PATH has a reliable foundation
system_path="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
if [[ "$PATH" != *"$system_path"* ]]; then
  export PATH="$system_path"
fi

# Add all common directories to PATH in order of priority (highest first)
# Personal bin directory should come first
add_to_path "$HOME/bin"
add_to_path "$HOME/.local/bin"

# Homebrew paths
if [[ -f /opt/homebrew/bin/brew ]]; then
  # Homebrew on Apple Silicon Mac
  eval "$(/opt/homebrew/bin/brew shellenv)"

  # Ruby from Homebrew if it exists
  if [[ -d "/opt/homebrew/opt/ruby/bin" ]]; then
    add_to_path "/opt/homebrew/opt/ruby/bin"
    gemdir=$(gem environment gemdir 2>/dev/null)
    if [[ -n "$gemdir" && -d "$gemdir/bin" ]]; then
      add_to_path "$gemdir/bin"
    fi
  fi
elif [[ -f /usr/local/bin/brew ]]; then
  # Homebrew on Intel Mac or Linux
  eval "$(/usr/local/bin/brew shellenv)"
fi

# Python - pyenv
if [[ -d "$HOME/.pyenv" ]]; then
  export PYENV_ROOT="$HOME/.pyenv"
  add_to_path "$PYENV_ROOT/bin"
  if command -v pyenv >/dev/null; then
    eval "$(pyenv init -)"
    # Only init pyenv-virtualenv if it's installed
    if [[ -d "$PYENV_ROOT/plugins/pyenv-virtualenv" ]]; then
      eval "$(pyenv virtualenv-init -)"
    fi
  fi
fi

# Pipenv configuration - Keep virtualenvs in project
export PIPENV_VENV_IN_PROJECT=1

# Python user packages
if [[ -d "$HOME/.local/lib/python"* ]]; then
  for pydir in "$HOME/.local/lib/python"*/site-packages; do
    # Add Python's bin directory if it exists
    pyver=$(basename "$(dirname "$pydir")")
    if [[ -d "$HOME/.local/lib/$pyver/bin" ]]; then
      add_to_path "$HOME/.local/lib/$pyver/bin"
    fi
  done
fi

# Node.js - nvm
if [[ -d "$HOME/.nvm" ]]; then
  export NVM_DIR="$HOME/.nvm"
  # Load nvm if present
  [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
  # Load bash completion for nvm
  [[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"
fi

# Node.js - fnm (Fast Node Manager)
if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --use-on-cd)"
fi

# Yarn configuration
if command -v yarn >/dev/null 2>&1; then
  add_to_path "$HOME/.yarn/bin"
  add_to_path "$HOME/.config/yarn/global/node_modules/.bin"
fi

# Rust - Cargo
if [[ -d "$HOME/.cargo" ]]; then
  add_to_path "$HOME/.cargo/bin"
fi

# Go
if [[ -d "/usr/local/go" ]]; then
  add_to_path "/usr/local/go/bin"
  # Add GOPATH if needed
  if [[ -d "$HOME/go" ]]; then
    export GOPATH="$HOME/go"
    add_to_path "$GOPATH/bin"
  fi
fi

# Java - SDKMAN
if [[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]]; then
  export SDKMAN_DIR="$HOME/.sdkman"
  source "$HOME/.sdkman/bin/sdkman-init.sh"
fi

# Editor tools
for editor_path in \
  "/Applications/Sublime Text.app/Contents/SharedSupport/bin" \
  "/Applications/Visual Studio Code.app/Contents/Resources/app/bin" \
  "/Applications/Sublime Text 3.app/Contents/SharedSupport/bin" \
  "/Applications/Visual Studio Code - Insiders.app/Contents/Resources/app/bin"; do
  if [[ -d "$editor_path" ]]; then
    append_to_path "$editor_path"
  fi
done

# Add rcForge utilities to path
add_to_path "$HOME/.config/rcforge/utils"

# Debug output - Show the current PATH if debugging is enabled
if [[ -n "${SHELL_DEBUG:-}" ]]; then
  echo "========== PATH CONFIGURATION =========="
  show_path
  echo "========================================"
fi

# Export utility functions
export -f add_to_path
export -f append_to_path
export -f show_path

# EOF
