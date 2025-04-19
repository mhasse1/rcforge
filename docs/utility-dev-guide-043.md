# rcForge Utility Development Guide

This guide helps you create custom utilities that integrate seamlessly with the rcForge framework.

## Getting Started

rcForge utilities are standalone scripts that can be executed directly or through the `rc` command. To ensure consistency and compatibility, follow the standards in this guide.

## File Structure and Location

Custom utilities should be placed in:
- `~/.config/rcforge/utils/` for user utilities
- `~/.config/rcforge/system/utils/` for system utilities (maintainers only)

User utilities with the same name as system utilities override them, allowing for customization.

## Basic Template

Start with our template utility script. Copy it to your utils directory:

```bash
cp ~/.config/rcforge/docs/template-utility.sh ~/.config/rcforge/utils/my-utility.sh
```

Then edit it to implement your functionality. Make sure to:
1. Update the script header (description, author, etc.)
2. Implement the necessary functions
3. Make it executable: `chmod 700 ~/.config/rcforge/utils/my-utility.sh`

## Standard Features

Every rcForge utility should support:

### 1. Help Documentation

```bash
rc my-utility help
# or
rc my-utility --help
```

Implement `ShowHelp()` function with:
- Utility description and purpose
- Usage syntax
- Available options and arguments
- Examples demonstrating common use cases

### 2. Summary

```bash
rc my-utility summary
# or
rc my-utility --summary
```

The summary is a one-line description displayed when users run `rc list`. Set it using the `# RC Summary:` comment in your script header.

### 3. Standard Arguments

Every utility should support these standard options:
- `--help` or `-h`: Display help
- `--summary`: Display one-line summary
- `--version`: Show version information

## Using Helper Functions

rcForge provides helper functions for consistent command-line parsing and output:

### 1. Standard Argument Parsing

```bash
# Parse arguments into associative array
declare -A options
ParseArguments options "$@" || exit $?

# Access parsed options
local option1="${options[option1]}"
local is_verbose="${options[verbose_mode]}"
```

### 2. Consistent Output Formatting

Use these functions for consistent output:
- `SectionHeader "Title"`: Display a formatted section header
- `InfoMessage "Information"`: Display informational message
- `SuccessMessage "Success details"`: Display success message
- `WarningMessage "Warning details"`: Display warning message
- `ErrorMessage "Error details"`: Display error message
- `VerboseMessage "$is_verbose" "Detailed information"`: Show message only if verbose mode is enabled

## Example Implementation

Here's a simple "hello" utility example:

```bash
#!/usr/bin/env bash
# hello.sh - Greet users with customizable message
# Author: Your Name
# Date: 2025-04-17
# Version: 0.4.1
# Category: utility
# RC Summary: Displays a customizable greeting message
# Description: A simple utility that displays a greeting message with configurable name and format

source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/utility-functions.sh"

# Set strict error handling
set -o nounset
set -o pipefail

# Global constants
[ -v gc_version ] || readonly gc_version="${RCFORGE_VERSION:-0.4.1}"
readonly UTILITY_NAME="hello"

# Show detailed help
ShowHelp() {
    local script_name
    script_name=$(basename "$0")

    echo "${UTILITY_NAME} - rcForge Utility (v${gc_version})"
    echo ""
    echo "Description:"
    echo "  Displays a customizable greeting message."
    echo ""
    echo "Usage:"
    echo "  rc ${UTILITY_NAME} [options] [name]"
    echo "  ${script_name} [options] [name]"
    echo ""
    echo "Options:"
    echo "  --format=FORMAT    Greeting format (default: 'Hello, NAME!')"
    echo "  --uppercase, -u    Display greeting in uppercase"
    echo "  --verbose, -v      Enable verbose output"
    echo "  --help, -h         Show this help message"
    echo "  --summary          Show a one-line description"
    echo "  --version          Show version information"
    echo ""
    echo "Examples:"
    echo "  rc ${UTILITY_NAME} World           # Outputs: Hello, World!"
    echo "  rc ${UTILITY_NAME} --format='Hi, NAME' Mark  # Outputs: Hi, Mark"
    echo "  rc ${UTILITY_NAME} --uppercase Alice    # Outputs: HELLO, ALICE!"
    exit 0
}

# Parse arguments
ParseArguments() {
    local -n options_ref="$1"; shift
    
    # Set defaults
    options_ref["format"]="Hello, NAME!"
    options_ref["uppercase"]=false
    options_ref["verbose_mode"]=false
    options_ref["name"]="Friend"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        local key="$1"
        case "$key" in
            -h|--help)
                ShowHelp # Exits
                ;;
            --summary)
                ExtractSummary "$0"; exit $? # Call helper and exit
                ;;
            --version)
                _rcforge_show_version "$0"; exit 0 # Call helper and exit
                ;;
            --format=*)
                options_ref["format"]="${key#*=}"
                shift ;;
            --format)
                shift
                if [[ -z "${1:-}" || "$1" == -* ]]; then
                    ErrorMessage "--format requires a value."
                    return 1
                fi
                options_ref["format"]="$1"
                shift ;;
            --uppercase|-u)
                options_ref["uppercase"]=true
                shift ;;
            -v|--verbose)
                options_ref["verbose_mode"]=true
                shift ;;
            --)
                shift
                break ;;
            -*)
                ErrorMessage "Unknown option: $key"
                ShowHelp # Exits
                ;;
            *)
                # First positional argument is the name
                options_ref["name"]="$1"
                shift
                # If there are more arguments, it's an error
                if [[ $# -gt 0 ]]; then
                    ErrorMessage "Unexpected additional arguments."
                    return 1
                fi
                ;;
        esac
    done
    
    return 0
}

# Main function
main() {
    declare -A options
    ParseArguments options "$@" || exit $?
    
    local format="${options[format]}"
    local name="${options[name]}"
    local is_uppercase="${options[uppercase]}"
    local is_verbose="${options[verbose_mode]}"
    
    VerboseMessage "$is_verbose" "Format: $format"
    VerboseMessage "$is_verbose" "Name: $name"
    VerboseMessage "$is_verbose" "Uppercase: $is_uppercase"
    
    # Replace NAME placeholder with actual name
    local greeting="${format//NAME/$name}"
    
    # Convert to uppercase if requested
    if [[ "$is_uppercase" == "true" ]]; then
        greeting=$(echo "$greeting" | tr '[:lower:]' '[:upper:]')
    fi
    
    # Display the greeting
    echo "$greeting"
    
    return 0
}

# Script execution
if IsExecutedDirectly || [[ "$0" == *"rc"* ]]; then
    main "$@"
    exit $?
fi

# EOF
```

## Testing Your Utility

Test your utility both directly and through the rc command:

```bash
# Direct execution
~/.config/rcforge/utils/my-utility.sh --arg value

# Through rc command
rc my-utility --arg value
```

## Documentation

Add a help file for your utility with detailed usage information. The help file should follow the same format as system utilities for consistency.

## Further Resources

- Run `rc list` to see examples of existing utilities
- Examine system utilities in `~/.config/rcforge/system/utils/` for reference
- Check the rcForge documentation for more details on the framework
