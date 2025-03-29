#!/bin/bash
##########################################
# rcforge v2.0.0 - Universal Shell Configuration
# Main loader script that sources all configurations
# in the correct order based on hostname and shell
##########################################

# Set restrictive file permissions by default (no group/world access)
umask 077

# Set strict error handling
set -o nounset  # Treat unset variables as errors
set -o errexit  # Exit on error

# Function to display a nice warning header
display_warning_header() {
  echo
  echo -e "\033[0;33m██╗    ██╗ █████╗ ██████╗ ███╗   ██╗██╗███╗   ██╗ ██████╗ \033[0m"
  echo -e "\033[0;33m██║    ██║██╔══██╗██╔══██╗████╗  ██║██║████╗  ██║██╔════╝ \033[0m"
  echo -e "\033[0;33m██║ █╗ ██║███████║██████╔╝██╔██╗ ██║██║██╔██╗ ██║██║  ███╗\033[0m"
  echo -e "\033[0;33m██║███╗██║██╔══██║██╔══██╗██║╚██╗██║██║██║╚██╗██║██║   ██║\033[0m"
  echo -e "\033[0;33m╚███╔███╔╝██║  ██║██║  ██║██║ ╚████║██║██║ ╚████║╚██████╔╝\033[0m"
  echo -e "\033[0;33m ╚══╝╚══╝ ╚═╝  ╚═╝╚═════╝      ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ \033[0m"
  echo
}

# Check if running as root
check_root() {
  # Check if UID is 0 (root)
  if [[ $EUID -eq 0 || $(id -u) -eq 0 ]]; then
    # Check if we're running with sudo
    local sudo_user="${SUDO_USER:-}"
    local username="${sudo_user:-$USER}"
    
    display_warning_header
    echo -e "\033[0;31mError: This script should not be run as root or with sudo.\033[0m"
    echo -e "\033[0;33mRunning shell configuration tools as root can create files with"
    echo -e "incorrect permissions and cause security issues.\033[0m"
    echo
    echo -e "Please run this script as a regular user: \033[0;36m${username}\033[0m"
    echo
    echo -e "\033[0;33mIf you understand the risks and still want to proceed,"
    echo -e "set the RCFORGE_ALLOW_ROOT=1 environment variable:\033[0m"
    echo
    echo -e "  \033[0;36mRCFORGE_ALLOW_ROOT=1 source ~/.config/rcforge/rcforge.sh\033[0m"
    echo
    
    # Check for override environment variable
    if [[ -n "${RCFORGE_ALLOW_ROOT:-}" ]]; then
      echo -e "\033[0;33mWarning: Running as root due to RCFORGE_ALLOW_ROOT override.\033[0m"
      echo -e "\033[0;33mThis is not recommended for security reasons.\033[0m"
      echo
      return 0  # Allow execution to continue
    fi
    
    # Return error since this is being sourced (exit would close the shell)
    return 1
  fi
  
  # Not root, allow execution to continue
  return 0
}

# Check for root permissions before proceeding - but only return to allow sourcing
if ! check_root; then
  # Just return if sourced instead of exiting
  return 1 2>/dev/null || exit 1
fi

# Check for Bash version requirement if using Bash
if [[ -n "${BASH_VERSION:-}" ]]; then
  bash_major_version=${BASH_VERSION%%.*}

  if [[ "$bash_major_version" -lt 4 ]]; then
    echo "Error: rcForge v2.0.0 requires Bash 4.0 or higher"
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
    echo "For now, you can use your existing v1.x.x configuration, or run with a newer version of Bash."

    # Instead of exiting, which would prevent loading any configuration,
    # we'll disable the include system for older Bash versions
    RCFORGE_DISABLE_INCLUDE=1
    echo "Include system will be disabled due to Bash version requirement."
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
  export RCFORGE_SRC_LIB="$RCFORGE_ROOT/src/lib"
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

  # Primary directories (with preference for user files)
  export RCFORGE_ROOT="$RCFORGE_USER_DIR"
  export RCFORGE_SCRIPTS="$RCFORGE_USER_SCRIPTS"
  export RCFORGE_INCLUDES="$RCFORGE_USER_INCLUDES"
  export RCFORGE_CORE="$RCFORGE_SYS_DIR/core"
  export RCFORGE_UTILS="$RCFORGE_SYS_DIR/utils"
  export RCFORGE_SRC_LIB="$RCFORGE_SYS_DIR/src/lib"
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
if [[ -f "$RCFORGE_SRC_LIB/include-functions.sh" ]]; then
  source "$RCFORGE_SRC_LIB/include-functions.sh"
  debug_echo "Include functions loaded from $RCFORGE_SRC_LIB/include-functions.sh"
else
  debug_echo "Include functions not found at $RCFORGE_SRC_LIB/include-functions.sh"

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