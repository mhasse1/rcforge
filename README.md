# rcForge v0.4.2 - Journey to the Deathstar

**A user-centric, modular shell configuration management system for Bash and Zsh.**
rcForge is a flexible, modular configuration system for Bash and Zsh shells that provides a single framework for managing your shell environment across multiple machines.

**Status:** Currently under active development

**Documentation:** (under development) See https://github.com/mhasse1/rcforge/wiki

``` ascii
      _.-._          _.-._                                     *        *
     / \_/ \        / \_/ \    pew        * \|/  *                *             (Modular
    >-(rc)-<       >-(rc)-< - - x     * - EXPLOSION - *              *           Scripts)
     \_/ \_/        \_/ \_/      pew      * /|\  *            *            *
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
curl -fsSL https://raw.githubusercontent.com/mhasse1/rcforge/main/install.sh | bash
```

## Post installation

After the installation, the line to source rcforge will be commented out in your .zshrc and .bashrc. Uncomment to start using the system.  We recommend you use `source ~/.config/rcforge/rcforge.sh` to verify the system is working correctly for you first.

**There is a one-second pause when rcForge starts up. Press '.' during this pause to terminate rcForge.**

### `.bashrc` recommended configuration

We recommend the following configuration for your `.bashrc` when once you have migrated everything out of your `.bashrc` file:

```
# Put non-interactive code here

case $- in
    *i*) ;;
      *) return;; # exit if non-interactive
esac

[ -f "${HOME}/.config/rcforge/rcforge.sh" ] && source "${HOME}/.config/rcforge/rcforge.sh"
```

### `.zshrc` recommended configuration

Zsh is a little more straightforward:

```
[ -f "${HOME}/.config/rcforge/rcforge.sh" ] && source "${HOME}/.config/rcforge/rcforge.sh"
```
Your non-interactive environment configuration should be added to `.zshenv`
