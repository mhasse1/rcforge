#!/bin/bash
## ###########################################################################
## 050_global_common_path.sh - Smart PATH management
## Conditionally adds directories to PATH if they exist
## ###########################################################################

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

# Node.js - nvm
if [[ -d "$HOME/.nvm" ]]; then
  export NVM_DIR="$HOME/.nvm"
  # Load nvm if present
  [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
  # Load bash completion for nvm
  [[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"
fi

# Yarn configuration
if command -v yarn >/dev/null 2>&1; then
  add_to_path "$HOME/.yarn/bin"
  add_to_path "$HOME/.config/yarn/global/node_modules/.bin"
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

# Sublime Text CLI
if [[ -d "/Applications/Sublime Text.app/Contents/SharedSupport/bin" ]]; then
  append_to_path "/Applications/Sublime Text.app/Contents/SharedSupport/bin"
fi

# VS Code CLI
if [[ -d "/Applications/Visual Studio Code.app/Contents/Resources/app/bin" ]]; then
  append_to_path "/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
fi

# Python user packages
if [[ -d "$HOME/Library/Python/3.9/bin" ]]; then
  append_to_path "$HOME/Library/Python/3.9/bin"
elif [[ -d "$HOME/Library/Python/3.10/bin" ]]; then
  append_to_path "$HOME/Library/Python/3.10/bin"
elif [[ -d "$HOME/Library/Python/3.11/bin" ]]; then
  append_to_path "$HOME/Library/Python/3.11/bin"
fi

# Debug output - Show the current PATH if debugging is enabled
if [[ -n "$SHELL_DEBUG" ]]; then
  debug_echo "========== PATH CONFIGURATION =========="
  show_path
  debug_echo "========================================"
fi
