# Getting Started with rcForge

This guide will help you install, configure, and start using rcForge to manage your shell environment.

## Installation

### Prerequisites

- Bash 4.0+ or Zsh
- Git (for installation from repository)
- Standard UNIX utilities (find, sort, etc.)

### Quick Installation

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
sudo dpkg -i rcforge_0.2.1_all.deb
sudo apt install -f  # Resolve any dependencies

# Add to your shell configuration
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
   ```

2. Copy core files:
   ```bash
   git clone https://github.com/mhasse1/rcforge.git /tmp/rcforge
   cp -r /tmp/rcforge/{core,utils,src} ~/.config/rcforge/
   cp /tmp/rcforge/rcforge.sh ~/.config/rcforge/
   cp /tmp/rcforge/include-structure.sh ~/.config/rcforge/
   ```

3. Update shell RC files:
   ```bash
   echo 'source "$HOME/.config/rcforge/rcforge.sh"' >> ~/.bashrc
   # and/or for Zsh
   echo 'source "$HOME/.config/rcforge/rcforge.sh"' >> ~/.zshrc
   ```

## Development Installation

If you're a developer working on rcForge itself:

```bash
# Clone the repository to the development location
git clone https://github.com/mhasse1/rcforge.git ~/src/rcforge

# Set development mode when using
export RCFORGE_DEV=1
source ~/src/rcforge/rcforge.sh
```

## Creating Your First Configuration Files

All configuration files follow this naming pattern:
```
###_[hostname|global]_[environment]_[description].sh
```

Where:
- `###`: Three-digit sequence number controlling load order
- `[hostname|global]`: Either the hostname of a specific machine or "global" for all machines
- `[environment]`: One of "common", "bash", or "zsh"
- `[description]`: Brief description of what the configuration does

### Example Configuration Files

1. Create a global environment file:
   ```bash
   cat > ~/.config/rcforge/scripts/100_global_common_environment.sh << 'EOF'
   #!/bin/bash
   # Global environment variables
   export EDITOR="vim"
   export VISUAL="vim"
   export TERM="xterm-256color"
   export LANG="en_US.UTF-8"
   EOF
   ```

2. Create shell-specific configurations:
   ```bash
   cat > ~/.config/rcforge/scripts/300_global_bash_prompt.sh << 'EOF'
   #!/bin/bash
   # Bash prompt customization
   PS1="\n\[\033[0;32m\]\u@\h\[\033[0m\] \[\033[0;34m\]\w\[\033[0m\]\n\$ "
   EOF
   ```

3. Create machine-specific configurations:
   ```bash
   # Replace "laptop" with your actual hostname
   cat > ~/.config/rcforge/scripts/700_laptop_common_vpn.sh << 'EOF'
   #!/bin/bash
   # VPN settings for laptop
   alias connect-vpn="sudo openconnect vpn.company.com"
   EOF
   ```

## Using the Include System

rcForge provides a modular function system that lets you include only the functions you need:

```bash
# In your configuration file
#!/bin/bash
# 400_global_common_functions.sh

# Include path management functions
include_function path add_to_path
include_function path append_to_path

# Include all common utility functions
include_category common

# Use the included functions
add_to_path "$HOME/bin"
```

## Using rcForge Tools

### Check for Configuration Conflicts

```bash
~/.config/rcforge/utils/check-seq.sh
```

### Fix Conflicts Interactively

```bash
~/.config/rcforge/utils/check-seq.sh --fix
```

### Create a Loading Diagram

```bash
~/.config/rcforge/utils/diagram-config.sh
```

### Export Configuration for Remote Servers

```bash
~/.config/rcforge/utils/export-config.sh --shell=bash
```

## Common Workflows

### Managing Multiple Machines

1. Keep your rcforge directory in a git repository
2. Create global configurations for settings you want everywhere
3. Create machine-specific configurations as needed
4. Clone your repository on each new machine and run the installation script

### Debugging Configuration Issues

If you're having trouble with your configuration:

```bash
# Enable debug mode
SHELL_DEBUG=1 source ~/.bashrc

# Check for sequence conflicts
~/.config/rcforge/utils/check-seq.sh

# Verify checksums
~/.config/rcforge/utils/check-checksums.sh
```

## Next Steps

- Read the [Universal Shell Guide](universal-shell-guide.md) for more details
- Explore the [example configurations](development-docs/examples/) for ideas
- Check out the [development documentation](development-docs/) if you want to contribute
- Learn about the [include system](README-includes.md) for modular functions

## Need Help?

If you run into any issues, please check the documentation or open an issue on the GitHub repository.