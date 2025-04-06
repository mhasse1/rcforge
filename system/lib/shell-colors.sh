#!/usr/bin/env bash
# shell-colors.sh - Comprehensive color and messaging utility for shell scripts
# Author: rcForge Team
# Date: 2025-04-06 # Updated Date
# Version: 0.3.0
# Category: system/library
# Description: Provides color definitions, output formatting, and standardized messaging functions. Intended to be sourced.

# Note: Do not use 'set -e' or 'set -u' in sourced library scripts as it can affect the parent shell.

# ============================================================================
# COLOR & FORMATTING DEFINITIONS (Exported)
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
export BRIGHT_BLACK='\033[1;30m' # Often appears gray
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
export RESET='\033[0m'      # Resets all attributes
export BOLD='\033[1m'
export DIM='\033[2m'
export ITALIC='\033[3m'     # Not widely supported
export UNDERLINE='\033[4m'
export BLINK='\033[5m'      # Often disabled or unsupported
export REVERSE='\033[7m'    # Swaps foreground and background

# ============================================================================
# COLOR SUPPORT DETECTION & CONTROL (Exported Variables)
# ============================================================================

# Variable to control whether color output is enabled. Can be pre-set to false.
export COLOR_OUTPUT_ENABLED="${COLOR_OUTPUT_ENABLED:-true}"
# Variable indicating if the terminal likely supports color. Set during initialization.
export COLOR_TERMINAL_SUPPORT="false"
# Variable for debug mode control. Can be pre-set.
export DEBUG_MODE="${DEBUG_MODE:-false}"

# ============================================================================
# Function: DetermineColorSupport
# Description: Check if the current environment (terminal) likely supports color output.
#              Sets the COLOR_TERMINAL_SUPPORT variable.
# Usage: DetermineColorSupport
# Returns: 0 if color support is detected, 1 otherwise.
# ============================================================================
DetermineColorSupport() {
    local color_support_detected=false # Use boolean

    # Check if stdout is a TTY
    if [[ -t 1 ]]; then
        # Check TERM variable and tput for color capability
        if [[ -n "${TERM:-}" && "$TERM" != "dumb" ]]; then
             # Check if tput exists and reports >= 8 colors
             if command -v tput &>/dev/null && [[ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]]; then
                 color_support_detected=true
             # Fallback for TERM=*-256color or similar without tput? Less reliable.
             # elif [[ "$TERM" == *color* ]]; then color_support_detected=true; fi
             fi
        fi
    fi

    # Set the exported variable based on detection
    export COLOR_TERMINAL_SUPPORT="$color_support_detected"

    # Return standard success/failure code
    if [[ "$color_support_detected" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# ============================================================================
# Function: EnableColorOutput
# Description: Explicitly enable colorized output (if terminal supports it).
# Usage: EnableColorOutput
# Returns: None. Modifies COLOR_OUTPUT_ENABLED.
# ============================================================================
EnableColorOutput() {
    # Only enable if terminal supports it
    if [[ "${COLOR_TERMINAL_SUPPORT:-false}" == "true" ]]; then
        export COLOR_OUTPUT_ENABLED=true
    fi
}

# ============================================================================
# Function: DisableColorOutput
# Description: Explicitly disable colorized output.
# Usage: DisableColorOutput
# Returns: None. Modifies COLOR_OUTPUT_ENABLED.
# ============================================================================
DisableColorOutput() {
    export COLOR_OUTPUT_ENABLED=false
}

# ============================================================================
# MESSAGING FUNCTIONS (PascalCase)
# ============================================================================

# ============================================================================
# Function: ErrorMessage
# Description: Print a message formatted as an error to stderr. Optionally exits.
# Usage: ErrorMessage "Error description" [exit_code]
# Arguments:
#   message (required) - The error message text.
#   exit_code (optional) - If provided, exits the script with this code.
# Returns: None. Prints to stderr. May exit script.
# ============================================================================
ErrorMessage() {
    local message="${1:-Unknown error}"
    local exit_code="${2:-}" # Optional exit code
    local prefix="[ERROR]" # Default prefix
    local color_prefix="${BRIGHT_RED}${prefix}${RESET}" # Colored prefix

    # Use colors only if enabled
    if [[ "${COLOR_OUTPUT_ENABLED:-false}" == "true" ]]; then
        # Use printf for reliable formatting and ANSI code interpretation
        printf "%b %s\n" "${color_prefix}" "${message}" >&2
    else
        printf "%s %s\n" "${prefix}" "${message}" >&2
    fi

    # Exit with specified code if provided
    if [[ -n "$exit_code" ]]; then
        exit "$exit_code"
    fi
}

# ============================================================================
# Function: WarningMessage
# Description: Print a message formatted as a warning to stderr.
# Usage: WarningMessage "Warning description"
# Arguments:
#   message (required) - The warning message text.
# Returns: None. Prints to stderr.
# ============================================================================
WarningMessage() {
    local message="${1:-Warning}"
    local prefix="[WARNING]"
    local color_prefix="${BRIGHT_YELLOW}${prefix}${RESET}"

    if [[ "${COLOR_OUTPUT_ENABLED:-false}" == "true" ]]; then
        printf "%b %s\n" "${color_prefix}" "${message}" >&2
    else
        printf "%s %s\n" "${prefix}" "${message}" >&2
    fi
}

# ============================================================================
# Function: InfoMessage
# Description: Print an informational message to stdout.
# Usage: InfoMessage "Information"
# Arguments:
#   message (required) - The informational message text.
# Returns: None. Prints to stdout.
# ============================================================================
InfoMessage() {
    local message="${1:-Information}"
    local prefix="[INFO]"
    local color_prefix="${BRIGHT_BLUE}${prefix}${RESET}"

    if [[ "${COLOR_OUTPUT_ENABLED:-false}" == "true" ]]; then
        printf "%b %s\n" "${color_prefix}" "${message}"
    else
        printf "%s %s\n" "${prefix}" "${message}"
    fi
}

# ============================================================================
# Function: SuccessMessage
# Description: Print a success message to stdout.
# Usage: SuccessMessage "Success details"
# Arguments:
#   message (required) - The success message text.
# Returns: None. Prints to stdout.
# ============================================================================
SuccessMessage() {
    local message="${1:-Operation successful}"
    local prefix="[SUCCESS]"
    local color_prefix="${BRIGHT_GREEN}${prefix}${RESET}"

    if [[ "${COLOR_OUTPUT_ENABLED:-false}" == "true" ]]; then
        printf "%b %s\n" "${color_prefix}" "${message}"
    else
        printf "%s %s\n" "${prefix}" "${message}"
    fi
}

# ============================================================================
# Function: DebugMessage
# Description: Print a debug message to stderr, only if DEBUG_MODE is true.
# Usage: DebugMessage "Debug details"
# Arguments:
#   message (required) - The debug message text.
# Returns: 0. Prints to stderr only if DEBUG_MODE=true.
# ============================================================================
DebugMessage() {
    # Check DEBUG_MODE variable
    if [[ "${DEBUG_MODE:-false}" != "true" ]]; then
        return 0 # Do nothing if debug mode is not enabled
    fi

    local message="${1:-Debug information}"
    local prefix="[DEBUG]"
    local color_prefix="${CYAN}${prefix}${RESET}" # Use Cyan for debug

    if [[ "${COLOR_OUTPUT_ENABLED:-false}" == "true" ]]; then
        printf "%b %s\n" "${color_prefix}" "${message}" >&2
    else
        printf "%s %s\n" "${prefix}" "${message}" >&2
    fi
    return 0
}

# ============================================================================
# FORMATTING FUNCTIONS (PascalCase)
# ============================================================================

# ============================================================================
# Function: SectionHeader
# Description: Print a formatted section header.
# Usage: SectionHeader "Header Text" [Color] [Width]
# Arguments:
#   text (required) - The header text.
#   color (optional) - ANSI color code (default: BRIGHT_BLUE).
#   width (optional) - Total width of the header line (default: 50).
# Returns: None. Prints formatted header to stdout.
# ============================================================================
SectionHeader() {
    local text="${1:-Section}"
    local color="${2:-$BRIGHT_BLUE}" # Use variables defined above
    local width="${3:-50}"
    local text_len=${#text}
    # Calculate padding, ensuring it's not negative
    local padding=$(( (width - text_len - 2) / 2 ))
    [[ $padding -lt 0 ]] && padding=0
    # Calculate remaining padding for right side if width is odd or text is long
    local r_padding=$(( width - text_len - 2 - padding ))
    [[ $r_padding -lt 0 ]] && r_padding=0

    # Create the separator line
    local line
    printf -v line '%*s' "$width" '' # Create string of spaces
    line="${line// /=}" # Replace spaces with '='

    if [[ "${COLOR_OUTPUT_ENABLED:-false}" == "true" ]]; then
        printf "\n%b%s%b\n" "${color}" "$line" "${RESET}"
        printf "%b%*s %s %*s%b\n" "${color}" "$padding" "" "${text}" "$r_padding" "" "${RESET}"
        printf "%b%s%b\n\n" "${color}" "$line" "${RESET}"
    else
        printf "\n%s\n" "$line"
        printf "%*s %s %*s\n" "$padding" "" "${text}" "$r_padding" ""
        printf "%s\n\n" "$line"
    fi
}

# ============================================================================
# Function: TextBlock
# Description: Print a message highlighted with background/foreground colors.
# Usage: TextBlock "Message" [ForegroundColor] [BackgroundColor]
# Arguments:
#   message (required) - Text to display.
#   fg_color (optional) - ANSI foreground color (default: WHITE).
#   bg_color (optional) - ANSI background color (default: BG_BLUE).
# Returns: 1 if message is empty, 0 otherwise. Prints to stdout.
# ============================================================================
TextBlock() {
    local message="${1:-}"
    local fg_color="${2:-$WHITE}"  # Default foreground
    local bg_color="${3:-$BG_BLUE}"  # Default background

    if [[ -z "$message" ]]; then
        # Use WarningMessage instead of ErrorMessage to avoid potential exit
        WarningMessage "No message provided to TextBlock function."
        return 1 # Indicate error
    fi

    if [[ "${COLOR_OUTPUT_ENABLED:-false}" == "true" ]]; then
        # Pad message with a space on each side
        printf "%b%b %s %b\n" "$fg_color" "$bg_color" "$message" "$RESET"
    else
        # Simple non-colored block representation
        printf "[ %s ]\n" "$message"
    fi
    return 0
}

# ============================================================================
# Function: StripColors
# Description: Remove ANSI escape codes (colors, formatting) from a string.
# Usage: stripped_text=$(StripColors "$colored_text")
# Arguments:
#   text (required) - Input string potentially containing ANSI codes.
# Returns: Echoes the stripped string.
# ============================================================================
StripColors() {
    local text="${1:-}"
    # Use sed with extended regex (-E) to remove codes like \x1b[...m
    # The $'...' is bash syntax to interpret \x1b
    printf "%s" "$text" | sed -E $'s/\x1b\\[[0-9;]*m//g'
}

# ============================================================================
# INITIALIZATION (Run when sourced)
# ============================================================================

# Perform initial color support detection
DetermineColorSupport || true # Run detection, ignore return code here

# If terminal doesn't support colors OR user pre-disabled, disable colors
if [[ "${COLOR_TERMINAL_SUPPORT}" != "true" || "${COLOR_OUTPUT_ENABLED}" != "true" ]]; then
    DisableColorOutput # Ensure COLOR_OUTPUT_ENABLED is false
fi

# ============================================================================
# DIRECT EXECUTION TEST BLOCK
# ============================================================================

# Run only if script is executed directly, not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Re-enable colors just for the test if they were disabled
    EnableColorOutput

    SectionHeader "Shell Colors & Messaging Test" "Magenta"

    InfoMessage "Testing messaging functions..."
    SuccessMessage "This is a success message."
    WarningMessage "This is a warning message."
    ErrorMessage "This is an error message (non-exiting)."

    # Test Debug Message
    InfoMessage "Testing Debug Message (enable DEBUG_MODE=true to see it)..."
    DebugMessage "This message should NOT be visible by default."
    export DEBUG_MODE=true
    DebugMessage "This message SHOULD be visible now."
    export DEBUG_MODE=false # Reset

    SectionHeader "Formatting Functions Test" "$Cyan"

    TextBlock "This is a text block with default colors."
    TextBlock "Custom colors text block." "$BRIGHT_YELLOW" "$BG_RED"
    TextBlock "Another custom block." "$BLACK" "$BG_CYAN"

    SectionHeader "Color Palette Test" "$Green"

    echo -e "${BLACK}BLACK ${RED}RED ${GREEN}GREEN ${YELLOW}YELLOW ${BLUE}BLUE ${MAGENTA}MAGENTA ${CYAN}CYAN ${WHITE}WHITE${RESET}"
    echo -e "${BRIGHT_BLACK}BRIGHT_BLACK ${BRIGHT_RED}BRIGHT_RED ${BRIGHT_GREEN}BRIGHT_GREEN ${BRIGHT_YELLOW}BRIGHT_YELLOW${RESET}"
    echo -e "${BRIGHT_BLUE}BRIGHT_BLUE ${BRIGHT_MAGENTA}BRIGHT_MAGENTA ${BRIGHT_CYAN}BRIGHT_CYAN ${BRIGHT_WHITE}BRIGHT_WHITE${RESET}"
    echo -e "${BG_BLACK} BG_BLACK ${RESET} ${BG_RED} BG_RED ${RESET} ${BG_GREEN} BG_GREEN ${RESET} ${BG_YELLOW} BG_YELLOW ${RESET}"
    echo -e "${BG_BLUE} BG_BLUE ${RESET} ${BG_MAGENTA} BG_MAGENTA ${RESET} ${BG_CYAN} BG_CYAN ${RESET} ${BG_WHITE}${BLACK} BG_WHITE ${RESET}"
    echo -e "${BOLD}BOLD ${DIM}DIM ${ITALIC}ITALIC ${UNDERLINE}UNDERLINE ${BLINK}BLINK ${REVERSE}REVERSE${RESET}"

    SectionHeader "StripColors Test" "$Yellow"
    local colored_string="${GREEN}This ${BOLD}has${RESET}${GREEN} colors.${RESET}"
    local stripped_string
    stripped_string=$(StripColors "$colored_string")
    InfoMessage "Original: $colored_string"
    InfoMessage "Stripped: $stripped_string"
    if [[ "$stripped_string" == "This has colors." ]]; then
        SuccessMessage "StripColors test PASSED."
    else
        ErrorMessage "StripColors test FAILED."
    fi
fi

# ============================================================================
# EXPORT FUNCTIONS FOR SOURCING SCRIPTS
# ============================================================================

# Export functions intended for use by other scripts that source this library
export -f DetermineColorSupport
export -f EnableColorOutput
export -f DisableColorOutput
export -f ErrorMessage
export -f WarningMessage
export -f InfoMessage
export -f SuccessMessage
export -f DebugMessage
export -f SectionHeader
export -f TextBlock
export -f StripColors

# EOF