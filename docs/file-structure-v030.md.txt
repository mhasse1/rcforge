# rcForge Files: Structure Guide (v0.3.0)

This document outlines the file structure of rcForge v0.3.0, providing a clear reference for developers and users.

## Project Overview

rcForge v0.3.0 adopts a user-centric, simplified architecture with these key components:

1. **Core Files** - Main script and essential functionality
2. **RC Scripts** - Shell configuration scripts with sequence-based loading
3. **Utility Scripts** - Tools accessible via the `rc` command
4. **Libraries** - Source-able utility files
5. **Documentation** - User and developer guides

## Technical Requirements

- **Core System**: Requires Bash 4.0 or higher
  - macOS users will need to install modern Bash via Homebrew or MacPorts
  - All system scripts use `#!/usr/bin/env bash` for cross-platform compatibility
- **End User Support**:
  - Both Bash and Zsh are supported as equal first-class citizens
  - RC scripts can be shell-specific (bash/zsh) or common to both
  - Configuration loading adapts to the user's active shell

## Directory Structure

The v0.3.0 redesign significantly simplifies the directory structure, focusing on a clean user-level installation:

```
${HOME}/.config/rcforge/
├── backups/                         # Backup storage for upgrades and rollbacks
├── docs/                            # User documentation
├── rc-scripts/                      # User shell configuration scripts
│   ├── 050_global_common_path.sh    # Example sequenced rc-scripts
│   ├── 210_global_bash_config.sh    #    ↓
│   ├── 210_global_zsh_config.sh     #    ↓
│   ├── 350_global_bash_prompt.sh    #    ↓
│   ├── 350_global_zsh_prompt.sh     #    ↓
│   └── 400_global_common_aliases.sh #    ↓
├── rcforge.sh                       # Core script for rcforge.sh
├── system/                          # Managed system files
│   ├── core/                        # Core system-only scripts
│   ├── include/                     # System include files
│   ├── lib/                         # System libraries
│   └── utils/                       # System utility scripts
│       ├── seq.sh                   # Example system utils
│       ├── diag.sh                  #    ↓
│       ├── export.sh                #    ↓
│       └── dnslookup.sh             #    ↓
└── utils/                           # User utility scripts
```

## Component Descriptions

### Main System Components

| Component              | Purpose                                      | Path                                  |
|------------------------|----------------------------------------------|---------------------------------------|
| Main Loader Script     | Core functionality that loads all rc-scripts | `~/.config/rcforge/rcforge.sh`        |
| System Libraries       | Shared functions and utilities               | `~/.config/rcforge/system/lib/`       |
| System Core Scripts    | Internal system scripts                      | `~/.config/rcforge/system/core/`      |
| System Include Files   | Modular function files                       | `~/.config/rcforge/system/include/`   |
| System Utility Scripts | Built-in tools accessible via `rc` command   | `~/.config/rcforge/system/utils/`     |

### User Components

| Component              | Purpose                                        | Path                                |
|------------------------|-------------------------------------------------|-------------------------------------|
| RC Scripts             | Sequential shell configuration scripts          | `~/.config/rcforge/rc-scripts/`     |
| User Utility Scripts   | User-created tools (override system utilities)  | `~/.config/rcforge/utils/`          |
| Backups                | Timestamped backups for upgrades and rollbacks  | `~/.config/rcforge/backups/`        |
| Documentation          | User guides and references                      | `~/.config/rcforge/docs/`           |

## Key Files Reference

### Core System Files

| File                                          | Purpose                                      |
|-----------------------------------------------|----------------------------------------------|
| `~/.config/rcforge/rcforge.sh`                | Main loader script                           |
| `~/.config/rcforge/system/lib/shell-colors.sh`| Color and formatting utilities               |
| `~/.config/rcforge/system/lib/include-functions.sh` | Include system functions               |
| `~/.config/rcforge/system/lib/utility-functions.sh` | Common utility functions               |
| `~/.config/rcforge/system/core/bash-version-check.sh` | Bash version validation              |
| `~/.config/rcforge/system/core/check-seq.sh`  | Script sequence conflict detection           |
| `~/.config/rcforge/system/core/check-checksums.sh` | RC file checksum verification          |
| `~/.config/rcforge/system/core/functions.sh`  | Core system functions                        |

### System Utility Scripts

| File                                                 | Purpose                                  |
|------------------------------------------------------|------------------------------------------|
| `~/.config/rcforge/system/utils/check-bash-version.sh` | Check Bash version compatibility      |
| `~/.config/rcforge/system/utils/create-include.sh`   | Create include function files           |
| `~/.config/rcforge/system/utils/diagram-config.sh`   | Visualize RC script loading sequence    |
| `~/.config/rcforge/system/utils/export-config.sh`    | Export configurations for remote use    |
| `~/.config/rcforge/system/utils/rcforge-setup.sh`    | Setup and configuration utility         |
| `~/.config/rcforge/system/utils/test-include.sh`     | Test include system functionality       |

### Example RC Scripts

| File                                               | Purpose                                   |
|----------------------------------------------------|-------------------------------------------|
| `~/.config/rcforge/rc-scripts/050_global_common_path.sh` | PATH configuration                  |
| `~/.config/rcforge/rc-scripts/210_global_bash_config.sh` | Bash-specific configuration         |
| `~/.config/rcforge/rc-scripts/210_global_zsh_config.sh`  | Zsh-specific configuration          |
| `~/.config/rcforge/rc-scripts/350_global_bash_prompt.sh` | Bash prompt configuration           |
| `~/.config/rcforge/rc-scripts/350_global_zsh_prompt.sh`  | Zsh prompt configuration            |
| `~/.config/rcforge/rc-scripts/400_global_common_aliases.sh` | Shell-agnostic aliases           |

## File Naming Conventions

### RC Scripts

All RC scripts follow this naming convention:
```
###_[hostname|global]_[environment]_[description].sh
```

Where:
- `###`: Three-digit sequence number that determines load order
- `[hostname|global]`: Either your specific hostname or "global" for all machines
- `[environment]`: One of "common", "bash", or "zsh"
- `[description]`: Brief description of what the script does

### Utility Scripts

Utility scripts have simpler naming:
```
utility-name.sh
```

Where:
- `utility-name`: Descriptive name using lowercase with hyphens
- `.sh`: Shell script extension (though utilities can be in any language)

## User Override System

A key feature of rcForge v0.3.0 is the user override system:

1. **RC Scripts**: User-created scripts take precedence in the loading sequence
2. **Utility Scripts**: User utilities in `~/.config/rcforge/utils/` override system utilities with the same name
3. **No System Installation**: Everything is contained within the user's home directory

### How User Overrides Work

To override a system utility:
1. Identify the system utility you want to customize (e.g., `~/.config/rcforge/system/utils/httpheaders.sh`)
2. Create a file with the same name in the user utils directory: `~/.config/rcforge/utils/httpheaders.sh`
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

rcForge v0.3.0 uses a user-level installation approach:

1. **Installation**: Creates the directory structure in `~/.config/rcforge/`
2. **Backup**: Before upgrades, creates a timestamped backup in `~/.config/rcforge/backups/`
3. **User Files**: Preserves all user-created RC scripts and utilities during upgrades

### Installation Process

```bash
curl -fsSL https://raw.githubusercontent.com/rcforge/install/main/install.sh | bash
```

This script:
- Creates the necessary directory structure
- Copies core system files and example RC scripts
- Adds the source line to your shell RC file
- Sets appropriate file permissions
- Creates backup if upgrading

## Security Considerations

rcForge v0.3.0 implements several security measures:

1. **Non-Root Installation**: Runs entirely within the user's home directory
2. **Strict File Permissions**:
   - 700 for directories (user read/write/execute only)
   - 700 for executable scripts
   - 600 for configuration files
3. **Backup System**: Automatic backups before updates
4. **Root Prevention**: Explicit checks to prevent accidental root execution

## Notes for Developers

When developing for rcForge v0.3.0:

1. **User-First Approach**: Design assuming user-level installation
2. **Override-Friendly Design**: Make utilities modular and override-friendly
3. **Self-Contained Scripts**: Utility scripts should handle their own dependencies
4. **Consistency**: Follow naming conventions and structural patterns
5. **Documentation**: Include proper help and summary information

## Differences from Previous Versions

rcForge v0.3.0 makes these key structural changes:

1. **No System Installation**: Everything is in `~/.config/rcforge/` rather than `/usr/share/rcforge/`
2. **Simplified Directory Structure**: Flattened RC scripts directory and clearer organization
3. **RC Command Framework**: Unified command interface with user override capability
4. **Lazy-Loading Approach**: Performance improvements through deferred loading
