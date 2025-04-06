#!/usr/bin/env bash
# shell-colors.sh - Comprehensive color and messaging utility for shell scripts
# Author: rcForge Team
# Date: 2025-04-05
# Version: 0.3.0
# Description: Provides color definitions, output formatting, and standardized messaging functions

# Set strict error handling
set -o nounset  # Treat unset variables as errors
set -o errexit  # Exit immediately if a command exits with a non-zero status

# ============================================================================
# COLOR DEFINITIONS
# ============================================================================

# Foreground Colors (Exported for use in other scripts)
export BLACK='\033[0;30m'
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export BLUE='\033[0;34m'
export MAGENTA='\033[0;35m'
export CYAN='\033[0;36m'
export WHITE='\033[0;37m'

# Bright Foreground Colors (Exported)
export BRIGHT_BLACK='\033[1;30m'
export BRIGHT_RED='\033[1;31m'
export BRIGHT_GREEN='\033[1;32m'
export BRIGHT_YELLOW='\033[1;33m'
export BRIGHT_BLUE='\033[1;34m'
export BRIGHT_MAGENTA='\033[1;35m'
export BRIGHT_CYAN='\033[1;36m'
export BRIGHT_WHITE='\033[1;37m'

# Background Colors (Exported)
export BG_BLACK='\033[40m'
export BG_RED='\033[41m'
export BG_GREEN='\033[42m'
export BG_YELLOW='\033[43m'
export BG_BLUE='\033[44m'
export BG_MAGENTA='\033[45m'
export BG_CYAN='\033[46m'
export BG_WHITE='\033[47m'

# Text Formatting (Exported)
export RESET='\033[0m'
export BOLD='\033[1m'
export DIM='\033[2m'
export ITALIC='\033[3m'
export UNDERLINE='\033[4m'
export BLINK='\033[5m'
export REVERSE='\033[7m'

# ============================================================================
# COLOR SUPPORT DETECTION
# ============================================================================

# Determine if the terminal supports colors
# Usage: DetermineColorSupport
# Returns: true if colors are supported, false otherwise
DetermineColorSupport() {
    local color_support=false
    
    # Check for color terminal support
    if [[ -t 1 ]]; then
        if [[ -n "${TERM:-}" && "$TERM" != "dumb" ]]; then
            color_support=true
        elif command -v tput >/dev/null 2>&1 && [[ "$(tput colors 2>/dev/null)" -ge 8 ]]; then
            color_support=true
        fi
    fi
    
    # Export the result for other scripts
    export COLOR_TERMINAL_SUPPORT="$color_support"
    
    # Return true/false based on color support
    if [[ "$color_support" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# ============================================================================
# MESSAGING FUNCTIONS
# ============================================================================

# Error message function with optional exit code
# Usage: ErrorMessage "Error message" [exit_code]
ErrorMessage() {
    local message="${1:-Unknown error}"
    local exit_code="${2:-}"
    local error_prefix="${BRIGHT_RED}[ERROR]${RESET}"
    
    # Always output to stderr
    if [[ "${COLOR_TERMINAL_SUPPORT:-false}" == "true" ]]; then
        printf "%b %s\n" "$error_prefix" "$message" >&2
    else
        printf "[ERROR] %s\n" "$message" >&2
    fi
    
    # Exit with specified code if provided
    if [[ -n "$exit_code" ]]; then
        exit "$exit_code"
    fi
}

# Warning message function
# Usage: WarningMessage "Warning message"
WarningMessage() {
    local message="${1:-Warning}"
    local warning_prefix="${BRIGHT_YELLOW}[WARNING]${RESET}"
    
    if [[ "${COLOR_TERMINAL_SUPPORT:-false}" == "true" ]]; then
        printf "%b %s\n" "$warning_prefix" "$message" >&2
    else
        printf "[WARNING] %s\n" "$message" >&2
    fi
}

# Informational message function
# Usage: InfoMessage "Information message"
InfoMessage() {
    local message="${1:-Information}"
    local info_prefix="${BRIGHT_BLUE}[INFO]${RESET}"
    
    if [[ "${COLOR_TERMINAL_SUPPORT:-false}" == "true" ]]; then
        printf "%b %s\n" "$info_prefix" "$message"
    else
        printf "[INFO] %s\n" "$message"
    fi
}

# Success message function
# Usage: SuccessMessage "Success message"
SuccessMessage() {
    local message="${1:-Operation successful}"
    local success_prefix="${BRIGHT_GREEN}[SUCCESS]${RESET}"
    
    if [[ "${COLOR_TERMINAL_SUPPORT:-false}" == "true" ]]; then
        printf "%b %s\n" "$success_prefix" "$message"
    else
        printf "[SUCCESS] %s\n" "$message"
    fi
}

# Debug message function (only shows if debug mode is enabled)
# Usage: DebugMessage "Debug message"
DebugMessage() {
    # Only display debug messages if debug mode is enabled
    if [[ "${DEBUG_MODE:-false}" != "true" ]]; then
        return 0
    fi
    
    local message="${1:-Debug information}"
    local debug_prefix="${CYAN}[DEBUG]${RESET}"
    
    if [[ "${COLOR_TERMINAL_SUPPORT:-false}" == "true" ]]; then
        printf "%b %s\n" "$debug_prefix" "$message" >&2
    else
        printf "[DEBUG] %s\n" "$message" >&2
    fi
}

# ============================================================================
# FORMATTING FUNCTIONS
# ============================================================================

# Create a section header with optional colors
# Usage: SectionHeader "Header text" [color]
SectionHeader() {
    local text="${1:-Section}"
    local color="${2:-$BRIGHT_BLUE}"
    local width=50
    local padding=$(( (width - ${#text} - 2) / 2 ))
    local line=$(printf '%*s' "$width" '' | tr ' ' '=')
    
    if [[ "${COLOR_TERMINAL_SUPPORT:-false}" == "true" ]]; then
        printf "\n%b%s%b\n" "$color" "$line" "$RESET"
        printf "%b%*s %s %*s%b\n" "$color" "$padding" "" "$text" "$padding" "" "$RESET"
        printf "%b%s%b\n\n" "$color" "$line" "$RESET"
    else
        printf "\n%s\n" "$line"
        printf "%*s %s %*s\n" "$padding" "" "$text" "$padding" ""
        printf "%s\n\n" "$line"
    fi
}

# Create a colored text block
# Usage: TextBlock "message" [foreground_color] [background_color]
TextBlock() {
    local message="${1:-}"
    local fg_color="${2:-$WHITE}"
    local bg_color="${3:-$BG_BLUE}"
    
    # Validate inputs
    if [[ -z "$message" ]]; then
        ErrorMessage "No message provided to TextBlock"
        return 1
    fi
    
    if [[ "${COLOR_TERMINAL_SUPPORT:-false}" == "true" ]]; then
        printf "%b%b %s %b\n" "$fg_color" "$bg_color" "$message" "$RESET"
    else
        printf "[ %s ]\n" "$message"
    fi
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Strip ANSI color codes from text
# Usage: StripColors "Colored text"
StripColors() {
    local text="${1:-}"
    
    # Use sed to remove ANSI color and formatting codes
    printf "%s" "$text" | sed -E $'s/\x1b\[[0-9;]*m//g'
}

# ============================================================================
# COLOR OUTPUT CONTROL
# ============================================================================

# Enable color output
# Usage: EnableColorOutput
EnableColorOutput() {
    export COLOR_OUTPUT_ENABLED=true
}

# Disable color output
# Usage: DisableColorOutput
DisableColorOutput() {
    export COLOR_OUTPUT_ENABLED=false
}

# ============================================================================
# INITIALIZATION
# ============================================================================

# Set default values (to be overridden by user preferences if needed)
export DEBUG_MODE="${DEBUG_MODE:-false}"
export COLOR_OUTPUT_ENABLED=true

# Initialize color support on script load
DetermineColorSupport

# If terminal doesn't support colors, disable color output
if ! DetermineColorSupport; then
    DisableColorOutput
fi

# For direct execution - show test output
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    SectionHeader "Shell Colors Test"
    
    InfoMessage "Testing color and messaging functions"
    SuccessMessage "This is a success message"
    WarningMessage "This is a warning message"
    ErrorMessage "This is an error message"
    
    export DEBUG_MODE=true
    DebugMessage "This is a debug message (only visible in debug mode)"
    
    TextBlock "This is a text block with default colors"
    TextBlock "Custom colors text block" "$YELLOW" "$BG_RED"
    
    SectionHeader "Color Palette"
    
    echo -e "${BLACK}BLACK${RESET} ${RED}RED${RESET} ${GREEN}GREEN${RESET} ${YELLOW}YELLOW${RESET}"
    echo -e "${BLUE}BLUE${RESET} ${MAGENTA}MAGENTA${RESET} ${CYAN}CYAN${RESET} ${WHITE}WHITE${RESET}"
    
    echo -e "${BRIGHT_BLACK}BRIGHT_BLACK${RESET} ${BRIGHT_RED}BRIGHT_RED${RESET}"
    echo -e "${BRIGHT_GREEN}BRIGHT_GREEN${RESET} ${BRIGHT_YELLOW}BRIGHT_YELLOW${RESET}"
    echo -e "${BRIGHT_BLUE}BRIGHT_BLUE${RESET} ${BRIGHT_MAGENTA}BRIGHT_MAGENTA${RESET}"
    echo -e "${BRIGHT_CYAN}BRIGHT_CYAN${RESET} ${BRIGHT_WHITE}BRIGHT_WHITE${RESET}"
    
    echo -e "${BG_BLACK}BG_BLACK${RESET} ${BG_RED}BG_RED${RESET} ${BG_GREEN}BG_GREEN${RESET}"
    echo -e "${BG_YELLOW}BG_YELLOW${RESET} ${BG_BLUE}BG_BLUE${RESET} ${BG_MAGENTA}BG_MAGENTA${RESET}"
    echo -e "${BG_CYAN}BG_CYAN${RESET} ${BG_WHITE}BG_WHITE${RESET}"
    
    echo -e "${BOLD}BOLD${RESET} ${DIM}DIM${RESET} ${ITALIC}ITALIC${RESET} ${UNDERLINE}UNDERLINE${RESET}"
    echo -e "${REVERSE}REVERSE${RESET} ${BLINK}BLINK${RESET}"
    
    SectionHeader "Formatting Examples"
    
    TextBlock "Error Block" "$WHITE" "$BG_RED"
    TextBlock "Success Block" "$BLACK" "$BG_GREEN"
    TextBlock "Warning Block" "$BLACK" "$BG_YELLOW"
    TextBlock "Info Block" "$WHITE" "$BG_BLUE"
fi

# Export functions for use in other scripts
export -f DetermineColorSupport
export -f ErrorMessage
export -f WarningMessage
export -f InfoMessage
export -f SuccessMessage
export -f DebugMessage
export -f SectionHeader
export -f TextBlock
export -f StripColors
export -f EnableColorOutput
export -f DisableColorOutput

# EOF
