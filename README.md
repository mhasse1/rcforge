# rcForge - Universal Shell Configuration System

rcForge is a flexible, modular configuration system for Bash and Zsh shells that provides a single framework for managing your shell environment across multiple machines.

> **Note for restricted systems**: If you're working on a system where you don't have root access or can't install packages, we recommend using the export feature. Configure rcForge on your personal machine, then use `export-config.sh` to generate a single configuration file that can be transferred to the restricted system. This allows you to maintain a consistent environment without requiring installation privileges.
>
> **Note regarding include system in 0.2.x**: This system has gotten a bit out of hand. I got carried away converting my utility scripts into functions.  I'll be changing this in 0.3.x instead of some of the other refactoring I wanted to do. I am considering either a utilities folder similar to `{system_root}/rcbin/` to add to the path or a core command `rc` that would have many of these scripts built into it and would be executed similar to `rc dirsz {path}` or `rc chkdom {domain}`.  This is probably too monolithic and it will likely be a blend of the two.

## System Requirements

- Bash 4.0+ (required for rcForge's internal core functionality)
- Zsh 5.0+ (fully supported)
- Git (for version control)
- Standard UNIX utilities (find, sort, etc.)

> **Note for older Bash versions**: If you're using Bash 3.2 (default on macOS), the system will operate in a limited compatibility mode without the include system. For full functionality, install a newer version via Homebrew:
>
> ```bash
> brew install bash
> # Add to /etc/shells if you want to make it your default shell
> echo "/opt/homebrew/bin/bash" | sudo tee -a /etc/shells
> # Optional: Change your default shell
> chsh -s /opt/homebrew/bin/bash
> ```

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

## Important Security Notice

### Running as Regular User Only

**rcForge is designed exclusively for use by regular users and should never be run as root.**

All rcForge scripts now include security checks that prevent execution with root privileges. This is not a limitation, but a critical security feature designed to:

1. **Prevent permissions issues**: Running as root can create files with incorrect ownership and permissions
2. **Protect sensitive data**: Shell configurations often contain sensitive information like API tokens
3. **Maintain system integrity**: Root shell configurations should remain minimal for system recovery
4. **Avoid security vulnerabilities**: Complex root shell scripts pose potential security risks
5. **Ensure reliable system recovery**: The root user's profile and RC files should be kept as simple as possible with minimal external dependencies to ensure functionality during system recovery

**We strongly recommend against bypassing these safeguards**. While an override is available using the `RCFORGE_ALLOW_ROOT=1` environment variable, this is only for exceptional situations and not recommended for normal use.

### Secure File Permissions

rcForge v2.0.0 implements a comprehensive security model with:

- Restrictive file permissions (`umask 077`) for all created files
- Directory permissions set to 700 (user-only access)
- Data file permissions set to 600 (user-only read/write)
- Shell script permissions set to 700 (user-only execution)

These permissions ensure your shell configuration files remain private and secure from other users on shared systems.

## Installation

### Quick Installation (Recommended)

```bash
# Clone the repository
git clone https://github.com/mhasse1/rcforge.git ~/.config/rcforge

# Run the installation script
bash ~/.config/rcforge/utils/install-rcforge.sh
```

### Package Installation

#### Debian/Ubuntu

```bash
# Download the latest release package
sudo dpkg -i rcforge_2.0.0_all.deb
sudo apt install -f  # Resolve any dependencies

# Add to your shell configuration (must be run as regular user, not root)
echo 'source "/usr/share/rcforge/rcforge.sh"' >> ~/.bashrc
# or for Zsh
echo 'source "/usr/share/rcforge/rcforge.sh"' >> ~/.zshrc
```

#### macOS with Homebrew

```bash
# Install from Homebrew
brew tap mhasse1/rcforge
brew install rcforge

# Add to your shell configuration
echo 'source "$(brew --prefix)/share/rcforge/rcforge.sh"' >> ~/.bashrc
# or for Zsh
echo 'source "$(brew --prefix)/share/rcforge/rcforge.sh"' >> ~/.zshrc
```

### Manual Installation

If you prefer to install manually:

1. Create directory structure:
   ```bash
   mkdir -p ~/.config/rcforge/{scripts,checksums,exports,include,docs}
   chmod 700 ~/.config/rcforge
   chmod 700 ~/.config/rcforge/{scripts,checksums,exports,include,docs}
   ```

2. Copy core files:
   ```bash
   git clone https://github.com/mhasse1/rcforge.git /tmp/rcforge
   cp -r /tmp/rcforge/{core,utils,src} ~/.config/rcforge/
   cp /tmp/rcforge/rcforge.sh ~/.config/rcforge/
   cp /tmp/rcforge/include-structure.sh ~/.config/rcforge/
   chmod 700 ~/.config/rcforge/rcforge.sh
   chmod 700 ~/.config/rcforge/include-structure.sh
   find ~/.config/rcforge -name "*.sh" -exec chmod 700 {} \;
   ```

3. Update shell RC files:
   ```bash
   echo 'source "$HOME/.config/rcforge/rcforge.sh"' >> ~/.bashrc
   chmod 600 ~/.bashrc
   # and/or for Zsh
   echo 'source "$HOME/.config/rcforge/rcforge.sh"' >> ~/.zshrc
   chmod 600 ~/.zshrc
   ```

## Project Structure

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
  ├── skel/...                # Skel folder for user installation
  └── rcforge.sh              # Main loader script
```

For development, see the repository structure in [rcforge-folder-structure.md](rcforge-folder-structure.md).

## Basic Usage

### Create a configuration file

Files follow the naming pattern:
```
###_[hostname|global]_[environment]_[description].sh
```

Example:
```bash
# Create a global environment file (for all machines, both shells)
cat > ~/.config/rcforge/scripts/100_global_common_environment.sh << 'EOF'
#!/bin/bash
export EDITOR="vim"
export TERM="xterm-256color"
export LANG="en_US.UTF-8"
EOF
chmod 700 ~/.config/rcforge/scripts/100_global_common_environment.sh

# Create a bash-specific file (for all machines, bash only)
cat > ~/.config/rcforge/scripts/300_global_bash_prompt.sh << 'EOF'
#!/bin/bash
PS1="\n\u@\h \w\n\$ "
EOF
chmod 700 ~/.config/rcforge/scripts/300_global_bash_prompt.sh

# Create a hostname-specific file (for 'laptop' machine only)
cat > ~/.config/rcforge/scripts/700_laptop_common_vpn.sh << 'EOF'
#!/bin/bash
alias connect-vpn="sudo openconnect vpn.company.com"
EOF
chmod 700 ~/.config/rcforge/scripts/700_laptop_common_vpn.sh
```

### Using the Include System

Include specific functions in your scripts:

```bash
# Include a specific function
include_function path add_to_path

# Include all functions in a category
include_category common

# Use the included functions
add_to_path "$HOME/bin"
```

### Check for conflicts

```bash
~/.config/rcforge/utils/check-seq.sh
```

### Create a loading diagram

```bash
~/.config/rcforge/utils/diagram-config.sh
```

### Export consolidated configuration for a remote server

```bash
~/.config/rcforge/utils/export-config.sh --shell=bash
```

## Documentation

See the full documentation in our guides:
- [Getting Started](docs/getting-started.md) - Quick setup guide
- [Universal Shell Guide](docs/universal-shell-guide.md) - For setting up and using rcForge
- [Developer's Guide](docs/development-docs/rcforge-developer-guide.md) - For creating custom configurations
- [Migration Guide](docs/development-docs/migration-guide.md) - For transitioning from traditional RC files
- [Include System Guide](docs/README-includes.md) - For using the include system
- [Security Guide](docs/security-guide.md) - For understanding the security model

## Recommended File Structure

| Range | Purpose |
|-------|---------|
| 000-199 | Critical configurations (PATH, etc.) |
| 200-399 | General configurations (Environment, Prompt, etc.) |
| 400-599 | Functions and aliases |
| 600-799 | Package specific configurations (pyenv, homebrew, etc.) |
| 800-949 | End of script info displays, clean up and closeout |
| 950-999 | Critical end of RC scripts |

## Security Best Practices

1. **Never run as root**: Shell configurations can contain sensitive information and should be run with standard user privileges.

2. **Maintain proper file permissions**: All rcForge files are secured with restrictive permissions by default.

3. **Keep sensitive data secure**: Use proper permission settings for files containing API tokens, private server addresses, etc.

4. **Regular security audits**: Periodically review your configurations for security issues.

5. **For root users**: Create a minimal, separate shell configuration for root access that does not source rcForge.

## License

MIT License

## Contributing

Contributions welcome! Please feel free to submit a Pull Request.
# EOF