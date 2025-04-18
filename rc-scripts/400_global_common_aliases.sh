#!/usr/bin/env bash
# 400_global_common_aliases.sh - Shell-agnostic aliases
# Author: rcForge Team
# Date: 2025-04-06 # Updated Date
# Category: rc-script/common
# Description: Common aliases for both Bash and Zsh shells

# ============================================================================
# NAVIGATION ALIASES
# ============================================================================

# Directory navigation shortcuts
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

# Go to specific common directories (ensure these paths are relevant)
alias home='cd "$HOME"'
alias rcforge='cd $HOME/.config/rcforge'
# alias dev='cd "$HOME/Development"' # Uncomment or modify if standard dev path exists
# alias docs='cd "$HOME/Documents"' # Uncomment or modify
# alias dl='cd "$HOME/Downloads"'   # Uncomment or modify

# Directory listing aliases (with fallbacks)
if IsBSD; then
  # BSD ls (macOS) with color support
  export CLICOLOR=1                        # Enable colors for BSD ls
  export LSCOLORS="exfxcxdxbxegedabagacad" # Optional: Customize LSCOLORS
  alias ls='ls -G -F'                      # Enable color and file type indicators
  alias ll='ls -lhGF'                      # Human-readable sizes
  alias la='ls -lahGF'                     # Include hidden files
else
  # GNU ls (Linux) with color support
  alias ls='ls --color=auto --group-directories-first -F'      # Add file type indicators (-F)
  alias ll='ls -lh --color=auto --group-directories-first -F'  # Human-readable sizes
  alias la='ls -lah --color=auto --group-directories-first -F' # Include hidden files
fi
alias l.="ls -A | grep -E '^\.'"

# ============================================================================
# UTILITY ALIASES
# ============================================================================

# Common commands with useful defaults (color where applicable)
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias diff='diff --color=auto --unified' # Unified diff format

# File operations with interactive confirmation (-i)
# alias cp='cp -i'
# alias mv='mv -i'
# alias rm='rm -i'
alias mkdir='mkdir -pv' # Create parent directories (-p), verbose (-v)

# System information (human-readable)
alias df='df -h'
alias du='du -h'
alias path="echo $PATH | sed 's/:/\n/g'"
# alias free='free -m' # Linux specific, might not be available on macOS

# Process management
alias psa='ps aux'
alias psg='ps aux | grep -v grep | grep -i' # Grep for processes

# Display date and time shortcuts
alias now='date +"%T"'
alias nowdate='date +"%Y-%m-%d"' # Use ISO format
alias nowtime='date +"%H:%M:%S"'

# Reload shell configuration (attempts common files and rcforge)
alias reload='exec $SHELL -l' # Preferred way to reload entire environment

# ts-node execution
alias ts='ts-node '

# sudo as su
alias su='sudo '

# ============================================================================
# NETWORK ALIASES
# ============================================================================

# IP address information
alias publicip='curl -s ifconfig.me/ip || curl -s api.ipify.org || echo "Could not fetch external IP"'                                 # External IP with fallback
alias localip='ipconfig getifaddr en0 2>/dev/null || ip -4 addr show scope global | grep inet | sed "s|.*inet ||;s|/.*||" | head -n 1' # macOS / Linux fallback

# Network utilities
alias ping='ping -c 5'
# alias ports='netstat -tulanp' # netstat might require sudo on Linux, ss is preferred
# alias listen='lsof -i -P | grep LISTEN' # lsof might not be installed

# HTTP requests using curl (check if command exists)
if command -v curl >/dev/null 2>&1; then
  alias get='curl -sSL' # Follow redirects
  alias post='curl -sSL -X POST'
  alias put='curl -sSL -X PUT'
  alias delete='curl -sSL -X DELETE'
  alias headers='curl -sSL -I' # Follow redirects, show headers
fi

# ============================================================================
# GIT ALIASES (check if git exists)
# ============================================================================

if command -v git >/dev/null 2>&1; then
  alias gs="git status"
  alias ga="git add"
  alias gc="git commit"
  alias gp="git push"
  alias gl="git pull"
  alias gd="git diff"
  alias gco="git checkout"
  alias gb="git branch"
fi
