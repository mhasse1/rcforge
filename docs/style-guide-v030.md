# rcForge Project Style Guide (v0.3.0)

## Table of Contents

- [Introduction](#introduction)
- [General Principles](#general-principles)
- [Shell Scripting Standards](#shell-scripting-standards)
  - [Script Structure](#script-structure)
  - [Standard Environment Variables](#standard-environment-variables)
  - [Main Function Standards](#main-function-standards)
  - [Output and Formatting](#output-and-formatting)
    - [Messaging](#messaging)
    - [Colors and Formatting](#colors-and-formatting)
    - [Error Handling](#error-handling)
  - [Function Design](#function-design)
  - [Source-able Files vs. Standalone Scripts](#source-able-files-vs-standalone-scripts)
- [RC Scripts Development](#rc-scripts-development)
  - [Naming Convention](#naming-convention)
  - [Sequence Ranges](#sequence-ranges)
  - [Common vs. Shell-Specific Scripts](#common-vs-shell-specific-scripts)
  - [Global vs. Hostname-Specific Scripts](#global-vs-hostname-specific-scripts)
- [RC Command Utility Development](#rc-command-utility-development)
  - [Utility Script Structure](#utility-script-structure)
  - [Help Documentation](#help-documentation)
  - [User Override Considerations](#user-override-considerations)
  - [Integration with Search](#integration-with-search)
  - [Lazy Loading Patterns](#lazy-loading-patterns)
- [Variable Naming Conventions](#variable-naming-conventions)
  - [Variable Types in Shell Scripts](#variable-types-in-shell-scripts)
  - [Key Rules for Variables in Libraries](#key-rules-for-variables-in-libraries)
  - [Example: Before and After Refactoring](#example-before-and-after-refactoring)
    - [Before (Inconsistent Conventions)](#before-inconsistent-conventions)
    - [After (Following Conventions)](#after-following-conventions)
- [Documentation Standards](#documentation-standards)
  - [Markdown Guidelines](#markdown-guidelines)
  - [RC Command Help Documentation](#rc-command-help-documentation)
- [Version Control](#version-control)
  - [Commit Messages](#commit-messages)
  - [Branch Naming](#branch-naming)
- [File Naming Conventions](#file-naming-conventions)
- [Error Handling](#error-handling-1)
- [Performance Considerations](#performance-considerations)
- [Testing Standards](#testing-standards)
  - [RC Script Testing](#rc-script-testing)
  - [RC Command Utility Testing](#rc-command-utility-testing)
- [Continuous Improvement](#continuous-improvement)

## Introduction

This style guide defines the coding standards, best practices, and conventions for the rcForge v0.3.0 project. Our goal is to maintain consistency, readability, and maintainability across all project contributions while adhering to the redesigned architecture.

## General Principles

1. **Clarity Over Cleverness**
   - Write code that is easy to understand, not code that makes you look smart
   - Prioritize readability over complex one-liners
   - Add comments to explain non-obvious logic
2. **DRY (Don't Repeat Yourself)**
   - Reuse existing functions and utilities
   - Create modular, reusable code
   - Avoid copy-pasting code blocks
3. **KISS (Keep It Simple, Stupid)**
   - Prefer simple solutions
   - Break complex logic into smaller, manageable functions
   - Avoid unnecessary complexity
4. **Fail Gracefully**
   - Always have a Plan B (and sometimes a Plan C)
   - Implement robust error handling
   - Provide meaningful error messages that help diagnose issues
   - Never let an unexpected error crash the entire system
5. **Convention over Configuration**
   - Embrace sensible defaults that work out of the box
   - Reduce the need for extensive configuration by making smart, consistent design choices
   - Follow established patterns in shell scripting and the rcForge ecosystem
   - Minimize the number of decisions a user must make to get started

## Shell Scripting Standards

> **⚠️ WARNING: #!/usr/bin/env bash**
> It is critical to use `#!/usr/bin/env bash` instead of `#!/bin/bash`. This ensures the greatest cross-system compatibility, particularly with Darwin and other systems with a default install of Bash <4.0.

### Script Structure

```bash
#!/usr/bin/env bash
# script-name.sh - Brief description
# Author: Name
# Date: YYYY-MM-DD
# Category: system (or utilities, core, etc.)
# Description: More detailed explanation of the script's purpose

# Source shared utilities
source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/shell-colors.sh"

# Set strict error handling
set -o nounset  # Treat unset variables as errors
set -o errexit  # Exit immediately if a command exits with a non-zero status

# Exported variables (for use in exported functions)
export COLOR_ENABLED=true
export DEBUG_MODE=false

# Global constants (not exported)
readonly gc_version="0.3.0"
readonly gc_app_name="rcForge"

# Function definitions...

# Main execution logic...

# EOF
```

### Standard Environment Variables

The following environment variables are standard in rcForge v0.3.0:

- `$RCFORGE_ROOT`: Points to the user's rcForge installation (typically `~/.config/rcforge`)
- `$RCFORGE_LIB`: Location of system libraries
- `$RCFORGE_UTILS`: Location of system utilities
- `$RCFORGE_SCRIPTS`: Location of user RC scripts
- `$RCFORGE_USER_UTILS`: Location of user utilities

### Main Function Standards

#### Purpose

Main functions serve as the primary entry point for script execution, providing a clean, organized structure for script logic and improving readability, testability, and maintainability.

#### Requirements

##### Function Definition

- For scripts longer than approximately 50-100 lines, implement a `main()` function

- Place the `main()` function near the end of the script, before the final execution block

- The

  ```
  main()
  ```

   function should:

  - Encapsulate the primary script logic
  - Handle high-level flow control
  - Coordinate calls to other functions
  - Manage command-line argument processing
  - Return appropriate exit codes

##### Execution Pattern

Implement an execution pattern that allows the script to be both sourced and run directly:

```bash
# Execute main function if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
  exit $?
elif [[ "${BASH_SOURCE[0]}" != "${0}" && "$0" == *"rc"* ]]; then
  # Also execute if called via the rc command
  main "$@"
  exit $?
fi
```

##### Best Practices

- Break complex logic into smaller, focused functions
- Use local variables within the main function
- Handle errors and provide meaningful exit codes
- Support common subcommands like `help`, `version`, or `summary`
- Implement argument parsing within the main function
- Provide clear, descriptive error messages

##### Example Structure

```bash
#!/usr/bin/env bash
# Example script demonstrating main function standards
# Function comments shortened for readability

# Function: ShowSummary
# Description: Display one-line summary for rc help
# Usage: ShowSummary
ShowSummary() {
  echo "Short summary of script functin"
}

# Function: show_help
# Description: Display help information
show_help() {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  --help, -h    Show this help message"
}

# Function: process_arguments
# Description: Parse and validate command-line arguments
process_arguments() {
  # Argument processing logic
}

# Main function
main() {
  # Argument processing
  process_arguments "$@"

  # Core script logic
  # Coordinate function calls
  # Handle primary workflow

  # Return appropriate exit code
  return 0
}

# Execution pattern
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
  exit $?
fi
```

##### Rationale

- Improves script modularity
- Enhances testability by separating logic into functions
- Provides a consistent structure across scripts
- Allows for easier debugging and maintenance
- Supports both direct execution and sourcing
- Aligns with rcForge's design philosophy of clarity and maintainability

##### Exceptions

- Very short, single-purpose scripts may not require a full `main()` function
- Use developer discretion, prioritizing readability and maintainability

#### Related Best Practices

- Use `set -o nounset` and `set -o errexit` for stricter error handling
- Implement comprehensive error checking
- Add meaningful comments explaining complex logic
- Consider using shellcheck for additional code quality verification

### Output and Formatting

#### Messaging
- Use predefined messaging functions:
  - `ErrorMessage()` for errors
  - `WarningMessage()` for warnings
  - `SuccessMessage()` for successful operations
  - `InfoMessage()` for informational output

Example:
```bash
InfoMessage "Starting configuration process..."
if ! ConfigureSystem; then
    ErrorMessage "Configuration failed. See logs for details."
    return 1
fi
SuccessMessage "Configuration completed successfully!"
```

#### Colors and Formatting

- Always source and use `shell-colors.sh` for color definitions
- Use `SectionHeader()` for section breaks
- Use `TextBlock()` for highlighted blocks of text

Example:
```bash
SectionHeader "System Configuration"

# Process configuration
if ConfigureSystem; then
    TextBlock "Configuration Successful" "$GREEN"
else
    TextBlock "Configuration Failed" "$RED"
fi
```

#### Error Handling

- Always check command success
- Provide meaningful error messages
- Use appropriate exit codes

Example:
```bash
if ! command -v git >/dev/null 2>&1; then
    ErrorMessage "Git not found. Please install git and try again."
    return 1
fi

if ! git clone "$repo_url"; then
    ErrorMessage "Failed to clone repository from $repo_url"
    return 2
fi
```

### Function Design

1. Function Naming
   - Use pascal case for core system functions, e.g., `FunctionName`
   - Use lowercase with underscores for utility functions, e.g., `utility_function`
   - Be descriptive about the function's purpose
   - Examples: `InstallDependencies()`, `validate_configuration()`
   - Include function headings as demonstrated in 2. Function Structure below.
   - When it does not interfere with the archecture of the script, all functions should be declared at the top of the script file.

2. **Function Structure**

   ```bash
   # ============================================================================
   # Function: FunctionName
   # Description: Clear, concise description of what the function does
   # Usage: Demonstrate how to call the function [Optional, not required for simple implementations or if no arguments]
   # Arguments: ["None" if no arguments]
   #   arg1 (required) - Description of first argument
   #   arg2 (optional) - Description of second argument (if applicable)
   # Options: [Optional, if present]
   #   --option1 Description of option
   #   --option2 Description of option
   # Environment Variables: [Optional, if present]
   #   ENV_VAR1 - Impact or requirement of environment variable
   # Returns: [Optional, if present]
   #   0 on success
   #   1 on error
   #   Specific exit codes if applicable
   # Exits: [Optional, if present]
   #   May exit with specific codes in error conditions
   # ============================================================================
   FunctionName() {
       # Validate inputs
       [[ $# -eq 0 ]] && ErrorMessage "No arguments provided" && return 1
   
       # Function logic
       local result
       if some_condition; then
           result=$(perform_action)
       else
           ErrorMessage "Condition not met"
           return 1
       fi
   
       # Return or output
       echo "$result"
   }
   ```

3. **Input Validation**
   - Check number and type of arguments
   - Validate input values
   - Provide helpful error messages

4. **Return Values**
   - Use `return 0` for success
   - Use `return 1` (or higher values) for errors
   - For functions that produce output, `echo` the result
   - For boolean functions, use `true` and `false`

### Source-able Files vs. Standalone Scripts

In rcForge v0.3.0, we adopt a pragmatic approach to functions vs. scripts:

#### When to Use Source-able Files

Use source-able files (libraries) when:
- Defining constants, variables, or functions used across multiple scripts
- Providing UI elements like colors and formatting
- Creating reusable utility functions
- Maintaining state between operations

Example source-able file structure:
```bash
#!/usr/bin/env bash
# utility-lib.sh - Common utility functions library
# Category: lib
# Author: Name
# Date: YYYY-MM-DD

# Exported variables (available to scripts that source this file)
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export RESET='\033[0m'

# Utility function for error messages
ErrorMessage() {
    echo -e "${RED}ERROR:${RESET} $1" >&2
}
export -f ErrorMessage

# EOF
```

#### When to Use Standalone Scripts

Use standalone scripts when:
- Creating complete, self-contained utilities
- Building tools for the `rc` command framework
- Implementing operations that don't need to maintain state
- Using languages other than Bash

Example standalone script structure:
```bash
#!/usr/bin/env bash
# utility-name.sh - Utility description
# Category: utility
# Author: Name
# Date: YYYY-MM-DD

# Source required libraries
source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/shell-colors.sh"

# Set strict error handling
set -o nounset
set -o errexit

# Main logic
main() {
    # Process arguments
    # Execute functionality
    # Return result
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

# EOF
```

## RC Scripts Development

RC scripts are the core configuration files loaded by rcForge during shell initialization.

### Naming Convention

All RC scripts must follow this naming convention:
```
###_[hostname|global]_[environment]_[description].sh
```

Where:
- `###`: Three-digit sequence number that determines load order
- `[hostname|global]`: Either your specific hostname or "global" for all machines
- `[environment]`: One of "common", "bash", or "zsh"
- `[description]`: Brief description of what the script does

Examples:
```
050_global_common_path.sh
210_global_bash_config.sh
350_hostname_zsh_prompt.sh
```

### Sequence Ranges

To maintain organization and prevent conflicts, use these sequence number ranges:

| Range   | Purpose                                   |
|---------|-------------------------------------------|
| 000-199 | Critical configurations (PATH, etc.)      |
| 200-399 | General configurations (Prompt, etc.)     |
| 400-599 | Functions and aliases                     |
| 600-799 | Package specific configurations           |
| 800-949 | End of script info displays, clean up     |
| 950-999 | Critical end of RC scripts                |

### Common vs. Shell-Specific Scripts

- Use `common` for settings that apply to both Bash and Zsh
- Use `bash` or `zsh` for shell-specific configurations
- Avoid duplicating settings across shell-specific scripts

### Global vs. Hostname-Specific Scripts

- Use `global` for settings that apply to all hosts
- Use a specific hostname for machine-specific settings
- Hostname-specific scripts override global scripts with the same sequence number

## RC Command Utility Development

The `rc` command provides a unified interface for accessing utilities.

### Utility Script Structure

```bash
#!/usr/bin/env bash
# utility-name.sh - Short utility description
# RC Summary: One-line description for RC help
# Author: Name
# Date: YYYY-MM-DD

# Source necessary libraries
source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/shell-colors.sh"

# Set strict error handling
set -o nounset
set -o errexit

# Display help information
show_help() {
    cat << EOF
utility-name - Detailed description

Description:
  Explain what the utility does in detail.

Usage:
  rc utility-name [options] <arguments>

Options:
  -v, --verbose    Enable verbose output
  -h, --help       Show this help message

Examples:
  rc utility-name example.com
  rc utility-name --verbose /path/to/file
EOF
}

# Display summary (used by rc help command)
show_summary() {
    echo "One-line description for RC help display"
}

# Main function
main() {
    # Process arguments
    case "${1:-}" in
        help|--help|-h)
            show_help
            return 0
            ;;
        summary|--summary)
            show_summary
            return 0
            ;;
        # Add other argument handling here
    esac

    # Main functionality
}

# Execute main if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

# EOF
```

### Help Documentation

Each RC utility must provide:

1. **Summary**: One-line description displayed in `rc help`
2. **Help**: Detailed usage information shown with `rc utility-name help`

The help documentation should include:
- Description
- Usage syntax
- Available options
- Examples

### User Override Considerations

When developing utilities for the RC command framework:

1. System utilities should be designed to be overridable
2. Use standard input/output patterns to maintain compatibility
3. Documentation should be separate from implementation to allow partial overrides
4. Check for custom user configuration before executing main logic

Example override-friendly design:
```bash
#!/usr/bin/env bash
# httpheaders.sh - HTTP header inspection utility

# Source necessary libraries
source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/shell-colors.sh"

# Configuration variables with defaults
: "${HTTPHEADERS_CONFIG_PATH:=$HOME/.config/rcforge/config/httpheaders.conf}"

# Load user configuration if it exists
if [[ -f "$HTTPHEADERS_CONFIG_PATH" ]]; then
    source "$HTTPHEADERS_CONFIG_PATH"
fi

# Main function
main() {
    # Implementation
}

# Execute main if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

# EOF
```

### Integration with Search

To ensure your utility is discoverable with `rc search`:

1. Include relevant keywords in your script's description
2. Add a clear, descriptive summary
3. Use standardized terminology for similar concepts

### Lazy Loading Patterns

For performance-critical utilities or complex commands:

```bash
# Example lazy loading implementation
utility_name() {
    # Unset this function to prevent recursion
    unset -f utility_name

    # Load full implementation
    if [[ -f "${RCFORGE_ROOT:-$HOME/.config/rcforge}/system/utils/utility_name.sh" ]]; then
        source "${RCFORGE_ROOT:-$HOME/.config/rcforge}/system/utils/utility_name.sh"
        # Call now-loaded implementation with original arguments
        utility_name "$@"
    else
        ErrorMessage "Could not load utility implementation"
        return 1
    fi
}
```

## Variable Naming Conventions

### Variable Types in Shell Scripts

Since Bash doesn't have formal type declarations, we use consistent naming conventions to indicate how variables should be used.

#### Variable Types Reference Table

| Type                 | Naming Convention       | Declaration Style                   | Example                                  | Notes                                                        |
| -------------------- | ----------------------- | ----------------------------------- | ---------------------------------------- | ------------------------------------------------------------ |
| Local Variable       | lowercase_snake_case    | `local var_name="value"`            | `local file_count=0`                     | Function-scoped, not available outside function              |
| Global Variable      | g_lowercase_snake_case  | `g_var_name="value"`                | `g_total_errors=0`                       | Script-level scope, not exported                             |
| Local Constant       | c_lowercase_snake_case  | `local readonly c_var_name="value"` | `local readonly c_max_retries=3`         | Function-scoped constant                                     |
| Global Constant      | gc_lowercase_snake_case | `readonly gc_var_name="value"`      | `readonly gc_application_name="rcForge"` | Script-level constant                                        |
| Environment Variable | UPPERCASE_SNAKE_CASE    | `export VAR_NAME="value"`           | `export PATH="/usr/bin:$PATH"`           | Made available to the current shell environment and child processes |
| Boolean Variable     | is_* or has_*           | `is_var=true` or `is_var=false`     | `is_verbose=true`                        | Use true/false directly                                      |

### Key Rules for Variables in Libraries

The most important rule when working with libraries and exported functions:

**Any variable referenced inside an exported function must itself be exported and should be set as such when first declared.**

#### Exported Variables

> **⚠️ WARNING: EXPORTED VARIABLES**
> When creating libraries with exported functions, any variables used within
> those functions MUST be exported and MUST use UPPERCASE_SNAKE_CASE naming.
> Never use c_ or gc_ prefixes for exported variables!

Variables that will be used by exported functions MUST:
- Use UPPERCASE_SNAKE_CASE naming (e.g., COLOR_OUTPUT_ENABLED)
- Be explicitly exported using the 'export' keyword when declared
- NOT use any prefixes like c_, gc_, etc. (these are reserved for constants)
- NOT be declared as readonly (as this can cause issues when sourced in different contexts)

``` bash
✅ CORRECT:
export RED='\033[0;31m'
export MAX_RETRIES=3

ErrorMessage() {
    echo -e "${RED}Error: $1${RESET}"
}
export -f ErrorMessage

❌ INCORRECT:
readonly gc_red='\033[0;31m'  # Wrong! Using gc_ prefix on an exported variable
local c_max_retries=3        # Wrong! Local variable used in exported function

ErrorMessage() {
    echo -e "${gc_red}Error: $1${RESET}"  # Will fail when sourced elsewhere
}
export -f ErrorMessage
```

#### Example Library with Exported Functions and Variables

```bash
# Example library with exported functions and variables
#!/usr/bin/env bash
# colors.sh - Simplified color utility

# CORRECT: Color variables are exported because exported functions use them
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export RESET='\033[0m'
export COLOR_ENABLED=true

# This function will work when called from another script
ErrorMessage() {
    local message="$1"
    if $COLOR_ENABLED; then
        echo -e "${RED}ERROR:${RESET} $message" >&2
    else
        echo "ERROR: $message" >&2
    fi
}

# Export the function
export -f ErrorMessage

# INCORRECT: This would fail when called from another script
readonly gc_MAX_TRIES=3  # Not exported
MaxTriesReached() {
    echo "Exceeded maximum tries ($gc_MAX_TRIES)"
}
export -f MaxTriesReached
```

### Example: Before and After Refactoring

#### Before (Inconsistent Conventions)

```bash
# Inconsistent conventions
COLORS_ENABLED="yes"  # String instead of boolean
maxRetries=5          # Camel case, unclear scope
temp="/tmp/workdir"   # No indication of scope or purpose

# Function that relies on global variables
show_error() {
    if [[ "$COLORS_ENABLED" == "yes" ]]; then
        echo -e "\033[31mERROR: $1\033[0m"
    else
        echo "ERROR: $1"
    fi
}
```

#### After (Following Conventions)

```bash
# Environment variable (will be exported)
export COLOR_OUTPUT_ENABLED=true  # Boolean value

# Global constant
readonly gc_max_retries=5

# Local variable (inside a function)
ProcessFiles() {
    local temp_dir="/tmp/workdir"
    # Using local constant inside function
    local readonly c_max_files=100
    # Function implementation...
}

# Function with proper local variables
ErrorMessage() {
    local message="$1"

    if $COLOR_OUTPUT_ENABLED; then
        echo -e "\033[31mERROR: $message\033[0m"
    else
        echo "ERROR: $message"
    fi
}
export -f ErrorMessage  # If needed elsewhere
```

## Documentation Standards

### Markdown Guidelines

- Use GitHub Flavored Markdown
- Maintain clear, concise documentation
- Use headers to organize content
- Include code blocks with syntax highlighting
- Use lists for enumeration

Example:
```markdown
# Utility Name

## Description
Brief description of the utility.

## Usage
```bash
rc utility-name [options] <arguments>
```

## Options
- `-v, --verbose`: Enable verbose output
- `-h, --help`: Show help message

## Examples
```bash
rc utility-name example.com
rc utility-name --verbose /path/to/file
```
```

### RC Command Help Documentation

Each RC command utility should include:

1. **Inline Documentation**:
   - Header comment with utility name and description
   - `RC Summary` tag with one-line description for `rc help`
   - Function comments for significant functions

2. **Help Command Support**:
   - `show_help()` function that displays comprehensive usage information
   - `show_summary()` function that returns the one-line description

3. **External Documentation** (when necessary):
   - Markdown file in the docs directory for complex utilities
   - Cross-references to related utilities or concepts

## Version Control

### Commit Messages
- Use imperative mood
- Limit first line to 50 characters
- Provide context in the body if needed

```
Add shell color utility functions

- Create comprehensive shell-colors.sh
- Include messaging and formatting utilities
- Update style guide to reflect new standards
```

### Branch Naming
- `feature/short-description`
- `bugfix/issue-description`
- `docs/documentation-update`

## File Naming Conventions

- Use lowercase
- Separate words with hyphens
- Include appropriate extension
- For RC scripts, follow the sequence-based naming convention
- Examples:
  - `bash-functions.sh`
  - `050_global_common_path.sh`
  - `httpheaders.sh`

## Error Handling

1. Use `set -e` to exit on error
2. Provide meaningful error messages
3. Use exit codes consistently
   - 0: Success
   - 1-125: Command-specific errors
   - 126-255: Shell-specific errors

Example error handling:
```bash
if ! command -v curl >/dev/null 2>&1; then
    ErrorMessage "curl command not found. Please install curl and try again."
    return 1
fi

result=$(curl -s "$url" 2>/dev/null) || {
    ErrorMessage "Failed to fetch data from $url"
    return 2
}
```

## Performance Considerations

- Use lazy loading for infrequently used functionality
- Avoid unnecessary subshells
- Use `[[ ]]` instead of `[ ]` for better performance and features
- Prefer built-in shell commands over external utilities
- Use `local` for function variables to prevent namespace pollution
- Minimize sourcing of files during shell initialization

## Testing Standards

### RC Script Testing

- Test scripts across both Bash and Zsh
- Verify sequence loading order
- Check for variable namespace conflicts
- Test hostname-specific overrides

### RC Command Utility Testing

- Test standalone execution
- Test execution through the `rc` command
- Verify help and summary display
- Test user override functionality
- Include error case testing

## Continuous Improvement

This style guide is a living document. Contributions and suggestions for improvement are welcome. When in doubt, prioritize readability, maintainability, and consistency.

The standards outlined here align with the v0.3.0 architecture and should be applied to all new development. Existing code should be updated to these standards when substantial modifications are made.

# EOF
