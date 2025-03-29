# rcForge Function Packages

rcForge comes with a collection of useful function packages that you can include in your configuration. These can be installed separately or together, depending on your needs.

## Deployment Path Structures

- ✅ Use `~/.config/rcforge/` for user-level configurations
- ✅ Use system paths: 
  - Linux/Debian: `/usr/share/rcforge/`
  - Homebrew: `$(brew --prefix)/share/rcforge/`
  - MacPorts: `/opt/local/share/rcforge/`

## Core Packages

### PATH Management (`050_global_common_path.sh`)

Smart PATH management that conditionally adds directories to your PATH if they exist. This prevents your PATH from becoming cluttered with non-existent directories and ensures the proper order of precedence.

Features:
- Automatically detects and configures Homebrew paths (both Intel and Apple Silicon Macs)
- Adds support for pyenv, nvm, Yarn, Go, and other development tools
- Configures language-specific paths (Python, Ruby, etc.)
- Adds editor paths (VS Code, Sublime Text)
- Prevents duplicate entries in your PATH

### Common Functions (`300_global_common_functions.sh`)

Essential utility functions for daily command-line use.

Functions include:
- `dirsize` - Show directory sizes, sorted by size
- `ff` - Find files with a pattern in the name
- `fd` - Find directories with a pattern in the name
- `extract` - Smart extraction for various archive formats
- `mcd` - Create a directory and cd into it
- `tmpd` - Create a temporary directory and cd into it
- `tgz` - Create a tarball from a directory
- `update_system` - Smart system updates (macOS, apt, dnf, pacman)
- `weather` - Check weather information
- `httpserver` - Start a simple HTTP server in the current directory
- `fif` - Find text in files
- `genpass` - Generate a random secure password
- `isup` - Check if a URL is up
- `ts2date` - Convert a timestamp to human-readable date
- `findbig` - Find largest files/directories
- `psg` - Search for a process

### Website & DNS Functions (`310_global_common_website_functions.sh`)

Advanced functions for website and domain management.

Functions include:
- `dns` - Simple DNS lookup with fallbacks to different commands
- `isup` - Comprehensive website availability checker
  - Handles different protocols
  - Shows HTTP status codes
  - Follows redirects
  - Performs DNS lookups
- `domain_check` - Check domain name availability for registration

## Installation Instructions

### Package Installation Paths

Choose the appropriate installation path based on your system:

1. User Configuration (Recommended):
   ```bash
   cp <package_source> ~/.config/rcforge/scripts/
   ```

2. System-wide Installation:
   ```bash
   # Linux/Debian
   sudo cp <package_source> /usr/share/rcforge/scripts/
   
   # Homebrew
   cp <package_source> $(brew --prefix)/share/rcforge/scripts/
   
   # MacPorts
   sudo cp <package_source> /opt/local/share/rcforge/scripts/
   ```

### Install Specific Packages

```bash
# Install a specific package (user configuration)
cp <PROJECT_ROOT>/packages/050_global_common_path.sh ~/.config/rcforge/scripts/

# Install core packages
cp <PROJECT_ROOT>/packages/{050_global_common_path.sh,300_global_common_functions.sh,310_global_common_website_functions.sh} ~/.config/rcforge/scripts/

# Install all packages 
cp <PROJECT_ROOT>/packages/*.sh ~/.config/rcforge/scripts/
```

### Development Paths

Suggested project root locations for development:
- `~/src/rcforge`
- `~/Projects/rcforge`
- `~/development/rcforge`

## Additional Function Packages

### Git Workflow Functions (`320_global_common_git_functions.sh`)

Enhance your Git workflow with advanced shortcuts and utilities.

Functions include:
- `git_clean_branches` - Remove local branches that have been merged
- `git_branch_status` - Show status of all branches compared to remote
- `git_history` - Interactive Git history viewing
- `git_standup` - Show your commits from the last day/week
- `git_stats` - Show repository statistics

### System Monitoring Functions (`330_global_common_system_functions.sh`)

Monitor system resources and health.

Functions include:
- `cpu_usage` - Show current CPU usage
- `mem_usage` - Show current memory usage
- `disk_alert` - Set alerts for low disk space
- `process_monitor` - Watch a specific process
- `system_load` - Show system load averages

### Docker Helper Functions (`340_global_common_docker_functions.sh`)

Simplify Docker container management.

Functions include:
- `docker_clean` - Remove unused containers and images
- `docker_stats` - Show container resource usage
- `docker_ips` - Show IP addresses of running containers
- `docker_exec` - Interactive shell to a container
- `docker_logs` - Enhanced container logs

### Network Diagnostic Functions (`350_global_common_network_functions.sh`)

Advanced network troubleshooting and information gathering.

Functions include:
- `port_check` - Check if a port is open
- `scan_network` - Scan local network for devices
- `show_interfaces` - Show all network interfaces
- `bandwidth_test` - Test internet bandwidth
- `trace_route` - Enhanced traceroute with hostname lookup

### Security Functions (`360_global_common_security_functions.sh`)

Enhance your security toolkit and workflow.

Functions include:
- `ssh_key_manage` - Manage SSH keys
- `encrypt_file` - Easily encrypt/decrypt files
- `secure_delete` - Securely delete files
- `password_gen` - Advanced password generator
- `hash_check` - Verify file integrity

## Creating Your Own Function Packages

Function packages should follow the rcForge naming convention:

```
###_[hostname|global]_[environment]_[description].sh
```

For a global function package available to both Bash and Zsh:
```
300_global_common_my_functions.sh
```

For a host-specific function package:
```
700_workstation_common_my_functions.sh
```

## Dynamic Path Detection

When loading function packages, the system will:
1. Check `RCFORGE_ROOT` environment variable
2. Search common predefined locations
3. Prompt the user as a last resort

## Contributing

Have useful functions to share? Consider contributing to the rcForge function package collection!
