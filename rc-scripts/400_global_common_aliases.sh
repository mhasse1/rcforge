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
# alias dev='cd "$HOME/Development"' # Uncomment or modify if standard dev path exists
# alias docs='cd "$HOME/Documents"' # Uncomment or modify
# alias dl='cd "$HOME/Downloads"'   # Uncomment or modify

# Directory listing aliases (with fallbacks)
if command -v exa >/dev/null 2>&1; then
  # Use exa if available (modern replacement for ls)
  alias ls='exa --group-directories-first'
  alias ll='exa -l --group-directories-first --header --git' # Long format, header, git status
  alias la='exa -la --group-directories-first --header --git' # Long format, all files
  alias lt='exa --tree --level=2' # Tree view, limited depth
  # alias lg='exa -l --git' # Covered by ll/la now
elif ls --color=auto &>/dev/null; then
  # GNU ls (Linux) with color support
  alias ls='ls --color=auto --group-directories-first -F' # Add file type indicators (-F)
  alias ll='ls -lh --color=auto --group-directories-first -F' # Human-readable sizes
  alias la='ls -lah --color=auto --group-directories-first -F' # Include hidden files
else
  # BSD ls (macOS) with color support
  export CLICOLOR=1       # Enable colors for BSD ls
  export LSCOLORS="exfxcxdxbxegedabagacad" # Optional: Customize LSCOLORS
  alias ls='ls -G -F'     # Enable color and file type indicators
  alias ll='ls -lhGF'   # Human-readable sizes
  alias la='ls -lahGF'  # Include hidden files
fi

# ============================================================================
# UTILITY ALIASES
# ============================================================================

# Common commands with useful defaults (color where applicable)
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias diff='diff --color=auto --unified' # Unified diff format

# File operations with interactive confirmation (-i)
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'
alias mkdir='mkdir -pv' # Create parent directories (-p), verbose (-v)

# System information (human-readable)
alias df='df -h'
alias du='du -h'
# alias free='free -m' # Linux specific, might not be available on macOS

# Process management
alias psa='ps aux'
alias psg='ps aux | grep -v grep | grep -i' # Grep for processes

# Display date and time shortcuts
alias now='date +"%T"'
alias nowdate='date +"%Y-%m-%d"' # Use ISO format
alias nowtime='date +"%H:%M:%S"'

# ============================================================================
# NETWORK ALIASES
# ============================================================================

# IP address information
alias ip='curl -s ifconfig.me/ip || curl -s api.ipify.org || echo "Could not fetch external IP"' # External IP with fallback
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
  alias g='git'
  alias gs='git status -sb' # Short branch status
  alias ga='git add'
  alias gaa='git add .'
  alias gau='git add -u'
  alias gc='git commit -m'
  alias gca='git commit -am'
  alias gd='git diff'
  alias gds='git diff --staged'
  alias gl='git log --oneline --graph --decorate --all' # More comprehensive log
  alias gp='git push'
  alias gpu='git push -u origin HEAD' # Push current branch and set upstream
  alias gpull='git pull --rebase --autostash' # Prefer rebase pull with stash
  alias gco='git checkout'
  alias gcb='git checkout -b' # Create new branch
  alias gb='git branch -vv' # Show branches with upstream info
  alias gm='git merge'
  alias gt='git tag'
  alias gf='git fetch --all --prune' # Fetch all remotes and prune deleted branches
fi

# ============================================================================
# DOCKER ALIASES (check if docker exists)
# ============================================================================

if command -v docker >/dev/null 2>&1; then
  alias d='docker'
  # alias dc='docker-compose' # docker compose is now preferred
  alias dps='docker ps -a --format "table {{.ID}}\t{{.Image}}\t{{.Names}}\t{{.Status}}"'
  alias di='docker images'
  alias dex='docker exec -it'
  alias dlog='docker logs -f' # Follow logs
  alias dstop='docker stop'
  alias drm='docker rm'
  alias drmi='docker rmi'
  # Add docker compose if needed
  # alias dco='docker compose'
fi

# ============================================================================
# MISC ALIASES
# ============================================================================

# Quick edit of configuration files (uses EDITOR variable set previously)
alias vimrc='$EDITOR ~/.vimrc' # If vim is used
alias bashrc='$EDITOR ~/.bashrc'
alias zshrc='$EDITOR ~/.zshrc'
alias aliases='$EDITOR "$HOME/.config/rcforge/rc-scripts/400_global_common_aliases.sh"' # Use quotes

# Reload shell configuration (attempts common files and rcforge)
alias reload='exec $SHELL -l' # Preferred way to reload entire environment

# Directory/file operations
alias md='mkdir -pv' # Already defined above
alias rd='rmdir' # Use with caution on non-empty dirs
alias src='source'

# Quick access to the rc command help
alias rch='rc help'

# Clear screen and scrollback buffer (more robust check)
if tput clear &>/dev/null; then
    alias cls='tput clear' # Use tput if available
else
    alias cls='clear' # Fallback to clear
fi

# EOF