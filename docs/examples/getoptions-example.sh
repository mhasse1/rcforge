#!/usr/bin/env bash
# getoptions-example.sh - Example utility using getoptions
# Author: rcForge Team
# Date: 2025-04-22
# Version: 0.5.0
# Category: examples
# RC Summary: Demonstrates how to use getoptions in rcForge utilities
# Description: A simple example utility showing how to integrate getoptions
#              for command-line argument parsing in rcForge utilities.

# Source required libraries
source "${RCFORGE_LIB:-$HOME/.local/share/rcforge/system/lib}/utility-functions.sh"
source "${RCFORGE_LIB:-$HOME/.local/share/rcforge/system/lib}/getoptions.sh"

# Set strict error handling
set -o nounset
set -o pipefail

# Global constants
[ -v gc_version ]  || readonly gc_version="${RCFORGE_VERSION:-0.5.0}"
[ -v gc_app_name ] || readonly gc_app_name="${RCFORGE_APP_NAME:-rcForge}"
readonly UTILITY_NAME="getoptions-example"

# ============================================================================
# OPTION PARSING SETUP
# ============================================================================

# Initialize getoptions with prefix 'opts'
GetoInit "opts"

# Define options
GetoFlag "opts" "v" "verbose" "Enable verbose output"
GetoFlag "opts" "q" "quiet" "Suppress all output except errors"
GetoParam "opts" "n" "name" "Specify a name to greet" "World"
GetoParam "opts" "c" "count" "Number of times to repeat greeting" "1"
GetoParam "opts" "o" "output" "Write output to file instead of stdout"

# Add standard help option
GetoAddHelp "opts"

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Function: WriteOutput
# Description: Write output either to stdout or to file
# Usage: WriteOutput "message" output_file quiet_mode
WriteOutput() {
    local message="$1"
    local output_file="${2:-}"
    local quiet_mode="${3:-false}"
    
    # Don't output if quiet mode is enabled
    [[ "$quiet_mode" == "true" ]] && return 0
    
    # Write to file if specified
    if [[ -n "$output_file" ]]; then
        printf "%s\n" "$message" >> "$output_file"
        return $?
    fi
    
    # Otherwise write to stdout
    printf "%s\n" "$message"
    return 0
}

# ============================================================================
# Function: main
# Description: Main execution logic.
# Usage: main "$@"
# Arguments: Command-line arguments
# Returns: 0 on success, non-zero on error.
# ============================================================================
main() {
    # Parse command-line arguments
    GetoParse "opts" "$@" || return $?
    
    # Access option values
    local verbose="${_opts_verbose:-false}"
    local quiet="${_opts_quiet:-false}"
    local name="${_opts_name:-World}"
    local count="${_opts_count:-1}"
    local output_file="${_opts_output:-}"
    
    # Validate options
    if [[ "$verbose" == "true" && "$quiet" == "true" ]]; then
        ErrorMessage "Cannot use both --verbose and --quiet"
        return 1
    fi
    
    if ! [[ "$count" =~ ^[0-9]+$ ]] || [[ "$count" -lt 1 ]]; then
        ErrorMessage "Count must be a positive integer"
        return 1
    fi
    
    # Create output file if needed
    if [[ -n "$output_file" ]]; then
        if [[ -f "$output_file" ]]; then
            if [[ ! -w "$output_file" ]]; then
                ErrorMessage "Output file is not writable: $output_file"
                return 1
            fi
            # Clear file
            > "$output_file"
        elif ! touch "$output_file" 2>/dev/null; then
            ErrorMessage "Cannot create output file: $output_file"
            return 1
        fi
    fi
    
    # Display section header
    if [[ "$quiet" == "false" && -z "$output_file" ]]; then
        SectionHeader "Example Greeting Utility"
    fi
    
    # Show verbose information
    if [[ "$verbose" == "true" ]]; then
        InfoMessage "Running with options:"
        InfoMessage "  Verbose: $verbose"
        InfoMessage "  Quiet: $quiet"
        InfoMessage "  Name: $name"
        InfoMessage "  Count: $count"
        if [[ -n "$output_file" ]]; then
            InfoMessage "  Output: $output_file"
        else
            InfoMessage "  Output: stdout"
        fi
        echo "" # Add spacing
    fi
    
    # Generate greeting
    local greeting="Hello, $name!"
    
    # Output greeting
    for ((i=1; i<=count; i++)); do
        WriteOutput "$greeting" "$output_file" "$quiet"
    done
    
    # Show success message if not quiet and not writing to file
    if [[ "$quiet" == "false" && -z "$output_file" ]]; then
        SuccessMessage "Greeting completed"
    elif [[ "$quiet" == "false" && -n "$output_file" ]]; then
        SuccessMessage "Greeting written to: $output_file"
    fi
    
    return 0
}

# Execute main function if run directly or via rc command
if IsExecutedDirectly || [[ "$0" == *"rc"* ]]; then
    main "$@"
    exit $? # Exit with status from main
fi

# EOF
