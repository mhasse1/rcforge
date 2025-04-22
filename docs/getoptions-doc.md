# rcForge getoptions Integration Guide

## Overview

This guide describes how to use getoptions within rcForge utilities. The getoptions library provides an elegant and consistent way to parse command-line arguments in shell scripts.

## Installation

getoptions is automatically installed with rcForge v0.5.0+. If you need to install or update it manually, you can use the following command:

```bash
rc getoptions-install
```

## Basic Usage

### 1. Source the Library

In your utility script, start by sourcing the necessary libraries:

```bash
# Source required libraries
source "${RCFORGE_LIB:-$HOME/.local/share/rcforge/system/lib}/utility-functions.sh"
source "${RCFORGE_LIB:-$HOME/.local/share/rcforge/system/lib}/getoptions.sh"
```

### 2. Initialize Options

Initialize the getoptions parser with a prefix that will be used for variable names:

```bash
# Initialize getoptions with prefix 'opts'
GetoInit "opts"
```

### 3. Define Options

Define the command-line options your utility will accept:

```bash
# Define boolean flag options
GetoFlag "opts" "v" "verbose" "Enable verbose output"
GetoFlag "opts" "f" "force" "Force operation without asking"

# Define options that take values
GetoParam "opts" "o" "output" "Specify output file path"
GetoParam "opts" "n" "name" "Specify name" "default-value"

# Add standard help option (recommended for all utilities)
GetoAddHelp "opts"
```

### 4. Parse Arguments

Parse the command-line arguments in your main function:

```bash
main() {
    # Parse command-line arguments
    GetoParse "opts" "$@" || return $?
    
    # Access option values (prefixed with _opts_)
    local verbose="${_opts_verbose:-false}"
    local force="${_opts_force:-false}"
    local output="${_opts_output:-}"
    local name="${_opts_name:-default-value}"
    
    # Rest of your code...
}
```

## Option Types

### Boolean Flags (GetoFlag)

```bash
GetoFlag "prefix" "short_option" "long_option" "help_text" ["default_value"]
```

- **prefix**: Variable name prefix (e.g., "opts")
- **short_option**: Single letter option (e.g., "v" for -v)
- **long_option**: Long form option (e.g., "verbose" for --verbose)
- **help_text**: Description shown in help output
- **default_value**: Optional, "true" or "false" (default: "false")

### Parameters (GetoParam)

```bash
GetoParam "prefix" "short_option" "long_option" "help_text" ["default_value"]
```

- **prefix**: Variable name prefix (e.g., "opts")
- **short_option**: Single letter option (e.g., "o" for -o)
- **long_option**: Long form option (e.g., "output" for --output)
- **help_text**: Description shown in help output
- **default_value**: Optional default value if option not provided

### Help Option (GetoAddHelp)

```bash
GetoAddHelp "prefix"
```

Adds a standard help option (-h, --help) that will display usage information and exit.

## Accessing Parsed Values

After calling `GetoParse`, options are available as variables with the specified prefix:

- **Boolean flags**: `_opts_verbose`, `_opts_force`, etc.
- **Parameters**: `_opts_output`, `_opts_name`, etc.

Always use default values when accessing options, in case they weren't set:

```bash
local verbose="${_opts_verbose:-false}"
local output="${_opts_output:-}"
```

## Complete Example

Here's a complete example of a utility using getoptions:

```bash
#!/usr/bin/env bash
# example-utility.sh - Example utility using getoptions

# Source required libraries
source "${RCFORGE_LIB:-$HOME/.local/share/rcforge/system/lib}/utility-functions.sh"
source "${RCFORGE_LIB:-$HOME/.local/share/rcforge/system/lib}/getoptions.sh"

# Set strict error handling
set -o nounset
set -o pipefail

# Global constants
readonly UTILITY_NAME="example-utility"

# Initialize getoptions
GetoInit "opts"

# Define options
GetoFlag "opts" "v" "verbose" "Enable verbose output"
GetoParam "opts" "o" "output" "Specify output file"
GetoAddHelp "opts"

# Main function
main() {
    # Parse arguments
    GetoParse "opts" "$@" || return $?
    
    # Access options
    local verbose="${_opts_verbose:-false}"
    local output="${_opts_output:-}"
    
    # Display section header
    SectionHeader "Example Utility"
    
    # Show verbose information if enabled
    if [[ "$verbose" == "true" ]]; then
        InfoMessage "Verbose mode enabled"
        InfoMessage "Output file: ${output:-standard output}"
    fi
    
    # Rest of your implementation...
    SuccessMessage "Operation completed successfully"
    return 0
}

# Execute main function if run directly or via rc command
if IsExecutedDirectly || [[ "$0" == *"rc"* ]]; then
    main "$@"
    exit $? # Exit with status from main
fi
```

## Advanced Usage

### Custom Error Handling

The error handler is defined in `GetoInit` and by default will display an error message, show usage, and exit. You can redefine it after initialization if needed:

```bash
# After GetoInit "opts"
# Redefine the error handler
eval "opts_error() {
    ErrorMessage \"Custom error handler: \$1\"
    return 1  # Don't exit, just return error
}"
```

### Multiple Option Groups

You can define multiple option groups with different prefixes:

```bash
# Global options
GetoInit "global"
GetoFlag "global" "v" "verbose" "Enable verbose output"
GetoAddHelp "global"

# Command-specific options for the 'create' command
GetoInit "create"
GetoParam "create" "n" "name" "Specify name"
GetoFlag "create" "f" "force" "Force creation"

# Parse global options first
GetoParse "global" "$@"
shift $?  # Shift to the remaining arguments

# Check for command
case "$1" in
    create)
        shift
        GetoParse "create" "$@"
        # Handle create command...
        ;;
    # Other commands...
esac
```

## Troubleshooting

### Option Parsing Doesn't Work

- Ensure you've called `GetoInit` before defining options
- Verify that option definitions use consistent prefixes
- Make sure you call `GetoParse` with the correct prefix and arguments

### Help Shows No Options

- Check that options were defined after `GetoInit`
- Verify that the help function is using the correct prefix

### General Debugging

Enable verbose output in the shell to see what's happening:

```bash
set -x  # Enable command tracing
# Problem code
set +x  # Disable command tracing
```

## Reference

| Function | Description |
|----------|-------------|
| `GetoInit prefix` | Initialize getoptions with the given prefix |
| `GetoFlag prefix short long help [default]` | Define a boolean flag option |
| `GetoParam prefix short long help [default]` | Define a parameter option (with value) |
| `GetoAddHelp prefix` | Add standard help option |
| `GetoParse prefix "$@"` | Parse command-line arguments |
