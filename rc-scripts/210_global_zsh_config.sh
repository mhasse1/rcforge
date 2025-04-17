#!/usr/bin/env zsh
# 210_global_zsh_config.sh - Zsh-specific settings
# Author: rcForge Team
# Date: 2025-04-06 # Updated Date
# Category: rc-script/zsh
# Description: Configuration settings specific to Zsh shell

# ============================================================================
# SHELL OPTIONS (setopt)
# ============================================================================

# --- Navigation ---
setopt AUTO_CD           # Change directory without cd if it's a valid path
setopt AUTO_PUSHD        # Automatically pushd directories when changing
setopt PUSHD_IGNORE_DUPS # Don't push duplicate directories onto the stack
setopt PUSHD_SILENT      # Don't print the directory stack after pushd/popd
setopt CDABLE_VARS       # Allow cd to variables that contain a directory path

# --- History ---
setopt APPEND_HISTORY         # Append to history file, don't overwrite
setopt EXTENDED_HISTORY       # Save timestamp and duration
setopt HIST_EXPIRE_DUPS_FIRST # Expire duplicate entries first when trimming
setopt HIST_IGNORE_DUPS       # Don't record commands that are duplicates of the previous one
setopt HIST_IGNORE_ALL_DUPS   # Avoid storing duplicates anywhere in the history
setopt HIST_IGNORE_SPACE      # Don't record commands starting with a space
setopt HIST_FIND_NO_DUPS      # Don't display duplicates when searching history
setopt HIST_SAVE_NO_DUPS      # Don't save duplicate entries in the history file
setopt HIST_VERIFY            # Show command with history expansion before running it
setopt SHARE_HISTORY          # Share history between all Zsh sessions immediately

# --- Completion ---
setopt ALWAYS_TO_END    # Move cursor to the end of a completed word
setopt AUTO_LIST        # Automatically list choices on ambiguous completion
setopt AUTO_MENU        # Show completion menu on second consecutive tab press
setopt COMPLETE_IN_WORD # Allow completion from within a word
setopt NO_NOMATCH       # Pass pattern to command if no match found (instead of error)
setopt LIST_PACKED      # Show completion list packed compactly
setopt MENU_COMPLETE    # Automatically select first completion match on menu

# --- Input/Output ---
setopt CORRECT # Enable command correction suggestion
# setopt CORRECT_ALL        # Enable correction for arguments too (can be annoying)
setopt INTERACTIVE_COMMENTS # Allow comments in interactive shell sessions
setopt NO_BEEP              # Disable audible bell on errors

# --- Job Control ---
setopt AUTO_RESUME    # Resume existing jobs automatically by name
setopt LONG_LIST_JOBS # List jobs in long format by default
setopt NO_HUP         # Don't kill background jobs on shell exit
setopt NOTIFY         # Report status of background jobs immediately

# --- Globbing ---
setopt EXTENDED_GLOB # Enable extended globbing features (^, #, ~)
setopt GLOB_DOTS     # Include dotfiles in globbing results
# setopt NO_CASE_GLOB       # Make globbing case-insensitive (use with caution)

# ============================================================================
# HISTORY CONFIGURATION (Variables set in common config)
# ============================================================================
# HISTFILE, HISTSIZE, SAVEHIST are usually set in common config
# Zsh specific history location if needed, otherwise common default is used

# ============================================================================
# ZSH MODULES
# ============================================================================

# Load essential modules if needed (often loaded by frameworks like Oh My Zsh)
# Check if already loaded to avoid errors/redundancy
zmodload zsh/complist || true
autoload -Uz compinit || true # Completion system
autoload -Uz colors || true   # Color support
autoload -Uz vcs_info || true # Version control information
autoload -Uz add-zsh-hook || true# Hook system
autoload -Uz select-word-style || true # Word selection style

# Initialize modules (safe to run multiple times)
colors # Initialize color variables (%F{red}, etc.)

# Initialize completion system only if not already initialized
# Check for compstate variable; initialize if empty
if [[ ! -v compstate[prompt] ]]; then
    # Speed up compinit by caching; specify cache file path
    _comp_cache_path="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"
    if [[ -f "${_comp_cache_path}.zwc" ]]; then
        compinit -i -C -d "${_comp_cache_path}" # Use cache
    else
        compinit -i -d "${_comp_cache_path}" # Initialize and create cache
    fi
    unset _comp_cache_path # Clean up temp var
fi

# Select word style (make word boundaries similar to Bash)
select-word-style bash

# ============================================================================
# COMPLETION SYSTEM (zstyle)
# ============================================================================

# Configure completion behavior using zstyle

# --- General ---
zstyle ':completion:*' menu select=2 # Show menu on second tab, select with tab/arrows
zstyle ':completion:*' verbose yes   # Show descriptions for completion candidates
zstyle ':completion:*' group-name '' # Don't group completions by type explicitly

# --- Matching ---
# Case-insensitive matching
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
# Allow errors for typos (e.g., complete 'git stotus' as 'git status')
zstyle ':completion:*' completer _complete _match _correct _approximate
zstyle ':completion:*' max-errors 2 numeric

# --- Formatting ---
zstyle ':completion:*:descriptions' format '%B%F{green}-- %d --%f%b'                   # Format descriptions
zstyle ':completion:*:messages' format '%B%F{yellow}-- %d --%f%b'                      # Format messages
zstyle ':completion:*:warnings' format '%B%F{red}-- %d --%f%b'                         # Format warnings
zstyle ':completion:*:*:*:*:processes' command "ps -u $USER -o pid,user,command -w -w" # Command for process completion

# --- Caching (compinit handles main cache) ---
# zstyle ':completion:*' use-cache on
# zstyle ':completion:*' cache-path "$HOME/.cache/zsh/zcompcache" # Handled by compinit

# --- Specific command completion options ---
# Example: Make cd completion understand .., ..., etc.
zstyle ':completion:*:*:cd:*:directory-stack' menu yes select

# ============================================================================
# KEY BINDINGS (bindkey)
# ============================================================================

# Ensure Zsh keymap is set (usually 'emacs' or 'viins')
# https://zsh.sourceforge.io/Doc/Release/index.html
# https://thevaluable.dev/zsh-install-configure-mouseless/
# https://thevaluable.dev/zsh-line-editor-configuration-mouseless/
# bindkey -e # Force Emacs mode
bindkey -v # Force Vi mode

# Instead of visual, have v lauch our editor
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey -M vicmd v edit-command-line

# Standard Emacs-like bindings (useful even in Vi command mode)
# bindkey '^A' beginning-of-line
# bindkey '^E' end-of-line
# bindkey '^K' kill-line
# bindkey '^U' backward-kill-line # More standard kill whole line
# bindkey '^W' backward-kill-word # Often default
# bindkey '^Y' yank
# bindkey '^R' history-incremental-search-backward
# bindkey '^S' history-incremental-search-forward # May need `setopt NO_FLOW_CONTROL`
# bindkey '^P' up-line-or-search                  # Or up-line-or-history
# bindkey '^N' down-line-or-search                # Or down-line-or-history
# bindkey '^F' forward-char
# bindkey '^B' backward-char
# bindkey '^D' delete-char-or-list # Be careful with list

# Fix common terminal issues with backspace/delete
bindkey '^?' backward-delete-char # Backspace
bindkey '^[[3~' delete-char       # Delete key

# Word movement (Alt+Left/Right or Esc+B/F)
bindkey '\eb' backward-word # Esc+B
bindkey '\ef' forward-word  # Esc+F
# bindkey '^[[1;3C' forward-word # Alt+Right (May vary by terminal)
# bindkey '^[[1;3D' backward-word # Alt+Left (May vary by terminal)

# History substring search (type part of command, press Up/Down)
# autoload -Uz history-substring-search
# bindkey '^[[A' history-substring-search-up   # Up arrow
# bindkey '^[[B' history-substring-search-down # Down arrow

# ============================================================================
# ENVIRONMENT SETTINGS (Zsh specific, overrides common if needed)
# ============================================================================
# EDITOR set in common config
# TERM set in common config

# ============================================================================
# DEFAULT ALIASES (Sourced from common file)
# ============================================================================
# Alias definitions are kept in a separate file (400_global_common_aliases.sh)

# EOF
