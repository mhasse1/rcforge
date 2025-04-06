#!/usr/bin/env zsh
# 210_global_zsh_config.sh - Zsh-specific settings
# Author: rcForge Team
# Date: 2025-04-05
# Version: 0.3.0
# Description: Configuration settings specific to Zsh shell

# Skip if not running in Zsh
if [[ -z "${ZSH_VERSION:-}" ]]; then
  return 0
fi

# ============================================================================
# SHELL OPTIONS
# ============================================================================

# Enable vi mode
bindkey -v

# Set vi command mode timeout to 0.1s for better responsiveness
export KEYTIMEOUT=1

# History settings
setopt APPEND_HISTORY        # Append to history file, don't overwrite
setopt EXTENDED_HISTORY      # Save timestamp and runtime information
setopt HIST_EXPIRE_DUPS_FIRST # Expire duplicate entries first
setopt HIST_IGNORE_DUPS      # Don't record duplicates
setopt HIST_IGNORE_SPACE     # Don't record commands starting with space
setopt HIST_FIND_NO_DUPS     # Don't display duplicates when searching
setopt HIST_SAVE_NO_DUPS     # Don't save duplicates
setopt HIST_VERIFY           # Edit history substitutions before executing

# Directory navigation
setopt AUTO_CD               # Change directory without cd
setopt AUTO_PUSHD            # Push directories onto stack
setopt PUSHD_IGNORE_DUPS     # Don't push duplicates onto stack
setopt PUSHD_SILENT          # Don't print stack after pushd/popd

# Completion settings
setopt ALWAYS_TO_END         # Move cursor to end of word on completion
setopt AUTO_LIST             # Automatically list choices
setopt AUTO_MENU             # Show completion menu on tab press
setopt COMPLETE_IN_WORD      # Complete from both ends of a word
setopt NO_NOMATCH            # Pass unmatched patterns to command

# Correction
setopt CORRECT               # Enable command correction
setopt CORRECT_ALL           # Enable argument correction

# Job control
setopt AUTO_RESUME           # Resume existing jobs instead of creating new ones
setopt LONG_LIST_JOBS        # List jobs in long format

# Other options
setopt INTERACTIVE_COMMENTS  # Allow comments in interactive shells

# ============================================================================
# HISTORY CONFIGURATION
# ============================================================================

# Set history file location
HISTFILE="${HISTFILE:-$HOME/.zsh_history}"

# History size settings
HISTSIZE=10000               # Commands to remember in memory
SAVEHIST=100000              # Commands to save in file

# ============================================================================
# ZSH MODULES
# ============================================================================

# Load essential modules
autoload -Uz compinit        # Completion system
autoload -Uz colors          # Color support
autoload -Uz vcs_info        # Version control information
autoload -Uz add-zsh-hook    # Hook system
autoload -Uz select-word-style # Word selection style

# Initialize modules
compinit -d "$HOME/.cache/zsh/zcompdump-$ZSH_VERSION"
colors

# Select word style (treat words like Bash does)
select-word-style bash

# ============================================================================
# COMPLETION SYSTEM
# ============================================================================

# Set completion options
zstyle ':completion:*' menu select            # Selection menu
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}" # Use LS_COLORS
zstyle ':completion:*' verbose yes            # Verbose completion info
zstyle ':completion:*' group-name ''          # Group by type
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' # Case insensitive
zstyle ':completion:*:descriptions' format '%F{green}-- %d --%f'
zstyle ':completion:*:messages' format '%F{yellow}-- %d --%f'
zstyle ':completion:*:warnings' format '%F{red}-- No matches found --%f'
zstyle ':completion:*:*:*:*:processes' command "ps -u $USER -o pid,user,command -w -w"

# Cache completions for faster startup
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$HOME/.cache/zsh/zcompcache"

# ============================================================================
# KEY BINDINGS
# ============================================================================

# Create directory for key bindings
[[ -d "$HOME/.cache/zsh" ]] || mkdir -p "$HOME/.cache/zsh"

# Emacs key bindings for command line editing (even in vi mode)
bindkey '^A' beginning-of-line
bindkey '^E' end-of-line
bindkey '^K' kill-line
bindkey '^U' kill-whole-line
bindkey '^W' backward-kill-word
bindkey '^Y' yank
bindkey '^R' history-incremental-search-backward
bindkey '^S' history-incremental-search-forward
bindkey '^P' up-line-or-history
bindkey '^N' down-line-or-history

# Fix backspace and delete keys
bindkey '^?' backward-delete-char
bindkey '^[[3~' delete-char

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

# Terminal type
export TERM="${TERM:-xterm-256color}"

# ============================================================================
# DEFAULT ALIASES
# ============================================================================

# Alias definitions are kept in a separate file to make them
# accessible to both Bash and Zsh. See 400_global_common_aliases.sh

# EOF
