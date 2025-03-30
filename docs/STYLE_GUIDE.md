# rcForge Project Style Guide

## Table of Contents

- [Introduction](#introduction)
- [General Principles](#general-principles)
- [Shell Scripting Standards](#shell-scripting-standards)
  - [Script Structure](#script-structure)
  - [Standard Environment Variables and Functions](#standard-environment-variables-and-functions)
  - [Output and Formatting](#output-and-formatting)
    - [Messaging](#messaging)
    - [Colors and Formatting](#colors-and-formatting)
    - [Error Handling](#error-handling)
  - [Function Design](#function-design)
  - [Include System Development Standards](#include-system-development-standards)
    - [Include Function File Guidelines](#include-function-file-guidelines)
    - [Utility Script Development](#utility-script-development)
    - [Include System Best Practices](#include-system-best-practices)
    - [Error Handling in Utility Scripts](#error-handling-in-utility-scripts)
    - [Utility Scripts Performance Considerations](#utility-scripts-performance-considerations)
    - [Testing Utility Scripts and Functions](#testing-utility-scripts-and-functions)
  - [Continuous Improvement](#continuous-improvement)
- [Markdown Documentation](#markdown-documentation)
  - [General Guidelines](#general-guidelines)
  - [Documentation Structure](#documentation-structure)
- [Version Control](#version-control)
  - [Commit Messages](#commit-messages)
  - [Branch Naming](#branch-naming)
- [File Naming Conventions](#file-naming-conventions)
- [Variable Naming Conventions](#variable-naming-conventions)
  - [Variable Types in Shell Scripts](#variable-types-in-shell-scripts)
  - [Key Rules for Variables in Libraries](#key-rules-for-variables-in-libraries)
  - [Example: Before and After Refactoring](#example-before-and-after-refactoring)
    - [Before (Inconsistent Conventions)](#before-inconsistent-conventions)
    - [After (Following Conventions)](#after-following-conventions)
- [Code Organization](#code-organization)
  - [Directory Structure](#directory-structure)
- [Error Handling](#error-handling-1)
- [Performance Considerations](#performance-considerations)
- [Continuous Improvement](#continuous-improvement-1)

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

**Note** the use of `#!/usr/bin/env bash` instead of `#!/bin/bash`.  This ensures the greatest cross system compatibility, particularly with Darwin.

### Script Structure

```bash
#!/usr/bin/env bash
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

## Variable Scope and Naming Conventions

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

**Please see below for further implementation and usage examples.**

### Key Rules for Variables in Libraries

The most important rule when working with libraries and exported functions:

**Any variable referenced inside an exported function must itself be exported and should be set as such when first declared.**

- Exported variables should not be declared as readonly.

- Exported variables should not use the c_ or gc_ prefix.

```bash
# Example library with exported functions and variables
#!/bin/bash
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

By consistently following these naming conventions, scripts become more readable, maintainable, and less prone to variable scope errors.

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
