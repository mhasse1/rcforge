#!/usr/bin/env bash
# 210_global_bash_config.sh - Bash-specific settings
# Author: rcForge Team
# Date: 2025-04-05
# Version: 0.3.0
# Description: Configuration settings specific to Bash shell

# Skip if not running in Bash
if [[ -z "${BASH_VERSION:-}" ]]; then
  return 0
fi

# ============================================================================
# SHELL OPTIONS
# ============================================================================

# Enable vi mode
set -o vi

# History settings
shopt -s histappend     # Append to history file, don't overwrite
shopt -s cmdhist        # Store multi-line commands as single line
shopt -s lithist        # Use embedded newlines in multi-line history
shopt -s histverify     # Edit history substitutions before executing

# Display settings
shopt -s checkwinsize   # Check window size after each command

# Directory navigation
shopt -s autocd 2>/dev/null || true   # Change directory without cd (Bash 4.0+)
shopt -s cdspell        # Autocorrect minor spelling errors in cd
shopt -s dirspell 2>/dev/null || true # Autocorrect directory spelling (Bash 4.0+)
shopt -s cdable_vars    # Allow cd to variables containing directory names

# Globbing enhancements
shopt -s globstar 2>/dev/null || true # Enable ** recursive glob (Bash 4.0+)
shopt -s extglob        # Extended pattern matching
shopt -s nocaseglob     # Case-insensitive globbing

# ============================================================================
# HISTORY CONFIGURATION
# ============================================================================

# Set history file location
export HISTFILE="${HISTFILE:-$HOME/.bash_history}"

# History size settings
export HISTSIZE=10000          # Commands to remember in memory
export HISTFILESIZE=100000     # Commands to save in file

# History control flags
export HISTCONTROL=ignoreboth:erasedups  # Ignore duplicates and space-prefixed commands

# History timestamp format
export HISTTIMEFORMAT="%F %T "  # ISO date and time format

# History exclusion patterns
export HISTIGNORE="ls:cd:pwd:exit:date:* --help:history:clear"

# ============================================================================
# COMPLETION
# ============================================================================

# Enable programmable completion features
if ! shopt -oq posix; then
  if [[ -f /usr/share/bash-completion/bash_completion ]]; then
    # Modern location
    source /usr/share/bash-completion/bash_completion
  elif [[ -f /etc/bash_completion ]]; then
    # Legacy location
    source /etc/bash_completion
  elif [[ -f "$(brew --prefix 2>/dev/null)/etc/bash_completion" ]]; then
    # Homebrew location
    source "$(brew --prefix)/etc/bash_completion"
  fi
fi

# ============================================================================
# ENVIRONMENT SETTINGS
# ============================================================================

# Set default editor based on availability
if command -v vim >/dev/null 2>&1; then
  export EDITOR="vim"
elif command -v nano >/dev/null 2>&1; then
  export EDITOR="nano"
else
  export EDITOR="vi"
fi

# Color support for ls and grep
if command -v dircolors >/dev/null 2>&1; then
  if [[ -r "$HOME/.dircolors" ]]; then
    eval "$(dircolors -b "$HOME/.dircolors")"
  else
    eval "$(dircolors -b)"
  fi
fi

# Terminal type settings
export TERM="${TERM:-xterm-256color}"

# ============================================================================
# DEFAULT ALIASES
# ============================================================================

# Alias definitions are kept in a separate file to make them
# accessible to both Bash and Zsh. See 400_global_common_aliases.sh

# EOF
