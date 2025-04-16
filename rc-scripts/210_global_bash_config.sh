#!/usr/bin/env bash
# 210_global_bash_config.sh - Bash-specific settings
# Author: rcForge Team
# Date: 2025-04-06 # Updated Date
# Category: rc-script/bash
# Description: Configuration settings specific to Bash shell

# Note: No 'set -e' or 'set -u' here as this is sourced by interactive shells.

# ============================================================================
# SHELL OPTIONS (set -o, shopt)
# ============================================================================

# --- History ---
# Variables are set in common config (HISTSIZE, HISTFILESIZE, HISTCONTROL, HISTTIMEFORMAT, HISTIGNORE)
shopt -s histappend # Append to history file, don't overwrite
shopt -s cmdhist    # Save multi-line commands as single history entry
shopt -s lithist    # Preserve embedded newlines in multi-line history entries
shopt -s histverify # Allow editing history substitutions before execution

# --- Display ---
shopt -s checkwinsize # Update window size after each command

# --- Navigation ---
# Enable extended cd features (requires Bash 4.0+)
shopt -s autocd 2>/dev/null || true   # Change directory by typing directory name
shopt -s cdspell                      # Autocorrect minor spelling errors in 'cd' command
shopt -s dirspell 2>/dev/null || true # Autocorrect directory spelling in commands
shopt -s cdable_vars                  # Allow 'cd varname' if $varname is a directory path

# --- Globbing ---
shopt -s globstar 2>/dev/null || true # Enable ** recursive globbing (Bash 4.0+)
shopt -s extglob                      # Enable extended pattern matching features (+, ?, *, !, @)
shopt -s nocaseglob                   # Make filename globbing case-insensitive

# --- Other ---
shopt -s hostcomplete # Enable hostname completion (Tab after @)

# --- Set vi mode ---
set -o vi

# ============================================================================
# HISTORY CONFIGURATION (Variables set in common config)
# ============================================================================
# HISTFILE, HISTSIZE, HISTFILESIZE, HISTCONTROL, HISTTIMEFORMAT set in common config
# Optionally add more specific HISTIGNORE patterns here if needed

# ============================================================================
# COMPLETION (Bash Programmable Completion)
# ============================================================================

# Enable programmable completion features if not in POSIX mode
if ! shopt -oq posix; then
  # Check standard locations for bash_completion script
  if [[ -f /usr/share/bash-completion/bash_completion ]]; then
    # shellcheck disable=SC1091
    source /usr/share/bash-completion/bash_completion
  elif [[ -f /etc/bash_completion ]]; then
    # shellcheck disable=SC1090,SC1091
    source /etc/bash_completion
  elif [[ -n "${BASH_COMPLETION_COMPAT_DIR:-}" && -f "${BASH_COMPLETION_COMPAT_DIR}/bash_completion" ]]; then
    # Use environment variable if set (often by package managers like Homebrew)
    # shellcheck disable=SC1090
    source "${BASH_COMPLETION_COMPAT_DIR}/bash_completion"
  fi
fi

# Enable case-insensitive completion
# Note: This might already be handled by inputrc settings
# bind 'set completion-ignore-case on' # Uncomment if needed

# ============================================================================
# ENVIRONMENT SETTINGS (Bash specific, overrides common if needed)
# ============================================================================
# EDITOR set in common config
# TERM set in common config

# Color support for ls and grep (via dircolors)
if command -v dircolors >/dev/null 2>&1; then
  # Use user's custom dircolors if it exists, otherwise use defaults
  if [[ -r "$HOME/.dircolors" ]]; then
    eval "$(dircolors -b "$HOME/.dircolors")"
  else
    eval "$(dircolors -b)"
  fi
  # Aliases in 400_global_common_aliases.sh enable --color=auto for ls/grep
fi

# EOF
