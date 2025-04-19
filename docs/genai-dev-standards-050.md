# rcForge GenAi Development Standards

## 1. Introduction

This document provides comprehensive guidelines for AI assistants contributing to the rcForge project. These standards ensure consistent, maintainable, and high-quality code that aligns with the project's architecture and philosophy.

AI assistants should use these guidelines when:
- Writing or modifying code for rcForge
- Generating documentation
- Providing design recommendations
- Troubleshooting issues

These standards apply to rcForge v0.5.0 and later versions, which use the XDG-compliant directory structure.

## 2. Project Overview

- **Name**: rcForge
- **Current Version**: 0.5.0
- **Repository**: GitHub repository (mhasse1/rcforge)
- **Architecture**: User-centric design with XDG-compliant directory structure
- **Purpose**: Modular, maintainable shell configuration management system for Bash and Zsh environments
- **Target Platforms**: Unix-like systems including Linux and macOS

rcForge helps users transform shell configuration chaos into a robust, organized, and portable setup, making it easy to maintain consistent shell environments across multiple machines.

## 3. Technical Requirements

### Core System Requirements
- **Bash Version**: 4.3 or higher for core system functions
  - All shebangs use `#!/usr/bin/env bash` for cross-platform compatibility
  - macOS users will need to install modern Bash via Homebrew or MacPorts
  - The core system checks Bash version compatibility at runtime

### End User Support
- Both Bash and Zsh are supported as equal first-class citizens
- Configuration scripts can be shell-specific or common to both
- System adapts to user's active shell environment

### Directory Structure (XDG-Compliant)
- **Configuration files**: Located in `${XDG_CONFIG_HOME:-$HOME/.config}/rcforge/`
  - Contains `rc-scripts/` and `config/` directories
- **Program data files**: Located in `${XDG_DATA_HOME:-$HOME/.local/share}/rcforge/`
  - Contains `system/`, `backups/`, `utils/`, `rcforge.sh`, and other program data

## 4. AI-Specific Development Protocols

### Critical File Location Verification

Before modifying ANY existing file:
1. First check the file in the uploaded documents list
2. Cross-reference with the file structure information
3. Explicitly confirm the full path when suggesting changes

**ALWAYS** specify the complete path when suggesting modifications, using XDG environment variables where appropriate.

**NEVER** suggest structural changes without explicit discussion - highlight these as separate recommendations and obtain approval before implementing.

**NEVER** assume standard locations or make undocumented structural changes.

**ALWAYS** use `${XDG_CONFIG_HOME:-$HOME/.config}/rcforge/` and `${XDG_DATA_HOME:-$HOME/.local/share}/rcforge/` rather than hardcoded paths.

### Discussion-First Approach

- Begin with exploring design approaches and considerations
- Evaluate tradeoffs between potential solutions
- Reach agreement on design direction before coding
- Confirm understanding of requirements, even for direct code requests
- Consider user-override implications for any system utilities

## 5. Code Development Standards

### RC Scripts Development
- Follow the sequence-based naming convention:
  ```
  ###_[hostname|global]_[environment]_[description].sh
  ```
- Valid `[environment]` values:
  - `common`: Works in both Bash and Zsh
  - `bash`: Bash-specific scripts
  - `zsh`: Zsh-specific scripts
- Respect the sequence number ranges for appropriate functionality
- Place all RC scripts in `${XDG_CONFIG_HOME:-$HOME/.config}/rcforge/rc-scripts/`

### RC Command Utilities
- All utilities must support the RC command interface:
  - `help` subcommand displays detailed usage information
  - `summary` subcommand returns a one-line description
- Include clear documentation with examples
- Support user override by avoiding hardcoded paths
- Design with modularity in mind
- Place system utilities in `${XDG_DATA_HOME:-$HOME/.local/share}/rcforge/system/utils/`
- Place user utilities in `${XDG_DATA_HOME:-$HOME/.local/share}/rcforge/utils/`

### Function vs. Scripts Approach
- Use the pragmatic approach:
  - Standalone scripts for complete RC utilities
  - Source-able libraries for shared functionality
  - Functions when maintaining state is important
- Implement lazy loading patterns for performance-critical components

## 6. Implementation Guidelines for AI

### Code Quality Standards
- Provide exact line numbers when suggesting code snippets
- Write code from a Unix systems developer perspective
- Create documentation with technical writing expertise
- Test all utilities and scripts in both Bash and Zsh environments
- Ensure all utilities check for and handle error conditions gracefully

### Security Considerations
- Avoid using or suggesting root-level operations
- Maintain strict file permissions:
  - 700 for directories
  - 700 for scripts
  - 600 for configs
- Verify secure handling of user input in all utilities
- Implement appropriate input validation

### Testing Requirements
- Test RC scripts in both Bash and Zsh environments
- Verify lazy loading functionality works as expected
- Test user override capability for utilities
- Ensure all utilities function properly through the RC command interface
- Validate sequence-based loading works as expected

## 7. Documentation Standards

- Create clear, concise help documentation for all utilities
- Include practical examples in all help text
- Ensure documentation follows markdown standards
- Add appropriate source comments
- Update documentation when implementing changes
- Ensure all RC command utilities have proper summary text for `rc help`

### Standard Header Format
```bash
#!/usr/bin/env bash
# filename.sh - Short utility description
# Author: Author Name
# Date: YYYY-MM-DD
# Version: 0.5.0 # Version should match current rcForge version
# Category: system/utility or user/utility
# RC Summary: One-line description for RC help display
# Description: More detailed explanation of what this utility does
```

## 8. Common Patterns and Templates

### Reset of rcForge Environment

`lib/set-rcforge-environment.sh` has been added to `system/lib`. This file detects and resets the rcForge environment. Both `rcforge.sh` and `utility-functions.sh` source this library on launch. These environment variables are a **requirement** of using rcForge, and scripts should fail if one or more of these enironment variables are needed by the script and missing.

### Cross-Shell Compatibility Philosophy

The rcForge project prioritizes simplicity and cross-shell compatibility. Always prefer simple, universal solutions over shell-specific implementations.

**Guiding Principles:**
1. Prefer POSIX-compatible features when possible
2. Implement universal approaches first
3. Only use shell-specific features when absolutely necessary
4. Avoid unnecessary branching by shell type

**Preferred Pattern Example - Processing Files:**
```bash
# Universal approach using while loop
while IFS= read -r file; do
    # Process file safely here
    echo "Processing: $file"
done < <(find /path/to/dir -type f -name "*.sh")
```

**Anti-Pattern to Avoid - Shell-Specific Branching:**
```bash
# Unnecessarily complex shell-specific implementation
if IsZsh; then
    config_files=( ${(f)find_cmd_output} ) # Zsh-specific
elif IsBash; then
    mapfile -t config_files <<< "$find_cmd_output" # Bash-specific
else
    # Fallback (may break with spaces/newlines)
    config_files=( $(echo "$find_cmd_output") )
fi
```

### Standard Function Template

```bash
# ============================================================================
# Function: FunctionName
# Description: Brief description of what the function does.
# Usage: FunctionName arg1 arg2
# Arguments:
#   $1 (required) - Description of first argument
#   $2 (optional) - Description of second argument
# Returns: Description of return value or exit code
# ============================================================================
FunctionName() {
    local arg1="$1"
    local arg2="${2:-default_value}" # With default value

    # Function logic here

    return 0 # Success
}
```

### RC Command Integration

```bash
# Execute main function if run directly or via rc command wrapper
if IsExecutedDirectly || [[ "$0" == *"rc"* ]]; then
    main "$@"
    exit $? # Exit with status from main
fi
```

## 9. Artifact Generation Best Practices

### File Generation Requirements
- Request permission before generating any files
- Confirm complete generation of all files
- Explicitly identify any incomplete file generations
- Add "EOF" comment at the end of every file to verify completeness
- Validate conformance to the rc-scripts naming convention for configuration files

### Standard Permission Settings
```bash
# For directories
chmod 700 "$directory_path"

# For executable scripts
chmod 700 "$script_path"

# For configuration files
chmod 600 "$config_path"

# Example with explicit XDG paths
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/rcforge/rc-scripts"
chmod 700 "${XDG_CONFIG_HOME:-$HOME/.config}/rcforge/rc-scripts"

mkdir -p "${XDG_DATA_HOME:-$HOME/.local/share}/rcforge/utils"
chmod 700 "${XDG_DATA_HOME:-$HOME/.local/share}/rcforge/utils"
```

## 10. Change Management Guidelines

### Suggesting Improvements
- Clearly separate bug fixes from enhancements
- Indicate potential compatibility impacts
- For major changes:
  1. First explain the current approach
  2. Describe proposed changes
  3. Highlight benefits and potential issues
  4. Recommend implementation strategy

### Backward Compatibility
- Ensure new features degrade gracefully on older systems
- Provide appropriate version checks where needed
- Recommend incremental refactoring paths for breaking changes

### Update Notifications
- For feature additions, indicate documentation that needs updating
- Suggest version number changes based on semantic versioning principles
- Recommend changelog entries