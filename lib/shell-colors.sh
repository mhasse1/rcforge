#!/usr/bin/env bash
# shell-colors.sh - Comprehensive color and messaging utility for shell scripts
# Author: Mark Hasse
# Date: 2025-03-30
# Category: common
# Description: Provides color definitions, output formatting, and standardized messaging functions

# Strict error handling
set -o nounset  # Treat unset variables as errors
set -o errexit  # Exit immediately if a command exits with a non-zero status

# ============================================================================
# COLOR DEFINITIONS
# ============================================================================

# Foreground Colors
export BLACK='\033[0;30m'
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export BLUE='\033[0;34m'
export MAGENTA='\033[0;35m'
export CYAN='\033[0;36m'
export WHITE='\033[0;37m'

# Bright Foreground Colors
export BRIGHT_BLACK='\033[1;30m'
export BRIGHT_RED='\033[1;31m'
export BRIGHT_GREEN='\033[1;32m'
export BRIGHT_YELLOW='\033[1;33m'
export BRIGHT_BLUE='\033[1;34m'
export BRIGHT_MAGENTA='\033[1;35m'
export BRIGHT_CYAN='\033[1;36m'
export BRIGHT_WHITE='\033[1;37m'

# Background Colors
export BG_BLACK='\033[40m'
export BG_RED='\033[41m'
export BG_GREEN='\033[42m'
export BG_YELLOW='\033[43m'
export BG_BLUE='\033[44m'
export BG_MAGENTA='\033[45m'
export BG_CYAN='\033[46m'
export BG_WHITE='\033[47m'

# Text Formatting
export RESET='\033[0m'
export BOLD='\033[1m'
export DIM='\033[2m'
export ITALIC='\033[3m'
export UNDERLINE='\033[4m'
export BLINK='\033[5m'
export REVERSE='\033[7m'

# Environment Variables for Color Support
export TERM_COLORS_SUPPORTED=false
export COLOR_OUTPUT_ENABLED=true
# ============================================================================
# CORE MESSAGING FUNCTIONS
# ============================================================================

# Display an error message to stderr
# Usage: ErrorMessage "Error message" [exit_code]
ErrorMessage() {
    local message="${1:-Unknown error}"
    local exit_code="${2:-1}"

    # Always use stderr for error messages
    if [[ "$COLOR_OUTPUT_ENABLED" == true ]]; then
        printf "%b[ERROR]%b %s\n" "$c_BRIGHT_RED" "$c_RESET" "$message" >&2
    else
        printf "[ERROR] %s\n" "$message" >&2
    fi

    # Only exit if an exit code is provided and not 0
    if [[ "$exit_code" -ne 0 ]]; then
        exit "$exit_code"
    fi
}

# Display a warning message to stderr
# Usage: WarningMessage "Warning message"
WarningMessage() {
    local message="${1:-Warning}"

    if [[ "$COLOR_OUTPUT_ENABLED" == true ]]; then
        printf "%b[WARNING]%b %s\n" "$c_BRIGHT_YELLOW" "$c_RESET" "$message" >&2
    else
        printf "[WARNING] %s\n" "$message" >&2
    fi
}

# Display an informational message to stdout
# Usage: InfoMessage "Info message"
InfoMessage() {
    local message="${1:-Information}"

    if [[ "$COLOR_OUTPUT_ENABLED" == true ]]; then
        printf "%b[INFO]%b %s\n" "$c_BRIGHT_BLUE" "$c_RESET" "$message"
    else
        printf "[INFO] %s\n" "$message"
    fi
}

# Display a success message to stdout
# Usage: SuccessMessage "Success message"
SuccessMessage() {
    local message="${1:-Operation successful}"

    if [[ "$COLOR_OUTPUT_ENABLED" == true ]]; then
        printf "%b[SUCCESS]%b %s\n" "$c_BRIGHT_GREEN" "$c_RESET" "$message"
    else
        printf "[SUCCESS] %s\n" "$message"
    fi
}

# ============================================================================
# ADVANCED OUTPUT FORMATTING FUNCTIONS
# ============================================================================

# Create a section header
# Usage: SectionHeader "Section Title" [color]
SectionHeader() {
    local title="${1:-Section}"
    local color="${2:-$c_CYAN}"
    local separator="${3:--}"
    local width="${4:-50}"

    local header_line
    header_line=$(printf "%*s" "$width" | tr ' ' "$separator")

    printf "\n%b%s%b\n" "$color" "$header_line" "$c_RESET"
    printf "%b%*s%b\n" "$color" $(( (width + ${#title}) / 2 )) "$title" "$c_RESET"
    printf "%b%s%b\n\n" "$color" "$header_line" "$c_RESET"
}

# Display a colored text block
# Usage: TextBlock "Message" [foreground_color] [background_color]
TextBlock() {
    local message="${1:-}"
    local fg_color="${2:-$c_WHITE}"
    local bg_color="${3:-$c_BG_BLUE}"

    if [[ -z "$message" ]]; then
        ErrorMessage "No message provided to TextBlock"
        return 1
    fi

    # Check if color output is enabled
    if [[ "$COLOR_OUTPUT_ENABLED" == true ]]; then
        printf "%b%b %s %b\n" "$fg_color" "$bg_color" "$message" "$c_RESET"
    else
        # Fallback to plain text if colors are disabled
        printf "%s\n" "$message"
    fi
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Strip color codes from text
# Usage: StripColors "Colored text"
StripColors() {
    local text="${1:-}"

    # Use sed to remove ANSI color and formatting codes
    printf "%s" "$text" | sed -E $'s/\x1b\[[0-9;]*m//g'
}

# Validate color input
# Usage: ValidateColor "color_name"
ValidateColor() {
    local color="${1:-}"
    local color_var="c_${color^^}"

    if [[ -z "$color" ]]; then
        ErrorMessage "No color provided" 1
    fi

    if [[ -z "${!color_var:-}" ]]; then
        ErrorMessage "Invalid color: $color" 1
    fi

    return 0
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

# Utility functions to control color output
# Enable color output
EnableColorOutput() {
    COLOR_OUTPUT_ENABLED=true
}

# Disable color output
DisableColorOutput() {
    COLOR_OUTPUT_ENABLED=false
}

# Check if color output is supported
IsColorOutputSupported() {
    # Check if terminal supports colors
    if [[ -t 1 ]] && [[ "$(tput colors)" -ge 8 ]]; then
        TERM_COLORS_SUPPORTED=true
    else
        TERM_COLORS_SUPPORTED=false
    fi

    return $([[ "$TERM_COLORS_SUPPORTED" == true ]])
}

# Initialize color output support
InitializeColorOutput() {
    IsColorOutputSupported

    # Enable color output by default if colors are supported
    if [[ "$TERM_COLORS_SUPPORTED" == true ]]; then
        EnableColorOutput
    else
        DisableColorOutput
    fi
}

# Call initialization on script load
InitializeColorOutput

# If this script is sourced, make functions available
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # Export functions so they can be used in other scripts
    export -f ErrorMessage
    export -f WarningMessage
    export -f InfoMessage
    export -f SuccessMessage
    export -f SectionHeader
    export -f TextBlock
    export -f StripColors
    export -f ValidateColor
    export -f EnableColorOutput
    export -f DisableColorOutput
    export -f IsColorOutputSupported
    export -f InitializeColorOutput

    # Export environment variables
    export COLOR_OUTPUT_ENABLED
    export TERM_COLORS_SUPPORTED
fi

# EOF
