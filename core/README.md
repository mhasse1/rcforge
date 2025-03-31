# rcForge - Universal Shell Configuration System

rcForge is a flexible, modular configuration system for Bash and Zsh shells that provides a single framework for managing your shell environment across multiple machines.

> **Note for restricted systems**: If you're working on a system where you don't have root access or can't install packages, we recommend using the export feature. Configure rcForge on your personal machine, then use `export-config.sh` to generate a single configuration file that can be transferred to the restricted system. This allows you to maintain a consistent environment without requiring installation privileges.

## System Requirements

- **Bash 4.0+** (required for full functionality, especially the include system and associative arrays)
- Zsh 5.0+ (partially supported)
- Git (for version control)
- Standard UNIX utilities (find, sort, etc.)

> **Bash Version Compatibility**
> For older Bash versions (e.g., Bash 3.2 on macOS), rcForge operates in a limited compatibility mode:
> ```bash
> # Install a newer Bash version via Homebrew
> brew install bash
> 
> # Add to available shells
> echo "/opt/homebrew/bin/bash" | sudo tee -a /etc/shells
> 
> # Optional: Change default shell
> chsh -s /opt/homebrew/bin/bash
> ```

## Key Features

- **Cross-shell Compatibility**: Seamless support for Bash and Zsh
- **Machine-Specific Configurations**: Dynamic config loading based on hostname
- **Deterministic Loading Order**: Explicit sequence number management
- **Conflict Detection**: Automatic identification and resolution of configuration conflicts
- **Visual Configuration Diagrams**: Generate loading order visualizations
- **Checksum Verification**: Detect unauthorized changes to RC files
- **Export Functionality**: Easily transfer configurations to remote servers
- **Modular Include System**: Organize and manage shell functions efficiently

## Enhanced Security Features

- **Root Execution Prevention**: Protect against inadvertent root-level configuration changes
- **Comprehensive Checksum Validation**: Ensure configuration file integrity
- **Sequence Conflict Resolution**: Prevent configuration loading conflicts

## Installation Methods

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
# Install package
sudo dpkg -i rcforge_0.2.0_all.deb
sudo apt install -f  # Resolve dependencies

# Source in shell configuration
echo 'source "/usr/share/rcforge/rcforge.sh"' >> ~/.bashrc
# or for Zsh
echo 'source "/usr/share/rcforge/rcforge.sh"' >> ~/.zshrc
```

#### macOS with Homebrew

```bash
# Install via Homebrew
brew tap mhasse1/rcforge
brew install rcforge

# Source in shell configuration
echo 'source "$(brew --prefix)/share/rcforge/rcforge.sh"' >> ~/.bashrc
# or for Zsh
echo 'source "$(brew --prefix)/share/rcforge/rcforge.sh"' >> ~/.zshrc
```

## Configuration File Naming Convention

Configuration files follow this pattern:
```
###_[hostname|global]_[environment]_[description].sh
```

### Example Configuration Files

```bash
# Global environment configuration
cat > ~/.config/rcforge/scripts/100_global_common_environment.sh << 'EOF'
#!/bin/bash
export EDITOR="vim"
export TERM="xterm-256color"
export LANG="en_US.UTF-8"
EOF

# Bash-specific prompt configuration
cat > ~/.config/rcforge/scripts/300_global_bash_prompt.sh << 'EOF'
#!/bin/bash
PS1="\n\u@\h \w\n\$ "
EOF

# Hostname-specific configuration
cat > ~/.config/rcforge/scripts/700_laptop_common_vpn.sh << 'EOF'
#!/bin/bash
alias connect-vpn="sudo openconnect vpn.company.com"
EOF
```

## Utility Functions

### Include System

```bash
# Include a specific function
include_function path add_to_path

# Include all functions in a category
include_category common

# Use the included functions
add_to_path "$HOME/bin"
```

### Utility Commands

```bash
# Check for configuration conflicts
~/.config/rcforge/utils/check-seq.sh

# Create configuration loading diagram
~/.config/rcforge/utils/diagram-config.sh

# Export configuration for remote server
~/.config/rcforge/utils/export-config.sh --shell=bash
```

## Recommended Configuration Sequence Ranges

| Range | Purpose |
|-------|---------|
| 000-199 | Critical configurations (PATH, etc.) |
| 200-399 | Environment and Prompt configurations |
| 400-599 | Functions and aliases |
| 600-799 | Package-specific configurations |
| 800-949 | Cleanup and final configurations |
| 950-999 | Critical end-of-script operations |

## Documentation

Comprehensive guides available:
- [Getting Started](docs/getting-started.md)
- [Universal Shell Guide](docs/universal-shell-guide.md)
- [Developer's Guide](docs/development-docs/rcforge-developer-guide.md)
- [Migration Guide](docs/development-docs/migration-guide.md)
- [Include System Guide](docs/README-includes.md)

## Version

Current version: 0.2.0 (Pre-release)

## License

MIT License

## Contributing

Contributions are welcome! Please submit pull requests or open issues on our GitHub repository.

## Support

For issues, questions, or feature requests, please visit our GitHub repository or open an issue.
