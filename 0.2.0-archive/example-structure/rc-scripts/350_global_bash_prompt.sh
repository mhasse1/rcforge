#!/bin/bash
##########################################
# 200_bash_prompt.sh - Bash prompt
##########################################
function __rootprompt() {
  if [[ "${USER}" = "root" ]]; then
    echo 'root #'
  else
    echo '\$'
  fi
}

# Define colors - make sure to use Bash-compatible escape sequences
if [[ -x /usr/bin/tput ]] && tput setaf 1 &>/dev/null; then
  # We have color support
  BLUE="\[\033[0;34m\]"
  GREEN="\[\033[0;32m\]"
  YELLOW="\[\033[0;33m\]"
  CYAN="\[\033[0;36m\]"
  RED="\[\033[0;31m\]"
  PURPLE="\[\033[0;35m\]"
  RESET="\[\033[0m\]"
  BOLD="\[\033[1m\]"
else
  # No color support
  BLUE=""
  GREEN=""
  YELLOW=""
  CYAN=""
  RED=""
  PURPLE=""
  RESET=""
  BOLD=""
fi

# Git branch function
function __git_branch() {
  local branch
  if branch=$(git branch --show-current 2>/dev/null); then
    if [[ -n "$branch" ]]; then
      echo " ($branch)"
    fi
  fi
}

# Return status indicator - use explicit echo -e to ensure proper interpretation
function __return_status() {
  local status=$?
  if [[ $status -eq 0 ]]; then
    echo -e "\033[0;32m✓\033[0m"
  else
    echo -e "\033[0;31m✗ $status\033[0m"
  fi
}

# Custom prompt with Git branch and exit status
# Use standard PS1 escape sequences which Bash properly interprets
PS1='\n$(__return_status) $(__rootprompt) '"$RESET"'['"$CYAN"'\u'"$RESET"'@'"$YELLOW"'\h'"$RESET"'] '"$GREEN"'\w'"$PURPLE"'$(__git_branch)'"$RESET"'\n'
PS2="     "
