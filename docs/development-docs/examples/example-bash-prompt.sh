#!/bin/bash
# 300_global_bash_prompt.sh - Custom Bash prompt with Git integration
# Author: Mark Hasse
# Copyright: Analog Edge LLC
# Date: 2025-03-20

# Exit if not running in bash
if ! shell_is_bash; then
  debug_echo "Skipping bash prompt in non-bash shell"
  return 0
fi

debug_echo "Setting up enhanced bash prompt"

# Define colors if terminal supports them
if [[ -x /usr/bin/tput ]] && tput setaf 1 >/dev/null 2>&1; then
  # Define colors
  RESET="\[\033[0m\]"
  BOLD="\[\033[1m\]"
  BLUE="\[\033[38;5;27m\]"
  GREEN="\[\033[38;5;35m\]"
  YELLOW="\[\033[38;5;214m\]"
  RED="\[\033[38;5;196m\]"
  PURPLE="\[\033[38;5;92m\]"
  CYAN="\[\033[38;5;45m\]"
  GRAY="\[\033[38;5;245m\]"
else
  # No color support
  RESET=""
  BOLD=""
  BLUE=""
  GREEN=""
  YELLOW=""
  RED=""
  PURPLE=""
  CYAN=""
  GRAY=""
fi

# Git status function
get_git_status() {
  # Check if git is available
  if ! cmd_exists git; then
    return
  fi

  # Check if we're in a git repo
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return
  fi

  local branch=$(git symbolic-ref --short HEAD 2>/dev/null || git describe --tags --always 2>/dev/null)
  local git_status=$(git status --porcelain 2>/dev/null)

  # Check for changes
  if [[ -z "$git_status" ]]; then
    echo " ${GREEN}(${branch})${RESET}"
  else
    # Count modified, added, and untracked files
    local modified=$(echo "$git_status" | grep -E "^[ MARC]M" | wc -l)
    local added=$(echo "$git_status" | grep -E "^A[ MD]|^M[ A]" | wc -l)
    local untracked=$(echo "$git_status" | grep -E "^\?\?" | wc -l)

    # Show status with counts
    echo " ${YELLOW}(${branch}${RED}:${modified}±${added}+${untracked}?${YELLOW})${RESET}"
  fi
}

# Show virtualenv if activated
get_virtualenv() {
  if [[ -n "$VIRTUAL_ENV" ]]; then
    echo " ${BLUE}($(basename "$VIRTUAL_ENV"))${RESET}"
  fi
}

# Show hostname in red if this is an SSH session
get_hostname_colored() {
  if [[ -n "$SSH_CLIENT" || -n "$SSH_TTY" ]]; then
    echo "${RED}\h${RESET}"
  else
    echo "${GREEN}\h${RESET}"
  fi
}

# Time command execution and show duration if longer than threshold
timer_start() {
  TIMER_START=$(date +%s)
}

timer_stop() {
  local duration=$(($(date +%s) - $TIMER_START))
  unset TIMER_START

  # Only show duration if longer than 3 seconds
  if [[ $duration -gt 3 ]]; then
    echo " ${YELLOW}(${duration}s)${RESET}"
  fi
}

# Set up the prompt command and trap to measure execution time
trap 'timer_start' DEBUG
export PROMPT_COMMAND='timer_value=$(timer_stop)'

# Define the main prompt
PS1="\n${GRAY}[\t]${RESET} ${BOLD}\u@$(get_hostname_colored)${RESET} ${BLUE}\w${RESET}\$(get_git_status)\$(get_virtualenv)\${timer_value}\n\$ "

# Set secondary prompt
PS2="${GRAY}→ ${RESET}"

debug_echo "Bash prompt configured"
