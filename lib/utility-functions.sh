#!/bin/bash
# Common function to add to utility scripts for command-line usage

# Function to check if script is being sourced or executed directly
is_executed_directly() {
  # Check if script is being sourced (bash-specific method)
  if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # Script is being sourced
    return 1
  else
    # Script is being executed directly
    return 0
  fi
}

# Function to display version information
show_version() {
  echo "rcForge v0.2.0"
  echo "Copyright (c) 2025 Analog Edge LLC"
  echo "Released under the MIT License"
}

# Function to display help and usage information
show_help() {
  local script_name=$(basename "${BASH_SOURCE[0]}")
  
  # If called via a symlink, show the symlink name instead
  if [[ "$0" != "${BASH_SOURCE[0]}" ]]; then
    script_name=$(basename "$0")
  fi

  echo "Usage: $script_name [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --help, -h     Show this help message"
  echo "  --version, -v  Show version information"
  
  # Add script-specific options here
  # ...
  
  echo ""
}

# Function to process common command-line arguments
process_common_args() {
  # Process command-line arguments
  while [[ "$#" -gt 0 ]]; do
    case $1 in
      --help|-h)
        show_help
        exit 0
        ;;
      --version|-v)
        show_version
        exit 0
        ;;
      *)
        # Return the unprocessed argument for script-specific handling
        echo "$1"
        return 0
        ;;
    esac
    shift
  done
  
  return 0
}

# Main entry point when executed directly
if is_executed_directly; then
  # Process common arguments first
  for arg in "$@"; do
    processed=$(process_common_args "$arg")
    
    # If processed is empty, the argument was handled
    if [[ -n "$processed" ]]; then
      # Handle script-specific arguments here
      # ...
      true
    fi
  done
  
  # Script-specific functionality when executed directly
  # ...
fi
# EOF
