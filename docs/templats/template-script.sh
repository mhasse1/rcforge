#!/bin/bash
# ###_[hostname|global]_[environment]_[description].sh
# Description: Template for rcForge configuration files
# Author: Mark Hasse
# Copyright: Analog Edge LLC
# Date: YYYY-MM-DD

# Exit if sourced in an unsupported shell
# (only needed for shell-specific scripts)
if [[ -n "$shell_name" && "$shell_name" != "bash" && "$environment" == "bash" ]]; then
  debug_echo "Skipping bash-specific script in $shell_name"
  return 0
fi

# Exit if on the wrong hostname
# (only needed for hostname-specific scripts)
if [[ -n "$current_hostname" && "$current_hostname" != "your-hostname" && "$hostname" != "global" ]]; then
  debug_echo "Skipping hostname-specific script on $current_hostname"
  return 0
fi

# Local function definitions (if needed)
local_function() {
  # Function code here
  echo "This is a local function"
}

# Debug information about the environment
debug_echo "Running configuration script: $(basename "$0")"
debug_echo "Current shell: $shell_name"
debug_echo "Current hostname: $current_hostname"

# Main configuration code
# ...

# OS-specific configuration
if is_macos; then
  # macOS-specific configuration
  debug_echo "Configuring for macOS"
elif is_linux; then
  # Linux-specific configuration
  debug_echo "Configuring for Linux"
fi

# Set up command aliases if they're appropriate for this environment
if cmd_exists git; then
  alias g="git"
  alias gs="git status"
fi

# Add directories to PATH if needed
add_to_path "$HOME/bin"
append_to_path "$HOME/.local/bin"

# Source additional files if needed
source_file "$HOME/.config/custom/settings.sh" "Custom settings"

debug_echo "Configuration complete: $(basename "$0")"
