# rcForge Project Style Guide (v0.5.0)

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
  - [Utility Template Usage](#utility-template-usage)
  - [Standard Function Implementations](#standard-function-implementations)
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
- [XDG Compliance (v0.5.0+)](#xdg-compliance-v050)
  - [Directory Structure](#directory-structure)
  - [Path References](#path-references)

## Introduction

This style guide defines the coding standards, best practices, and conventions for the rcForge v0.5.0 project. Our goal is to maintain consistency, readability, and maintainability across all project contributions while adhering to the redesigned architecture. This version updates the standards to align with the XDG-compliant directory structure and new features in v0.5.0.

Note that in many cases this document is still aspirational and as code is revised, attempts are being made to bring things up to the latest standards.

One more note, if at times the instructions seem pedantic, it is because I found edge cases when working witih AI coding assistants and these explicit instructions were required to address those cases.

## General Principles

1. **No spaces or special characters in file names.**

   * We want to be able to automate and script quickly without playing around with IFS.

2. **Clarity Over Cleverness**

   - Write code that is easy to understand, not code that makes you look smart

   - Prioritize readability over complex one-liners

   - Add comments to explain non-obvious logic

   - **BASH** is the core of our system. When it makes sense extract code to a separate file to ensure it runs in BASH rather than increasing code and complexity by introducing workarounds to directly support ZSH.

     - See rcforge/system/core/run-integrity-checks.sh for an example. This code was embedded in rcforge.sh and was broken out to ensure it runs in BASH.

   - **ZSH** is a first class citizen in this system. When it is necessary to support ZSH, contradicting the prior principle is the right decision.

   - Do not string multiple commands onto the same line

     - See standards for `if...then` and `loops`. There are appropriate use cases for these constructs.

     - Examples:

           # Acceptable:
           if [[ -z "$header" ]]; then
           	continue
           else
           	exit 1
           fi

           ## Acceptable for simple cases:
           [[ -z "$header" ]] && continue || exit 1

           ## Not acceptable:
           if [[ -z "$header" || ! "$header" == *": "* ]]; then; continue; fi

3. **DRY (Don't Repeat Yourself)**

   - Reuse existing functions and utilities
   - Create modular, reusable code
   - Avoid copy-pasting code blocks

4. **KISS (Keep It Simple, Stupid)**
   - Prefer simple solutions
   - Break complex logic into smaller, manageable functions
   - Avoid unnecessary complexity

5. **Fail Gracefully**
   - Always have a Plan B (and sometimes a Plan C)
   - Implement robust error handling
   - Provide meaningful error messages that help diagnose issues
   - Never let an unexpected error crash the entire system

6. **Convention over Configuration**
   - Embrace sensible defaults that work out of the box
   - Reduce the need for extensive configuration by making smart, consistent design choices
   - Follow established patterns in shell scripting and the rcForge ecosystem
   - Minimize the number of decisions a user must make to get started

## Shell Scripting Standards

> **⚠️ WARNING: #!/usr/bin/env bash**
> It is critical to use `#!/usr/bin/env bash` instead of `#!/bin/bash`. This ensures the greatest cross-system compatibility, particularly with Darwin and other systems with a default install of Bash <4.0.

**Project Name in Code**

The correct name of the project is `rcForge`.  For camel_case applications it should be written `RcForge`. To shorten the function or variable name, use `rc`.

### Project Libraries

**Primary Library:** Most shared functionality (messaging, colors, common checks, context detection) is provided by `${RCFORGE_LIB}/utility-functions.sh`.

* **Sourcing Strategy:** Scripts needing these common functions should `source` the main `utility-functions.sh` library using the `$RCFORGE_LIB` variable (see Script Structure example for safe sourcing).
* **Nested Sourcing:** The `utility-functions.sh` library internally sources `shell-colors.sh`. Therefore, scripts should **not** typically source `shell-colors.sh` directly. Sourcing only `utility-functions.sh` provides access to both utility functions and color/messaging capabilities.

### Script Structure

```bash
#!/usr/bin/env bash
# script-name.sh - Brief description
# Author: Name
# Date: YYYY-MM-DD
# Version: 0.5.0
# Category: system (or utilities, core, etc.)
# RC Summary: One-line description for RC help display
# Description: More detailed explanation of the script's purpose

# Source shared utilities
source "${RCFORGE_LIB:-$HOME/.local/rcforge/system/lib}/utility-functions.sh"

# Set strict error handling
set -o nounset  # Treat unset variables as errors
set -o pipefail # Ensure pipeline fails on any component failing
# set -o errexit  # Commented: Let functions handle their own errors

# Global constants (not exported)
[ -v gc_version ]  || readonly gc_version="${RCFORGE_VERSION:-0.5.0}"
[ -v gc_app_name ] || readonly gc_app_name="${RCFORGE_APP_NAME:-rcForge}"
readonly UTILITY_NAME="utility-name" # Replace with actual name

# Function definitions...

# Main function definition...

# Script execution guard
if IsExecutedDirectly || [[ "$0" == *"rc"* ]]; then
    main "$@"
    exit $? # Exit with status from main
fi

# EOF
```

### Standard Environment Variables

The following environment variables are standard in rcForge v0.5.0:

- `$RCFORGE_CONFIG_ROOT`: Points to the user's rcForge configuration directory (`~/.config/rcforge`)
- `$RCFORGE_LOCAL_ROOT`: Points to the rcForge system installation (`~/.local/rcforge`)
- `$RCFORGE_LIB`: Location of system libraries
- `$RCFORGE_UTILS`: Location of system utilities
- `$RCFORGE_SCRIPTS`: Location of user RC scripts
- `$RCFORGE_USER_UTILS`: Location of user utilities
- `$RCFORGE_CONFIG`: Location of configuration files

### Main Function Standards

#### Purpose

Main functions serve as the primary entry point for script execution, providing a clean, organized structure for script logic and improving readability, testability, and maintainability.

#### Requirements

##### Function Definition

- For scripts longer than approximately 50-100 lines, implement a `main()` function

- Place the `main()` function near the end of the script, before the final execution block

- The `main()`  function should:

  - Encapsulate the primary script logic
  - Handle high-level flow control
  - Coordinate calls to other functions
  - Manage command-line argument processing
  - Return appropriate exit codes

##### Execution Pattern

Implement an execution pattern that allows the script to be both sourced and run directly:

```bash
# Execute main function if run directly or via the rc command
if IsExecutedDirectly || [[ "$0" == *"rc"* ]]; then
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

# Function: ShowHelp
# Description: Display help information
# Usage: ShowHelp
ShowHelp() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --help, -h    Show this help message"
    exit 0
}

# Function: ParseArguments
# Description: Parse and validate command-line arguments
# Usage: ParseArguments options_array_name "$@"
ParseArguments() {
    local -n options_ref="$1"
    shift

    # Argument processing logic
    # ...

    return 0
}

# Main function
main() {
    # Parse arguments
    declare -A options
    ParseArguments options "$@" || exit $?

    # Access parsed options
    local option1="${options[option1]}"
    local is_verbose="${options[verbose_mode]}"

    # Display section header
    SectionHeader "Script Operation"

    # Core script logic
    # ...

    SuccessMessage "Operation completed successfully."
    return 0
}

# Execution pattern
if IsExecutedDirectly || [[ "$0" == *"rc"* ]]; then
    main "$@"
    exit $? # Exit with status from main
fi
```

### Output and Formatting

#### Messaging
- Use predefined messaging functions:
  - `ErrorMessage()` for errors
  - `WarningMessage()` for warnings
  - `SuccessMessage()` for successful operations
  - `InfoMessage()` for informational output
  - `VerboseMessage()` for verbose-mode output

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

- Use sourced color constants from `utility-functions.sh` (which sources `shell-colors.sh`)
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

1. **Function Naming**

   - **General Rule:** Use **PascalCase** (e.g., `MyFunction`) for most functions defined within scripts (utilities, core scripts, rc-scripts), except for specific entry points like `main` or user-facing commands like `rc` which use lowercase.

    - **Library Function Distinction ("Public" vs. "Internal"):**
        Since Bash lacks formal public/private scope control, we use naming conventions within library files (`system/lib/`) to indicate intended usage:
        - **Public Library Functions (PascalCase):** Functions intended to be called directly by other scripts that `source` the library should follow the standard **PascalCase** convention (e.g., `InfoMessage`, `DetectShell`, `CommandExists`). These form the public API of the library.
        - **Internal Library Helpers (\_snake\_case):** Functions intended *only* for use by other functions *within the same library file* should use a leading underscore followed by **lowercase\_snake\_case** (e.g., `_extract_summary`, `_print_wrapped_message`). The leading underscore clearly signals that this function is an internal implementation detail and should generally not be called directly from outside the library file. This convention improves clarity about function scope and intended usage.

    - **Descriptive Names:** Regardless of convention, all function names should be descriptive about their purpose.

    - **Examples:**
        - `InstallDependencies()` (Local function in a utility script)
        - `SectionHeader()` (Public function defined in a library, called by utilities)
        - `_calculate_padding()` (Internal helper function within a library, called only by `SectionHeader`)
        - `_extract_summary()` (Internal helper function within `utility-functions.sh`)

2. **Function Structure**

   Restrict long comment lines to 72 characters and indent the following lines. See `Usage` in the example below.

   ```bash
   # end of previous logic (note single empty line after this one)

   # ============================================================================
   # Function: FunctionName
   # Description: Clear, concise description of what the function does
   # Usage: Demonstrate how to call the function [Optional, not required for
   #        simple implementations or if no arguments]
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

In rcForge v0.5.0, we adopt a pragmatic approach to functions vs. scripts:

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

# Include guard - don't load twice
if [[ -n "${_RCFORGE_UTILITY_LIB_SH_SOURCED:-}" ]]; then
    return 0
fi
_RCFORGE_UTILITY_LIB_SH_SOURCED=true

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
# RC Summary: One-line description for rc help display

# Source required libraries
source "${RCFORGE_LIB:-$HOME/.local/rcforge/system/lib}/utility-functions.sh"

# Set strict error handling
set -o nounset
set -o pipefail

# Global constants
[ -v gc_version ]  || readonly gc_version="${RCFORGE_VERSION:-0.5.0}"
[ -v gc_app_name ] || readonly gc_app_name="${RCFORGE_APP_NAME:-rcForge}"
readonly UTILITY_NAME="utility-name"

# Main logic
main() {
    # Process arguments
    # Execute functionality
    # Return result
}

# Execute main function if run directly or via rc command
if IsExecutedDirectly || [[ "$0" == *"rc"* ]]; then
    main "$@"
    exit $?
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
# RC Summary: One-line description for RC help display
# Author: Name
# Date: YYYY-MM-DD
# Version: 0.5.0
# Category: system/utility
# Description: More detailed explanation

# Source necessary libraries
source "${RCFORGE_LIB:-$HOME/.local/rcforge/system/lib}/utility-functions.sh"

# Set strict error handling
set -o nounset
set -o pipefail

# Global constants
[ -v gc_version ]  || readonly gc_version="${RCFORGE_VERSION:-0.5.0}"
[ -v gc_app_name ] || readonly gc_app_name="${RCFORGE_APP_NAME:-rcForge}"
readonly UTILITY_NAME="utility-name"

# ============================================================================
# Function: ShowHelp
# Description: Display detailed help information for this utility.
# Usage: ShowHelp
# Arguments: None
# Returns: None. Exits with status 0.
# ============================================================================
ShowHelp() {
    local script_name
    script_name=$(basename "$0")

    echo "${UTILITY_NAME} - ${gc_app_name} Utility (v${gc_version})"
    echo ""
    echo "Description:"
    echo "  Detailed utility description goes here."
    echo ""
    echo "Usage:"
    echo "  rc ${UTILITY_NAME} [options] <arguments>"
    echo "  ${script_name} [options] <arguments>"
    echo ""
    echo "Options:"
    echo "  --option1=VALUE    Description of option1"
    echo "  --option2          Description of option2"
    echo "  --verbose, -v      Enable verbose output"
    echo "  --help, -h         Show this help message"
    echo "  --summary          Show a one-line description (for rc help)"
    echo "  --version          Show version information"
    echo ""
    echo "Examples:"
    echo "  rc ${UTILITY_NAME} --option1=value example.com"
    echo "  rc ${UTILITY_NAME} --verbose /path/to/file"
    exit 0
}

# ============================================================================
# Function: ParseArguments
# Description: Parse command-line arguments for this utility.
# Usage: declare -A options; ParseArguments options "$@"
# Arguments:
#   $1 (required) - Reference to associative array for storing parsed options
#   $2+ (required) - Command line arguments to parse
# Returns: Populates associative array by reference. Returns 0 on success, 1 on error.
# ============================================================================
ParseArguments() {
    local -n options_ref="$1"
    shift

    # Ensure Bash 4.3+ for namerefs (-n)
    if [[ "${BASH_VERSINFO[0]}" -lt 4 || ( "${BASH_VERSINFO[0]}" -eq 4 && "${BASH_VERSINFO[1]}" -lt 3 ) ]]; then
        ErrorMessage "Internal Error: ParseArguments requires Bash 4.3+ for namerefs."
        return 1
    fi

    # Set default values
    options_ref["option1"]=""
    options_ref["verbose_mode"]=false

    # Process arguments
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
            --option1=*)
                options_ref["option1"]="${key#*=}"
                shift ;;
            --option1)
                shift
                if [[ -z "${1:-}" || "$1" == -* ]]; then
                    ErrorMessage "--option1 requires a value."
                    return 1
                fi
                options_ref["option1"]="$1"
                shift ;;
            -v|--verbose)
                options_ref["verbose_mode"]=true
                shift ;;
            --)
                shift # Move past --
                break # Stop processing options
                ;;
            -*)
                ErrorMessage "Unknown option: $key"
                return 1 ;;
            *)
                ErrorMessage "Unexpected argument: $key"
                return 1 ;;
        esac
    done

    return 0
}

# ============================================================================
# Function: main
# Description: Main execution logic.
# Usage: main "$@"
# Arguments:
#   $@ - Command line arguments
# Returns: 0 on success, 1 on failure.
# ============================================================================
main() {
    # Use associative array for options (requires Bash 4+)
    declare -A options
    # Parse arguments, exit if parser returns non-zero (error)
    ParseArguments options "$@" || exit $?

    # Access options from the array
    local option1="${options[option1]}"
    local is_verbose="${options[verbose_mode]}"

    # Display section header
    SectionHeader "rcForge ${UTILITY_NAME^} Utility"

    # Example verbose message
    VerboseMessage "$is_verbose" "Running with options: option1=${option1}, verbose=${is_verbose}"

    # Main implementation goes here
    # ...

    SuccessMessage "Operation completed successfully."
    return 0
}

# Script execution
if IsExecutedDirectly || [[ "$0" == *"rc"* ]]; then
    main "$@"
    exit $? # Exit with status from main
fi

# EOF
```

### Utility Template Usage

New for v0.5.0, rcForge provides a template utility script that should be used as the starting point for all new utilities. You can find this template at `~/.local/rcforge/docs/template-utility.sh`. When creating a new utility:

1. Copy the template to your destination directory:
   ```bash
   cp ~/.local/rcforge/docs/template-utility.sh ~/.local/rcforge/utils/my-utility.sh
   ```

2. Edit the template to implement your functionality, updating:
   - Script header (name, description, etc.)
   - `UTILITY_NAME` constant
   - `ShowHelp()` function content
   - `ParseArguments()` function logic
   - `main()` function implementation

3. Make it executable:
   ```bash
   chmod 700 ~/.local/rcforge/utils/my-utility.sh
   ```

### Standard Function Implementations

All utilities should implement these standard functions:

1. **ShowHelp()**: Display detailed help information.
   ```bash
   ShowHelp() {
       local script_name
       script_name=$(basename "$0")

       echo "${UTILITY_NAME} - rcForge Utility (v${gc_version})"
       # Help content...
       exit 0
   }
   ```

2. **ParseArguments()**: Parse command-line arguments.
   ```bash
   ParseArguments() {
       local -n options_ref="$1"; shift

       # Set defaults
       options_ref["option1"]=""
       options_ref["verbose_mode"]=false

       # Process arguments
       while [[ $# -gt 0 ]]; do
           # Argument handling...
       done

       return 0
   }
   ```

3. **main()**: Main execution logic.
   ```bash
   main() {
       declare -A options
       ParseArguments options "$@" || exit $?

       # Implementation...

       return 0
   }
   ```

These functions provide consistent behavior across all utilities. Additionally, commands should implement specialized functions as needed for their specific functionality.

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
source "${RCFORGE_LIB:-$HOME/.local/rcforge/system/lib}/utility-functions.sh"

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
if IsExecutedDirectly || [[ "$0" == *"rc"* ]]; then
    main "$@"
    exit $?
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
    if [[ -f "${RCFORGE_LOCAL_ROOT:-$HOME/.local/rcforge}/system/utils/utility_name.sh" ]]; then
        source "${RCFORGE_LOCAL_ROOT:-$HOME/.local/rcforge}/system/utils/utility_name.sh"
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

**Note:** Any variable referenced inside an exported function must itself be exported and should be set as such when first declared.

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

#### Application-Wide Constants

For application-wide constants like version and name:
- Use `RCFORGE_UPPERCASE_SNAKE_CASE` for exported variables
- Maintain a readonly global constant with `gc_` prefix for scripts requiring immutability
- Store these in the main loader script (`rcforge.sh`)

Example:
```bash
# In rcforge.sh
export RCFORGE_APP_NAME="rcForge"
export RCFORGE_VERSION="0.5.0"

# For local use in a script
[ -v gc_app_name ] || readonly gc_app_name="${RCFORGE_APP_NAME:-ENV_ERROR}"
[ -v gc_version ]  || readonly gc_version="${RCFORGE_VERSION:-ENV_ERROR}"
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

Each rc command utility should include:

1. **Inline Documentation**:
   - Header comment with utility name and description
   - `RC Summary` tag with one-line description for `rc help`
   - Function comments for significant functions

2. **Help Command Support**:
   - `ShowHelp()` function that displays comprehensive usage information
   - `ExtractSummary()` function provided by utility-functions.sh

3. **External Documentation** (when necessary):
   - Wiki documentation for complex utilities
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

1. Use `set -o pipefail` to catch errors in pipelines
2. Provide meaningful error messages
3. Use exit codes consistently
   - 0: Success
   - 1: General error
   - 2: Misuse of shell built-ins
   - 126: Command invoked cannot execute
   - 127: Command not found
   - 128+n: Fatal error signal "n"

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

### Control Structure Formatting

Consistent formatting of control structures like `if` statements and loops is crucial for readability.

**`if` Statements:**

Use the following multi-line format for `if`, `elif`, and `else` blocks. Place `then`, `else`, and `fi` on their own lines, indented at the same level as the corresponding `if` or `elif`. Indent the actions within each block.

```bash
if [[ condition ]]; then
    action_if_true
    another_action_if_true
elif [[ another_condition ]]; then
    action_if_elif_true
else
    action_if_all_false
fi
```

**Loops (`for`, `while`, `until`):**

Similarly, format loops with `do` and `done` on separate lines, aligned vertically. Indent the actions inside the loop body.

- **`for` loop:**

  ```
  for item in "${list[@]}"; do
      action_on_item
      another_action
  done
  ```

- **`while` loop:**

  ```
  while [[ condition ]]; do
      action_while_true
      another_action
  done
  ```

- **`until` loop:**

  ```
  until [[ condition ]]; do
      action_until_true
      another_action
  done
  ```

* **Step `for` loop:**

  * **C-style `for` loop**

  ```
  limit=5
  for (( i=0; i < limit; i++ )); do
      echo "Iteration number: $i"
      # Other actions within the loop
  done
  ```

  **Ranged `for` loop**

  ```
  limit=5
  for i in {1..5}; do
      echo "Iteration number: $i"
      # Other actions within the loop
  done
  ```

Adhering to this formatting ensures that the structure of the code is immediately clear, making it easier to follow the logic and maintain the scripts.

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

## XDG Compliance (v0.5.0+)

New in v0.5.0, rcForge follows the XDG Base Directory Specification for improved organization and compatibility.

### Directory Structure

rcForge v0.5.0 separates user configuration from system files:

```
~/.config/rcforge/          # User configuration
├── config/                 # Configuration files
│   └── path.conf           # PATH configuration
└── rc-scripts/             # Shell configuration scripts

~/.local/rcforge/           # System files
├── backups/                # Backup files
├── config/                 # System configuration
│   ├── api_key_settings    # API key storage
│   ├── bash-location       # Compliant Bash path
│   └── checksums/          # File checksums
├── rcforge.sh              # Main loader script
└── system/                 # System components
    ├── core/               # Core functionality
    ├── lib/                # Shared libraries
    └── utils/              # System utilities
```

### Path References

All scripts should use the following environment variables to reference directories:

- `$RCFORGE_CONFIG_ROOT` for ~/.config/rcforge
- `$RCFORGE_LOCAL_ROOT` for ~/.local/rcforge
- `$RCFORGE_SCRIPTS` for rc-scripts directory
- `$RCFORGE_CONFIG` for configuration directory
- `$RCFORGE_LIB` for libraries directory
- `$RCFORGE_UTILS` for system utilities
- `$RCFORGE_USER_UTILS` for user utilities

Example:
```bash
# Correct path references
source "${RCFORGE_LIB}/utility-functions.sh"
config_file="${RCFORGE_CONFIG}/my-config.conf"
script_dir="${RCFORGE_SCRIPTS}"

# Incorrect (hard-coded paths)
source "$HOME/.local/rcforge/system/lib/utility-functions.sh" # Bad: hard-coded
```

### Example Path Fallbacks

When sourcing libraries, use this pattern to support both old and new installations:

```bash
# Best practice for sourcing libraries with fallback
source "${RCFORGE_LIB:-$HOME/.local/rcforge/system/lib}/utility-functions.sh"
```

## Continuous Improvement

This style guide is a living document. Contributions and suggestions for improvement are welcome. When in doubt, prioritize readability, maintainability, and consistency.

The standards outlined here align with the v0.5.0 architecture and should be applied to all new development. Existing code should be updated to these standards when substantial modifications are made.

# EOF