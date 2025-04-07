#!/usr/bin/env bash
# 050_global_common_path.sh - Smart PATH management
# Author: rcForge Team
# Date: 2025-04-06 # Updated Date
# Category: rc-script/common
# Description: Conditionally adds directories to PATH if they exist, managing order.

# ============================================================================
# PATH UTILITY FUNCTIONS (PascalCase)
# ============================================================================

# ============================================================================
# Function: AddToPath
# Description: Add directory to PATH if it exists and isn't already there.
# Usage: AddToPath directory [prepend|append]
# Arguments:
#   directory (required) - The directory path to add.
#   position (optional) - 'prepend' (default) or 'append'.
# Returns: 0. Modifies PATH environment variable.
# ============================================================================
AddToPath() {
  local dir="$1"
  local position="${2:-prepend}" # Default to prepend

  # Resolve potential ~ or other expansions, handle non-existent dir gracefully
  # Use eval to expand ~ but be cautious
  # dir=$(eval echo "$dir") # Use cautiously or avoid if possible

  # Better: Check existence *before* modifying PATH
  if [[ ! -d "$dir" ]]; then
    # Optionally print verbose message if dir doesn't exist
    # [[ -n "${SHELL_DEBUG:-}" ]] && echo "rcForge PATH: Directory not found, skipping: $dir"
    return 0
  fi

  # Check if directory is already effectively in PATH (handles trailing slashes)
  case ":${PATH}:" in
    *":${dir}:"*) return 0 ;; # Exact match
    *":${dir}/:"*) return 0 ;; # Match with trailing slash
  esac

  # Add to PATH
  if [[ "$position" == "append" ]]; then
    export PATH="${PATH:+$PATH:}$dir" # Append, handle empty initial PATH
  else
    export PATH="$dir${PATH:+:$PATH}" # Prepend, handle empty initial PATH
  fi
  # Optionally print verbose message
  # [[ -n "${SHELL_DEBUG:-}" ]] && echo "rcForge PATH: Added ($position): $dir"
  return 0
}

# ============================================================================
# Function: AppendToPath
# Description: Add directory to the END of PATH if it exists and isn't already there.
# Usage: AppendToPath directory
# Returns: 0. Modifies PATH environment variable.
# ============================================================================
AppendToPath() {
  AddToPath "$1" "append" # Call PascalCase
}

# ============================================================================
# Function: ShowPath
# Description: Display current PATH entries, one per line.
# Usage: ShowPath
# Returns: None. Prints PATH entries to stdout.
# ============================================================================
ShowPath() {
  # Use printf for safer handling of potential special characters if PATH was manipulated externally
  printf '%s\n' "${PATH//:/$'\n'}"
}

# ============================================================================
# PATH CONFIGURATION
# ============================================================================

# Initialize PATH with essential system directories if they aren't present
# This provides a baseline. Order matters.
local base_system_paths="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
if [[ ":${PATH}:" != *":/usr/local/bin:"* && ":${PATH}:" != *":/usr/bin:"* ]]; then
     # If core paths seem missing, prepend them carefully
     export PATH="$base_system_paths${PATH:+:$PATH}"
fi

# --- User Specific Bins ---
AddToPath "$HOME/bin"          # User's custom scripts (prepend)
AddToPath "$HOME/.local/bin"   # Common location for pip user installs (prepend)

# --- Package Managers ---

# Homebrew (macOS / Linux) - Let brew's shellenv handle PATH setup
if command -v brew &>/dev/null; then
    # Check common locations or rely on brew command itself
    # This assumes 'brew shellenv' correctly sets PATH and other vars
    eval "$(brew shellenv 2>/dev/null)" || WarningMessage "brew shellenv failed. Homebrew paths may not be set."

    # Optional: Add specific brew package bins if needed and not handled by shellenv
    # Example for Ruby (often needs specific path addition)
    local brew_prefix
    brew_prefix=$(brew --prefix 2>/dev/null || echo "")
    if [[ -n "$brew_prefix" && -d "$brew_prefix/opt/ruby/bin" ]]; then
        AddToPath "$brew_prefix/opt/ruby/bin"
        # Add gem bin path if gem command exists
        if command -v gem &>/dev/null; then
             local gem_user_dir
             gem_user_dir=$(gem environment user_gemhome 2>/dev/null || echo "")
             if [[ -n "$gem_user_dir" && -d "$gem_user_dir/bin" ]]; then
                  AddToPath "$gem_user_dir/bin"
             fi
        fi
    fi
fi

# --- Language Version Managers ---

# pyenv (Python)
if [[ -d "$HOME/.pyenv" ]]; then
  export PYENV_ROOT="$HOME/.pyenv"
  # Add shims and bin dirs first for pyenv command access
  AddToPath "$PYENV_ROOT/shims"
  AddToPath "$PYENV_ROOT/bin"
  # Initialize pyenv (adds python versions to PATH) only if command exists now
  if command -v pyenv &>/dev/null; then
    eval "$(pyenv init --path)" # Use --path for PATH only modification
    eval "$(pyenv init -)"      # For shell integration, shims, etc.
    # Initialize pyenv-virtualenv if plugin exists
    if command -v pyenv-virtualenv-init &>/dev/null; then
         eval "$(pyenv virtualenv-init -)"
    fi
  fi
fi
# Pipenv: Use virtualenvs within project directories
export PIPENV_VENV_IN_PROJECT=1

# nvm (Node.js) - Sourcing its script handles PATH
if [[ -d "$HOME/.nvm" ]]; then
  export NVM_DIR="$HOME/.nvm"
  # Lazy load NVM script to improve shell startup speed? Or source directly?
  # Sourcing directly:
  [[ -s "$NVM_DIR/nvm.sh" ]] && \. "$NVM_DIR/nvm.sh"  # Load nvm
  [[ -s "$NVM_DIR/bash_completion" ]] && \. "$NVM_DIR/bash_completion"  # Load nvm bash_completion (Bash specific)
fi

# fnm (Node.js) - Sourcing its script handles PATH
if command -v fnm &>/dev/null; then
  eval "$(fnm env --use-on-cd)"
fi

# Yarn (Node.js package manager) - Add global bin paths
if command -v yarn &>/dev/null; then
  AddToPath "$HOME/.yarn/bin" # Yarn 1 global path
  AddToPath "$(yarn global bin 2>/dev/null || echo "$HOME/.config/yarn/global/node_modules/.bin")" # Yarn Berry+ global path
fi

# Cargo (Rust)
if [[ -d "$HOME/.cargo" ]]; then
  AddToPath "$HOME/.cargo/bin"
fi

# Go
if [[ -d "/usr/local/go/bin" ]]; then # Common install path
  AddToPath "/usr/local/go/bin"
fi
# User GOPATH (legacy or specific setup)
export GOPATH="${GOPATH:-$HOME/go}" # Set default GOPATH if not set
if [[ -d "$GOPATH/bin" ]]; then
     AddToPath "$GOPATH/bin"
fi

# SDKMAN (Java, etc.) - Sourcing its script handles PATH
if [[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]]; then
  export SDKMAN_DIR="$HOME/.sdkman"
  # shellcheck disable=SC1090
  source "$SDKMAN_DIR/bin/sdkman-init.sh"
fi

# --- Application Specific Paths ---

# Add common paths for GUI editor command-line tools (macOS)
if [[ "$(uname)" == "Darwin" ]]; then
    local editor_path="" # Loop variable
    for editor_path in \
        "/Applications/Sublime Text.app/Contents/SharedSupport/bin" \
        "/Applications/Visual Studio Code.app/Contents/Resources/app/bin" \
        # Add others if needed
        # REMOVED semicolon from the end of this list
    do # This should now parse correctly
        AppendToPath "$editor_path" # Append editor paths
    done
fi

# --- rcForge Utilities ---
# Add user and system utility directories (user takes precedence)
AddToPath "$RCFORGE_USER_UTILS" # Add user utils first (prepend)
AddToPath "$RCFORGE_UTILS"      # Add system utils after (prepend)

# ============================================================================
# FINAL PATH CLEANUP & DEBUG
# ============================================================================

# Optional: Remove duplicate entries (though AddToPath helps prevent them)
# Can be slow; uncomment if necessary
# export PATH=$(echo "$PATH" | awk -v RS=: -v ORS=: '!a[$0]++{print $0}' | sed 's/:$//')

# Debug output - Show the final PATH if debugging is enabled
if [[ -n "${SHELL_DEBUG:-}" ]]; then
  echo -e "\n${BOLD}${CYAN}Final PATH Configuration:${RESET}"
  ShowPath # Call PascalCase
  echo "========================================"
fi

# Export utility functions if they are intended for user use (e.g., in other scripts)
export -f AddToPath
export -f AppendToPath
export -f ShowPath

# EOF