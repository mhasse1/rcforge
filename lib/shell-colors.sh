#!/bin/bash
# shell-colors.sh - Comprehensive color and formatting utility for shell scripts
# Provides consistent color and formatting definitions across scripts

# Text Colors (Foreground)
# Standard colors
export COLOR_BLACK='\033[0;30m'
export COLOR_RED='\033[0;31m'
export COLOR_GREEN='\033[0;32m'
export COLOR_YELLOW='\033[0;33m'
export COLOR_BLUE='\033[0;34m'
export COLOR_PURPLE='\033[0;35m'
export COLOR_CYAN='\033[0;36m'
export COLOR_WHITE='\033[0;37m'

# Bright colors
export COLOR_BRIGHT_BLACK='\033[1;30m'
export COLOR_BRIGHT_RED='\033[1;31m'
export COLOR_BRIGHT_GREEN='\033[1;32m'
export COLOR_BRIGHT_YELLOW='\033[1;33m'
export COLOR_BRIGHT_BLUE='\033[1;34m'
export COLOR_BRIGHT_PURPLE='\033[1;35m'
export COLOR_BRIGHT_CYAN='\033[1;36m'
export COLOR_BRIGHT_WHITE='\033[1;37m'

# Background Colors
export BG_BLACK='\033[40m'
export BG_RED='\033[41m'
export BG_GREEN='\033[42m'
export BG_YELLOW='\033[43m'
export BG_BLUE='\033[44m'
export BG_PURPLE='\033[45m'
export BG_CYAN='\033[46m'
export BG_WHITE='\033[47m'

# Bright Background Colors
export BG_BRIGHT_BLACK='\033[100m'
export BG_BRIGHT_RED='\033[101m'
export BG_BRIGHT_GREEN='\033[102m'
export BG_BRIGHT_YELLOW='\033[103m'
export BG_BRIGHT_BLUE='\033[104m'
export BG_BRIGHT_PURPLE='\033[105m'
export BG_BRIGHT_CYAN='\033[106m'
export BG_BRIGHT_WHITE='\033[107m'

# Text Formatting
export FORMAT_BOLD='\033[1m'
export FORMAT_DIM='\033[2m'
export FORMAT_UNDERLINE='\033[4m'
export FORMAT_BLINK='\033[5m'
export FORMAT_REVERSE='\033[7m'
export FORMAT_HIDDEN='\033[8m'

# Reset all formatting
export COLOR_RESET='\033[0m'

# Aliases for backward compatibility
export RED="$COLOR_RED"
export GREEN="$COLOR_GREEN"
export YELLOW="$COLOR_YELLOW"
export BLUE="$COLOR_BLUE"
export CYAN="$COLOR_CYAN"
export RESET="$COLOR_RESET"

# Utility functions for colored output

# Print colored text
# Usage: print_color COLOR_NAME "Your message"
print_color() {
    local color_var="COLOR_${1^^}"
    local message="$2"
    
    if [[ -n "${!color_var}" ]]; then
        echo -e "${!color_var}${message}${COLOR_RESET}"
    else
        echo "$message"
    fi
}

# Print error message (red)
print_error() {
    print_color "red" "$1" >&2
}

# Print success message (green)
print_success() {
    print_color "green" "$1"
}

# Print warning message (yellow)
print_warning() {
    print_color "yellow" "$1"
}

# Print info message (blue)
print_info() {
    print_color "blue" "$1"
}

# Create a header with color
# Usage: print_header BACKGROUND_COLOR FOREGROUND_COLOR "Header Text"
print_header() {
    local bg_color="BG_${1^^}"
    local fg_color="COLOR_${2^^}"
    local header_text="$3"
    
    if [[ -n "${!bg_color}" && -n "${!fg_color}" ]]; then
        echo -e "${!bg_color}${!fg_color}${header_text}${COLOR_RESET}"
    else
        echo "$header_text"
    fi
}

# Export utility functions
export -f print_color
export -f print_error
export -f print_success
export -f print_warning
export -f print_info
export -f print_header

# EOF
