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
DetermineColorSupport() {
    local color_support=false
    
    # Check for color terminal support
    if [[ -t 1 ]] && [[ "$(tput colors 2>/dev/null)" -ge 8 ]]; then
        color_support=true
    fi
    
    # Export the result for other scripts
    export COLOR_TERMINAL_SUPPORT="$color_support"
    
    # Return success if colors are supported
    [[ "$color_support" == "true" ]]
}

# ============================================================================
# MESSAGING FUNCTIONS
# ============================================================================

# Error message function with optional exit code
# Usage: ErrorMessage "Error message" [exit_code]
ErrorMessage() {
    local message="${1:-Unknown error}"
    local exit_code="${2:-1}"
    local error_prefix="${BRIGHT_RED}[ERROR]${RESET}"
    
    # Always output to stderr
    if [[ "${COLOR_TERMINAL_SUPPORT:-false}" == "true" ]]; then
        printf "%b %s\n" "$error_prefix" "$message" >&2
    else
        printf "[ERROR] %s\n" "$message" >&2
    fi
    
    # Exit with specified code if non-zero
    if [[ "$exit_code" -ne 0 ]]; then
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

# ============================================================================
# ADVANCED COLOR FORMATTING
# ============================================================================

# Create a colored block of text
# Usage: ColorBlock "message" [foreground_color] [background_color]
ColorBlock() {
    local message="${1:-}"
    local fg_color="${2:-$WHITE}"
    local bg_color="${3:-$BG_BLUE}"
    
    # Validate inputs
    if [[ -z "$message" ]]; then
        ErrorMessage "No message provided to ColorBlock"
        return 1
    fi
    
    if [[ "${COLOR_TERMINAL_SUPPORT:-false}" == "true" ]]; then
        printf "%b%b %s %b\n" "$fg_color" "$bg_color" "$message" "$RESET"
    else
        printf "%s\n" "$message"
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

# Validate color input
# Usage: ValidateColor "color_name"
ValidateColor() {
    local color="${1:-}"
    
    if [[ -z "$color" ]]; then
        ErrorMessage "No color provided"
        return 1
    fi
    
    # Check against known color variables
    local known_colors=(
        BLACK RED GREEN YELLOW BLUE MAGENTA CYAN WHITE
        BRIGHT_BLACK BRIGHT_RED BRIGHT_GREEN BRIGHT_YELLOW 
        BRIGHT_BLUE BRIGHT_MAGENTA BRIGHT_CYAN BRIGHT_WHITE
        BG_BLACK BG_RED BG_GREEN BG_YELLOW BG_BLUE 
        BG_MAGENTA BG_CYAN BG_WHITE
    )
    
    local found=false
    for known_color in "${known_colors[@]}"; do
        if [[ "$color" == "$known_color" ]]; then
            found=true
            break
        fi
    done
    
    if [[ "$found" == false ]]; then
        ErrorMessage "Invalid color: $color"
        return 1
    fi
    
    return 0
}

# ============================================================================
# COLOR OUTPUT CONTROL
# ============================================================================

# Enable color output
EnableColorOutput() {
    export COLOR_OUTPUT_ENABLED=true
}

# Disable color output
DisableColorOutput() {
    export COLOR_OUTPUT_ENABLED=false
}

# ============================================================================
# INITIALIZATION
# ============================================================================

# Initialize color support on script load
InitializeColorSystem() {
    # Detect color terminal support
    DetermineColorSupport
    
    # Default to enabling color output if terminal supports it
    if [[ "${COLOR_TERMINAL_SUPPORT}" == "true" ]]; then
        EnableColorOutput
    else
        DisableColorOutput
    fi
}

# Call initialization function
InitializeColorSystem

# Export utility functions
export -f ErrorMessage
export -f WarningMessage
export -f InfoMessage
export -f SuccessMessage
export -f ColorBlock
export -f StripColors
export -f ValidateColor
export -f EnableColorOutput
export -f DisableColorOutput
export -f InitializeColorSystem

# EOF
