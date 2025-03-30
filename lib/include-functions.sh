#!/bin/bash
# include-functions.sh - Core functions for the include system
# Author: Mark Hasse
# Date: March 28, 2025

# Keep track of included functions to avoid duplicates
declare -A _INCLUDED_FUNCTIONS

# Keep track of category paths to speed up lookups
declare -A _CATEGORY_PATHS

# Check if include system is disabled
if [[ -n "${RCFORGE_DISABLE_INCLUDE:-}" ]]; then
  # Simple include_function stub for compatibility
  include_function() {
    debug_echo "Warning: include_function called but include system is disabled (requires Bash 4.0+)"
    debug_echo "  Attempted to include: $1/$2"
    return 1
  }

  # Simple include_category stub for compatibility
  include_category() {
    debug_echo "Warning: include_category called but include system is disabled (requires Bash 4.0+)"
    debug_echo "  Attempted to include category: $1"
    return 1
  }

  # Simple list function stub
  list_available_functions() {
    echo "Include system is disabled (requires Bash 4.0+)"
    return 1
  }

  # Export stubs
  export -f include_function
  export -f include_category
  export -f list_available_functions

  # Return early to avoid processing the rest of the file
  return
fi

# Function to determine the rcForge directory structure
get_rcforge_paths() {
  # Set up paths based on environment
  if [[ -n "${RCFORGE_DEV}" ]]; then
    # Development mode
    export RCFORGE_ROOT="${RCFORGE_ROOT:-$HOME/src/rcforge}"
    export RCFORGE_SYS_INCLUDE="${RCFORGE_SYS_INCLUDE:-$RCFORGE_ROOT/include}"
    export RCFORGE_SYS_LIB="${RCFORGE_SYS_LIB:-$RCFORGE_ROOT/lib}"
  else
    # Determine system directories based on available installations
    if [[ -d "/usr/share/rcforge" ]]; then
      # System installation on Linux
      export RCFORGE_SYS_DIR="/usr/share/rcforge"
    elif [[ -d "/opt/homebrew/share/rcforge" ]]; then
      # Homebrew installation on Apple Silicon
      export RCFORGE_SYS_DIR="/opt/homebrew/share/rcforge"
    elif [[ -n "$(which brew 2>/dev/null)" && -d "$(brew --prefix 2>/dev/null)/share/rcforge" ]]; then
      # Homebrew installation (generic)
      export RCFORGE_SYS_DIR="$(brew --prefix)/share/rcforge"
    elif [[ -d "$HOME/.config/rcforge" && -f "$HOME/.config/rcforge/rcforge.sh" ]]; then
      # User-only installation
      export RCFORGE_SYS_DIR="$HOME/.config/rcforge"
    else
      # Fallback - try current rcforge installation
      export RCFORGE_SYS_DIR="${RCFORGE_SYS_DIR:-$HOME/.config/rcforge}"
    fi

    # User directories
    export RCFORGE_ROOT="${RCFORGE_ROOT:-$HOME/.config/rcforge}"

    # System include and lib directories
    export RCFORGE_SYS_INCLUDE="${RCFORGE_SYS_INCLUDE:-$RCFORGE_SYS_DIR/include}"
    export RCFORGE_SYS_LIB="${RCFORGE_SYS_LIB:-$RCFORGE_SYS_DIR/lib}"
  fi

  # User include directory
  export RCFORGE_USER_INCLUDE="${RCFORGE_USER_INCLUDE:-$RCFORGE_ROOT/include}"

  debug_echo "rcForge paths:"
  debug_echo "  Root: $RCFORGE_ROOT"
  debug_echo "  System include: $RCFORGE_SYS_INCLUDE"
  debug_echo "  System lib: $RCFORGE_SYS_LIB"
  debug_echo "  User include: $RCFORGE_USER_INCLUDE"
}

# Initialize paths on load
get_rcforge_paths

# Function to include a specific function from the include system
# Usage: include_function category function_name
include_function() {
  local category="$1"
  local function_name="$2"
  local quiet="${3:-0}"

  # Skip if already included
  if [[ -n "${_INCLUDED_FUNCTIONS[$function_name]}" ]]; then
    [[ "$quiet" -eq 0 ]] && debug_echo "Function already included: $function_name"
    return 0
  fi

  # Determine search paths
  if [[ -z "${_CATEGORY_PATHS[$category]}" ]]; then
    # Update paths in case environment has changed
    get_rcforge_paths

    # Set search path for this category
    local user_path="$RCFORGE_USER_INCLUDE/$category"
    local sys_path="$RCFORGE_SYS_INCLUDE/$category"

    # Store the path list for this category
    _CATEGORY_PATHS[$category]="$user_path:$sys_path"
  fi

  # Search for the function
  local found=0
  IFS=':' read -ra search_paths <<< "${_CATEGORY_PATHS[$category]}"
  for search_dir in "${search_paths[@]}"; do
    local func_file="$search_dir/$function_name.sh"

    if [[ -f "$func_file" && -r "$func_file" ]]; then
      [[ "$quiet" -eq 0 ]] && debug_echo "Including function: $function_name from $func_file"

      # Source the function file
      source "$func_file"

      # Mark as included
      _INCLUDED_FUNCTIONS[$function_name]=1

      found=1
      break
    fi
  done

  if [[ $found -eq 0 ]]; then
    [[ "$quiet" -eq 0 ]] && debug_echo "Warning: Function not found: $category/$function_name"
    return 1
  fi

  return 0
}

# Function to include all functions in a category
# Usage: include_category category
include_category() {
  local category="$1"
  local quiet="${2:-0}"
  local count=0

  # Determine search paths
  if [[ -z "${_CATEGORY_PATHS[$category]}" ]]; then
    # Update paths in case environment has changed
    get_rcforge_paths

    # Set search path for this category
    local user_path="$RCFORGE_USER_INCLUDE/$category"
    local sys_path="$RCFORGE_SYS_INCLUDE/$category"

    # Store the path list for this category
    _CATEGORY_PATHS[$category]="$user_path:$sys_path"
  fi

  # Search for functions
  IFS=':' read -ra search_paths <<< "${_CATEGORY_PATHS[$category]}"
  for search_dir in "${search_paths[@]}"; do
    if [[ -d "$search_dir" ]]; then
      for func_file in "$search_dir"/*.sh; do
        if [[ -f "$func_file" && -r "$func_file" ]]; then
          local function_name=$(basename "$func_file" .sh)

          # Skip if already included
          if [[ -n "${_INCLUDED_FUNCTIONS[$function_name]}" ]]; then
            continue
          fi

          [[ "$quiet" -eq 0 ]] && debug_echo "Including function: $function_name from $func_file"

          # Source the function file
          source "$func_file"

          # Mark as included
          _INCLUDED_FUNCTIONS[$function_name]=1

          ((count++))
        fi
      done
    fi
  done

  [[ "$quiet" -eq 0 ]] && debug_echo "Included $count functions from category: $category"

  return 0
}

# Function to show all available functions
# Usage: list_available_functions [category]
list_available_functions() {
  local target_category="$1"

  # Update paths in case environment has changed
  get_rcforge_paths

  local sys_include_dir="$RCFORGE_SYS_INCLUDE"
  local user_include_dir="$RCFORGE_USER_INCLUDE"

  echo "Available Functions:"
  echo "===================="

  # If category is specified, only list that category
  if [[ -n "$target_category" ]]; then
    echo "Category: $target_category"
    echo "------------------"

    # Check user directory first
    if [[ -d "$user_include_dir/$target_category" ]]; then
      for func_file in "$user_include_dir/$target_category"/*.sh; do
        if [[ -f "$func_file" ]]; then
          local function_name=$(basename "$func_file" .sh)
          echo "  $function_name (user)"
        fi
      done
    fi

    # Then check system directory
    if [[ -d "$sys_include_dir/$target_category" ]]; then
      for func_file in "$sys_include_dir/$target_category"/*.sh; do
        if [[ -f "$func_file" ]]; then
          local function_name=$(basename "$func_file" .sh)
          # Skip if already listed from user directory
          if [[ ! -f "$user_include_dir/$target_category/$function_name.sh" ]]; then
            echo "  $function_name (system)"
          fi
        fi
      done
    fi

    return
  fi

  # List all categories and functions
  # First get all categories
  local categories=()

  # Add categories from system directory
  if [[ -d "$sys_include_dir" ]]; then
    for dir in "$sys_include_dir"/*/; do
      if [[ -d "$dir" ]]; then
        local category=$(basename "$dir")
        categories+=("$category")
      fi
    done
  fi

  # Add categories from user directory
  if [[ -d "$user_include_dir" ]]; then
    for dir in "$user_include_dir"/*/; do
      if [[ -d "$dir" ]]; then
        local category=$(basename "$dir")
        # Add only if not already in list
        if [[ ! " ${categories[@]} " =~ " $category " ]]; then
          categories+=("$category")
        fi
      fi
    done
  fi

  # Sort categories
  IFS=$'\n' categories=($(sort <<<"${categories[*]}"))
  unset IFS

  # List functions by category
  for category in "${categories[@]}"; do
    echo "Category: $category"
    echo "------------------"

    # Check user directory first
    if [[ -d "$user_include_dir/$category" ]]; then
      for func_file in "$user_include_dir/$category"/*.sh; do
        if [[ -f "$func_file" ]]; then
          local function_name=$(basename "$func_file" .sh)
          echo "  $function_name (user)"
        fi
      done
    fi

    # Then check system directory
    if [[ -d "$sys_include_dir/$category" ]]; then
      for func_file in "$sys_include_dir/$category"/*.sh; do
        if [[ -f "$func_file" ]]; then
          local function_name=$(basename "$func_file" .sh)
          # Skip if already listed from user directory
          if [[ ! -f "$user_include_dir/$category/$function_name.sh" ]]; then
            echo "  $function_name (system)"
          fi
        fi
      done
    fi

    echo ""
  done
}

# Export functions so they're available to other scripts
export -f include_function
export -f include_category
export -f list_available_functions
export -f get_rcforge_paths
# EOF