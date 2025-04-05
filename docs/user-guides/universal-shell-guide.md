# rcForge - Universal Shell Configuration System
## Installation & User Guide

Welcome to rcForge! This guide will help you install, configure, and customize your shell environment across multiple machines while maintaining a clean, organized structure.

## Table of Contents
- [Overview](#overview)
- [Key Features](#key-features)
- [Installation](#installation)
- [File Naming Convention](#file-naming-convention)
- [Recommended Sequence Ranges](#recommended-sequence-ranges)
- [Creating Configuration Files](#creating-configuration-files)
- [Managing Conflicts](#managing-conflicts)
- [Verifying Checksums](#verifying-checksums)
- [Visualizing Your Configuration](#visualizing-your-configuration)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## System Requirements

rcForge requires:

- Bash 4.0 or higher
- Standard UNIX utilities (find, sort, etc.)
- `md5sum` or equivalent (for checksum verification)

The system has been tested on Linux and macOS but should work on any UNIX-like system with Bash installed, including modern Oracle Solaris.

### Notes on Dependencies

**Checksum Verification:** The system uses `md5sum` (Linux) or `md5` (macOS) for verifying checksums of RC files. If these utilities are not available on your system:

1. You can disable checksum verification by removing or commenting out the checksum verification call in `rcforge.sh`.
2. On systems without `md5sum`, a fallback to other checksum utilities (like `shasum`) can be configured in the `calculate_checksum()` function in `core/functions.sh`.

**For macOS users:** macOS uses `md5` instead of `md5sum`. The system automatically detects this and uses the appropriate command.

For systems where any dependencies are not available, please open an issue on the GitHub repository and we'd be happy to explore compatibility options.

## Overview

rcForge provides a unified approach to managing shell configurations across different machines and shell environments (Bash and Zsh). It uses a smart loading system based on sequence numbers, hostname detection, and shell type to ensure the right configurations are loaded in the right order.

## Key Features

- **Cross-shell compatibility**: Works with both Bash and Zsh
- **Machine-specific configurations**: Load configs based on hostname
- **Deterministic loading order**: Explicit sequence numbers
- **Conflict detection**: Automatically identifies and helps resolve loading conflicts
- **Version control friendly**: Keep all configs in a git repo, they'll only load on appropriate machines
- **Visual diagrams**: See your configuration's loading order
- **Checksum verification**: Detect unauthorized changes to your RC files

## Installation

### Prerequisites

- Bash or Zsh shell
- Git (optional, for version control)

### Step 1: Clone the Repository

```bash
# Clone from GitHub repository 
git clone https://github.com/mhasse1/rcforge.git ~/.config/rcforge
```

### Step 2: Run the Installation Script

```bash
# Execute the installation script
bash ~/.config/rcforge/utils/install-rcforge.sh
```

### Step 3: Update Your Shell RC Files

The installation script should have already updated your shell RC files, but you can verify by checking if these lines exist in your `.bashrc` and/or `.zshrc` file:

```bash
# Source the rcForge configuration
if [[ -f "$HOME/.config/rcforge/rcforge.sh" ]]; then
  source "$HOME/.config/rcforge/rcforge.sh"
fi
```

### Step 4: Create Initial Configuration Files

Create your configuration files in the `~/.config/rcforge/scripts` directory using the naming convention described below.

For example:

```bash
# Create a global common environment file
cat > ~/.config/rcforge/scripts/100_global_common_environment.sh << 'EOF'
#!/bin/bash
# Global environment variables
export EDITOR="vim"
export VISUAL="vim"
export TERM="xterm-256color"
EOF

# Create a global shell-specific configuration
cat > ~/.config/rcforge/scripts/300_global_bash_settings.sh << 'EOF'
#!/bin/bash
# Bash-specific settings (only loads in bash)
set -o vi
shopt -s histappend
shopt -s checkwinsize
EOF
```

### Step 5: Test Your Configuration

```bash
source ~/.bashrc  # or ~/.zshrc
```

### Package Installation

#### Debian/Ubuntu

```bash
# Install the package
sudo dpkg -i rcforge_0.2.1_all.deb
sudo apt install -f  # Resolve dependencies

# Add to your shell configuration
echo 'source "/usr/share/rcforge/rcforge.sh"' >> ~/.bashrc
```

#### macOS with Homebrew

```bash
# Install with Homebrew
brew tap mhasse1/rcforge
brew install rcforge

# Add to your shell configuration
echo 'source "$(brew --prefix)/share/rcforge/rcforge.sh"' >> ~/.zshrc
```

### Development Installation

If you're working on rcForge development:

```bash
# Clone to development directory
git clone https://github.com/mhasse1/rcforge.git ~/src/rcforge

# Use development mode
export RCFORGE_DEV=1
source ~/src/rcforge/rcforge.sh
```

## File Naming Convention

All configuration files follow this naming pattern:

```
###_[hostname|global]_[environment]_[description].sh
```

Where:
- `###`: Three-digit sequence number controlling load order (required)
- `[hostname|global]`: Either the hostname of a specific machine or "global" for all machines (required)
- `[environment]`: One of "common", "bash", or "zsh" (required)
- `[description]`: Brief description of the configuration purpose (required)

Examples:
- `050_global_common_path.sh` - PATH configuration for all machines and shells
- `300_global_bash_prompt.sh` - Bash prompt configuration for all machines
- `500_global_zsh_completion.sh` - Zsh completion settings for all machines
- `700_laptop_common_vpn.sh` - VPN settings only for the machine with hostname "laptop"
- `950_workstation_zsh_plugins.sh` - Zsh plugins only for the machine with hostname "workstation"

## Recommended Sequence Ranges

To maintain organization, we recommend using these sequence number ranges:

| Range | Purpose |
|-------|---------|
| 000-099 | Critical global common configurations (PATH, etc.) |
| 100-299 | Normal global common configurations (aliases, environment variables) |
| 300-499 | Global Bash-specific configurations |
| 500-699 | Global Zsh-specific configurations |
| 700-899 | Hostname-specific common configurations |
| 900-949 | Hostname-specific Bash configurations |
| 950-999 | Hostname-specific Zsh configurations |

## Creating Configuration Files

### Common Configurations (Both Shells)

```bash
cat > ~/.config/rcforge/scripts/100_global_common_aliases.sh << 'EOF'
#!/bin/bash
# Common aliases for all machines

# Navigation aliases
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."

# List directory aliases
alias ls="ls --color=auto"
alias ll="ls -la"
alias l.="ls -d .*"

# Grep with color
alias grep="grep --color=auto"
EOF
```

### Bash-Specific Configurations

```bash
cat > ~/.config/rcforge/scripts/300_global_bash_prompt.sh << 'EOF'
#!/bin/bash
# Bash prompt configuration

# Define colors
if [[ -x /usr/bin/tput ]] && tput setaf 1 &>/dev/null; then
  BLUE="\[\033[0;34m\]"
  GREEN="\[\033[0;32m\]"
  YELLOW="\[\033[0;33m\]"
  RESET="\[\033[0m\]"
else
  BLUE=""
  GREEN=""
  YELLOW=""
  RESET=""
fi

# Set prompt
PS1="\n${GREEN}\u@\h${RESET} ${BLUE}\w${RESET}\n\$ "
EOF
```

### Zsh-Specific Configurations

```bash
cat > ~/.config/rcforge/scripts/500_global_zsh_prompt.sh << 'EOF'
#!/bin/zsh
# Zsh prompt configuration

# Load colors
autoload -U colors && colors

# Set prompt
PROMPT='
%F{green}%n@%m%f %F{blue}%~%f
%# '
EOF
```

### Machine-Specific Configurations

```bash
# Replace "laptop" with your actual hostname
cat > ~/.config/rcforge/scripts/700_laptop_common_proxy.sh << 'EOF'
#!/bin/bash
# Proxy settings for laptop

export http_proxy="http://proxy.example.com:8080"
export https_proxy="http://proxy.example.com:8080"
export no_proxy="localhost,127.0.0.1,.example.com"
EOF
```

### Hostname Matching

For machine-specific configuration files to work correctly, the hostname in the filename must match the actual hostname of the machine. Here's how to ensure you're using the correct hostname:

1. **Check your current hostname**:
   ```bash
   # Most systems
   hostname
   
   # Or alternatively
   echo $HOSTNAME
   ```

2. **Use that exact hostname in your configuration files**:
   ```bash
   # If your hostname is "dev-server"
   700_dev-server_common_settings.sh
   ```

3. **Handling hostname inconsistencies**: If your hostname changes or is inconsistent across logins (FQDN vs. short name), you can override the detected hostname:
   ```bash
   # Create a hostname override file (make sure it loads early)
   cat > ~/.config/rcforge/scripts/001_global_common_hostname.sh << 'EOF'
   #!/bin/bash
   # Override hostname detection
   export current_hostname="dev-server"
   EOF
   ```

This ensures that the system will always use the hostname you specify regardless of what the system reports.

## Managing Conflicts

The system automatically checks for sequence number conflicts within the same execution path during startup. If conflicts are found, you'll see a warning message.

### Checking for Conflicts Manually

```bash
~/.config/rcforge/utils/check-seq.sh
```

### Fixing Conflicts Interactively

```bash
~/.config/rcforge/utils/check-seq.sh --fix
```

### Checking All Possible Execution Paths

```bash
~/.config/rcforge/utils/check-seq.sh --all
```

## Verifying Checksums

The system monitors changes to your `.bashrc` and `.zshrc` files to detect unauthorized modifications. If changes are detected, you'll see a warning.

### Checking Checksums Manually

```bash
~/.config/rcforge/utils/check-checksums.sh
```

### Updating Checksums After Changes

```bash
~/.config/rcforge/utils/check-checksums.sh --fix
```

## Visualizing Your Configuration

Generate a diagram showing your configuration's loading order:

```bash
~/.config/rcforge/utils/diagram-config.sh
```

This creates a diagram in `~/.config/rcforge/docs/loading_order_diagram.md` that you can view with any Markdown viewer.

## Using the Include System

rcForge v0.2.1+ includes a modular function system that lets you include only the functions you need:

```bash
# Include specific functions
include_function path add_to_path
include_function common is_macos

# Include all functions in a category
include_category common

# Use the included functions
add_to_path "$HOME/bin"
is_macos && echo "Running on macOS"
```

For more information on the include system, see [docs/README-includes.md](README-includes.md).

## Exporting Configurations for Remote Servers

When working with remote servers, you might not want to set up the full configuration system. The `export-config.sh` script allows you to compile all applicable configuration files into a single file that can be transferred to a remote server.

### Basic Usage

```bash
# Export Bash configuration for the current hostname
~/.config/rcforge/utils/export-config.sh --shell=bash

# Export Zsh configuration for a specific hostname
~/.config/rcforge/utils/export-config.sh --shell=zsh --hostname=workstation
```

### Advanced Options

```bash
# Export to a specific location
~/.config/rcforge/utils/export-config.sh --shell=bash --output=~/my-bashrc

# Keep debug statements in the exported file
~/.config/rcforge/utils/export-config.sh --shell=bash --keep-debug

# Remove comments from the exported file
~/.config/rcforge/utils/export-config.sh --shell=bash --no-comments
```

### Transferring to Remote Servers

```bash
# Export and transfer in one command
~/.config/rcforge/utils/export-config.sh --shell=bash && scp ~/.config/rcforge/exports/$(hostname)_bashrc user@server:~/.bashrc

# For temporary use on a remote server
~/.config/rcforge/utils/export-config.sh --shell=bash && scp ~/.config/rcforge/exports/$(hostname)_bashrc user@server:~/ && ssh user@server "source ~/$(hostname)_bashrc"
```

This export functionality is particularly useful for:
- Servers where you want a simplified configuration
- Systems where you need a single file rather than the full modular system
- Quickly copying your configuration to new machines
- Debugging and reviewing your full configuration

## Directory Structure

rcForge uses the following directory structure:

```
~/.config/rcforge/            # User installation
  ├── scripts/                # Your shell configuration scripts
  ├── include/                # Your custom include functions
  ├── rcforge.sh              # Main loader script
  ├── exports/                # Exported configurations for remote servers
  └── docs/                   # Documentation

/usr/share/rcforge/           # System installation (package-based)
  ├── core/                   # Core functionality
  ├── utils/                  # Utility scripts
  ├── src/                    # Source code
  │   └── lib/                # Libraries
  ├── include/                # System include functions
  └── rcforge.sh              # Main loader script

~/src/rcforge/                # Development repository
  ├── scripts/                # Example scripts
  ├── core/                   # Core functionality
  ├── utils/                  # Utility scripts
  ├── src/                    # Source code
  ├── include/                # Include functions
  └── ...                     # Other development files
```

## Best Practices

1. **Use descriptive names**: Make the purpose of each file clear in its filename
2. **Follow sequence ranges**: Stick to the recommended sequence number ranges
3. **Version control**: Keep your configurations in a git repository
4. **Keep files focused**: Each file should do one thing and do it well
5. **Machine-specific vs global**: Only use machine-specific configurations when necessary
6. **Add comments**: Document why you're setting particular configurations
7. **Check for conflicts**: Run the conflict checker after adding new files
8. **Shell-specific code**: Avoid using bash-specific features in common files

## Handling Headless vs. GUI Linux Configurations

When managing configurations across multiple Linux systems, you'll typically have:
- Many headless servers (no GUI)
- A few GUI workstations/laptops

### Recommended Approach

1. **Create your baseline Linux configurations as global**:
   ```
   100_global_common_environment.sh  # Environment variables for all systems
   300_global_bash_settings.sh       # Bash settings for all systems 
   500_global_zsh_settings.sh        # Zsh settings for all systems
   ```

2. **Add GUI-specific configurations as hostname-specific**:
   ```
   750_workstation_common_xresources.sh  # X11 resources configuration
   760_workstation_common_gui_tools.sh   # GUI-specific tools/environment
   960_workstation_zsh_gui_plugins.sh    # GUI-specific Zsh plugins
   ```

3. **If you have multiple GUI systems with identical needs**, use symbolic links:
   ```bash
   # Create the configuration once
   vim ~/.config/rcforge/scripts/750_workstation_common_xresources.sh
   
   # Link it for another hostname
   ln -s ~/.config/rcforge/scripts/750_workstation_common_xresources.sh \
         ~/.config/rcforge/scripts/750_laptop_common_xresources.sh
   ```

### Example GUI-Specific Configuration

Here's what a GUI-specific configuration might include:

```bash
#!/bin/bash
# 750_workstation_common_gui_tools.sh

# Only run these configurations if a display is available
if [[ -n "$DISPLAY" ]]; then
  # Set GUI-specific environment variables
  export GDK_SCALE=1.5
  export QT_SCALE_FACTOR=1.5
  
  # Add GUI application directories to PATH
  append_to_path "$HOME/.local/share/applications"
  
  # Set up X resources if file exists
  if [[ -f "$HOME/.Xresources" ]]; then
    xrdb -merge "$HOME/.Xresources"
  fi
  
  # GUI specific aliases
  alias open="xdg-open"
  alias pbcopy="xclip -selection clipboard"
  alias pbpaste="xclip -selection clipboard -o"
fi
```

### Check for GUI Before Running Commands

A key practice for GUI configurations is to always check for the presence of a display or GUI environment before running GUI-related commands:

```bash
# Check for display
if [[ -n "$DISPLAY" ]]; then
  # GUI-specific commands here
fi
```

## Troubleshooting

### Configuration Not Loading

1. Check if your RC file is sourcing `rcforge.sh`
2. Ensure file permissions are correct: `chmod +x ~/.config/rcforge/*.sh`
3. Enable debug mode: `SHELL_DEBUG=1 source ~/.bashrc`

### Sequence Conflicts

Run `~/.config/rcforge/utils/check-seq.sh --fix` to resolve conflicts interactively.

### Wrong Hostname Detection

If your hostname is detected incorrectly, you can:

1. Create a file that exports the correct hostname:
   ```bash
   echo 'export current_hostname="your-hostname"' > ~/.config/rcforge/scripts/001_global_common_hostname.sh
   ```

### WSL-Specific Issues

#### File Permission Problems

If your scripts lose execute permissions:

```bash
# Fix permissions
find ~/.config/rcforge -type f -name "*.sh" -exec chmod +x {} \;
```

#### Line Ending Issues

If you see errors like `bad interpreter` or `\r command not found`:

```bash
# Install dos2unix if needed
sudo apt install dos2unix

# Convert all scripts
find ~/.config/rcforge -type f -name "*.sh" -exec dos2unix {} \;
```

### Performance Issues

If your shell startup is slow:

1. Check which files might be causing the delay with `SHELL_DEBUG=1 source ~/.bashrc`
2. Consider consolidating multiple small files into larger files
3. Ensure that any commands that run external processes (like `curl` or `grep`) are necessary at startup

---

By following this guide, you should have a clean, organized, and maintainable shell configuration system that works across multiple machines and shell environments. Enjoy your new streamlined shell experience with rcForge!