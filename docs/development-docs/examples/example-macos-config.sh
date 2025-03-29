#!/bin/bash
# 750_global_macos_settings.sh - macOS-specific configurations
# Author: Mark Hasse
# Copyright: Analog Edge LLC
# Date: 2025-03-20

# Only run on macOS
if ! is_macos; then
  debug_echo "Skipping macOS configuration on non-macOS system"
  return 0
fi

debug_echo "Setting up macOS-specific configurations"

#------------------------------------------------
# macOS-specific helper functions
#------------------------------------------------

# Set a macOS default setting
set_macos_default() {
  local domain="$1"
  local key="$2"
  local value="$3"
  local type="$4"

  debug_echo "Setting macOS default: $domain $key = $value ($type)"
  defaults write "$domain" "$key" -"$type" "$value"
}

# Copy to clipboard function
copy_to_clipboard() {
  pbcopy
}

# Paste from clipboard function
paste_from_clipboard() {
  pbpaste
}

#------------------------------------------------
# macOS path and environment configuration
#------------------------------------------------

# Configure Homebrew
if [[ -f "/opt/homebrew/bin/brew" ]]; then
  # Apple Silicon Macs
  debug_echo "Configuring Homebrew for Apple Silicon"
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -f "/usr/local/bin/brew" ]]; then
  # Intel Macs
  debug_echo "Configuring Homebrew for Intel Mac"
  eval "$(/usr/local/bin/brew shellenv)"
fi

# Add common macOS directories to path
add_to_path "/usr/local/sbin"
add_to_path "/opt/homebrew/opt/coreutils/libexec/gnubin"

# Set macOS-specific environment variables
export COPYFILE_DISABLE=true # Prevent ._ files on external drives
export BASH_SILENCE_DEPRECATION_WARNING=1 # Silence bash deprecation warnings

#------------------------------------------------
# macOS aliases and shortcuts
#------------------------------------------------

# Show/hide hidden files
alias showfiles="defaults write com.apple.finder AppleShowAllFiles -bool true && killall Finder"
alias hidefiles="defaults write com.apple.finder AppleShowAllFiles -bool false && killall Finder"

# Lock screen
alias afk="pmset displaysleepnow"

# Flush DNS cache
alias flushdns="sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder"

# Clean up system junk
alias cleanup="brew cleanup && brew doctor"

# QuickLook from terminal
alias ql="qlmanage -p"

# Better ls commands using exa if available
if cmd_exists exa; then
  alias ls="exa"
  alias ll="exa -la"
  alias lt="exa --tree"
else
  # Standard ls with colors
  alias ls="ls -G"
  alias ll="ls -la"
fi

#------------------------------------------------
# Application shortcuts
#------------------------------------------------

# Better open command
open_app() {
  local app_name="$1"
  shift
  local args="$@"

  if [[ -d "/Applications/$app_name.app" ]]; then
    debug_echo "Opening $app_name with args: $args"
    open -a "$app_name" $args
  else
    echo "Application not found: $app_name"
    return 1
  fi
}

# App shortcuts if they exist
alias typora="open_app Typora"
alias vscode="open_app 'Visual Studio Code'"
alias chrome="open_app 'Google Chrome'"
alias firefox="open_app Firefox"
alias safari="open_app Safari"

#------------------------------------------------
# macOS system tweaks
#------------------------------------------------

# The following tweaks are only applied when NOT in debug mode
if [[ -z "$SHELL_DEBUG" ]]; then
  # Disable press-and-hold for keys in favor of key repeat
  set_macos_default NSGlobalDomain ApplePressAndHoldEnabled false bool

  # Set a faster keyboard repeat rate
  set_macos_default NSGlobalDomain KeyRepeat 2 int
  set_macos_default NSGlobalDomain InitialKeyRepeat 15 int

  # Use plain text as default format in TextEdit
  set_macos_default com.apple.TextEdit RichText 0 int

  # Finder: show all filename extensions
  set_macos_default NSGlobalDomain AppleShowAllExtensions true bool

  debug_echo "Applied macOS system tweaks"
else
  debug_echo "Skipping macOS system tweaks in debug mode"
fi

debug_echo "macOS configuration complete"
