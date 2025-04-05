# rcForge Migration Guide

This guide will help you transition your existing shell configurations to the rcForge system. It covers strategies for preserving your current setup while gaining the benefits of a more organized and modular configuration.

## Table of Contents

- [Introduction](#introduction)
- [Step 1: Inventory Your Current Setup](#step-1-inventory-your-current-setup)
- [Step 2: Plan Your New Structure](#step-2-plan-your-new-structure)
- [Step 3: Create Initial Configuration Files](#step-3-create-initial-configuration-files)
- [Step 4: Test and Refine](#step-4-test-and-refine)
- [Step 5: Go Live](#step-5-go-live)
- [Handling Legacy Scripts](#handling-legacy-scripts)
- [Special Considerations](#special-considerations)
- [Troubleshooting](#troubleshooting)

## Introduction

Migrating to rcForge doesn't have to happen all at once. You can take a phased approach, gradually moving functionality from your existing configuration files into the new structure while maintaining compatibility with your current setup.

## Step 1: Inventory Your Current Setup

Begin by identifying all your current configuration files and what they do:

1. **List all active RC files**:
   ```bash
   ls -la ~/.bash* ~/.zsh* ~/.profile ~/.shell* 2>/dev/null
   ```

2. **Identify the key components** in your configuration:
   - Environment variables
   - PATH modifications
   - Aliases
   - Functions
   - Prompt configurations
   - Tool-specific configurations
   - Machine-specific settings

3. **Prioritize components** based on importance and how frequently you use them

## Step 2: Plan Your New Structure

Plan how you'll organize your new configuration files:

1. **Global vs. machine-specific**: What settings should apply everywhere vs. only on specific machines?

2. **Shell-specific vs. common**: What settings are specific to bash or zsh vs. common to both?

3. **Choose sequence numbers** based on dependencies:
   - Early loading (000-099): PATH, critical environment variables
   - Middle loading (100-699): Most configurations, aliases, etc.
   - Late loading (700-999): Prompts, final adjustments, machine-specific overrides

## Step 3: Create Initial Configuration Files

Start by creating your most important configuration files:

1. **Critical environment setup**:
   ```bash
   # 050_global_common_path.sh
   # Critical PATH setup
   include_function path add_to_path
   
   add_to_path "$HOME/bin"
   add_to_path "$HOME/.local/bin"
   ```

2. **Common aliases and functions**:
   ```bash
   # 200_global_common_aliases.sh
   # Common aliases for all shells and machines
   alias ll="ls -la"
   alias ..="cd .."
   ```

3. **Shell-specific configurations**:
   ```bash
   # 300_global_bash_settings.sh
   # Bash-specific settings
   if shell_is_bash; then
     set -o vi
     # Other bash-specific settings
   fi
   ```

4. **Machine-specific settings**:
   ```bash
   # 750_laptop_common_vpn.sh
   # VPN settings only for laptop
   if [[ "$current_hostname" == "laptop" ]]; then
     alias vpn-connect="sudo openconnect example.com"
   fi
   ```

## Step 4: Test and Refine

Test your new configurations before fully switching over:

1. **Create a test script** to source your new configuration:
   ```bash
   #!/bin/bash
   # test-rcforge.sh
   export SHELL_DEBUG=1
   source ~/.config/rcforge/rcforge.sh
   ```

2. **Run a test shell** with your new configuration:
   ```bash
   bash --rcfile ./test-rcforge.sh
   ```

3. **Check for issues** and fix them before proceeding

## Step 5: Go Live

Once you're satisfied with your new configuration:

1. **Back up your existing RC files**:
   ```bash
   cp ~/.bashrc ~/.bashrc.bak
   cp ~/.zshrc ~/.zshrc.bak
   ```

2. **Update your actual RC files** to source rcForge:
   ```bash
   echo 'source "$HOME/.config/rcforge/rcforge.sh"' >> ~/.bashrc
   echo 'source "$HOME/.config/rcforge/rcforge.sh"' >> ~/.zshrc
   ```

3. **Start a new shell** and verify everything works correctly

## Handling Legacy Scripts

If you have existing scripts that depend on your old configuration:

1. **Create compatibility layer** scripts:
   ```bash
   # 900_global_common_legacy_compat.sh
   # Maintain compatibility with legacy scripts
   
   # Source legacy functions that might be needed
   source_file "$HOME/.old_functions.sh" "Legacy functions"
   ```

2. **Gradually refactor** legacy scripts to use the new functions

## Special Considerations

### Custom Prompts

Migrate your custom prompts carefully:

```bash
# 300_global_bash_prompt.sh
# Custom Bash prompt

# Only run in Bash
if ! shell_is_bash; then
  return 0
fi

# Include the required functions
include_function common is_macos

# Your existing prompt code here, using rcForge functions where appropriate
```

### Tool-Specific Configurations

For tools with their own configuration files:

1. **Keep tool-specific configs** in their original locations (e.g., `~/.gitconfig`)

2. **Create loading scripts** for environment variables and shells:
   ```bash
   # 600_global_common_python.sh
   # Python environment configuration
   
   # Include the required functions
   include_function path add_to_path
   
   if cmd_exists pyenv; then
     export PYENV_ROOT="$HOME/.pyenv"
     add_to_path "$PYENV_ROOT/bin"
     eval "$(pyenv init -)"
   fi
   ```

### Private or Sensitive Information

For sensitive data:

1. **Create a private directory** not tracked by version control:
   ```bash
   mkdir -p ~/.config/rcforge/scripts/private
   ```

2. **Add private configurations**:
   ```bash
   # 800_global_common_private.sh
   # Load private configurations
   source_files "$HOME/.config/rcforge/scripts/private" "*.sh" "Private scripts"
   ```

## Troubleshooting

### Missing Functions

If you encounter "command not found" errors for functions:

1. **Check function definitions**: Make sure the functions you're using are defined before they're called

2. **Check loading order**: Functions should be defined in files with lower sequence numbers

3. **Use the include system**: For v0.2.1+, use the include system to access common functions:
   ```bash
   include_function path add_to_path
   include_function common is_macos
   ```

### Slow Shell Startup

If your shell starts up slowly:

1. **Enable debugging**:
   ```bash
   SHELL_DEBUG=1 source ~/.bashrc
   ```

2. **Identify slow-loading files** and optimize them

3. **Consider lazy-loading** for seldom-used, slow-loading components:
   ```bash
   # Instead of loading NVM immediately
   load_nvm() {
     export NVM_DIR="$HOME/.nvm"
     [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
   }
   # Now NVM only loads when you call load_nvm
   ```

### Shell Differences

If you encounter different behavior between shells:

1. **Use shell detection**:
   ```bash
   if shell_is_bash; then
     # Bash-specific code
   elif shell_is_zsh; then
     # Zsh-specific code
   fi
   ```

2. **Keep shell-specific settings** in their own files with the appropriate naming convention

## Conclusion

Migrating to rcForge might take some initial effort, but the benefits of a more organized, modular, and portable shell configuration system are worth it. Take your time, migrate incrementally, and enjoy having a shell configuration that works consistently across all your machines.
