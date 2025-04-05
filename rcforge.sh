#!/usr/bin/env bash
##########################################
# rcforge v0.2.0 - Universal Shell Configuration
# Main loader script that sources all configurations
# in the correct order based on hostname and shell
# Author: Mark Hasse
# Date: 2025-04-05
##########################################

# Set strict error handling
set -o nounset  # Treat unset variables as errors
set -o errexit  # Exit immediately if a command exits with a non-zero status

# Check for Bash version requirement if using Bash
if [[ -n "${BASH_VERSION:-}" ]]; then
  bash_major_version=${BASH_VERSION%%.*}

  if [[ "$bash_major_version" -lt 4 ]]; then
    echo "Error: rcForge v0.2.0 requires Bash 4.0 or higher"
    echo "Your current Bash version is: $BASH_VERSION"
    echo ""
    echo "On macOS, you can install a newer version with Homebrew:"
    echo "  brew install bash"
    echo ""
    echo "Then add it to your available shells:"
    echo "  sudo bash -c 'echo /opt/homebrew/bin/bash >> /etc/shells'"
    echo ""
    echo "And optionally set it as your default shell:"
    echo "  chsh -s /opt/homebrew/bin/bash"
    echo ""
    echo "For now, you can use your existing v0.1.x configuration, or run with a newer version of Bash."

    # Instead of exiting, which would prevent loading any configuration,
    # we'll disable the include system for older Bash versions
    RCFORGE_DISABLE_INCLUDE=1
    echo "Include system will be disabled due to Bash version requirement."
  fi
fi

# Check for root execution (security feature)
if [[ $EUID -eq 0 ]]; then
  if [[ -z "${RCFORGE_ALLOW_ROOT:-}" ]]; then
    echo "WARNING: rcForge should not be run as root for security reasons."
    echo "If you must proceed, set RCFORGE_ALLOW_ROOT=1 in your environment."
    echo "See the security guide for more information."
    # We don't exit here to maintain backward compatibility
  else
    echo "WARNING: Running as root with RCFORGE_ALLOW_ROOT override. This is not recommended."
  fi
fi

# Detect if we're running in development mode
if [[ -n "${RCFORGE_DEV:-}" ]]; then
  # Development mode - Use the Git repository structure
  export RCFORGE_ROOT="$HOME/src/rcforge"
  export RCFORGE_SCRIPTS="$RCFORGE_ROOT/scripts"
  export RCFORGE_CORE="$RCFORGE_ROOT/core"
  export RCFORGE_UTILS="$RCFORGE_ROOT/utils"
  export RCFORGE_INCLUDES="$RCFORGE_ROOT/include"
  export RCFORGE_LIB="$RCFORGE_ROOT/lib"
  export RCFORGE_SKEL="$RCFORGE_ROOT/skel"
else
  # Production mode
  # Configure user level directories
  export RCFORGE_USER_DIR="$HOME/.config/rcforge"
  export RCFORGE_USER_SCRIPTS="$RCFORGE_USER_DIR/scripts"
  export RCFORGE_USER_INCLUDES="$RCFORGE_USER_DIR/include"

  # Check for system level installation
  if [[ -d "/usr/share/rcforge" ]]; then
    export RCFORGE_SYS_DIR="/usr/share/rcforge"
  elif [[ -d "/opt/homebrew/share/rcforge" ]]; then
    export RCFORGE_SYS_DIR="/opt/homebrew/share/rcforge"
  elif [[ -d "/usr/local/share/rcforge" ]]; then
    export RCFORGE_SYS_DIR="/usr/local/share/rcforge"
  else
    export RCFORGE_SYS_DIR="$HOME/.config/rcforge"
  fi

  export RCFORGE_SYS_INCLUDES="$RCFORGE_SYS_DIR/include"
  export RCFORGE_SKEL="$RCFORGE_SYS_DIR/skel"

  # Primary directories (with preference for user files)
  export RCFORGE_ROOT="$RCFORGE_USER_DIR"
  export RCFORGE_SCRIPTS="$RCFORGE_USER_SCRIPTS"
  export RCFORGE_INCLUDES="$RCFORGE_USER_INCLUDES"
  export RCFORGE_CORE="$RCFORGE_SYS_DIR/core"
  export RCFORGE_UTILS="$RCFORGE_SYS_DIR/utils"
  export RCFORGE_LIB="$RCFORGE_SYS_DIR/lib"
  
  # Check if user directories exist, if not try to create them
  if [[ ! -d "$RCFORGE_USER_DIR" ]]; then
    # Try to create user config directory and populate from skel if available
    if [[ -d "$RCFORGE_SKEL" ]]; then
      echo "Initializing new rcForge user configuration from skeleton..."
      mkdir -p "$RCFORGE_USER_DIR"
      cp -R "$RCFORGE_SKEL"/* "$RCFORGE_USER_DIR"/ 2>/dev/null || true
      # Set appropriate permissions
      chmod -R 700 "$RCFORGE_USER_DIR"
      find "$RCFORGE_USER_DIR" -type f -name "*.sh" -exec chmod 700 {} \; 2>/dev/null || true
      find "$RCFORGE_USER_DIR" -type f -not -name "*.sh" -exec chmod 600 {} \; 2>/dev/null || true
    else
      # Create basic directory structure if skel not available
      mkdir -p "$RCFORGE_USER_SCRIPTS" "$RCFORGE_USER_INCLUDES"
      mkdir -p "$RCFORGE_USER_DIR/exports" "$RCFORGE_USER_DIR/checksums" "$RCFORGE_USER_DIR/docs"
      chmod -R 700 "$RCFORGE_USER_DIR"
    fi
  fi
fi

# Uncomment for debugging
# export SHELL_DEBUG=1

# Simple debug function if core functions not available
debug_echo() {
  if [[ -n "${SHELL_DEBUG:-}" ]]; then
    echo "DEBUG: $*" >&2
  fi
}

# Source core functions if available
if [[ -f "$RCFORGE_CORE/functions.sh" ]]; then
  source "$RCFORGE_CORE/functions.sh"
  debug_echo "Core functions loaded from $RCFORGE_CORE/functions.sh"
else
  debug_echo "Core functions not found at $RCFORGE_CORE/functions.sh"

  # Function to detect current shell
  detect_shell() {
    if [[ -n "${ZSH_VERSION:-}" ]]; then
      shell_name="zsh"
    elif [[ -n "${BASH_VERSION:-}" ]]; then
      shell_name="bash"
    else
      # Fallback to checking $SHELL
      shell_name=$(basename "$SHELL")
    fi
    export shell_name
    debug_echo "Detected shell: $shell_name"
  }

  # Function to get the hostname, with fallback
  get_hostname() {
    if command -v hostname >/dev/null 2>&1; then
      hostname=$(hostname | cut -d. -f1)
    else
      # Fallback if hostname command not available
      hostname=${HOSTNAME:-$(uname -n | cut -d. -f1)}
    fi
    export current_hostname="${hostname}"
    debug_echo "Detected hostname: $current_hostname"
  }

  # Function to source a single file if it exists and is readable
  source_file() {
    local file="$1"
    local desc="${2:-file}"

    if [[ -f "$file" && -r "$file" ]]; then
      debug_echo "Loading $desc: $file"
      # shellcheck disable=SC1090
      source "$file"
      return 0
    else
      debug_echo "Skipping $desc (not found or not readable): $file"
      return 1
    fi
  }
fi

# Load include system if available
if [[ -f "$RCFORGE_LIB/include-functions.sh" ]]; then
  source "$RCFORGE_LIB/include-functions.sh"
  debug_echo "Include functions loaded from $RCFORGE_LIB/include-functions.sh"
else
  debug_echo "Include functions not found at $RCFORGE_LIB/include-functions.sh"

  # Simple include_function stub for compatibility
  include_function() {
    debug_echo "Warning: include_function called but include system not available"
    debug_echo "  Attempted to include: $1/$2"
    return 1
  }

  # Simple include_category stub for compatibility
  include_category() {
    debug_echo "Warning: include_category called but include system not available"
    debug_echo "  Attempted to include category: $1"
    return 1
  }
fi

# Start timing for performance measurement
if [[ -n "${SHELL_DEBUG:-}" ]]; then
  if command -v date >/dev/null 2>&1; then
    start_time=$(date +%s.%N 2>/dev/null) || start_time=$SECONDS
  else
    start_time=$SECONDS
  fi
fi

# Detect current shell and hostname
detect_shell
get_hostname

# Helper function to match and source files with the correct pattern
source_platform_files() {
  local pattern_global_common="[0-9]*_global_common_*.sh"
  local pattern_global_shell="[0-9]*_global_${shell_name}_*.sh"
  local pattern_hostname_common="[0-9]*_${current_hostname}_common_*.sh"
  local pattern_hostname_shell="[0-9]*_${current_hostname}_${shell_name}_*.sh"

  # Load all matching files in sequence order
  if [[ -d "$RCFORGE_SCRIPTS" ]]; then
    debug_echo "Finding applicable configuration files..."
    find "$RCFORGE_SCRIPTS" -maxdepth 1 -type f \( -name "$pattern_global_common" -o -name "$pattern_global_shell" -o -name "$pattern_hostname_common" -o -name "$pattern_hostname_shell" \) | sort | while read -r file; do
      source_file "$file" "$(basename "$file")"
    done
  else
    echo "WARNING: Scripts directory not found: $RCFORGE_SCRIPTS" >&2
    debug_echo "No configuration files will be loaded"
  fi
}

# Source all configuration files in sequence order
debug_echo "Loading configuration from $RCFORGE_SCRIPTS"
source_platform_files

# Calculate and report loading time if debugging is enabled
if [[ -n "${SHELL_DEBUG:-}" ]]; then
  if command -v date >/dev/null 2>&1 && [[ "$start_time" != "$SECONDS" ]]; then
    end_time=$(date +%s.%N 2>/dev/null)
    elapsed=$(echo "$end_time - $start_time" | bc 2>/dev/null)
    debug_echo "Shell configuration loaded in $elapsed seconds"
  else
    debug_echo "Shell configuration loaded successfully"
  fi
fi

# Run automated checks if enabled
if [[ -z "${RCFORGE_NO_CHECKS:-}" ]]; then
  # Check for sequence conflicts
  if [[ -f "$RCFORGE_CORE/check-seq.sh" ]]; then
    bash "$RCFORGE_CORE/check-seq.sh" >/dev/null 2>&1 || true
  fi

  # Verify RC file checksums
  if [[ -f "$RCFORGE_CORE/check-checksums.sh" ]]; then
    bash "$RCFORGE_CORE/check-checksums.sh" >/dev/null 2>&1 || true
  fi
fi

##########################################
# End of configuration
##########################################
# EOF
