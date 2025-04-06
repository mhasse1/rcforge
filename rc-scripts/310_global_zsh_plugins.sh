#!/usr/bin/env zsh
# 310_global_zsh_plugins.sh - Zsh plugin configuration
# Author: rcForge Team
# Date: 2025-04-06
# Version: 0.3.0
# Description: Configures and loads Zsh plugins

# Skip if not running in Zsh
if [[ -z "${ZSH_VERSION:-}" ]]; then
  return 0
fi

# ============================================================================
# PLUGIN MANAGER SETUP
# ============================================================================

# Path to the plugin manager directory
ZSH_PLUGIN_DIR="$HOME/.zsh/plugins"

# Create plugin directory if it doesn't exist
if [[ ! -d "$ZSH_PLUGIN_DIR" ]]; then
  mkdir -p "$ZSH_PLUGIN_DIR"
fi

# ============================================================================
# PLUGIN LOADING FUNCTION
# ============================================================================

# Function: load_plugin
# Description: Load a plugin from the plugins directory
# Usage: load_plugin plugin_name
load_plugin() {
  local plugin_name="$1"
  local plugin_path="$ZSH_PLUGIN_DIR/$plugin_name"
  
  # Check if plugin exists
  if [[ -d "$plugin_path" ]]; then
    # Add to fpath for completion functions
    fpath=("$plugin_path" $fpath)
    
    # Source the main plugin file if it exists
    if [[ -f "$plugin_path/$plugin_name.plugin.zsh" ]]; then
      source "$plugin_path/$plugin_name.plugin.zsh"
    elif [[ -f "$plugin_path/$plugin_name.zsh" ]]; then
      source "$plugin_path/$plugin_name.zsh"
    elif [[ -f "$plugin_path/$plugin_name.sh" ]]; then
      source "$plugin_path/$plugin_name.sh"
    fi
  fi
}

# ============================================================================
# LOAD CORE PLUGINS
# ============================================================================

# Auto-suggestions (fish-like suggestions)
if [[ -d "$ZSH_PLUGIN_DIR/zsh-autosuggestions" ]]; then
  load_plugin "zsh-autosuggestions"
  # Configure suggestions style
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=240"
  ZSH_AUTOSUGGEST_STRATEGY=(history completion)
fi

# Syntax highlighting (must be loaded after other plugins)
if [[ -d "$ZSH_PLUGIN_DIR/zsh-syntax-highlighting" ]]; then
  load_plugin "zsh-syntax-highlighting"
  # Configure highlighting styles
  ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern cursor)
fi

# Fast directory switching
if [[ -d "$ZSH_PLUGIN_DIR/zsh-z" ]]; then
  load_plugin "zsh-z"
  # Configure z behavior
  ZSHZ_CMD="j"  # Use 'j' instead of 'z' command
  ZSHZ_DATA="$HOME/.cache/zsh/z-data"  # Path to z data file
fi

# ============================================================================
# PLUGIN INSTALLATION HELPER
# ============================================================================

# Function: install_plugin
# Description: Clone a plugin repository
# Usage: install_plugin repo_url plugin_name
install_plugin() {
  local repo_url="$1"
  local plugin_name="$2"
  local plugin_path="$ZSH_PLUGIN_DIR/$plugin_name"
  
  if [[ ! -d "$plugin_path" ]]; then
    echo "Installing plugin: $plugin_name"
    git clone --depth=1 "$repo_url" "$plugin_path"
    return $?
  else
    echo "Plugin already installed: $plugin_name"
    return 0
  fi
}

# Export the plugin functions
export -f load_plugin
export -f install_plugin

# EOF
