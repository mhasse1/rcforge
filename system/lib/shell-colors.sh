#!/usr/bin/env bash
# shell-colors.sh - Comprehensive color and messaging utility for shell scripts
# Author: rcForge Team
# Date: 2025-04-07 # Updated Date for refactor
# Version: 0.4.1
# Category: system/library
# Description: Provides color definitions, output formatting, and standardized messaging functions with dynamic wrapping. Intended to be sourced.

# shellcheck disable=SC2034 # Disable unused variable warnings in this library file

# --- Include Guard ---
# Check if already sourced
if [[ -n "${_RCFORGE_SHELL_COLORS_SH_SOURCED:-}" ]]; then
    return 0 # Already sourced, exit gracefully
fi
# Mark as sourced
_RCFORGE_SHELL_COLORS_SH_SOURCED=true
# --- End Include Guard ---

# Note: Do not use 'set -e' or 'set -u' in sourced library scripts as it can affect the parent shell.
# ============================================================================
# COLOR & FORMATTING DEFINITIONS (Readonly, Not Exported unless necessary)
# ============================================================================

# Foreground Colors
readonly BLACK='\033[0;30m'
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[0;37m'

# Bright Foreground Colors
readonly BRIGHT_BLACK='\033[1;30m' # Often gray
readonly BRIGHT_RED='\033[1;31m'
readonly BRIGHT_GREEN='\033[1;32m'
readonly BRIGHT_YELLOW='\033[1;33m'
readonly BRIGHT_BLUE='\033[1;34m'
readonly BRIGHT_MAGENTA='\033[1;35m'
readonly BRIGHT_CYAN='\033[1;36m'
readonly BRIGHT_WHITE='\033[1;37m'

# Background Colors
readonly BG_BLACK='\033[40m'
readonly BG_RED='\033[41m'
readonly BG_GREEN='\033[42m'
readonly BG_YELLOW='\033[43m'
readonly BG_BLUE='\033[44m'
readonly BG_MAGENTA='\033[45m'
readonly BG_CYAN='\033[46m'
readonly BG_WHITE='\033[47m'

# Text Formatting
readonly RESET='\033[0m' # Resets all attributes
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly ITALIC='\033[3m' # Not widely supported
readonly UNDERLINE='\033[4m'
readonly BLINK='\033[5m'   # Often disabled or unsupported
readonly REVERSE='\033[7m' # Swaps foreground and background

# ============================================================================
# GLOBAL STATE VARIABLES (Exported - necessary for session-wide state)
# ============================================================================

export COLOR_OUTPUT_ENABLED="${COLOR_OUTPUT_ENABLED:-true}"
export DEBUG_MODE="${DEBUG_MODE:-false}"
# Internal state, might not need export but safer for now
export COLOR_TERMINAL_SUPPORT="false"
# Flag to show fold warning only once
export RCFORGE_FOLD_WARNING_SHOWN="false"

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# ============================================================================
# Function: GetTerminalWidth
# Description: Detects the current terminal width using COLUMNS or tput.
# Usage: local width=$(GetTerminalWidth)
# Arguments: None
# Returns: Echoes the terminal width or a default value (e.g., 80).
# ============================================================================
GetTerminalWidth() {
    local width=0
    # Prefer $COLUMNS if set and greater than 0
    if [[ -n "${COLUMNS:-}" && "$COLUMNS" -gt 0 ]]; then
        width="$COLUMNS"
    # Fallback to tput cols
    elif command -v tput &>/dev/null && tput cols &>/dev/null; then
        width=$(tput cols)
        # Ensure tput returned a valid number > 0
        if ! [[ "$width" =~ ^[0-9]+$ && "$width" -gt 0 ]]; then
            width=0 # Invalid tput output
        fi
    fi
    # If width is still 0 (detection failed), use default
    if [[ "$width" -le 0 ]]; then
        width=80 # Default width
    fi
    echo "$width"
}

# ============================================================================
# Function: _PrintWrappedMessage (Internal Helper)
# Description: Internal helper to print prefixed and wrapped messages with indentation.
# Usage: _PrintWrappedMessage "PREFIX" "COLOR_PREFIX" INDENT_WIDTH "MESSAGE" [REDIRECT]
# Arguments:
#   $1 (required) - Plain text prefix (e.g., "[INFO]").
#   $2 (required) - Colored prefix string (e.g., "${BLUE}[INFO]${RESET}").
#   $3 (required) - Integer width for indenting subsequent lines.
#   $4 (required) - The message text to wrap.
#   $5 (optional) - Redirection target (e.g., stderr). Default stdout.
# Returns: None. Prints wrapped message.
# ============================================================================
_PrintWrappedMessage() {
    local prefix="$1"
    local color_prefix="$2"
    local indent_width=${3:-0}
    local message="$4"
    local redirect_target="${5:-stdout}" # Changed default notation
    local term_width
    local message_wrap_width
    local wrapped_message
    local indent_spaces=""
    local fold_exists=false
    local output_stream="1" # Default to stdout

    # Generate indentation spaces string
    [[ "$indent_width" -gt 0 ]] && printf -v indent_spaces '%*s' "$indent_width" ''

    term_width=$(GetTerminalWidth)
    # Calculate width for message part for fold command
    message_wrap_width=$((term_width - indent_width - 1))    # Subtract indent + space for cursor
    [[ message_wrap_width -lt 20 ]] && message_wrap_width=20 # Minimum wrap width

    # Check for fold command
    if command -v fold >/dev/null 2>&1; then
        fold_exists=true
        wrapped_message=$(printf '%s\n' "$message" | fold -s -w "$message_wrap_width")
    else
        wrapped_message="$message" # Use original message if fold unavailable
        # Show warning only once per session
        if [[ "${RCFORGE_FOLD_WARNING_SHOWN}" == "false" ]]; then
            # Use direct echo for this warning to avoid recursion if WarningMessage uses this helper
            echo "WARNING: 'fold' command not found. Output wrapping disabled." >&2
            export RCFORGE_FOLD_WARNING_SHOWN="true"
        fi
    fi

    # Set output stream descriptor
    [[ "$redirect_target" == "stderr" ]] && output_stream="2"

    # Print wrapped message with prefix and indentation
    local first_line=true
    while IFS= read -r line; do
        if [[ "$first_line" == true ]]; then
            if [[ "${COLOR_OUTPUT_ENABLED:-false}" == "true" ]]; then
                printf "%b %s\n" "${color_prefix}" "${line}" >&"$output_stream"
            else
                printf "%s %s\n" "${prefix}" "${line}" >&"$output_stream"
            fi
            first_line=false
        else
            # Print subsequent lines with indentation
            printf "%s%s\n" "${indent_spaces}" "${line}" >&"$output_stream"
        fi
    done < <(printf '%s\n' "$wrapped_message") # Feed wrapped message to the loop
}

# ============================================================================
# COLOR SUPPORT DETECTION & CONTROL
# ============================================================================

# ============================================================================
# Function: DetermineColorSupport
# Description: Check if the current environment (terminal) likely supports color output. Sets COLOR_TERMINAL_SUPPORT.
# Usage: DetermineColorSupport
# Arguments: None
# Returns: 0 if color support is detected, 1 otherwise. Modifies COLOR_TERMINAL_SUPPORT.
# ============================================================================
DetermineColorSupport() {
    local color_support_detected=false # Use boolean
    if [[ -t 1 ]]; then                # Check if stdout is a TTY
        if [[ -n "${TERM:-}" && "$TERM" != "dumb" ]]; then
            if command -v tput &>/dev/null && [[ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]]; then
                color_support_detected=true
            fi
        fi
    fi
    export COLOR_TERMINAL_SUPPORT="$color_support_detected"
    [[ "$color_support_detected" == "true" ]] && return 0 || return 1
}

# ============================================================================
# Function: EnableColorOutput
# Description: Explicitly enable colorized output (if terminal supports it).
# Usage: EnableColorOutput
# Arguments: None
# Returns: None. Modifies COLOR_OUTPUT_ENABLED.
# ============================================================================
EnableColorOutput() {
    if [[ "${COLOR_TERMINAL_SUPPORT:-false}" == "true" ]]; then
        export COLOR_OUTPUT_ENABLED=true
    fi
}

# ============================================================================
# Function: DisableColorOutput
# Description: Explicitly disable colorized output.
# Usage: DisableColorOutput
# Arguments: None
# Returns: None. Modifies COLOR_OUTPUT_ENABLED.
# ============================================================================
DisableColorOutput() {
    export COLOR_OUTPUT_ENABLED=false
}

# ============================================================================
# MESSAGING FUNCTIONS (Do NOT Export by default)
# ============================================================================

# ============================================================================
# Function: ErrorMessage
# Description: Print a message formatted as an error to stderr, wrapped and indented. Optionally exits.
# Usage: ErrorMessage "Error description" [exit_code]
# Arguments:
#   $1 (required) - The error message text. Uses $* internally.
#   $2 (optional) - If provided, exits the script with this code.
# Returns: None. Prints to stderr. May exit script.
# ============================================================================
ErrorMessage() {
    local message="${*}" # Capture all args as the message
    local exit_code=""
    # Check if the last argument is purely numeric, assume it's exit code
    if [[ "${*:$#}" =~ ^[0-9]+$ ]]; then
        exit_code="${*:$#}"
        # Remove exit code from message string (tricky with $* - easier to rebuild)
        local num_args=$#
        if [[ "$num_args" -gt 1 ]]; then
            message="${*:1:$((num_args - 1))}"
        else
            message="" # No message if only exit code provided
        fi
        # Ensure message isn't empty if only exit code given
        [[ -z "$message" ]] && message="Exiting with code $exit_code"
    fi

    local prefix="[ERROR]"
    local color_prefix="${BRIGHT_RED}${prefix}${RESET}"
    local indent_width=8 # Length of "[ERROR] "

    _PrintWrappedMessage "$prefix" "$color_prefix" "$indent_width" "$message" "stderr" # Pass stderr redirection hint

    [[ -n "$exit_code" ]] && exit "$exit_code"
}

# ============================================================================
# Function: WarningMessage
# Description: Print a message formatted as a warning to stderr, wrapped and indented.
# Usage: WarningMessage "Warning description"
# Arguments:
#   $* (required) - The warning message text.
# Returns: None. Prints to stderr.
# ============================================================================
WarningMessage() {
    local message="${*}"
    local prefix="[WARNING]"
    local color_prefix="${BRIGHT_YELLOW}${prefix}${RESET}"
    local indent_width=10 # Length of "[WARNING] "
    _PrintWrappedMessage "$prefix" "$color_prefix" "$indent_width" "$message" "stderr"
}

# ============================================================================
# Function: InfoMessage
# Description: Print an informational message to stdout, wrapped and indented.
# Usage: InfoMessage "Information"
# Arguments:
#   $* (required) - The informational message text.
# Returns: None. Prints to stdout.
# ============================================================================
InfoMessage() {
    local message="${*}"
    local prefix="[INFO]"
    local color_prefix="${BRIGHT_BLUE}${prefix}${RESET}"
    local indent_width=7 # Length of "[INFO] "
    _PrintWrappedMessage "$prefix" "$color_prefix" "$indent_width" "$message"
}

# ============================================================================
# Function: SuccessMessage
# Description: Print a success message to stdout, wrapped and indented.
# Usage: SuccessMessage "Success details"
# Arguments:
#   $* (required) - The success message text.
# Returns: None. Prints to stdout.
# ============================================================================
SuccessMessage() {
    local message="${*}"
    local prefix="[SUCCESS]"
    local color_prefix="${BRIGHT_GREEN}${prefix}${RESET}"
    local indent_width=10 # Length of "[SUCCESS] "
    _PrintWrappedMessage "$prefix" "$color_prefix" "$indent_width" "$message"
}

# ============================================================================
# Function: DebugMessage
# Description: Print a debug message to stderr, wrapped and indented, only if DEBUG_MODE is true.
# Usage: DebugMessage "Debug details"
# Arguments:
#   $* (required) - The debug message text.
# Returns: 0. Prints to stderr only if DEBUG_MODE=true.
# ============================================================================
DebugMessage() {
    [[ "${DEBUG_MODE:-false}" != "true" ]] && return 0
    local message="${*}"
    local prefix="[DEBUG]"
    local color_prefix="${CYAN}${prefix}${RESET}"
    local indent_width=8 # Length of "[DEBUG] "
    _PrintWrappedMessage "$prefix" "$color_prefix" "$indent_width" "$message" "stderr"
    return 0
}

# ============================================================================
# Function: VerboseMessage
# Description: Print a message to stdout, wrapped and indented, only if verbose flag is true.
# Usage: VerboseMessage is_verbose "Details..."
# Arguments:
#   $1 (required) - Boolean ('true' or 'false') indicating if verbose mode is active.
#   $* (required) - The message text (all subsequent arguments).
# Returns: 0. Prints to stdout only if $1 is 'true'.
# ============================================================================
VerboseMessage() {
    local is_verbose="${1:-false}" # Default to false if not provided
    # Check if the first argument is literally 'true'
    if [[ "$is_verbose" != "true" ]]; then
        return 0
    fi
    shift                # Remove the boolean flag from the arguments
    local message="${*}" # Use the rest as the message
    local prefix="[VERBOSE]"
    # Use Magenta for verbose messages
    local color_prefix="${MAGENTA}${prefix}${RESET}"
    local indent_width=10 # Length of "[VERBOSE] "

    # Check if message is non-empty after shifting
    if [[ -n "$message" ]]; then
        _PrintWrappedMessage "$prefix" "$color_prefix" "$indent_width" "$message"
    fi
    return 0
}

# ============================================================================
# FORMATTING FUNCTIONS (Do NOT Export by default)
# ============================================================================

# ============================================================================
# Function: SectionHeader
# Description: Print a formatted section header.
# Usage: SectionHeader "Header Text" [Color] [Width]
# Arguments:
#   text (required) - The header text.
#   color (optional) - ANSI color code variable (default: BRIGHT_BLUE).
#   width (optional) - Total width of the header line (default: dynamically detected or 80).
# Returns: None. Prints formatted header to stdout.
# ============================================================================
SectionHeader() {
    local text="${1:-Section}"
    local color="${2:-$BRIGHT_BLUE}"        # Use variables defined above
    local width="${3:-$(GetTerminalWidth)}" # Use dynamic width by default
    local text_len=${#text}
    # Calculate padding, ensuring it's not negative
    local padding=$(((width - text_len - 2) / 2))
    [[ $padding -lt 0 ]] && padding=0
    # Calculate remaining padding for right side if width is odd or text is long
    local r_padding=$((width - text_len - 2 - padding))
    [[ $r_padding -lt 0 ]] && r_padding=0

    # Create the separator line
    local line
    printf -v line '%*s' "$width" '' # Create string of spaces
    line="${line// /=}"              # Replace spaces with '='

    if [[ "${COLOR_OUTPUT_ENABLED:-false}" == "true" ]]; then
        printf "\n%b%s%b\n" "${color}" "$line" "${RESET}"
        printf "%b%*s %s %*s%b\n" "${color}" "$padding" "" "${text}" "$r_padding" "" "${RESET}"
        printf "%b%s%b\n" "${color}" "$line" "${RESET}"
    else
        printf "\n%s\n" "$line"
        printf "%*s %s %*s\n" "$padding" "" "${text}" "$r_padding" ""
        printf "%s\n" "$line"
    fi
}

# ============================================================================
# Function: TextBlock
# Description: Print a message highlighted with background/foreground colors, wrapped.
# Usage: TextBlock "Message" [ForegroundColor] [BackgroundColor]
# Arguments:
#   $1 (required) - Text to display.
#   $2 (optional) - ANSI foreground color variable (default: WHITE).
#   $3 (optional) - ANSI background color variable (default: BG_BLUE).
# Returns: 1 if message is empty, 0 otherwise. Prints to stdout.
# ============================================================================
TextBlock() {
    local message="${1:-}"          # Message is the first argument
    local fg_color="${2:-$WHITE}"   # Use 2nd arg or default
    local bg_color="${3:-$BG_BLUE}" # Use 3rd arg or default
    local wrapped_message
    local term_width=$(GetTerminalWidth)
    local wrap_width=$((term_width > 4 ? term_width - 4 : term_width - 1)) # Width for fold, leaving ~2 spaces padding
    [[ $wrap_width -lt 20 ]] && wrap_width=20
    local fold_exists=false
    command -v fold >/dev/null 2>&1 && fold_exists=true

    if [[ -z "$message" ]]; then
        WarningMessage "No message provided to TextBlock function."
        return 1
    fi

    # Wrap the message content
    if [[ "$fold_exists" == "true" ]]; then
        wrapped_message=$(printf '%s\n' "$message" | fold -s -w "$wrap_width")
    else
        wrapped_message="$message" # Use original if fold not available
        # Warning already handled by _PrintWrappedMessage's internal check
    fi

    # Print wrapped message line by line with background color
    local first_line=true
    while IFS= read -r line; do
        # Print line with 1 space padding inside background
        if [[ "${COLOR_OUTPUT_ENABLED:-false}" == "true" ]]; then
            printf "%b%b %s %b\n" "$fg_color" "$bg_color" "$line" "$RESET"
        else
            printf "[ %s ]\n" "$line" # Simple non-colored block
        fi
        # Subsequent lines would normally be indented, but for a block, maybe not?
        # Keeping it simple: each wrapped line gets the same block treatment.
        # If indentation is needed: add logic similar to _PrintWrappedMessage
        # first_line=false (if needed)
    done < <(printf '%s\n' "$wrapped_message")

    return 0
}

# ============================================================================
# Function: Wrap (Simple internal wrapper for fold)
# Description: Wraps text to terminal width using fold command.
# Usage: wrapped_text=$(Wrap "$text" [indent])
# Arguments:
#   $1 (required) - Text to wrap.
#   $2 (optional) - Indentation width for subsequent lines (default 0).
# Returns: Echoes wrapped text.
# ============================================================================
Wrap() {
    local text="$1"
    local indent_width="${2:-0}"
    local term_width=$(GetTerminalWidth)
    local wrap_width=$((term_width - indent_width - 1))
    [[ $wrap_width -lt 20 ]] && wrap_width=20
    local indent_spaces=""
    [[ "$indent_width" -gt 0 ]] && printf -v indent_spaces '%*s' "$indent_width" ''
    local first_line=true

    if command -v fold >/dev/null 2>&1; then
        printf '%s\n' "$text" | fold -s -w "$wrap_width" | while IFS= read -r line; do
            if [[ "$first_line" == true ]]; then
                echo "$line"
                first_line=false
            else
                echo "${indent_spaces}${line}"
            fi
        done
    else
        echo "$text" # Return unwrapped if fold not available
        # Warning handled by _PrintWrappedMessage
    fi
}

# ============================================================================
# Function: StripColors
# Description: Remove ANSI escape codes (colors, formatting) from a string.
# Usage: stripped_text=$(StripColors "$colored_text")
# Arguments:
#   $* (required) - Input string potentially containing ANSI codes.
# Returns: Echoes the stripped string.
# ============================================================================
StripColors() {
    local text="${*}"
    # Use sed with extended regex (-E) to remove codes like \x1b[...m
    # The $'...' is bash syntax to interpret \x1b
    printf "%s" "$text" | sed -E $'s/\x1b\\[[0-9;]*m//g'
}

# ============================================================================
# INITIALIZATION
# ============================================================================

# Perform initial color support detection when sourced
DetermineColorSupport || true

# Ensure colors are disabled if not supported or explicitly disabled
if [[ "${COLOR_TERMINAL_SUPPORT}" != "true" || "${COLOR_OUTPUT_ENABLED}" != "true" ]]; then
    DisableColorOutput
fi

# ============================================================================
# EXPORT FUNCTIONS (NONE - REMOVED EXPORTS)
# ============================================================================

# No functions exported from this library by default anymore.
# Scripts needing these functions must source this file.

# EOF
