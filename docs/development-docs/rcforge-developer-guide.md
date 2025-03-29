# rcForge Developer's Guide

Welcome to the rcForge Developer's Guide! This document is designed for shell script authors who want to create custom configuration files that integrate with the rcForge system.

## Table of Contents

- [Introduction](#introduction)
- [Development Environment](#development-environment)
- [Script Naming Convention](#script-naming-convention)
- [Script Structure](#script-structure)
- [Available Functions](#available-functions)
- [Debugging Tips](#debugging-tips)
- [Best Practices](#best-practices)
- [Examples](#examples)
- [Advanced Topics](#advanced-topics)

## Introduction

rcForge is a modular shell configuration system that allows you to organize your shell configurations across multiple machines and shell types. When developing scripts for rcForge, you'll have access to shared functions that handle common tasks like:

- Shell detection
- File sourcing
- Path manipulation
- Debugging
- OS detection
- And more!

This guide will show you how to create scripts that leverage these functions to build robust shell configurations.

## Development Environment

As a developer working on rcForge itself, you'll want to use the development environment setup:

1. **Clone the repository to the development location**:
   ```bash
   git clone https://github.com/mhasse1/rcforge.git ~/src/rcforge
   ```

2. **Set development mode to use the repo directly**:
   ```bash
   export RCFORGE_DEV=1
   source ~/src/rcforge/rcforge.sh
   ```

3. **Directory Structure**:
   ```
   ~/src/rcforge/                # Development repository
     ├── scripts/                # Example scripts
     ├── core/                   # Core functionality
     ├── utils/                  # Utility scripts
     ├── src/                    # Source code
     │   └── lib/                # Libraries
     ├── include/                # Include system functions
     ├── docs/                   # Documentation
     └── ...                     # Other development files
   ```

When `RCFORGE_DEV=1` is set, rcForge will load directly from this repository instead of the user or system installation.

## Script Naming Convention

All rcForge files follow this naming convention:

```
### Checksums

```bash
# Calculate checksum of a file
checksum=$(calculate_checksum "$HOME/.bashrc")
echo "Checksum: $checksum"

# Verify checksum of an RC file
verify_checksum "$HOME/.bashrc" "$HOME/.config/rcforge/checksums/bashrc.md5" ".bashrc"
```

## Debugging Tips

When developing your scripts, these techniques can help with debugging:

1. **Enable debug mode**:
   ```bash
   SHELL_DEBUG=1 source ~/.bashrc
   ```

2. **Isolate problematic scripts**:
   If your configuration isn't working as expected, try temporarily renaming scripts to change their loading order or disable them.

3. **Use debug_echo liberally**:
   Add debug_echo statements to track the flow of your script:
   ```bash
   debug_echo "Value of variable: $variable"
   ```

4. **Check for conflicts**:
   Run the conflict checker to ensure your new script doesn't conflict with existing ones:
   ```bash
   ~/src/rcforge/utils/check-seq.sh
   ```

5. **Develop in dev mode**:
   When working on rcForge itself, use the development mode:
   ```bash
   export RCFORGE_DEV=1
   source ~/src/rcforge/rcforge.sh
   ```

## Best Practices

1. **Keep scripts focused**: Each script should do one thing and do it well.

2. **Check environment before making changes**:
   ```bash
   # Only set up X11 if a display is available
   if [[ -n "$DISPLAY" ]]; then
     # X11 configuration here
   fi
   ```

3. **Use conditionals for shell-specific code in common files**:
   ```bash
   if shell_is_bash; then
     # Bash-specific code
   elif shell_is_zsh; then
     # Zsh-specific code
   fi
   ```

4. **Set defaults wisely**:
   ```bash
   # Set default editor based on what's available
   if cmd_exists vim; then
     export EDITOR="vim"
     export VISUAL="vim"
   elif cmd_exists nano; then
     export EDITOR="nano"
     export VISUAL="nano"
   fi
   ```

5. **Use descriptive comments**: Help others (and your future self) understand your configuration.

6. **Add error handling for critical operations**:
   ```bash
   if ! cmd_exists aws; then
     warn_echo "AWS CLI not found. Cloud functions will be unavailable."
   fi
   ```

7. **Structure your repository properly**:
   ```
   ~/src/rcforge/
     ├── scripts/           # Example configuration scripts
     ├── core/              # Core functions and utilities
     ├── utils/             # Utility scripts
     ├── src/               # Source code
     │   └── lib/           # Libraries (include system, etc.)
     ├── include/           # Include functions
     └── docs/              # Documentation
   ```

## Examples

### Basic Environment Configuration

```bash
#!/bin/bash
# 100_global_common_environment.sh - Basic environment variables

# Include required functions
include_function common is_macos
include_function common is_linux

# Set language and locale
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# Set default editors based on availability
if cmd_exists vim; then
  debug_echo "Setting vim as default editor"
  export EDITOR="vim"
  export VISUAL="vim"
elif cmd_exists nano; then
  debug_echo "Setting nano as default editor"
  export EDITOR="nano"
  export VISUAL="nano"
fi

# Set history size
export HISTSIZE=10000
export HISTFILESIZE=10000

debug_echo "Environment configuration complete"
```

### Hostname-Specific Configuration

```bash
#!/bin/bash
# 700_workstation_common_dev_tools.sh - Development environment for workstation

# Only configure if this is the right hostname
if [[ "$current_hostname" != "workstation" ]]; then
  debug_echo "Skipping workstation dev configuration on $current_hostname"
  return 0
fi

# Include required functions
include_function path add_to_path
include_function path append_to_path

debug_echo "Setting up development environment for workstation"

# Set up development directories
if [[ ! -d "$HOME/Projects" ]]; then
  mkdir -p "$HOME/Projects"
  debug_echo "Created Projects directory"
fi

# Add development tools to path
add_to_path "$HOME/.cargo/bin"  # Rust
add_to_path "$HOME/.local/share/go/bin"  # Go

# Configure development aliases
alias cdev="cd $HOME/Projects"
alias gst="git status"
alias gl="git log --oneline --graph --decorate --all"

# Set up environment variables for development tools
export GOPATH="$HOME/.local/share/go"
export RUSTUP_HOME="$HOME/.rustup"
export CARGO_HOME="$HOME/.cargo"

debug_echo "Development environment configured"
```

### Shell-Specific Configuration

```bash
#!/bin/bash
# 300_global_bash_keybindings.sh - Bash-specific key bindings

# Only configure if this is bash
if ! shell_is_bash; then
  debug_echo "Skipping bash key bindings in non-bash shell"
  return 0
fi

debug_echo "Setting up bash key bindings"

# Set vi mode
set -o vi

# Better history searching
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'

# Ctrl+L to clear screen (default but explicitly set)
bind -m vi-insert "\C-l":clear-screen

debug_echo "Bash key bindings configured"
```

## Advanced Topics

### Creating Dynamic Configurations

Sometimes you need to generate configuration dynamically. Here's how:

```bash
#!/bin/bash
# 150_global_common_dynamic_config.sh - Dynamically generated configuration

# Include required functions
include_function common is_macos
include_function common is_linux

# Generate configuration based on system properties
if is_macos; then
  # Get macOS version
  mac_version=$(sw_vers -productVersion)
  debug_echo "Detected macOS version: $mac_version"
  
  # Configure differently based on macOS version
  if [[ "$mac_version" > "10.15" ]]; then
    # Newer macOS-specific settings
    export MACOS_MODERN=1
  else
    # Older macOS-specific settings
    export MACOS_LEGACY=1
  fi
elif is_linux; then
  # Get Linux distribution
  if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    debug_echo "Detected Linux distribution: $NAME $VERSION_ID"
    
    case "$ID" in
      ubuntu|debian)
        export LINUX_DEB_BASED=1
        ;;
      fedora|centos|rhel)
        export LINUX_RPM_BASED=1
        ;;
    esac
  fi
fi

debug_echo "Dynamic configuration complete"
```

### Creating Helper Scripts for Other Scripts

You can create helper scripts that provide functions for use in other scripts:

```bash
#!/bin/bash
# 010_global_common_helpers.sh - Helper functions for other scripts

# Define helper functions
get_git_branch() {
  git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}

get_python_virtualenv() {
  if [[ -n "$VIRTUAL_ENV" ]]; then
    echo " ($(basename "$VIRTUAL_ENV"))"
  fi
}

is_ssh_session() {
  [[ -n "$SSH_CLIENT" || -n "$SSH_TTY" ]]
}

debug_echo "Helper functions defined"
```

### Timing Your Scripts

If you have slow-loading scripts, you can add timing:

```bash
#!/bin/bash
# 200_global_common_slow_operation.sh - Configuration that might be slow

debug_echo "Starting potentially slow operation"
start_time=$(date +%s.%N)

# Potentially slow operation here
sleep 1  # Simulating slow operation

end_time=$(date +%s.%N)
elapsed=$(echo "$end_time - $start_time" | bc)
debug_echo "Slow operation completed in $elapsed seconds"
```

---

I hope this developer's guide helps you create robust and effective scripts for the rcForge system! Remember, the goal is to create modular, focused configurations that are easy to maintain and work across different environments.

Happy scripting!_[hostname|global]_[environment]_[description].sh
```

Where:
- `###`: Three-digit sequence number controlling load order (required)
- `[hostname|global]`: Either the hostname of a specific machine or "global" for all machines (required)
- `[environment]`: One of "common", "bash", or "zsh" (required)
- `[description]`: Brief description of the configuration purpose (required)

Examples:
- `050_global_common_path.sh` - PATH configuration for all machines and shells
- `300_global_bash_prompt.sh` - Bash prompt configuration for all machines
- `700_laptop_common_vpn.sh` - VPN settings only for the machine with hostname "laptop"

## Script Structure

Here's a recommended structure for your rcForge files:

```bash
#!/bin/bash
# Brief description of what this script does
# Author: Your Name
# Date: YYYY-MM-DD

# Include required functions
include_function common is_macos
include_function path add_to_path

# Local function definitions (if needed)
local_function() {
  # Function code here
}

# Main configuration code
# ...

# If needed, show debug information
debug_echo "Configured something: $variable"
```

## Available Functions

The rcForge system provides a rich set of utility functions you can use in your scripts. Here are the key functions:

### Shell Detection

```bash
# Returns the detected shell name ("bash" or "zsh")
echo $shell_name

# Returns true if current shell is bash
shell_is_bash && echo "Running in Bash"

# Returns true if current shell is zsh
shell_is_zsh && echo "Running in Zsh"

# Checks if a command exists
cmd_exists git && echo "Git is installed"
```

### Debugging

```bash
# Print a debug message (only visible when SHELL_DEBUG=1)
debug_echo "Setting up environment variables"

# Toggle debug tracing on/off (only when SHELL_DEBUG=1)
toggle_debug_trace on  # Turn on bash -x tracing
# Complex code here
toggle_debug_trace off  # Turn off tracing

# Display a warning message with an attention-grabbing header
warn_echo "Missing required configuration file"
```

### OS Detection

```bash
# Check for macOS
if is_macos; then
  # macOS-specific configuration
fi

# Check for Linux
if is_linux; then
  # Linux-specific configuration
fi

# Check for Windows (WSL or Git Bash)
if is_windows; then
  # Windows/WSL-specific configuration
fi
```

### Path Management

```bash
# Add a directory to the beginning of PATH (if it exists and isn't already there)
add_to_path "$HOME/bin"

# Add a directory to the end of PATH (if it exists and isn't already there)
append_to_path "$HOME/.local/bin"

# Display the current PATH in a readable format
show_path
```

### File Operations

```bash
# Source a file if it exists
source_file "$HOME/.config/custom/settings.sh" "Custom settings"

# Source multiple files matching a pattern
source_files "$HOME/.config/custom" "*.sh" "Custom scripts"
```

### Include System (v2.0.0+)

```bash
# Include a specific function from a category
include_function path add_to_path
include_function common is_macos

# Include all functions in a category
include_category common

# List all available functions
list_available_functions
```

###