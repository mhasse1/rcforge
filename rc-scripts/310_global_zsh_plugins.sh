#!/usr/bin/env zsh
# 310_global_zsh_plugins.sh - Zsh plugin configuration
# Author: rcForge Team
# Date: 2025-04-06
# Category: rc-script/zsh
# Description: Configures and loads Zsh plugins. Defines helper functions.

# Skip if not running in Zsh
if [[ -z "${ZSH_VERSION:-}" ]]; then
  return 0
fi

# ============================================================================
# PLUGIN MANAGER SETUP
# ============================================================================

# Path to the plugin manager directory (User configurable?)
# Consider using an environment variable or default within XDG structure
: "${ZSH_PLUGIN_DIR:=$HOME/.zsh/plugins}"

# Create plugin directory if it doesn't exist
if [[ ! -d "$ZSH_PLUGIN_DIR" ]]; then
  # Should this use InfoMessage if sourced early? Installer should handle this dir.
  # echo "Creating Zsh plugin directory: $ZSH_PLUGIN_DIR"
  mkdir -p "$ZSH_PLUGIN_DIR"
fi

# ============================================================================
# Function: LoadPlugin
# Description: Load a specific Zsh plugin from the configured plugin directory.
#              Adds plugin dir to fpath and sources standard plugin files.
# Usage: LoadPlugin plugin_name
# Arguments:
#   plugin_name (required) - The directory name of the plugin.
# Returns: None. Sources plugin files if found.
# ============================================================================
LoadPlugin() {
  local plugin_name="$1"
  local plugin_path="$ZSH_PLUGIN_DIR/$plugin_name"

  # Check if plugin directory exists
  if [[ -d "$plugin_path" ]]; then
    # Add plugin directory to fpath for completion functions
    fpath=("$plugin_path" $fpath)

    # Source the main plugin file if it exists, trying common names
    if [[ -f "$plugin_path/$plugin_name.plugin.zsh" ]]; then
      source "$plugin_path/$plugin_name.plugin.zsh"
    elif [[ -f "$plugin_path/$plugin_name.zsh" ]]; then
      source "$plugin_path/$plugin_name.zsh"
    elif [[ -f "$plugin_path/$plugin_name.sh" ]]; then
      # Source .sh file if others not found (less common for zsh plugins)
      source "$plugin_path/$plugin_name.sh"
    # else
      # Optionally warn if directory exists but no loadable file found
      # echo "Warning: No loadable file found for plugin '$plugin_name' in $plugin_path"
    fi
  # else
    # Optionally warn if plugin directory doesn't exist
    # echo "Warning: Plugin directory not found for '$plugin_name': $plugin_path"
  fi
}

# ============================================================================
# Function: InstallPlugin
# Description: Clone a Zsh plugin repository if it doesn't already exist.
#              Requires 'git' command to be available.
# Usage: InstallPlugin repo_url plugin_name
# Arguments:
#   repo_url (required) - The Git repository URL of the plugin.
#   plugin_name (required) - The target directory name for the plugin.
# Returns: 0 on success or if already installed, 1 on git clone failure.
# ============================================================================
InstallPlugin() {
  local repo_url="$1"
  local plugin_name="$2"
  local plugin_path="$ZSH_PLUGIN_DIR/$plugin_name"

  if [[ ! -d "$plugin_path" ]]; then
    # Check if git exists first
    if ! command -v git &>/dev/null; then
         echo "${RED}ERROR:${RESET} 'git' command not found. Cannot install plugin '$plugin_name'." >&2
         return 1
    fi
    # Use messaging functions if available (might be too early?)
    echo "Installing plugin: $plugin_name" # Simple echo for robustness
    # Perform clone, capture status
    if git clone --depth=1 "$repo_url" "$plugin_path"; then
        return 0 # Success
    else
        echo "${RED}ERROR:${RESET} Failed to clone plugin '$plugin_name' from $repo_url." >&2
        # Clean up potentially empty directory
        rm -rf "$plugin_path" &>/dev/null || true
        return 1 # Failure
    fi
  else
    # Use messaging functions if available
    # echo "Plugin already installed: $plugin_name" # Simple echo
    return 0 # Already installed is success
  fi
}


# ============================================================================
# LOAD CORE PLUGINS (Examples - User should manage actual plugins)
# ============================================================================

# These are examples. Consider a mechanism for users to define *which* plugins to load.
# Maybe check for a user-defined list or source a separate user plugin file?

# Example: Auto-suggestions (fish-like suggestions)
if [[ -d "$ZSH_PLUGIN_DIR/zsh-autosuggestions" ]]; then
  LoadPlugin "zsh-autosuggestions"
  # Configuration (consider moving to where plugin is managed)
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=240"
  ZSH_AUTOSUGGEST_STRATEGY=(history completion)
fi

# Example: Syntax highlighting (must be loaded *after* completion setup ideally)
if [[ -d "$ZSH_PLUGIN_DIR/zsh-syntax-highlighting" ]]; then
  LoadPlugin "zsh-syntax-highlighting"
  # Configuration
  ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern cursor root) # Added root
fi

# Example: Fast directory switching (z)
if [[ -d "$ZSH_PLUGIN_DIR/zsh-z" ]]; then
  LoadPlugin "zsh-z"
  # Configuration
  _Z_CMD="j" # Common alternative command for z
  # Define data file location robustly within XDG structure if possible
  _Z_DATA="${XDG_CACHE_HOME:-$HOME/.cache}/z"
fi

# ============================================================================
# EXPORT HELPER FUNCTIONS (Optional)
# ============================================================================

# Export functions if they are intended to be called directly by the user
# or other scripts outside the rcForge loading sequence.
export -f LoadPlugin
export -f InstallPlugin

# EOF