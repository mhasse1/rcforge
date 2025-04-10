# rcForge v0.4.2 - Journey to the Deathstar

**A user-centric, modular shell configuration management system for Bash and Zsh.**
rcForge is a flexible, modular configuration system for Bash and Zsh shells that provides a single framework for managing your shell environment across multiple machines.

**Status:** Currently under active development

**Documentation:** (under development) See https://github.com/mhasse1/rcforge/wiki

``` ascii
      _.-._          _.-._                                     *        *
     / \_/ \        / \_/ \               * \|/  *                *
    >-(_)-<        >-(_)-< - -x       * - EXPLOSION - *              *
     \_/ \_/        \_/ \_/               * /|\  *            *            *
      `-'            `-'                                            *
```

## System Requirements

- **Bash 4.3+ (required for rcForge's internal core functionality)**
- Zsh 5.0+ (optional-fully supported)
- Git (for version control)
- Standard UNIX utilities (find, sort, etc.)

## Features

- **100% shell-based**: Uses BASH + the standard \*NIX toolset. No additional languages or binaries required.
- **Cross-shell compatibility**: Works with both Bash and Zsh
- **Machine-specific configurations**: Load configs based on hostname
- **Deterministic loading order**: Explicit sequence numbers
- **Conflict detection**: Automatically identifies and helps resolve loading conflicts
- **Visual diagrams**: See your configuration's loading order
- **Checksum verification**: Detect unauthorized changes to your RC files
- **Export functionality**: Consolidate configurations into one *rc file for restricted servers (should also support older environments)
- **Include system**: Modular function organization with dependency management
- **Basic security model**: Protection from root execution and file permission issues


## Installation

Install or upgrade using the following command:

```bash
curl -fsSL [https://raw.githubusercontent.com/mhasse1/rcforge/main/install-script.sh](https://raw.githubusercontent.com/mhasse1/rcforge/main/install-script.sh) | bash
```
