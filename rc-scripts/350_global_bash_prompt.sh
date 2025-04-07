#!/usr/bin/env bash
# 350_global_bash_prompt.sh - Bash prompt configuration using PROMPT_COMMAND
# Author: rcForge Team
# Date: 2025-04-07
# Category: rc-script/bash
# Description: Sets the PS1 and PS2 prompt strings for Bash dynamically.

# Skip if not running in Bash
if [[ -z "${BASH_VERSION:-}" ]]; then
  return 0
fi

# ============================================================================
# RAW COLOR CODES (Defined locally for prompt building, no \[ \])
# ============================================================================
# Check if terminal supports color (use tput)
__prompt_colors_enabled=false
if [[ -x /usr/bin/tput ]] && tput setaf 1 &>/dev/null; then
    if [[ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]]; then
        __prompt_colors_enabled=true
    fi
fi

# Define raw codes only if colors are supported
if [[ "$__prompt_colors_enabled" == "true" ]]; then
  readonly C_BLUE='\033[0;34m'
  readonly C_GREEN='\033[0;32m'
  readonly C_YELLOW='\033[0;33m'
  readonly C_CYAN='\033[0;36m'
  readonly C_RED='\033[0;31m'
  readonly C_PURPLE='\033[0;35m'
  readonly C_RESET='\033[0m'
  readonly C_BOLD='\033[1m'
else
  readonly C_BLUE=""
  readonly C_GREEN=""
  readonly C_YELLOW=""
  readonly C_CYAN=""
  readonly C_RED=""
  readonly C_PURPLE=""
  readonly C_RESET=""
  readonly C_BOLD=""
fi


# ============================================================================
# PROMPT HELPER FUNCTIONS (Output raw codes)
# ============================================================================

# ============================================================================
# Function: _prompt_rootprompt
# Description: Returns prompt symbol based on user ID ($/#) with raw codes.
# Usage: $(_prompt_rootprompt)
# ============================================================================
_prompt_rootprompt() {
  if [[ $EUID -eq 0 ]]; then
      # Red # for root
      printf "%b#%b" "${C_RED}" "${C_RESET}"
  else
      # Regular $ (use default color or white - let PS1 handle final color)
      printf "%s" "\$"
 fi
}

# ============================================================================
# Function: _prompt_gitbranch
# Description: Displays current Git branch and status indicators with raw codes.
# Usage: $(_prompt_gitbranch)
# ============================================================================
_prompt_gitbranch() {
    local branch
    local status_indicators=""

    # Check if git command exists and we are in a repo
    if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null; then
        branch=$(git branch --show-current 2>/dev/null)

        if [[ -n "$branch" ]]; then
            # Check for staged changes (+)
            if ! git diff --quiet --cached; then
                status_indicators+="${C_GREEN}+" # Green +
            fi
            # Check for unstaged changes (*)
            if ! git diff --quiet; then
                status_indicators+="${C_RED}*" # Red *
            fi
            # Check for untracked files (?) - OPTIONAL, can be slow
            # if [[ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ]]; then
            #     status_indicators+="${C_RED}?" # Red ?
            # fi

            # Output format: (branch<indicators>) - Use PURPLE for surrounding text
             printf " %b(%s%s%b)%b" "${C_PURPLE}" "${branch}" "${status_indicators}" "${C_PURPLE}" "${C_RESET}"
        fi
    fi
    # No output if not in a git repo or no branch found
}

# ============================================================================
# Function: _prompt_returnstatus
# Description: Displays indicator for the exit status of the last command with raw codes.
# Usage: $(_prompt_returnstatus)
# ============================================================================
_prompt_returnstatus() {
  local status=$?
  if [[ $status -eq 0 ]]; then
    # Raw codes only: Green Checkmark Reset
    printf "%b✓%b" "${C_GREEN}" "${C_RESET}"
  else
    # Raw codes only: Red Cross Status Reset
    printf "%b✗ %s%b" "${C_RED}" "$status" "${C_RESET}"
  fi
}

# ============================================================================
# PROMPT BUILDING FUNCTION (Called by PROMPT_COMMAND)
# ============================================================================
_rcforge_build_prompt() {
    local exit_status=$? # Capture exit status early

    # --- Build Prompt String ---
    # Use helper functions that return raw codes
    local status_indicator=$(_prompt_returnstatus) # Uses captured $?
    local git_info=$(_prompt_gitbranch)
    local prompt_symbol=$(_prompt_rootprompt)

    # Assemble PS1 string, adding \[ \] around *all* non-printing parts
    PS1="" # Start fresh
    PS1+="\n" # Newline before prompt
    PS1+="\[${status_indicator}\]" # Status (already has colors/reset)
    PS1+=" \[$C_RESET\][\[$C_CYAN\]\u\[$C_RESET\]@\[$C_YELLOW\]\h\[$C_RESET\]]" # user@host
    PS1+=" \[$C_GREEN\]\w\[$C_RESET\]" # Working directory
    PS1+="\[${git_info}\]" # Git info (already has colors/reset)
    PS1+="\n" # Newline after first line
    PS1+="\[${prompt_symbol}\]" # Prompt symbol (already has colors/reset)
    PS1+=" " # Trailing space

    # Set PS2 (Continuation prompt)
    # Note: PS2 also needs escaping for non-printing characters
    PS2="\[${C_YELLOW}\]> \[$C_RESET\]"
}

# ============================================================================
# SET PROMPT_COMMAND
# ============================================================================
# Set PROMPT_COMMAND to call the builder function
# Append to existing PROMPT_COMMAND if it's already set by something else
PROMPT_COMMAND="_rcforge_build_prompt${PROMPT_COMMAND:+;$PROMPT_COMMAND}"

# Clean up temporary variable used for color check
unset __prompt_colors_enabled

# EOF