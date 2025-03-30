#!/bin/bash
# create-include.sh - Create a new include function file
# Author: Mark Hasse
# Date: March 29, 2025

set -e  # Exit on error

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'  # Reset color

# Check if script is being sourced or executed directly
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
  echo "rcForge v0.2.0 - Include Function Creator"
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
  echo "  --name=NAME          Function name"
  echo "  --category=CATEGORY  Function category"
  echo "  --desc=DESCRIPTION   Function description"
  echo "  --args=ARGUMENTS     Function arguments"
  echo "  --system             Create in system include directory (requires admin permission)"
  echo "  --force              Overwrite existing function"
  echo "  --help, -h           Show this help message"
  echo "  --version, -v        Show version information"
  echo ""
  echo "Examples:"
  echo "  $script_name                       # Interactive mode"
  echo "  $script_name --name=my_function --category=common  # Specify basic options"
  echo "  $script_name --name=parse_json --category=text --desc=\"Parse JSON data\" --args=\"json_string\" # Full specification"
  echo ""
}

# Parse command line arguments
function_name=""
category=""
description=""
arguments=""
force=0
use_system=0

# Process command-line arguments
process_args() {
  while [[ "$#" -gt 0 ]]; do
    case $1 in
      --name=*)
        function_name="${1#*=}"
        ;;
      --category=*)
        category="${1#*=}"
        ;;
      --desc=*|--description=*)
        description="${1#*=}"
        ;;
      --args=*|--arguments=*)
        arguments="${1#*=}"
        ;;
      --system)
        use_system=1
        ;;
      --force)
        force=1
        ;;
      --help|-h)
        show_help
        exit 0
        ;;
      --version|-v)
        show_version
        exit 0
        ;;
      *)
        echo -e "${RED}Unknown parameter: $1${RESET}"
        show_help
        exit 1
        ;;
    esac
    shift
  done
}

# Determine rcForge paths
determine_paths() {
  # Detect if we're running in development mode
  if [[ -n "${RCFORGE_DEV}" ]]; then
    # Development mode
    RCFORGE_DIR="$HOME/src/rcforge"
    SYS_INCLUDE_DIR="$RCFORGE_DIR/include"
  else
    # Production mode - Detect system installation
    if [[ -d "/usr/share/rcforge" ]]; then
      RCFORGE_SYS_DIR="/usr/share/rcforge"
    elif [[ -d "/opt/homebrew/share/rcforge" ]]; then
      RCFORGE_SYS_DIR="/opt/homebrew/share/rcforge"
    elif [[ -n "$(which brew 2>/dev/null)" && -d "$(brew --prefix 2>/dev/null)/share/rcforge" ]]; then
      RCFORGE_SYS_DIR="$(brew --prefix)/share/rcforge"
    else
      RCFORGE_SYS_DIR="$HOME/.config/rcforge"
    fi
    SYS_INCLUDE_DIR="$RCFORGE_SYS_DIR/include"
  fi

  # User level directories
  USER_DIR="$HOME/.config/rcforge"
  USER_INCLUDE_DIR="$USER_DIR/include"
}

# Interactive mode
run_interactive_mode() {
  # Display header
  echo -e "${BLUE}┌──────────────────────────────────────────────────────┐${RESET}"
  echo -e "${BLUE}│ rcForge Include File Creator                         │${RESET}"
  echo -e "${BLUE}└──────────────────────────────────────────────────────┘${RESET}"
  echo ""
  
  # Determine which include directory to use
  if [[ $use_system -eq 1 ]]; then
    INCLUDE_DIR="$SYS_INCLUDE_DIR"
    echo -e "${CYAN}Using system include directory: ${YELLOW}$INCLUDE_DIR${RESET}"
  else
    INCLUDE_DIR="$USER_INCLUDE_DIR"
    echo -e "${CYAN}Using user include directory: ${YELLOW}$INCLUDE_DIR${RESET}"
  
    # Ask if the user wants to use the system directory instead
    if [[ -d "$SYS_INCLUDE_DIR" && -z "$category" ]]; then
      echo -e "${YELLOW}Which include directory do you want to use?${RESET}"
      echo "1) User directory: $USER_INCLUDE_DIR (default)"
      echo "2) System directory: $SYS_INCLUDE_DIR"
      read -r choice
  
      if [[ "$choice" == "2" ]]; then
        INCLUDE_DIR="$SYS_INCLUDE_DIR"
        echo -e "${CYAN}Switched to system include directory: ${YELLOW}$INCLUDE_DIR${RESET}"
      fi
    fi
  fi
  
  # Ask for category if not provided
  if [[ -z "$category" ]]; then
    echo -e "${CYAN}Available categories:${RESET}"
    categories=()
  
    # Get existing categories from both user and system directories
    for dir in "$INCLUDE_DIR"/*/; do
      if [[ -d "$dir" ]]; then
        local category_name=$(basename "$dir")
        categories+=("$category_name")
        echo "  $category_name"
      fi
    done
  
    # Also check system directory if we're using user directory
    if [[ "$INCLUDE_DIR" == "$USER_INCLUDE_DIR" && "$INCLUDE_DIR" != "$SYS_INCLUDE_DIR" ]]; then
      for dir in "$SYS_INCLUDE_DIR"/*/; do
        if [[ -d "$dir" ]]; then
          local category_name=$(basename "$dir")
          # Only add if not already in the list
          if [[ ! " ${categories[@]} " =~ " $category_name " ]]; then
            categories+=("$category_name")
            echo "  $category_name (system)"
          fi
        fi
      done
    fi
  
    if [[ ${#categories[@]} -eq 0 ]]; then
      echo "  No categories found."
      echo -e "${YELLOW}Creating a new category...${RESET}"
    fi
  
    echo ""
    echo -e "${YELLOW}Enter category (existing or new):${RESET}"
    read -r category
  fi
  
  # Ask for function name if not provided
  if [[ -z "$function_name" ]]; then
    echo -e "${YELLOW}Enter function name:${RESET}"
    read -r function_name
  fi
  
  # Ask for function description if not provided
  if [[ -z "$description" ]]; then
    echo -e "${YELLOW}Enter function description:${RESET}"
    read -r description
  fi
  
  # Ask for function arguments if not provided
  if [[ -z "$arguments" ]]; then
    echo -e "${YELLOW}Enter function arguments (e.g., 'filepath' or 'url name'):${RESET}"
    read -r arguments
  fi
}

# Create the include function file
create_include_file() {
  # Create category if it doesn't exist
  category_dir="$INCLUDE_DIR/$category"
  if [[ ! -d "$category_dir" ]]; then
    mkdir -p "$category_dir"
    echo -e "${GREEN}✓ Created new category: $category${RESET}"
  fi
  
  # Create function file path
  function_file="$category_dir/$function_name.sh"
  
  # Check if function already exists
  if [[ -f "$function_file" && "$force" -eq 0 ]]; then
    echo -e "${RED}Function already exists: $function_file${RESET}"
    echo -e "${YELLOW}Do you want to overwrite it? (y/n)${RESET}"
    read -r overwrite
  
    if [[ ! "$overwrite" =~ ^[Yy] ]]; then
      echo -e "${RED}Operation cancelled.${RESET}"
      exit 1
    fi
  fi
  
  # Get author name
  author=${AUTHOR:-"$(git config user.name 2>/dev/null || echo 'Your Name')"}
  
  # Create function file
  cat > "$function_file" << EOF
#!/bin/bash
# $function_name.sh - $description
# Category: $category
# Author: $author
# Date: $(date +%F)

# Function: $function_name
# Description: $description
# Usage: $function_name $arguments
$function_name() {
  # Function implementation
  echo "Function $function_name not implemented yet"
}

# Export the function
export -f $function_name
EOF
  
  # Make it executable
  chmod +x "$function_file"
  
  echo -e "${GREEN}✓ Created function file: $function_file${RESET}"
  echo ""
  echo -e "${YELLOW}Edit the file to implement the function:${RESET}"
  echo "  \$EDITOR $function_file"
  echo ""
  echo -e "${YELLOW}To include this function in your scripts, use:${RESET}"
  echo "  include_function $category $function_name"
  echo ""
}

# Offer to edit the file
offer_to_edit() {
  echo -e "${YELLOW}Do you want to edit the file now? (y/n)${RESET}"
  read -r edit_now
  
  if [[ "$edit_now" =~ ^[Yy] ]]; then
    # Try to determine the best editor
    editor=${EDITOR:-$(which vim || which nano || which vi)}
    if [[ -n "$editor" ]]; then
      $editor "$function_file"
    else
      echo -e "${RED}No editor found. Please edit the file manually.${RESET}"
    fi
  fi
}

# Main function
main() {
  # Determine paths
  determine_paths
  
  # Process command line arguments
  process_args "$@"
  
  # Run in interactive mode if not all parameters are specified
  if [[ -z "$function_name" || -z "$category" ]]; then
    run_interactive_mode
  fi
  
  # Create the include function file
  create_include_file
  
  # Offer to edit the file
  offer_to_edit
}

# Run main function if executed directly
if is_executed_directly; then
  main "$@"
fi
# EOF
