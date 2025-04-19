# rcForge Files: Structure Guide (v0.5.0)

This document outlines the file structure of rcForge v0.5.0, providing a clear reference for developers and users.

## Project Overview

rcForge v0.5.0 introduces a significant architectural improvement by adopting the XDG Base Directory Specification. This change makes rcForge more compliant with modern Unix/Linux standards and improves organization by separating configuration from program data.

Key components:
1. **Config Files** - User-specific configuration in `~/.config/rcforge/`
2. **Program Data** - Application files in `~/.local/share/rcforge/`
3. **RC Scripts** - Shell configuration scripts in `~/.config/rcforge/rc-scripts/`
4. **System Scripts** - Core functionality in `~/.local/share/rcforge/system/`
5. **User Utilities** - Custom user scripts in `~/.local/share/rcforge/utils/`

## Technical Requirements

- **Core System**: Requires Bash 4.3 or higher
  - macOS users will need to install modern Bash via Homebrew or MacPorts
  - All system scripts use `#!/usr/bin/env bash` for cross-platform compatibility
- **End User Support**:
  - Both Bash and Zsh are supported as equal first-class citizens
  - RC scripts can be shell-specific (bash/zsh) or common to both
  - Configuration loading adapts to the user's active shell

## Directory Structure

### XDG-Compliant Layout (v0.5.0+)

```
${XDG_CONFIG_HOME:-$HOME/.config}/rcforge/
├── config/                         # User configuration files
│   ├── api_keys.conf               # API keys configuration
│   ├── path.conf                   # PATH configuration
│   └── checksums/                  # Configuration file checksums
└── rc-scripts/                     # User shell configuration scripts
    ├── 050_global_common_path.sh   # Example sequenced rc-script
    ├── 210_global_bash_config.sh   # Bash-specific config
    ├── 210_global_zsh_config.sh    # Zsh-specific config
    └── ...                         # Additional user scripts

${XDG_DATA_HOME:-$HOME/.local/share}/rcforge/
├── backups/                        # Automated backups
├── config/                         # System configuration
│   ├── bash-location               # Path to Bash 4.3+
│   └── checksums/                  # System file checksums
├── docs/                           # Documentation
├── rcforge.sh                      # Main loader script
├── system/                         # Core system files
│   ├── core/                       # Core system scripts
│   │   ├── bash-version-check.sh   # Bash compatibility checker
│   │   ├── rc.sh                   # Command dispatcher
│   │   └── run-integrity-checks.sh # Integrity check runner
│   ├── lib/                        # Shared library functions
│   │   ├── shell-colors.sh         # Color and formatting
│   │   ├── utility-functions.sh    # Common utility functions
│   │   └── set_rcforge_environment.sh # Environment variables
│   └── utils/                      # System utility scripts
│       ├── apikey.sh               # API key management utility
│       ├── check-checksums.sh      # Checksum verification
│       ├── chkseq.sh               # Sequence conflict detection
│       ├── diag.sh                 # Configuration visualization
│       ├── export.sh               # Configuration export
│       └── ...                     # Other system utilities
└── utils/                          # User-created utilities
```

## Component Descriptions

### Main System Components

| Component              | Purpose                                      | Path                                  |
|------------------------|----------------------------------------------|---------------------------------------|
| Loader Script          | Core functionality that loads all rc-scripts | `~/.local/share/rcforge/rcforge.sh`   |
| System Libraries       | Shared functions and utilities               | `~/.local/share/rcforge/system/lib/`  |
| System Core Scripts    | Core functionality for the rcForge system    | `~/.local/share/rcforge/system/core/` |
| System Utilities       | Built-in tools accessible via `rc` command   | `~/.local/share/rcforge/system/utils/`|
| API Keys Configuration | Store API keys for external services         | `~/.config/rcforge/config/api_keys.conf` |
| PATH Configuration     | Configure environment PATH                   | `~/.config/rcforge/config/path.conf`  |

### User Components

| Component              | Purpose                                        | Path                                |
|------------------------|------------------------------------------------|------------------------------------|
| RC Scripts             | Sequential shell configuration scripts         | `~/.config/rcforge/rc-scripts/`    |
| User Utility Scripts   | User-created tools                             | `~/.local/share/rcforge/utils/`     |
| Backups                | Automated backups for upgrades and rollbacks   | `~/.local/share/rcforge/backups/`   |
| Documentation          | User guides and references                     | `~/.local/share/rcforge/docs/`      |

## Key Files Reference

### Core System Files

| File                                                      | Purpose                                      |
|-----------------------------------------------------------|----------------------------------------------|
| `~/.local/share/rcforge/rcforge.sh`                      | Main loader script                           |
| `~/.local/share/rcforge/system/lib/shell-colors.sh`      | Color and formatting utilities               |
| `~/.local/share/rcforge/system/lib/utility-functions.sh` | Common utility functions                     |
| `~/.local/share/rcforge/system/core/bash-version-check.sh` | Bash version validation                   |
| `~/.local/share/rcforge/system/lib/set_rcforge_environment.sh` | Set environment variables              |
| `~/.local/share/rcforge/system/core/rc.sh`              | RC command dispatcher                        |
| `~/.local/share/rcforge/system/utils/apikey.sh`         | API key management utility                   |

### User Configuration Files

| File                                      | Purpose                                        |
|-------------------------------------------|-------------------------------------------------|
| `~/.config/rcforge/config/path.conf`      | Configure PATH environment variable              |
| `~/.config/rcforge/config/api_keys.conf`  | Store API keys for external services            |
| `~/.config/rcforge/rc-scripts/`           | User shell configuration scripts directory       |

## RC Script Naming Convention

All RC scripts follow this naming convention:
```
###_[hostname|global]_[environment]_[description].sh
```

Where:
- `###`: Three-digit sequence number that determines load order
- `[hostname|global]`: Either your specific hostname or "global" for all machines
- `[environment]`: One of "common", "bash", or "zsh"
- `[description]`: Brief description of what the script does

Example: `050_global_common_path.sh` - Script with sequence 050, applies globally, works in both shells, configures PATH.

## New Features in v0.5.0

### XDG Base Directory Support
- Configuration files now stored in `~/.config/rcforge/`
- Program data now stored in `~/.local/share/rcforge/`
- Automatically migrates from pre-0.5.0 structure during upgrade

### PATH Configuration
- Path configuration now stored in `~/.config/rcforge/config/path.conf`
- Automatically builds PATH from configured directories

### API Key Management
- New API key management system
- Securely store API keys in `~/.config/rcforge/config/api_keys.conf`
- Use the `rc apikey` command to manage API keys

## User Override System

A key feature of rcForge is the user override system:

1. **RC Scripts**: User-created scripts take precedence in the loading sequence
2. **Utility Scripts**: User utilities in `~/.local/share/rcforge/utils/` override system utilities with the same name
3. **No System Installation**: Everything is contained within the user's home directory

### How User Overrides Work

To override a system utility:
1. Identify the system utility you want to customize (e.g., `~/.local/share/rcforge/system/utils/diag.sh`)
2. Create a file with the same name in the user utils directory: `~/.local/share/rcforge/utils/diag.sh`
3. Your version will now be used instead of the system version

## The RC Command Framework

The `rc` command provides a unified interface for accessing utilities:

```
rc [command] [options] [arguments]
```

When you run an `rc` command:

1. It first checks for a user utility matching the command name
2. If not found, it looks for a system utility with that name
3. It executes the first matching utility found

All utilities support these standard subcommands:
- `help`: Display detailed usage information
- `summary`: Show one-line description (used by `rc help`)

## Installation and Upgrade

rcForge v0.5.0 uses a user-level installation approach:

1. **XDG-Compliant Installation**: Files are placed in standard XDG directories
2. **Backup**: Before upgrades, creates a timestamped backup in `~/.local/share/rcforge/backups/`
3. **User Files**: Preserves all user-created RC scripts and utilities during upgrades
4. **Automated Migration**: Automatically migrates from pre-0.5.0 directory structure

### Installation Command

```bash
curl -fsSL https://raw.githubusercontent.com/mhasse1/rcforge/main/install.sh | bash
```

## Best Practices for New Utilities

1. Follow the naming convention for RC scripts
2. Use the standard utility template for new utilities
3. Implement both `--help` and `--summary` options
4. Place user utilities in `~/.local/share/rcforge/utils/`
5. Store API keys using the `rc apikey` utility instead of hardcoding them
