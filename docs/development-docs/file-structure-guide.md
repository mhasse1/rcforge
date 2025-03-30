# rcForge Files: Source and Destination Documentation

This document maps the development structure of rcForge to installation destinations, providing a clear reference for developers and package maintainers.

## Project Overview

rcForge is organized into several key components:

1. **Core Files** - Main script and essential functionality
2. **Include System** - Modular function organization
3. **Utility Scripts** - Helper tools and utilities
4. **Documentation** - User and developer guides
5. **Example Configurations** - Sample files for users

## Development Structure vs. Installation Destinations

### Key Files in Repository Root

| Development Location   | Purpose               | System Installation Destination           | User Configuration                                  |
| ---------------------- | --------------------- | ----------------------------------------- | --------------------------------------------------- |
| `rcforge.sh`           | Main loader script    | `/usr/share/rcforge/rcforge.sh`           | `$HOME/.config/rcforge/rcforge.sh` (copy)           |
| `include-structure.sh` | Include system setup  | `/usr/share/rcforge/include-structure.sh` | `$HOME/.config/rcforge/include-structure.sh` (copy) |
| `CHANGELOG.md`         | Version history       | `/usr/share/doc/rcforge/CHANGELOG.md`     | N/A                                                 |
| `LICENSE`              | MIT license           | `/usr/share/doc/rcforge/LICENSE`          | N/A                                                 |
| `README.md`            | Project documentation | `/usr/share/doc/rcforge/README.md`        | `$HOME/.config/rcforge/docs/README.md` (copy)       |

### Core Functionality

| Development Location         | Purpose                       | System Installation Destination                 | User Configuration |
| ---------------------------- | ----------------------------- | ----------------------------------------------- | ------------------ |
| `core/functions.sh`          | Core utility functions        | `/usr/share/rcforge/core/functions.sh`          | N/A                |
| `core/bash-version-check.sh` | Bash version validation       | `/usr/share/rcforge/core/bash-version-check.sh` | N/A                |
| `core/check-seq.sh`          | Sequence checking utility     | `/usr/share/rcforge/core/check-seq.sh`          | N/A                |
| `core/check-checksums.sh`    | RC file checksum verification | `/usr/share/rcforge/core/check-checksums.sh`    | N/A                |

### Include System Files

| Development Location       | Purpose                   | System Installation Destination               | User Configuration |
| -------------------------- | ------------------------- | --------------------------------------------- | ------------------ |
| `lib/include-functions.sh` | Include system core       | `/usr/share/rcforge/lib/include-functions.sh` | N/A                |
| `include/path/`            | Path management functions | `/usr/share/rcforge/include/path/`            | N/A                |
| `include/common/`          | Common utility functions  | `/usr/share/rcforge/include/common/`          | N/A                |
| `include/git/`             | Git-related functions     | `/usr/share/rcforge/include/git/`             | N/A                |
| `include/network/`         | Network utility functions | `/usr/share/rcforge/include/network/`         | N/A                |
| `include/system/`          | System information        | `/usr/share/rcforge/include/system/`          | N/A                |
| `include/text/`            | Text processing           | `/usr/share/rcforge/include/text/`            | N/A                |
| `include/web/`             | Web-related functions     | `/usr/share/rcforge/include/web/`             | N/A                |

### Utilities and Tools

| Development Location          | Purpose                  | System Installation Destination                  | User Configuration |
| ----------------------------- | ------------------------ | ------------------------------------------------ | ------------------ |
| `utils/rcforge-setup.sh`      | Setup utility            | `/usr/share/rcforge/utils/rcforge-setup.sh`      | N/A                |
| `utils/export-config.sh`      | Export configurations    | `/usr/share/rcforge/utils/export-config.sh`      | N/A                |
| `utils/diagram-config.sh`     | Create config diagrams   | `/usr/share/rcforge/utils/diagram-config.sh`     | N/A                |
| `utils/create-include.sh`     | Create include functions | `/usr/share/rcforge/utils/create-include.sh`     | N/A                |
| `utils/check-bash-version.sh` | Check Bash version       | `/usr/share/rcforge/utils/check-bash-version.sh` | N/A                |
| `utils/test-include.sh`       | Test include system      | `/usr/share/rcforge/utils/test-include.sh`       | N/A                |

### Example Configuration Files

| Development Location                     | Purpose         | System Installation Destination                             | User Configuration                                           |
| ---------------------------------------- | --------------- | ----------------------------------------------------------- | ------------------------------------------------------------ |
| `scripts/050_global_common_path.sh`      | PATH management | `/usr/share/rcforge/scripts/050_global_common_path.sh`      | `$HOME/.config/rcforge/scripts/050_global_common_path.sh` (copy) |
| `scripts/200_global_common_config.sh`    | Common settings | `/usr/share/rcforge/scripts/200_global_common_config.sh`    | `$HOME/.config/rcforge/scripts/200_global_common_config.sh` (copy) |
| `scripts/210_global_bash_config.sh`      | Bash settings   | `/usr/share/rcforge/scripts/210_global_bash_config.sh`      | `$HOME/.config/rcforge/scripts/210_global_bash_config.sh` (copy) |
| `scripts/210_global_zsh_config.sh`       | Zsh settings    | `/usr/share/rcforge/scripts/210_global_zsh_config.sh`       | `$HOME/.config/rcforge/scripts/210_global_zsh_config.sh` (copy) |
| `scripts/350_global_bash_prompt.sh`      | Bash prompt     | `/usr/share/rcforge/scripts/350_global_bash_prompt.sh`      | `$HOME/.config/rcforge/scripts/350_global_bash_prompt.sh` (copy) |
| `scripts/350_global_zsh_prompt.sh`       | Zsh prompt      | `/usr/share/rcforge/scripts/350_global_zsh_prompt.sh`       | `$HOME/.config/rcforge/scripts/350_global_zsh_prompt.sh` (copy) |
| `scripts/400_global_common_aliases.sh`   | Common aliases  | `/usr/share/rcforge/scripts/400_global_common_aliases.sh`   | `$HOME/.config/rcforge/scripts/400_global_common_aliases.sh` (copy) |
| `scripts/500_global_common_functions.sh` | User functions  | `/usr/share/rcforge/scripts/500_global_common_functions.sh` | `$HOME/.config/rcforge/scripts/500_global_common_functions.sh` (copy) |
| Other script files...                    | Various configs | `/usr/share/rcforge/scripts/`                               | `$HOME/.config/rcforge/scripts/` (copy)                      |

### Documentation

| Development Location              | Purpose                 | System Installation Destination                     | User Configuration                             |
| --------------------------------- | ----------------------- | --------------------------------------------------- | ---------------------------------------------- |
| `docs/user-guides/`               | User documentation      | `/usr/share/doc/rcforge/user-guides/`               | `$HOME/.config/rcforge/docs/` (selected files) |
| `docs/development-docs/`          | Developer documentation | `/usr/share/doc/rcforge/development-docs/`          | N/A                                            |
| `docs/development-docs/examples/` | Example scripts         | `/usr/share/doc/rcforge/development-docs/examples/` | N/A                                            |
| `docs/templates/`                 | Templates               | `/usr/share/doc/rcforge/templates/`                 | N/A                                            |

### User-specific Directories

| Directory    | Purpose                    | Location                           |
| ------------ | -------------------------- | ---------------------------------- |
| `scripts/`   | User configuration scripts | `$HOME/.config/rcforge/scripts/`   |
| `include/`   | User function overrides    | `$HOME/.config/rcforge/include/`   |
| `exports/`   | Exported configurations    | `$HOME/.config/rcforge/exports/`   |
| `checksums/` | RC file checksums          | `$HOME/.config/rcforge/checksums/` |
| `docs/`      | User documentation         | `$HOME/.config/rcforge/docs/`      |

## Installation Executable Links

| Development Location      | Executable Name | Installation Destination           |
| ------------------------- | --------------- | ---------------------------------- |
| `utils/rcforge-setup.sh`  | `rcforge-setup` | `/usr/bin/rcforge-setup` (symlink) |
| `rcforge.sh`              | `rcforge`       | `/usr/bin/rcforge` (symlink)       |
| `utils/export-config.sh`  | `rcf-export`    | `/usr/bin/rcf-export` (symlink)    |
| `utils/diagram-config.sh` | `rcf-diagram`   | `/usr/bin/rcf-diagram` (symlink)   |
| `utils/create-include.sh` | `rcf-include`   | `/usr/bin/rcf-include` (symlink)   |

## Package-Specific Files

### Debian Package

| Development Location                | Purpose                  |
| ----------------------------------- | ------------------------ |
| `debian/control`                    | Package metadata         |
| `debian/postinst`                   | Post-installation script |
| `debian/prerm`                      | Pre-removal script       |
| `debian/rules`                      | Build rules              |
| `debian/source/format`              | Source format            |
| `packaging/scripts/build-deb.sh`    | Build script             |
| `packaging/scripts/validate-deb.sh` | Validation script        |

### Homebrew Formula

| Development Location                   | Purpose          |
| -------------------------------------- | ---------------- |
| `Formula/rcforge.rb`                   | Homebrew formula |
| `packaging/scripts/brew-test-local.sh` | Testing script   |

## Directory Structure Overview

Rather than providing a complete directory listing that would quickly become outdated during active development, this section outlines the key directories and their purposes.

### Development Structure

```
rcforge/
├── core/                         # Core functionality
├── docs/                         # Documentation
│   ├── development-docs/         # Developer docs
│   ├── templates/                # Template files
│   └── user-guides/              # User-facing documentation
├── include/                      # System include files by category
├── lib/                          # Libraries and core functionality
├── packaging/                    # Packaging-related scripts and configs
├── scripts/                      # Example configuration scripts
└── utils/                        # Utility scripts
```

### System Installation Structure

```
/usr/share/rcforge/               # System files
├── core/                         # Core functions
├── include/                      # System include files
│   ├── path/                     # Path functions
│   ├── common/                   # Common utilities
│   └── ...                       # Other categories
├── lib/                          # Library files
├── scripts/                      # Example scripts
└── utils/                        # Utility scripts

/usr/share/doc/rcforge/           # System documentation
├── development-docs/             # Developer documentation
├── templates/                    # Templates
└── user-guides/                  # User guides

/usr/bin/                         # Executable symlinks
├── rcforge -> /usr/share/rcforge/rcforge.sh
├── rcforge-setup -> /usr/share/rcforge/utils/rcforge-setup.sh
├── rcf-export -> /usr/share/rcforge/utils/export-config.sh
├── rcf-diagram -> /usr/share/rcforge/utils/diagram-config.sh
└── rcf-include -> /usr/share/rcforge/utils/create-include.sh
```

### User Configuration Structure

```
$HOME/.config/rcforge/           # User configuration
├── checksums/                   # Checksums for RC files
├── docs/                        # User documentation
├── exports/                     # Exported configurations
├── include/                     # User include functions
├── scripts/                     # User configuration scripts
├── include-structure.sh         # Include system setup
└── rcforge.sh                   # Main loader script
```

## Notes on Installation Process

1. **System Installation:** Places files in system directories (`/usr/share/rcforge/`, `/usr/share/doc/rcforge/`)
2. **User Configuration:** Creates and populates `$HOME/.config/rcforge/` with user-specific files
3. **Executable Links:** Creates a symlink at `/usr/bin/rcforge` pointing to the setup script

The installation process:

- Creates necessary directories with appropriate permissions
- Copies example configurations to user directory if not present
- Creates empty include directories in the user's home for potential function overrides
- Sets up appropriate symlinks and permissions
- Updates shell RC files to source rcForge

### Include System Operation

The include system operates with a dual-directory approach:

1. **System Include Files** (`/usr/share/rcforge/include/`):
   - Contains all the official rcForge-provided functions
   - Organized in subdirectories by category (path/, common/, git/, etc.)
   - Each subdirectory contains related function files
   - Updated through package upgrades
   - Maintained by project developers
   - Security fixes and enhancements are deployed here
2. **User Include Directory** (`$HOME/.config/rcforge/include/`):
   - Initially a single empty directory after installation
   - Provided as a space for users to create their own custom functions
   - Users can organize this directory however they prefer
   - Can be used to override system functions or create entirely new ones
   - To override a system function, users would create matching path/filename
   - Not modified during system updates
   - Users can ignore this directory entirely if they don't need custom functions

This design allows:

- System-provided functions to be updated centrally
- Security fixes to be deployed without user intervention
- Users complete freedom for their custom functions and overrides
- Simplified maintenance and upgrades

## Homebrew Installation (macOS)

For Homebrew installations, the paths are adjusted:

| Component     | Homebrew Location                     |
| ------------- | ------------------------------------- |
| System files  | `$(brew --prefix)/share/rcforge/`     |
| Documentation | `$(brew --prefix)/share/doc/rcforge/` |
| Executables   | `$(brew --prefix)/bin/rcforge`        |

The user configuration structure remains the same at `$HOME/.config/rcforge/`.

# EOF
