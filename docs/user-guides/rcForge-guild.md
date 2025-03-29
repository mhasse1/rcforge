# rcForge Function Reference

This document serves as a reference for all the built-in functions available in the rcForge function packages.

## Table of Contents
- [PATH Management (050_global_common_path.sh)](#path-management)
- [Common Functions (300_global_common_functions.sh)](#common-functions)
- [Website Functions (310_global_common_website_functions.sh)](#website-functions)
- [Git Functions (320_global_common_git_functions.sh)](#git-functions)
- [System Functions (330_global_common_system_functions.sh)](#system-functions)

## PATH Management
From `050_global_common_path.sh`

This script provides intelligent PATH management by conditionally adding directories only if they exist. It prevents duplicate entries and maintains a clean, organized PATH.

Key features:
- Ensures essential system directories are in PATH
- Adds appropriate directories for Homebrew (Apple Silicon and Intel Macs)
- Configures Python development environment (pyenv, virtualenv)
- Sets up Node.js environment (nvm, Yarn)
- Adds Go paths when present
- Configures editor paths (VS Code, Sublime Text)
- Adds language-specific paths (Ruby gems, Python packages)

## Common Functions
From `300_global_common_functions.sh`

Comprehensive set of utility functions for everyday shell use.

| Function | Description |
|----------|-------------|
| `dirsize [dir]` | Show directory sizes, sorted by size |
| `ff <pattern>` | Find files with a pattern in the name |
| `fd <pattern>` | Find directories with a pattern in the name |
| `size_by_type [dir]` | List total size of each file type |
| `extract <file>` | Extract various archive formats |
| `mcd <dir>` | Create a directory and cd into it |
| `tmpd [prefix]` | Create a temporary directory and cd into it |
| `tgz <dir>` | Create a tarball from a directory |
| `update_system` | Update system packages (macOS, apt, dnf, pacman) |
| `weather [location]` | Check weather information |
| `httpserver [port]` | Start a HTTP server in the current directory |
| `fif <pattern>` | Find text in files |
| `genpass [length]` | Generate a random secure password |
| `isup <url>` | Check if a URL is up |
| `ts2date <timestamp>` | Convert a timestamp to human-readable date |
| `findbig [dir] [count]` | Find largest files/directories |
| `psg <pattern>` | Search for a process |
| `bak <file>` | Create a backup of a file with timestamp |
| `countdown [seconds]` | Set a timer with countdown |
| `calc <expression>` | Calculate a mathematical expression |
| `myips` | Show public and local IP addresses |
| `note [title]` | Create a simple markdown note |

## Website Functions
From `310_global_common_website_functions.sh`

Functions for website testing, domain management, and network diagnostics.

| Function | Description |
|----------|-------------|
| `dns <domain>` | Perform DNS lookup with fallbacks |
| `isup <url>` | Comprehensive website availability check |
| `domain_check <domain>` | Check domain availability for registration |
| `ssl_check <domain>` | Check SSL certificate expiration |
| `enhanced_traceroute <domain>` | Perform traceroute with extended information |
| `headers <url>` | Get detailed HTTP headers |
| `ping_test <host> [count]` | Perform ping test with statistics |

## Git Functions
From `320_global_common_git_functions.sh`

Advanced Git utilities to enhance your workflow and provide insights.

| Function | Description |
|----------|-------------|
| `git_clean_branches` | Clean up merged/deleted branches |
| `git_branch_status` | Show status of all branches compared to remote |
| `git_history [--local] [--author <name>]` | Interactive Git history viewing |
| `git_standup [--week] [author]` | Show your commits from the last day/week |
| `git_stats` | Show repository statistics |
| `git_patch [filename]` | Create a patch file for current changes |
| `git_url` | Get the GitHub/GitLab URL for current repository |
| `git_graph [--local]` | Show a simplified git log graph |
| `git_undo` | Undo the last commit but keep the changes |
| `git_file_history <file> [num_commits]` | View file changes in last N commits |

## System Functions
From `330_global_common_system_functions.sh`

System monitoring and information utilities.

| Function | Description |
|----------|-------------|
| `cpu_usage` | Show current CPU usage |
| `mem_usage` | Show current memory usage |
| `disk_alert [threshold] [disk]` | Set alerts for low disk space |
| `process_monitor <process> [interval]` | Watch a specific process |
| `system_load` | Show system load averages |
| `services_status` | Show running services |
| `open_ports` | Show all open ports |
| `system_temp` | System temperature sensors |
| `list_users` | List all users on the system |
| `watch_resources [interval]` | Watch system resources in real-time |
| `system_info` | Get system information |

## Using These Functions

## Deployment Path Structure

- User Configuration: `~/.config/rcforge/`
- System Installation Paths:
  - Linux/Debian: `/usr/share/rcforge/`
  - Homebrew: `$(brew --prefix)/share/rcforge/`
  - MacPorts: `/opt/local/share/rcforge/`

### Installation Methods

To use these functions, install the appropriate package files:

```bash
# Install a specific package
# Use your preferred installation path, e.g.:
cp <PROJECT_ROOT>/packages/300_global_common_functions.sh ~/.config/rcforge/scripts/

# Install all core packages
cp <PROJECT_ROOT>/packages/{050_global_common_path.sh,300_global_common_functions.sh,310_global_common_website_functions.sh} ~/.config/rcforge/scripts/
```

After installing, reload your shell configuration:

```bash
source ~/.bashrc  # For Bash
# or
source ~/.zshrc   # For Zsh
```

### Dynamic Path Detection

The installation scripts will attempt to detect the project root using:
1. `RCFORGE_ROOT` environment variable
2. Common predefined locations (e.g., `~/src/rcforge`, `~/Projects/rcforge`)
3. User prompt as a last resort

## Creating Your Own Function Packages

You can create your own function packages following the rcForge naming convention:

```
###_[hostname|global]_[environment]_[description].sh
```

For example:
```bash
# Create a custom function package for all machines and shells
mkdir -p ~/.config/rcforge/scripts
touch ~/.config/rcforge/scripts/400_global_common_my_functions.sh

# Edit with your favorite editor
vim ~/.config/rcforge/scripts/400_global_common_my_functions.sh
```

Make sure to make your scripts executable:
```bash
chmod +x ~/.config/rcforge/scripts/400_global_common_my_functions.sh
```

## Customizing Existing Functions

If you want to modify an existing function, you can copy the function package and edit it:

```bash
# Copy the common functions package
cp ~/.config/rcforge/scripts/300_global_common_functions.sh ~/.config/rcforge/scripts/301_global_common_my_functions.sh

# Edit with your favorite editor
vim ~/.config/rcforge/scripts/301_global_common_my_functions.sh
```

The script with the higher sequence number (301) will be loaded after the original (300), so your customized functions will take precedence.
