# rcForge Project Style Guide

## Table of Contents
- [Introduction](#introduction)
- [General Principles](#general-principles)
- [Shell Scripting Standards](#shell-scripting-standards)
- [Markdown Documentation](#markdown-documentation)
- [Version Control](#version-control)
- [Naming Conventions](#naming-conventions)
- [Code Organization](#code-organization)
- [Error Handling](#error-handling)
- [Performance Considerations](#performance-considerations)

## Introduction

This style guide defines the coding standards, best practices, and conventions for the rcForge project. Our goal is to maintain consistency, readability, and maintainability across all project contributions.

## General Principles

1. **Clarity Over Cleverness**
   - Write code that is easy to understand
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

### Output and Formatting

#### Messaging
- Use predefined messaging functions:
  - `error_message()` for errors
  - `warning_message()` for warnings
  - `success_message()` for successful operations
  - `info_message()` for informational output

#### Colors and Formatting
- Always use `shell-colors.sh` for color definitions
- Use `display_header()` for script headers
- Use `section_header()` for section breaks

#### Error Handling
- Always check command success
- Provide meaningful error messages
- Use appropriate exit codes

### Function Design

1. **Function Naming**
   - Use lowercase with underscores
   - Be descriptive about the function's purpose
   - Examples: `install_dependencies()`, `validate_configuration()`

2. **Function Structure**
   ```bash
   function_name() {
       # Validate inputs
       [[ $# -eq 0 ]] && error_message "No arguments provided" && return 1

       # Function logic
       local result
       if some_condition; then
           result=$(perform_action)
       else
           error_message "Condition not met"
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

## Naming Conventions

### Files
- Use lowercase
- Separate words with hyphens
- Include appropriate extension
- Examples:
  - `bash-functions.sh`
  - `system-configuration.md`

### Variables
- Lowercase with underscores
- Descriptive names
- Examples:
  - `install_directory`
  - `system_configuration`

### Constants
- UPPERCASE with underscores
- Example: `MAX_RETRIES`, `DEFAULT_TIMEOUT`

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

# EOF
