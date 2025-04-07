#!/usr/bin/env bash
# shell-colors.sh - Comprehensive color and messaging utility for shell scripts
# Author: rcForge Team
# Date: 2025-04-06 # Updated Date
# Version: 0.3.0
# Category: system/library
# Description: Provides color definitions, output formatting, and standardized messaging functions with dynamic wrapping. Intended to be sourced.

# Note: Do not use 'set -e' or 'set -u' in sourced library scripts as it can affect the parent shell.

# ============================================================================
# COLOR & FORMATTING DEFINITIONS (Exported Readonly)
# ============================================================================

# Foreground Colors
export readonly BLACK='\033[0;30m'
export readonly RED='\033[0;31m'
export readonly GREEN='\033[0;32m'
export readonly YELLOW='\033[0;33m'
export readonly BLUE='\033[0;34m'
export readonly MAGENTA='\033[0;35m'
export readonly CYAN='\033[0;36m'
export readonly WHITE='\033[0;37m'

# Bright Foreground Colors
export readonly BRIGHT_BLACK='\033[1;30m' # Often gray
export readonly BRIGHT_RED='\033[1;31m'
export readonly BRIGHT_GREEN='\033[1;32m'
export readonly BRIGHT_YELLOW='\033[1;33m'
export readonly BRIGHT_BLUE='\033[1;34m'
export readonly BRIGHT_MAGENTA='\033[1;35m'
export readonly BRIGHT_CYAN='\033[1;36m'
export readonly BRIGHT_WHITE='\033[1;37m'

# Background Colors
export readonly BG_BLACK='\033[40m'
export readonly BG_RED='\033[41m'
export readonly BG_GREEN='\033[42m'
export readonly BG_YELLOW='\033[43m'
export readonly BG_BLUE='\033[44m'
export readonly BG_MAGENTA='\033[45m'
export readonly BG_CYAN='\033[46m'
export readonly BG_WHITE='\033[47m'

# Text Formatting
export readonly RESET='\033[0m'      # Resets all attributes
export readonly BOLD='\033[1m'
export readonly DIM='\033[2m'
export readonly ITALIC='\033[3m'     # Not widely supported
export readonly UNDERLINE='\033[4m'
export readonly BLINK='\033[5m'      # Often disabled or unsupported
export readonly REVERSE='\033[7m'    # Swaps foreground and background

# ============================================================================
# GLOBAL STATE VARIABLES (Exported)
# ============================================================================

export COLOR_OUTPUT_ENABLED="${COLOR_OUTPUT_ENABLED:-true}"
export DEBUG_MODE="${DEBUG_MODE:-false}"
# Internal state, might not need export
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
#   $5 (optional) - Redirection target (e.g., >&2 for stderr). Default stdout.
# Returns: None. Prints wrapped message.
# ============================================================================
_PrintWrappedMessage() {
    local prefix="$1"
    local color_prefix="$2"
    local indent_width=${3:-0}
    local message="$4"
    local redirect_target="${5:-}" # Optional redirection like >&2
    local term_width
    local message_wrap_width
    local wrapped_message
    local indent_spaces=""
    local fold_exists=false
    local output_cmd="printf" # Base command

    # Generate indentation spaces string
    [[ "$indent_width" -gt 0 ]] && printf -v indent_spaces '%*s' "$indent_width" ''

    term_width=$(GetTerminalWidth)
    # Calculate width for message part for fold command
    message_wrap_width=$(( term_width - indent_width - 1 )) # Subtract indent + space for cursor
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

    # Prepare output command with potential redirection
    if [[ -n "$redirect_target" ]]; then
        output_cmd+=" >&2" # Hardcoding stderr for now, could be parameterised more
    fi

    # Print wrapped message with prefix and indentation
    local first_line=true
    while IFS= read -r line; do
        if [[ "$first_line" == true ]]; then
            if [[ "${COLOR_OUTPUT_ENABLED:-false}" == "true" ]]; then
                 eval "$output_cmd \"%b %s\\n\" \"${color_prefix}\" \"\${line}\""
            else
                 eval "$output_cmd \"%s %s\\n\" \"${prefix}\" \"\${line}\""
            fi
            first_line=false
        else
            # Print subsequent lines with indentation
             eval "$output_cmd \"%s%s\\n\" \"\${indent_spaces}\" \"\${line}\""
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
    if [[ -t 1 ]]; then # Check if stdout is a TTY
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
# MESSAGING FUNCTIONS (Exported)
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
            message="${*:1:$((num_args-1))}"
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
# FORMATTING FUNCTIONS (Exported)
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
    local color="${2:-$BRIGHT_BLUE}" # Use variables defined above
    local width="${3:-$(GetTerminalWidth)}" # Use dynamic width by default
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
# Description: Print a message highlighted with background/foreground colors, wrapped.
# Usage: TextBlock "Message" [ForegroundColor] [BackgroundColor]
# Arguments:
#   message (required) - Text to display. Uses $* internally.
#   fg_color (optional) - ANSI foreground color variable (default: WHITE).
#   bg_color (optional) - ANSI background color variable (default: BG_BLUE).
# Returns: 1 if message is empty, 0 otherwise. Prints to stdout.
# ============================================================================
TextBlock() {
    local message="${*}" # Capture all arguments as message
    local fg_color="$WHITE" # Default foreground
    local bg_color="$BG_BLUE" # Default background
    local wrapped_message

    # Check if last 2 args look like color vars (heuristic)
    local arg_count=$#
    if [[ "$arg_count" -ge 2 ]] && [[ "${*:$arg_count}" =~ ^\\033\[[0-9;]+m$ ]]; then
        bg_color="${*:$arg_count}"
        if [[ "$arg_count" -ge 3 ]] && [[ "${*:$((arg_count-1)):1}" =~ ^\\033\[[0-9;]+m$ ]]; then
             fg_color="${*:$((arg_count-1)):1}"
             # Rebuild message excluding last 2 args
             message="${*:1:$((arg_count-2))}"
        else
             # Rebuild message excluding last arg
             message="${*:1:$((arg_count-1))}"
        fi
    elif [[ "$arg_count" -ge 1 ]] && [[ "${*:$arg_count}" =~ ^\\033\[[0-9;]+m$ ]]; then
         fg_color="${*:$arg_count}"
         # Rebuild message excluding last arg
         message="${*:1:$((arg_count-1))}"
    fi


    if [[ -z "$message" ]]; then
        WarningMessage "No message provided to TextBlock function." # Use WarningMessage
        return 1 # Indicate error
    fi

    # Wrap the message content, indenting subsequent lines by 1 space for padding
    wrapped_message=$(Wrap "$message" 1) # Call library's Wrap function

    # Print wrapped message line by line with background color
    local first_line=true
    while IFS= read -r line; do
         if [[ "$first_line" == true ]]; then
             if [[ "${COLOR_OUTPUT_ENABLED:-false}" == "true" ]]; then
                 printf "%b%b %s %b\n" "$fg_color" "$bg_color" "$line" "$RESET"
             else
                 printf "[ %s ]\n" "$line" # Simple non-colored block
             fi
             first_line=false
         else
              if [[ "${COLOR_OUTPUT_ENABLED:-false}" == "true" ]]; then
                  printf "%b%b  %s %b\n" "$fg_color" "$bg_color" "$line" "$RESET" # Indent subsequent lines
             else
                  printf "  %s\n" "$line"
             fi
         fi
    done < <(printf '%s\n' "$wrapped_message")

    return 0
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
# EXPORT FUNCTIONS
# ============================================================================

# Export functions intended for use by other scripts that source this library
export -f GetTerminalWidth # Might be useful externally
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
# Do not export _PrintWrappedMessage as it's internal

# EOF