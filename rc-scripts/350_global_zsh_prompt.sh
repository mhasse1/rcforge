#!/usr/bin/env zsh
# 350_global_zsh_prompt.sh - Zsh prompt configuration
# Author: rcForge Team
# Date: 2025-04-06 # Updated Date
# Category: rc-script/zsh
# Description: Configures a customized Zsh prompt with git information and exit status


# ============================================================================
# ZSH PROMPT SETUP
# ============================================================================

# Enable prompt substitution for dynamic content
setopt PROMPT_SUBST

# Load required Zsh modules for prompt customization
autoload -Uz vcs_info        # Version Control System info
autoload -Uz add-zsh-hook    # Hook functions
autoload -Uz colors && colors  # Enable color variables (%F{color})

# ============================================================================
# VERSION CONTROL INFORMATION (GIT)
# ============================================================================

# Configure vcs_info for Git integration
zstyle ':vcs_info:*' enable git                   # Enable Git support
zstyle ':vcs_info:git*' formats " %F{magenta}(git:%b%m)%f"  # Format: (git:branch<modified>)
zstyle ':vcs_info:git*' actionformats " %F{magenta}(git:%b|%a%m)%f" # Format during rebase/merge etc.
zstyle ':vcs_info:git*' check-for-changes true    # Check repo status
zstyle ':vcs_info:git*' stagedstr " %F{green}+%f"  # Indicator for staged changes
zstyle ':vcs_info:git*' unstagedstr " %F{red}*%f"  # Indicator for unstaged changes

# Add hook to automatically update VCS info before displaying the prompt
add-zsh-hook precmd vcs_info

# Function to check for untracked Git files (Zsh hook function naming convention)
# Needs to be defined *before* being added to the hook style below
function +vi-git-untracked() {
  # Check if 'git' command exists and we are inside a git repo work tree
  if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null; then
    # If git ls-files finds untracked files, add '?' indicator
    if [[ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ]]; then
      # Append the indicator to the 'misc' part of vcs_info message
      hook_com[misc]+="%F{red}?%f"
    fi
  fi
}

# Add the untracked files check function to the vcs_info hook system
zstyle ':vcs_info:git*+set-message:*' hooks git-untracked

# ============================================================================
# PROMPT UTILITY FUNCTIONS
# ============================================================================

# ============================================================================
# Function: VirtualenvInfo
# Description: Returns Python virtual environment name within parenthesis if active.
# Usage: $(VirtualenvInfo)
# Returns: Echoes formatted string like "(venv) " or empty string.
# ============================================================================
VirtualenvInfo() {
  # Check if VIRTUAL_ENV variable is set and non-empty
  if [[ -n "${VIRTUAL_ENV:-}" ]]; then
    # Use Zsh prompt expansion for colors
    echo "(%F{cyan}$(basename "$VIRTUAL_ENV")%f) "
  fi
}

# ============================================================================
# Function: ReturnStatus
# Description: Returns a colored indicator based on the exit status of the last command.
# Usage: $(ReturnStatus)
# Returns: Echoes green checkmark for success (0), red cross and status code for failure.
# ============================================================================
ReturnStatus() {
  local status=$? # Capture last command's exit status
  if [[ $status -eq 0 ]]; then
    echo "%F{green}✓%f" # Green checkmark
  else
    echo "%F{red}✗ $status%f" # Red cross and status code
  fi
}

# ============================================================================
# Function: ShortPwd
# Description: Returns a shortened representation of the current working directory.
#              Replaces $HOME with ~, limits length, shows ellipsis and last dirs if too long.
# Usage: $(ShortPwd)
# Returns: Echoes the shortened PWD string.
# ============================================================================
ShortPwd() {
  # Use Zsh's built-in prompt escape %~ which often does what's needed
  # echo "%~"
  # Or, custom logic for more control:
  local pwd_length=30 # Max length before shortening
  local current_dir="${PWD/#$HOME/~}" # Replace home path with ~

  if [[ ${#current_dir} -gt $pwd_length ]]; then
    # Use Zsh prompt truncation if available and simpler: %<N>d or %<N>~
    # echo "%${pwd_length}<...<%d" # Example using Zsh truncation
    # Manual truncation logic:
    local -a parts # Array for path components
    # Use Zsh specific splitting on '/'
    parts=(${(s:/:)current_dir})
    local num_parts=${#parts}

    # Show full path if only root or one level deep from shortened point
    if [[ $num_parts -le 3 ]]; then
      echo "$current_dir"
    else
      # Show ellipsis and last two components
      echo ".../${parts[-2]}/${parts[-1]}"
    fi
  else
    # Path is short enough, show as is
    echo "$current_dir"
  fi
}

# ============================================================================
# Function: RootPrompt
# Description: Returns the prompt symbol ($ or #) colored red if root.
# Usage: $(RootPrompt)
# Returns: Echoes the appropriate colored prompt symbol.
# ============================================================================
RootPrompt() {
  # Use Zsh prompt conditional %(!.#.$) - '#' if root, '$' otherwise
  # echo "%(!.%F{red}#%f.%F{white}$%f)"
  # Or manual check:
  if [[ $EUID -eq 0 ]]; then
    echo "%F{red}#%f" # Red '#' for root
  else
    echo "%F{white}$%f" # White '$' for regular user
  fi
}

# ============================================================================
# PROMPT CONFIGURATION
# ============================================================================

# ============================================================================
# Function: SetTerminalTitle
# Description: Zsh hook function to set the terminal window title.
# Usage: Automatically called by precmd hook.
# ============================================================================
SetTerminalTitle() {
  # Set title to user@host: current_dir
  # %n: username, %m: short hostname, %~: PWD with ~ substitution
  print -Pn "\e]0;%n@%m: %~\a"
}
# Register the function to run before each prompt
add-zsh-hook precmd SetTerminalTitle

# --- Define the Prompt ---
# Choose a prompt style by uncommenting the desired PROMPT line.

# Style 1: Minimal, single-line prompt
# PROMPT='%F{green}%n@%m%f:%F{blue}$(ShortPwd)%f${vcs_info_msg_0_} $(RootPrompt) '

# Style 2: Three-line prompt with status indicator (default)
# Note: Ensure newline is correctly handled, often needs careful quoting or %{%} markers
# Using prompt expansion within single quotes is generally safer in Zsh
PROMPT='
%(?.%F{green}✓%f.%F{red}✗%f) '%F{240}%*%f' [%F{cyan}%n%f@%F{yellow}%m%f] %F{green}%~%f${vcs_info_msg_0_}
'
# This uses Zsh conditional %(?.success.failure), %~ for pwd, %# for root/user prompt char

# Alternative Style 2 (Using Functions): Needs careful newline handling
# PROMPT='
# $(ReturnStatus) $(RootPrompt) [%F{cyan}%n%f@%F{yellow}%m%f] %F{green}$(ShortPwd)%f${vcs_info_msg_0_}
# $(VirtualenvInfo)%f' # Potential issues with subshells/newlines

# Style 3: Full-featured multi-line prompt (Example using functions)
# PROMPT='
# %F{yellow}┌─[%F{green}%n%f@%F{blue}%m%F{yellow}]─[%F{red}%D{%H:%M:%S}%F{yellow}]─[%F{green}$(ShortPwd)%F{yellow}]
# %F{yellow}└─[${vcs_info_msg_0_}%F{yellow}]─[$(ReturnStatus)%F{yellow}]→ %f'

# Secondary prompt (for commands spanning multiple lines)
PROMPT2='  '

# Right-side prompt (e.g., showing time) - uses %* for time
# RPROMPT='%F{240}%*%f'

# Ensure vcs_info is updated for RPROMPT if it uses VCS info
# zstyle ':vcs_info:git*' rprompt ' %F{cyan}%b%f'

# EOF