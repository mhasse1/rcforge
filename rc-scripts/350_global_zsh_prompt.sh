#!/usr/bin/env zsh
# 350_global_zsh_prompt.sh - Zsh prompt configuration
# Author: rcForge Team
# Date: 2025-04-05
# Version: 0.3.0
# Description: Configures a customized Zsh prompt with git information and exit status

# Skip if not running in Zsh
if [[ -z "${ZSH_VERSION:-}" ]]; then
  return 0
fi

# ============================================================================
# ZSH PROMPT SETUP
# ============================================================================

# Enable prompt substitution
setopt PROMPT_SUBST

# Load required modules
autoload -Uz vcs_info
autoload -Uz add-zsh-hook
autoload -Uz colors && colors

# ============================================================================
# VERSION CONTROL INFORMATION
# ============================================================================

# Configure vcs_info for Git
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git*' formats " %F{magenta}(git:%b%m)%f"
zstyle ':vcs_info:git*' actionformats " %F{magenta}(git:%b|%a%m)%f"
zstyle ':vcs_info:git*' check-for-changes true
zstyle ':vcs_info:git*' stagedstr " %F{green}+%f"
zstyle ':vcs_info:git*' unstagedstr " %F{red}*%f"

# Add hook to update vcs info before prompt display
add-zsh-hook precmd vcs_info

# Function to check for untracked files
function +vi-git-untracked() {
  if [[ -n $(git ls-files --others --exclude-standard 2>/dev/null) ]]; then
    hook_com[misc]+="%F{red}?%f"
  fi
}

# Add untracked files check to hooks
zstyle ':vcs_info:git*+set-message:*' hooks git-untracked

# ============================================================================
# PROMPT UTILITY FUNCTIONS
# ============================================================================

# Function: virtualenv_info
# Description: Returns Python virtual environment name if active
function virtualenv_info() {
  if [[ -n "$VIRTUAL_ENV" ]]; then
    echo "(%F{cyan}$(basename $VIRTUAL_ENV)%f) "
  fi
}

# Function: return_status
# Description: Returns exit status indicator
function return_status() {
  local status=$?
  if [[ $status -eq 0 ]]; then
    echo "%F{green}✓%f"
  else
    echo "%F{red}✗ $status%f"
  fi
}

# Function: short_pwd
# Description: Returns shortened path (home dir as ~, last 2 dirs in path)
function short_pwd() {
  local pwd_length=30
  local dir="${PWD/#$HOME/~}"
  
  if [[ ${#dir} -gt $pwd_length ]]; then
    # Show only last 2 directories in path
    local parts=(${(s:/:)dir})
    local num_parts=${#parts}
    
    if [[ $num_parts -le 3 ]]; then
      echo "$dir"
    else
      echo ".../${parts[-2]}/${parts[-1]}"
    fi
  else
    echo "$dir"
  fi
}

# Function: root_prompt
# Description: Returns prompt symbol based on root status
function root_prompt() {
  if [[ $EUID -eq 0 ]]; then
    echo "%F{red}root #%f"
  else
    echo "%F{white}$%f"
  fi
}

# ============================================================================
# PROMPT CONFIGURATION
# ============================================================================

# Set terminal title
function set_terminal_title() {
  print -Pn "\e]0;%n@%m: %~\a"
}
add-zsh-hook precmd set_terminal_title

# Choose a prompt style (comment out the ones you don't want)

# Style 1: Minimal, single-line prompt
# PROMPT='%F{green}%n@%m%f:%F{blue}%~%f${vcs_info_msg_0_} $(root_prompt) '

# Style 2: Two-line prompt with status indicator (default)
PROMPT='
$(return_status) $(root_prompt) [%F{cyan}%n%f@%F{yellow}%m%f] %F{green}$(short_pwd)%f${vcs_info_msg_0_}
$(virtualenv_info)%f'

# Style 3: Full-featured multi-line prompt
# PROMPT='
# %F{yellow}┌─[%F{green}%n%f@%F{blue}%m%F{yellow}]─[%F{red}%D{%H:%M:%S}%F{yellow}]─[%F{green}%~%F{yellow}]
# %F{yellow}└─[${vcs_info_msg_0_}%F{yellow}]─[$(return_status)%F{yellow}]→ %f'

# Secondary prompt for multi-line commands
PROMPT2='%F{yellow}> %f'

# Right prompt (showing time)
RPROMPT='%F{240}%*%f'

# EOF
