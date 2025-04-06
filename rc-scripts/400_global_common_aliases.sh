#!/usr/bin/env bash
# 400_global_common_aliases.sh - Shell-agnostic aliases
# Author: rcForge Team
# Date: 2025-04-05
# Version: 0.3.0
# Description: Common aliases for both Bash and Zsh shells

# ============================================================================
# NAVIGATION ALIASES
# ============================================================================

# Directory navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

# Go to specific directories
alias home='cd $HOME'
alias dev='cd $HOME/Development'
alias docs='cd $HOME/Documents'
alias dl='cd $HOME/Downloads'

# Directory listing
if command -v exa >/dev/null 2>&1; then
  # Use exa if available (https://github.com/ogham/exa)
  alias ls='exa'
  alias ll='exa -l'
  alias la='exa -la'
  alias lt='exa -T'  # Tree view
  alias lg='exa -l --git'  # Show git status
elif ls --color=auto &>/dev/null; then
  # GNU ls (Linux)
  alias ls='ls --color=auto'
  alias ll='ls -lh --color=auto'
  alias la='ls -lah --color=auto'
else
  # BSD ls (macOS)
  export CLICOLOR=1
  alias ls='ls -G'
  alias ll='ls -lhG'
  alias la='ls -lahG'
fi

# ============================================================================
# UTILITY ALIASES
# ============================================================================

# Common commands with useful defaults
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias diff='diff --color=auto'

# File operations
alias cp='cp -i'  # Confirm before overwriting
alias mv='mv -i'  # Confirm before overwriting
alias rm='rm -i'  # Confirm before removing
alias mkdir='mkdir -p'  # Create parent directories

# System information
alias df='df -h'  # Human-readable sizes
alias du='du -h'  # Human-readable sizes
alias free='free -m'  # Show sizes in MB

# Process management
alias psa='ps aux'
alias psg='ps aux | grep -v grep | grep -i'

# Display date and time
alias now='date +"%T"'
alias nowdate='date +"%d-%m-%Y"'
alias nowtime='date +"%T"'

# ============================================================================
# NETWORK ALIASES
# ============================================================================

# IP address information
alias ip='curl -s ifconfig.me'  # External IP
alias localip='ipconfig getifaddr en0 2>/dev/null || ip addr | grep "inet " | grep -v 127.0.0.1 | awk "{print \$2}" | cut -d/ -f1'

# Network utilities
alias ping='ping -c 5'  # Ping with 5 packets
alias ports='netstat -tulanp'  # Show open ports
alias listen='lsof -i -P | grep LISTEN'  # Show listening ports

# HTTP requests
if command -v curl >/dev/null 2>&1; then
  alias get='curl -s'
  alias post='curl -s -X POST'
  alias put='curl -s -X PUT'
  alias delete='curl -s -X DELETE'
  alias headers='curl -s -I'
fi

# ============================================================================
# GIT ALIASES
# ============================================================================

if command -v git >/dev/null 2>&1; then
  alias g='git'
  alias gs='git status'
  alias ga='git add'
  alias gc='git commit'
  alias gd='git diff'
  alias gl='git log --oneline --graph --decorate'
  alias gp='git push'
  alias gpull='git pull'
  alias gco='git checkout'
  alias gb='git branch'
  alias gm='git merge'
  alias gt='git tag'
  alias gf='git fetch'
fi

# ============================================================================
# DOCKER ALIASES
# ============================================================================

if command -v docker >/dev/null 2>&1; then
  alias d='docker'
  alias dc='docker-compose'
  alias dps='docker ps'
  alias di='docker images'
  alias dex='docker exec -it'
  alias dlog='docker logs'
  alias dstop='docker stop'
  alias drm='docker rm'
  alias drmi='docker rmi'
fi

# ============================================================================
# MISC ALIASES
# ============================================================================

# Quick edit of configuration files
alias vimrc='$EDITOR ~/.vimrc'
alias bashrc='$EDITOR ~/.bashrc'
alias zshrc='$EDITOR ~/.zshrc'
alias aliases='$EDITOR ~/.config/rcforge/rc-scripts/400_global_common_aliases.sh'

# Reload shell configuration
alias reload='source ~/.bashrc 2>/dev/null || source ~/.zshrc 2>/dev/null || source $HOME/.config/rcforge/rcforge.sh'

# Directory/file operations
alias md='mkdir -p'
alias rd='rmdir'
alias src='source'

# Quick access to the rc command
alias rch='rc help'

# Clear screen and scrollback buffer
if [[ "$TERM" == "xterm"* ]]; then
  alias cls='printf "\033c"'
else
  alias cls='clear'
fi

# EOF
