#!/usr/bin/env bash
# 200_global_common_config.sh - Common shell configurations
# Author: rcForge Team
# Date: 2025-04-06
# Version: 0.3.0
# Description: Common configuration settings for both Bash and Zsh shells

# ============================================================================
# EDITOR CONFIGURATION
# ============================================================================

# Set default editor based on availability
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
  export EDITOR="vi"
  export VISUAL="vi"
fi

# ============================================================================
# LOCALE SETTINGS
# ============================================================================

# Set language and locale (UTF-8)
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export LC_CTYPE="en_US.UTF-8"

# ============================================================================
# HISTORY SETTINGS
# ============================================================================

# Common history settings for both shells
export HISTSIZE=10000       # Maximum events in memory
export SAVEHIST=100000      # Maximum events in history file
export HISTTIMEFORMAT="%F %T "  # ISO date and time format

# ============================================================================
# APPLICATION DEFAULTS
# ============================================================================

# Less configuration
export LESS="-R -F -X"  # Raw colors, exit if one screen, don't clear screen
export PAGER="less"     # Default pager

# Man page colors
export MANPAGER="less -R --use-color -Dd+r -Du+b -DS+ky"

# Default browser
if command -v open >/dev/null 2>&1; then
  export BROWSER="open"
elif command -v xdg-open >/dev/null 2>&1; then
  export BROWSER="xdg-open"
fi

# ============================================================================
# XDG BASE DIRECTORY SPECIFICATION
# ============================================================================

# Define XDG directories if not already set
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# Create directories if they don't exist
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME"

# EOF
