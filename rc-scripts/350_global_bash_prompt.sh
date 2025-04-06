#!/usr/bin/env bash
# 350_global_bash_prompt.sh - Bash prompt configuration
# Author: rcForge Team
# Date: 2025-04-06 # Updated Date
# Category: rc-script/bash
# Description: Sets the PS1 and PS2 prompt strings for Bash.

# Skip if not running in Bash
if [[ -z "${BASH_VERSION:-}" ]]; then
  return 0
fi

# ============================================================================
# Function: RootPrompt
# Description: Returns prompt symbol based on user ID ($/#).
# Usage: $(RootPrompt)
# ============================================================================
RootPrompt() {
  # Use Bash prompt expansion \$, which shows # if EUID=0, $ otherwise
  echo '\$'
  # Alternative explicit check:
  # if [[ $EUID -eq 0 ]]; then echo '#'; else echo '\$'; fi
}

# ============================================================================
# Function: GitBranch
# Description: Displays current Git branch and status indicators.
# Usage: $(GitBranch)
# ============================================================================
GitBranch() {
    local branch
    local status_indicators=""

    # Check if git command exists and we are in a repo
    if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null; then
        branch=$(git branch --show-current 2>/dev/null)

        if [[ -n "$branch" ]]; then
            # Check for staged changes (+)
            if ! git diff --quiet --cached; then
                status_indicators+="${GREEN}+${PURPLE}" # Green +
            fi
            # Check for unstaged changes (*)
            if ! git diff --quiet; then
                status_indicators+="${RED}*${PURPLE}" # Red *
            fi
            # Check for untracked files (?) - can be slow
            # if [[ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ]]; then
            #     status_indicators+="${RED}?${PURPLE}" # Red ?
            # fi

            # Output format: (branch+*)
            echo " (${branch}${status_indicators})"
        fi
    fi
    # No output if not in a git repo or no branch found
}

# ============================================================================
# Function: ReturnStatus
# Description: Displays indicator for the exit status of the last command.
# Usage: $(ReturnStatus)
# ============================================================================
ReturnStatus() {
  local status=$?
  if [[ $status -eq 0 ]]; then
    # Use literal escape codes within \[...\] for PS1
    echo -e "\[\033[0;32m\]✓\[\033[0m\]" # Green Checkmark
  else
    echo -e "\[\033[0;31m\]✗ $status\[\033[0m\]" # Red Cross + Status
  fi
}

# ============================================================================
# PROMPT CONFIGURATION
# ============================================================================

# Define colors using Bash PS1 escape sequences \[...\]
# Check if terminal supports color
if [[ -x /usr/bin/tput ]] && tput setaf 1 &>/dev/null; then
  # Color codes for PS1 (must be within \[...\])
  readonly BLUE="\[\033[0;34m\]"
  readonly GREEN="\[\033[0;32m\]"
  readonly YELLOW="\[\033[0;33m\]"
  readonly CYAN="\[\033[0;36m\]"
  readonly RED="\[\033[0;31m\]"
  readonly PURPLE="\[\033[0;35m\]"
  readonly RESET="\[\033[0m\]"
  readonly BOLD="\[\033[1m\]"
else
  # No color support
  readonly BLUE=""; readonly GREEN=""; readonly YELLOW=""; readonly CYAN=""
  readonly RED=""; readonly PURPLE=""; readonly RESET=""; readonly BOLD=""
fi

# --- PS1 - Main Prompt String ---
# Example two-line prompt:
# Line 1: [Status] [User@Host] PWD (GitBranch)
# Line 2: $/#
PS1="\n"'$(ReturnStatus)'" "'${RESET}[${CYAN}\u${RESET}@${YELLOW}\h${RESET}] ${GREEN}\w${PURPLE}$(GitBranch)${RESET}'"\n"'$(RootPrompt)'" "

# --- PS2 - Continuation Prompt String ---
# Used for multi-line commands
PS2="${YELLOW}> ${RESET}"

# --- PS4 - Debug Prompt String ---
# Used when 'set -x' is active, shows script name, line number, function
# export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# Optional: Set terminal window title (Bash doesn't have easy precmd hooks like Zsh)
# This updates title before each prompt display
# PROMPT_COMMAND="printf '\033]0;%s@%s:%s\007' \"${USER}\" \"${HOSTNAME%%.*}\" \"${PWD/#$HOME/~}\"; $PROMPT_COMMAND"

# EOF