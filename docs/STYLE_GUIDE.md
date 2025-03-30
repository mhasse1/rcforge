# rcForge Project Style Guide

## Table of Contents

- [Introduction](#introduction)
- [General Principles](#general-principles)
- [Shell Scripting Standards](#shell-scripting-standards)
    - [Script Structure](#script-structure)
    - [Output and Formatting](#output-and-formatting)
    - [Function Design](#function-design)
    - [Include System Development Standards](#include-system-development-standards)
- [Markdown Documentation](#markdown-documentation)
    - [General Guidelines](#general-guidelines)
    - [Documentation Structure](#documentation-structure)
- [Version Control](#version-control)
    - [Commit Messages](#commit-messages)
    - [Branch Naming](#branch-naming)
- [Naming Conventions](#naming-conventions)
    - [Files](#files)
    - [Variables](#variables)
    - [Constants](#constants)
- [Code Organization](#code-organization)
- [Error Handling](#error-handling)
- [Performance Considerations](#performance-considerations)
- [Continuous Improvement](#continuous-improvement)

## Introduction

This style guide defines the coding standards, best practices, and conventions for the rcForge project. Our goal is to maintain consistency, readability, and maintainability across all project contributions.

In many ways this document is aspirational.  All I can say is I'm working on it.

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

5. **Convention over Configuration** 🏗️

   - Embrace sensible defaults that work out of the box

   - Reduce the need for extensive configuration by making smart, consistent design choices

   - Follow established patterns in shell scripting and the rcForge ecosystem

   - Minimize the number of decisions a user must make to get started

## Shell Scripting Standards

### Script Structure

```bash
#!/bin/bash
# script-name.sh - Brief description of script purpose
# Author: Your Name
# Date: YYYY-MM-DD

# Always source color utilities first
source shell-colors.sh

# Set strict error handling
set -o nounset  # Treat unset variables as errors
set -o errexit  # Exit immediately if a command exits with a non-zero status
```

### Standard Environment Variables and Functions

`$RCFORGE_SYSTEM` provides the path to the 

### Output and Formatting

#### Messaging
- Use predefined messaging functions:
  - `ErrorMessage()` for errors
  - `WarningMessage()` for warnings
  - `SuccessMessage()` for successful operations
  - `InfoMessage()` for informational output

#### Colors and Formatting

- Always use `shell-colors.sh` for color definitions
- Use `DisplayHeader()` for script headers
- Use `SectionHeader()` for section breaks

#### Error Handling

- Always check command success
- Provide meaningful error messages
- Use appropriate exit codes

### Function Design

1. Function Naming
   - Use pascal case, e.g., `FunctionName`
   - Be descriptive about the function's purpose
   - Examples: `InstallDependencies()`, `ValidateConfiguration()`

2. **Function Structure**
   ```bash
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

   * Use `true` and `false` for boolean return values
   * Use the traditional `0` for success and `1`  for failure 

### Include System Development Standards

#### Include Function File Guidelines

##### File Naming

- Use lowercase with underscores

- Include category and function name

- Reside in appropriate category subdirectory

- Examples:

  ```
  include/
  └── category_name/
      ├── function_name.sh
      └── another_function.sh
  ```

##### Function File Structure

```bash
#!/bin/bash
# function_name.sh - Concise description of function purpose
# Category: function_category
# Author: Your Name
# Date: YYYY-MM-DD

# Function: function_name
# Description: Detailed explanation of function behavior
# Usage: function_name arg1 arg2
function_name() {
    # Input validation
    [[ $# -eq 0 ]] && error_message "No arguments provided" && return 1

    # Function implementation
    local result=""
    # Function logic here

    # Return or output
    echo "$result"
}

# Export the function to make it available in other scripts
export -f function_name
```

#### Utility Script Development

##### Command-Line Utility Standards

1. **Help and Version Handling**

   - Always implement `--help` and `--version` flags
   - Use consistent help and version output format
   - Provide clear usage instructions

2. **Argument Processing**

   ```bash
   # Example argument processing function
   process_args() {
       while [[ "$#" -gt 0 ]]; do
           case $1 in
               --help|-h)
                   show_help
                   exit 0
                   ;;
               --version|-v)
                   show_version
                   exit 0
                   ;;
               # Add specific script arguments here
               *)
                   process_specific_argument "$1"
                   ;;
           esac
           shift
       done
   }
   ```

3. **Interactive vs. Non-Interactive Modes**

   - Support both interactive and non-interactive execution
   - Provide clear flags for mode switching
   - Handle input validation in both modes

##### Utility Function Requirements

- Implement `is_executed_directly()` to detect script execution context
- Create reusable processing functions for common tasks
- Use consistent error handling and messaging

#### Include System Best Practices

1. **Function Categorization**
   Organize functions into clear, logical categories:
   - `path/`: Path manipulation functions
   - `common/`: Utility functions applicable across environments
   - `git/`: Git-related functions
   - `network/`: Network utility functions
   - `system/`: System information and management
   - `text/`: Text processing functions
   - `web/`: Web-related functions

2. **Dependency Management**
   - Use `include_function` to manage function dependencies
   - Document any external dependencies in function comments
   - Provide graceful fallback if dependencies are not met

#### Error Handling in Utility Scripts

```bash
# Enhanced error handling function
error_exit() {
    local message="$1"
    local exit_code="${2:-1}"
    
    # Use standard error (stderr) for error messages
    echo "ERROR: $message" >&2
    exit "$exit_code"
}

# Usage example
some_function() {
    if ! perform_critical_task; then
        error_exit "Critical task failed" 2
    fi
}
```

#### Utility Scripts Performance Considerations

- Minimize function complexity
- Use `local` for variables to prevent global namespace pollution
- Avoid unnecessary subshells
- Use built-in shell capabilities over external commands
- Test exported functions in a separate script to verify all dependencies are properly exported.

#### Testing Utility Scripts and Functions

- Always test both direct execution and sourcing scenarios
- Implement self-test capabilities
- Support verbose and quiet modes for debugging

### Continuous Improvement

This section of the style guide focuses on creating consistent, maintainable, and high-quality include functions and utility scripts. Regularly review and update these guidelines to reflect best practices and lessons learned from real-world usage.

## Markdown Documentation

### General Guidelines
- Use GitHub Flavored Markdown
- Maintain clear, concise documentation
- Use headers to organize content
- Include code blocks with syntax highlighting
- Use lists for enumeration

### Documentation Structure
- Clear, descriptive title
- Table of contents for longer documents
- Installation/usage instructions
- Examples
- Troubleshooting section

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
- Examples:
  - `bash-functions.sh`
  - `system-configuration.md`

## Variable Naming

### General Variable Naming

- Use lowercase with underscores (snake_case)
- Descriptive and clear names
- Scope limited to the current script or function

### Variable Scoping Conventions

- g_: Prefix for global variables (script-level or widely accessible)
- No prefix: Local variables (function parameters, loop counters, etc.)

#### Best Practices

- Minimize the use of global variables
- Prefer passing parameters and returning values
- Use global variables sparingly and with clear documentation
- Always consider the smallest possible scope for a variable

##### Variable Export Considerations

- **Exported Variable Assessment**: When creating variables, first determine if they'll need to be accessible from other scripts. If so, they should be treated as environment variables, not constants.
- **Function Dependency Consideration**: For any function that will be exported with `export -f`, identify all variables it depends on. Those variables must also be exported and follow environment variable conventions.

#### Global and Local Variable Examples

``` bash
# Global variable (script-level)
g_total_tests=0
g_configuration_path="/etc/myapp/config"

# Function with various variable scopes
process_data() {
    # No prefix for local, temporary variables
    local current_index=0
    local result=""
    
    # Use g_ prefix for variables that persist beyond the function
    g_last_processed_file=""
    
    # Function logic
    while read -r line; do
        # Very local variables, no prefix needed
        processed_line=$(transform "$line")
        current_index=$((current_index + 1))
    done
}
```

### Boolean Variables

- Use built-in arithmetic evaluation to handle boolean values
- Arithmetic evaluation provides a more direct and performance-efficient boolean handling in bash
- Assign `true` or  `false` directly.

#### Boolean Variable Examples 

```bash
# Recommended
bool_variable=true
bool_variable=false

if $bool_variable; then
  echo "Variable is true"
fi

if ! $bool_variable"; then
  echo "Variable is false"
fi

# Avoid these less idiomatic approaches
if [[ "$bool_variable" == "true" ]]; then
  echo "More verbose string comparison"
fi

if [[ "$bool_variable" -eq 1 ]]; then
  echo "Numeric comparison is less clear"
fi
```

### In-Script Constants

- Use `readonly` for constants
- Prefix constants with `c_`

#### Example of Constants

``` bash
# In-script local constant
readonly c_max_retries=3

# Constant used globally across a script
readonly gc_application_name="rcForge"
```

### Environment Variables

- Follow standard shell conventions for naming and case
- Should not include `c_` prefix or be marked `readonly`
- Use ALL_CAPS only for:
  1. Variables exported to the parent shell
  2. System-level environment variables
- Do not use uppercase for local script tracking variables

#### Environment Variable Examples

```bash
# Exported environment variables (UPPERCASE)
export PATH="/usr/local/bin:$PATH"
export HOME="/home/username"

# INCORRECT: Don't use constant naming for exported variables
readonly c_COLOR_OUTPUT_ENABLED=true  # Wrong - mixes constant style with exported need
```

## Code Organization

### Directory Structure
```
project-root/
├── core/           # Core functionality
├── include/        # Modular include functions
├── scripts/        # Example scripts
├── utils/          # Utility scripts
├── docs/           # Documentation
└── tests/          # Test scripts
```

## Error Handling

1. Use `set -e` to exit on error
2. Provide meaningful error messages
3. Use exit codes consistently
   - 0: Success
   - 1-125: Command-specific errors
   - 126-255: Shell-specific errors

## Performance Considerations

- Avoid unnecessary subshells
- Use `[[ ]]` instead of `[ ]`
- Prefer `read -r` for input
- Use `command -v` instead of `which`
- Minimize use of external commands
- Use `local` for variables in functions

## Continuous Improvement

This style guide is a living document. Contributions and suggestions for improvement are welcome. When in doubt, prioritize readability, maintainability, and consistency.

EOF
