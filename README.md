# rcForge v0.3.0 - Deathstar

**A user-centric, modular shell configuration management system for Bash and Zsh.**
rcForge is a flexible, modular configuration system for Bash and Zsh shells that provides a single framework for managing your shell environment across multiple machines.

**Status:** Currently under active development

**Documentation:** (under development) See https://github.com/mhasse1/rcforge/wiki

``` ascii
      _.-._                                            *        *
     / \_/ \               * \|/  *                       *
    >-(_)-<              * - EXPLOSION - *                     *
     \_/ \_/               * /|\  *                   *            *
      `-'                                                   *
```

## System Requirements

- Bash 4.0+ (required for rcForge's internal core functionality)
- Zsh 5.0+ (fully supported)
- Git (for version control)
- Standard UNIX utilities (find, sort, etc.)

## Features

- **Cross-shell compatibility**: Works with both Bash and Zsh
- **Machine-specific configurations**: Load configs based on hostname
- **Deterministic loading order**: Explicit sequence numbers
- **Conflict detection**: Automatically identifies and helps resolve loading conflicts
- **Visual diagrams**: See your configuration's loading order
- **Checksum verification**: Detect unauthorized changes to your RC files
- **Export functionality**: Consolidate configurations for remote servers
- **Include system**: Modular function organization with dependency management
- **Security model**: Protection from root execution and file permission issues

## Installation

Install or upgrade using the following command:

```bash
curl -fsSL [https://raw.githubusercontent.com/mhasse1/rcforge/main/install-script.sh](https://raw.githubusercontent.com/mhasse1/rcforge/main/install-script.sh) | bash
