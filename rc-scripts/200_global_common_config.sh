#!/usr/bin/env bash
# 200_global_common_config.sh - Common shell configurations
# Author: rcForge Team
# Date: 2025-04-06
# Category: rc-script/common
# Description: Common configuration settings for both Bash and Zsh shells

# Note: No 'set -e' or 'set -u' here as this is sourced by interactive shells.

# ============================================================================
# EDITOR CONFIGURATION
# ============================================================================

# Set default editor based on availability, preferring nvim > vim > nano > vi
if command -v nvim >/dev/null 2>&1; then
  export EDITOR="nvim"
  export VISUAL="nvim"
elif command -v vim >/dev/null 2>&1; then
  export EDITOR="vim"
  export VISUAL="vim"
elif command -v nano >/dev/null 2>&1; then
  export EDITOR="nano"
  export VISUAL="nano"
else
  # Fallback to vi if nothing else is found
  export EDITOR="vi"
  export VISUAL="vi"
fi

# ============================================================================
# LOCALE SETTINGS
# ============================================================================

# Set default language and locale to UTF-8 for broad compatibility
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"
# export LC_CTYPE="en_US.UTF-8" # LC_ALL usually covers this

# ============================================================================
# HISTORY SETTINGS (Common Variables)
# ============================================================================
# Specific behavior (setopt/shopt) is set in shell-specific files

# Common history environment variables
export HISTSIZE=10000          # Number of commands to keep in memory for the session
export SAVEHIST=100000         # Number of commands to save in the history file
export HISTFILE="${HISTFILE:-$HOME/.${SHELL##*/}_history}" # Shell-specific history file (e.g., .bash_history, .zsh_history)
export HISTTIMEFORMAT="%F %T " # Add ISO 8601 timestamp to history entries (%Y-%m-%d %H:%M:%S )

# ============================================================================
# APPLICATION DEFAULTS
# ============================================================================

# Configure 'less' as the default pager with useful options
# -R: Output raw control characters (enables color)
# -F: Quit if entire file fits on one screen
# -X: Don't clear screen on exit
export LESS="-R -F -X"
export PAGER="${PAGER:-less}" # Set PAGER only if not already set

# Configure 'man' pages to use 'less' with color support
# Requires 'less' to be available
export MANPAGER="less -R --use-color -Dd+r -Du+b -DS+ky"

# Set default browser command based on availability
if command -v open >/dev/null 2>&1; then # macOS
  export BROWSER="open"
elif command -v xdg-open >/dev/null 2>&1; then # Linux freedesktop standard
  export BROWSER="xdg-open"
fi

# ============================================================================
# XDG BASE DIRECTORY SPECIFICATION
# ============================================================================
# Define standard XDG directories if they are not already set by the system/user

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}" # Newer addition to spec

# Optionally create these directories if they don't exist (use with caution in sourced file)
# Consider if the installer should handle this instead.
# mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME" 2>/dev/null || true

# EOF