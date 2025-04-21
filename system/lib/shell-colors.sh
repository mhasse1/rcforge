#!/usr/bin/env bash
# shell-colors.sh - Adaptive color and messaging utility for shell scripts
# Author: rcForge Team (Updated)
# Date: 2025-04-20
# Version: 0.5.0
# Category: system/library
# Description: Provides adaptive color definitions, compact output formatting,
#              and standardized messaging functions. Automatically detects
#              terminal background color for optimal contrast.

# --- Include Guard ---
if [[ -n "${_RCFORGE_SHELL_COLORS_SH_SOURCED:-}" ]]; then
	return 0 # Already sourced, exit
fi
_RCFORGE_SHELL_COLORS_SH_SOURCED=true

# ============================================================================
# TERMINAL DETECTION & COLOR ADAPTATION
# ============================================================================

# Function: DetectTerminalBackground
# Description: Attempts to detect if terminal has light or dark background
# Returns: "light" or "dark" (defaulting to dark if detection fails)
DetectTerminalBackground() {
	local background="dark" # Default assumption

	# Check if color output is disabled entirely
	[[ "${COLOR_OUTPUT_ENABLED:-true}" != "true" ]] && return

	# Method 1: Check for environment variable hints
	if [[ "${COLORFGBG:-}" == *";0" || "${COLORFGBG:-}" == *";7" ]]; then
		background="light"
	elif [[ "${TERMINAL_THEME:-}" == *"light"* || "${TERM_THEME:-}" == *"light"* ]]; then
		background="light"
	fi

	# Method 2: Try to use terminal capabilities if available
	# This is less reliable but a good fallback attempt
	if [[ -t 1 && -z "${RCFORGE_THEME_DETECTED:-}" ]]; then
		# Simplified detection - check if terminal likely supports 256 colors
		if [[ "$TERM" == *"256"* && "$(command -v tput >/dev/null 2>&1 && tput colors 2>/dev/null || echo 0)" -ge 256 ]]; then
			# Save a marker to avoid repeated detection
			export RCFORGE_THEME_DETECTED=true
			InfoMessage "Auto-detected terminal background as: $background"
		fi
	fi

	echo "$background"
}

# Function: SetColorScheme
# Description: Sets color variables based on detected background
# Arguments: $1 - "light" or "dark" background
SetColorScheme() {
	local background="$1"

	# Reset all variables first
	unset BLACK RED GREEN YELLOW BLUE MAGENTA CYAN WHITE
	unset BRIGHT_BLACK BRIGHT_RED BRIGHT_GREEN BRIGHT_YELLOW BRIGHT_BLUE BRIGHT_MAGENTA BRIGHT_CYAN BRIGHT_WHITE
	unset BG_BLACK BG_RED BG_GREEN BG_YELLOW BG_BLUE BG_MAGENTA BG_CYAN BG_WHITE
	unset RESET BOLD DIM ITALIC UNDERLINE BLINK REVERSE

	# Always define these base text formatting codes
	RESET='\033[0m'
	BOLD='\033[1m'
	DIM='\033[2m'
	ITALIC='\033[3m'
	UNDERLINE='\033[4m'
	BLINK='\033[5m'
	REVERSE='\033[7m'

	# Define standard ANSI color codes
	BLACK='\033[0;30m'
	RED='\033[0;31m'
	GREEN='\033[0;32m'
	YELLOW='\033[0;33m'
	BLUE='\033[0;34m'
	MAGENTA='\033[0;35m'
	CYAN='\033[0;36m'
	WHITE='\033[0;37m'

	# Bright variants
	BRIGHT_BLACK='\033[1;30m'
	BRIGHT_RED='\033[1;31m'
	BRIGHT_GREEN='\033[1;32m'
	BRIGHT_YELLOW='\033[1;33m'
	BRIGHT_BLUE='\033[1;34m'
	BRIGHT_MAGENTA='\033[1;35m'
	BRIGHT_CYAN='\033[1;36m'
	BRIGHT_WHITE='\033[1;37m'

	# Background colors
	BG_BLACK='\033[40m'
	BG_RED='\033[41m'
	BG_GREEN='\033[42m'
	BG_YELLOW='\033[43m'
	BG_BLUE='\033[44m'
	BG_MAGENTA='\033[45m'
	BG_CYAN='\033[46m'
	BG_WHITE='\033[47m'

	# Semantic color assignments based on background
	if [[ "$background" == "light" ]]; then
		# Colors optimized for light background
		INFO_COLOR="$BLUE"
		SUCCESS_COLOR="$GREEN"
		WARNING_COLOR="$YELLOW"
		ERROR_COLOR="$RED"
		HEADER_FG="$BLACK"
		HEADER_BG="$BG_WHITE"
		SECTION_CHAR="━" # Heavier line for light backgrounds
	else
		# Colors optimized for dark background (default)
		INFO_COLOR="$BRIGHT_BLUE"
		SUCCESS_COLOR="$BRIGHT_GREEN"
		WARNING_COLOR="$BRIGHT_YELLOW"
		ERROR_COLOR="$BRIGHT_RED"
		HEADER_FG="$BRIGHT_WHITE"
		HEADER_BG="$BG_BLUE"
		SECTION_CHAR="─" # Lighter line for dark backgrounds
	fi

	# Define symbol set for message types
	INFO_SYMBOL="•"    # Bullet for information
	SUCCESS_SYMBOL="✓" # Checkmark for success
	WARNING_SYMBOL="!" # Exclamation for warnings
	ERROR_SYMBOL="✗"   # X mark for errors

	# Export important variables for use by other scripts
	export COLOR_BACKGROUND="$background"
}

# Initialize COLOR_OUTPUT_ENABLED based on terminal capabilities
if [[ -t 1 && "$(command -v tput >/dev/null 2>&1 && tput colors 2>/dev/null || echo 0)" -gt 2 ]]; then
	export COLOR_OUTPUT_ENABLED=true
else
	export COLOR_OUTPUT_ENABLED=false
fi

# Detect background and set initial color scheme
background=$(DetectTerminalBackground)
SetColorScheme "$background"

# ============================================================================
# MESSAGE FUNCTIONS (Compact Format)
# ============================================================================

# Function: InfoMessage
# Description: Print a compact informational message
# Usage: InfoMessage "Information to display"
InfoMessage() {
	if [[ "${COLOR_OUTPUT_ENABLED:-true}" == "true" ]]; then
		printf "%b%s%b %s\n" "${INFO_COLOR}" "${INFO_SYMBOL}" "${RESET}" "${*}"
	else
		printf "INFO: %s\n" "${*}"
	fi
}

# Function: SuccessMessage
# Description: Print a compact success message
# Usage: SuccessMessage "Success message"
SuccessMessage() {
	if [[ "${COLOR_OUTPUT_ENABLED:-true}" == "true" ]]; then
		printf "%b%s%b %s\n" "${SUCCESS_COLOR}" "${SUCCESS_SYMBOL}" "${RESET}" "${*}"
	else
		printf "SUCCESS: %s\n" "${*}"
	fi
}

# Function: WarningMessage
# Description: Print a compact warning message to stderr
# Usage: WarningMessage "Warning message"
WarningMessage() {
	if [[ "${COLOR_OUTPUT_ENABLED:-true}" == "true" ]]; then
		printf "%b%s%b %s\n" "${WARNING_COLOR}" "${WARNING_SYMBOL}" "${RESET}" "${*}" >&2
	else
		printf "WARNING: %s\n" "${*}" >&2
	fi
}

# Function: ErrorMessage
# Description: Print a compact error message to stderr, optionally exit
# Usage: ErrorMessage "Error message" [exit_code]
ErrorMessage() {
	local message="${*}"
	local exit_code=""

	# Check if last argument is numeric (potential exit code)
	if [[ "${*:$#}" =~ ^[0-9]+$ ]]; then
		exit_code="${*:$#}"
		# Remove exit code from message
		message="${*:1:$(($# - 1))}"
	fi

	if [[ "${COLOR_OUTPUT_ENABLED:-true}" == "true" ]]; then
		printf "%b%s%b %s\n" "${ERROR_COLOR}" "${ERROR_SYMBOL}" "${RESET}" "${message}" >&2
	else
		printf "ERROR: %s\n" "${message}" >&2
	fi

	# Exit if code provided
	[[ -n "$exit_code" ]] && exit "$exit_code"
}

# Function: DebugMessage
# Description: Print a debug message if DEBUG_MODE is enabled
# Usage: DebugMessage "Debug info"
DebugMessage() {
	[[ "${DEBUG_MODE:-false}" != "true" ]] && return 0

	if [[ "${COLOR_OUTPUT_ENABLED:-true}" == "true" ]]; then
		printf "%b%s%b %s\n" "${DIM}${CYAN}" ">" "${RESET}" "${*}" >&2
	else
		printf "DEBUG: %s\n" "${*}" >&2
	fi
}

# Function: VerboseMessage
# Description: Print verbose message if is_verbose flag is true
# Usage: VerboseMessage is_verbose "Message"
VerboseMessage() {
	local is_verbose="${1:-false}"
	[[ "$is_verbose" != "true" ]] && return 0
	shift

	if [[ "${COLOR_OUTPUT_ENABLED:-true}" == "true" ]]; then
		printf "%b%s%b %s\n" "${DIM}${MAGENTA}" "*" "${RESET}" "${*}"
	else
		printf "VERBOSE: %s\n" "${*}"
	fi
}

# ============================================================================
# FORMATTING FUNCTIONS (Compact Design)
# ============================================================================

# Function: SectionHeader
# Description: Display a compact, color-based section header
# Usage: SectionHeader "Section Title"
SectionHeader() {
	local text="${1:-Section}"
	local text_length=${#text}
	local max_width=50

	echo "" # Add spacing before header

	if [[ "${COLOR_OUTPUT_ENABLED:-true}" == "true" ]]; then
		if [[ $text_length -ge 47 ]]; then
			# For long titles, just display the text in header color without lines
			printf "%b%s%b\n" "${BOLD}${HEADER_FG}" "${text}" "${RESET}"
		else
			# Calculate side padding for shorter titles
			local padding=$(((max_width - text_length - 2) / 2))
			local right_padding=$padding

			# Adjust if text_length + padding*2 + 2 doesn't exactly equal max_width
			if [[ $((text_length + (padding * 2) + 2)) -ne $max_width ]]; then
				right_padding=$((right_padding + 1))
			fi

			# Create side decorations with appropriate padding
			local left_decoration=""
			local right_decoration=""
			printf -v left_decoration '%*s' "$padding" ''
			printf -v right_decoration '%*s' "$right_padding" ''
			left_decoration="${left_decoration// /$SECTION_CHAR}"
			right_decoration="${right_decoration// /$SECTION_CHAR}"

			# Print compact header with decorations
			printf "%b%s %s %s%b\n" "${BOLD}${HEADER_FG}" "${left_decoration}" "${text}" "${right_decoration}" "${RESET}"
		fi
	else
		# No-color fallback
		printf "=== %s ===\n" "${text}"
	fi
}

# Function: TextBlock
# Description: Display text in a highlighted block
# Usage: TextBlock "Text" [FG_COLOR] [BG_COLOR]
TextBlock() {
	local message="${1:-}"
	local fg_color="${2:-$WHITE}"
	local bg_color="${3:-$BG_BLUE}"

	if [[ -z "$message" ]]; then
		return 1
	fi

	if [[ "${COLOR_OUTPUT_ENABLED:-true}" == "true" ]]; then
		printf "%b%b %s %b\n" "${fg_color}" "${bg_color}" "${message}" "${RESET}"
	else
		printf "[ %s ]\n" "${message}"
	fi
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Function: EnableColorOutput
# Description: Explicitly enable color output
EnableColorOutput() {
	export COLOR_OUTPUT_ENABLED=true
}

# Function: DisableColorOutput
# Description: Explicitly disable color output
DisableColorOutput() {
	export COLOR_OUTPUT_ENABLED=false
}

# Function: GetTerminalWidth
# Description: Get current terminal width
# Returns: Width in columns, or 80 if detection fails
GetTerminalWidth() {
	local width=80 # Default

	if [[ -n "${COLUMNS:-}" ]]; then
		width="$COLUMNS"
	elif command -v tput &>/dev/null && tput cols &>/dev/null; then
		width=$(tput cols)
	fi

	echo "$width"
}

# Function: StripColors
# Description: Remove ANSI color codes from string
# Usage: StripColors "colored text"
StripColors() {
	printf "%s" "${*}" | sed -E $'s/\x1b\\[[0-9;]*m//g'
}

# EOF
