#!/usr/bin/env bash
# 350_global_bash_prompt.sh - Bash prompt configuration using PROMPT_COMMAND
# Author: rcForge Team
# Date: 2025-04-07 # Updated Date
# Category: rc-script/bash
# Description: Sets the PS1 and PS2 prompt strings for Bash dynamically.

# Note: Color variables (e.g., GREEN, RED, RESET) are sourced from shell-colors.sh
#       and should be available here.

# ============================================================================
# PROMPT HELPER FUNCTIONS (Output raw codes - rely on sourced colors)
# ============================================================================

# ============================================================================
# Function: _prompt_rootprompt
# Description: Returns prompt symbol based on user ID ($/#) with raw codes.
# Usage: $(_prompt_rootprompt)
# ============================================================================
_prompt_rootprompt() {
	if [[ $EUID -eq 0 ]]; then
		# Use color vars from shell-colors.sh
		printf "%b#%b" "${RED:-}" "${RESET:-}" # Add default empty value in case colors aren't set
	else
		# Use default terminal color for '$'
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
				status_indicators+="${GREEN:-}+" # Green +
			fi
			# Check for unstaged changes (*)
			if ! git diff --quiet; then
				status_indicators+="${RED:-}*" # Red *
			fi
			# Untracked check removed for performance, add back if needed

			# Output format: (branch<indicators>) - Use PURPLE/MAGENTA
			printf " %b(%s%s%b)%b" "${MAGENTA:-}" "${branch}" "${status_indicators}" "${MAGENTA:-}" "${RESET:-}"
		fi
	fi
	# No output if not in a git repo or no branch found
}

# ============================================================================
# Function: _prompt_returnstatus
# Description: Displays indicator for the exit status of the last command with raw codes.
# Usage: call in PROMPT_COMMAND, relies on $?
# ============================================================================
_prompt_returnstatus() {
	local status="$1" # Pass $? explicitly
	if [[ $status -eq 0 ]]; then
		# Use color vars from shell-colors.sh
		printf "%b✓%b" "${GREEN:-}" "${RESET:-}"
	else
		printf "%b✗ %s%b" "${RED:-}" "$status" "${RESET:-}"
	fi
}

# SSH connection indicator
function __ssh_indicator() {
	if [[ -n "$SSH_CLIENT" || -n "$SSH_TTY" || -n "$SSH_CONNECTION" ]]; then
		echo "$BLACK_YELLOW SSH $RESET "
	fi
}

# ============================================================================
# PROMPT BUILDING FUNCTION (Called by PROMPT_COMMAND)
# ============================================================================
_rcforge_build_prompt() {
	local exit_status=$? # Capture exit status *immediately*

	# --- Build Prompt String ---
	local status_indicator=$(_prompt_returnstatus "$exit_status") # Pass $?
	local git_info=$(_prompt_gitbranch)
	local prompt_symbol=$(_prompt_rootprompt)

	# Assemble PS1 string, adding \[ \] around *all* non-printing parts
	# Use color vars sourced from shell-colors.sh (e.g., CYAN, YELLOW, GREEN, RESET)
	# Provide default empty values ":-" in case shell-colors wasn't sourced correctly
	PS1=""                         # Start fresh
	PS1+="\n"                      # Newline before prompt
	PS1+="\[${status_indicator}\]" # Status (already has colors/reset)
	PS1+=" \[${RESET:-}\]"
	PS1+="\[${__ssh_indicator}\]"
	PS1+=" \[${RESET:-}\]"
	PS1+=" [\[${CYAN:-}\]\u\[${RESET:-}\]@\[${YELLOW:-}\]\h\[${RESET:-}\]]" # user@host
	PS1+=" \[${GREEN:-}\]\w\[${RESET:-}\]"                                  # Working directory
	PS1+="\[${git_info}\]"                                                  # Git info (already has colors/reset)
	PS1+="\n"                                                               # Newline after first line

	# Set PS2 (Continuation prompt)
	PS2="    "
}

# ============================================================================
# SET PROMPT_COMMAND
# ============================================================================
# Set PROMPT_COMMAND to call the builder function
# Append to existing PROMPT_COMMAND if it's already set by something else
PROMPT_COMMAND="_rcforge_build_prompt${PROMPT_COMMAND:+;$PROMPT_COMMAND}"

# EOF
