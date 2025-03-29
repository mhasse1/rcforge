#!/bin/bash
# check-seq.sh - Detects sequence number conflicts in rcForge configuration

set -e  # Exit on error

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'  # Reset color

# Detect script directory and parent
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# Detect project root dynamically
detect_project_root() {
  local possible_roots=(
    "${RCFORGE_ROOT}"                  # Explicitly set environment variable
    "${PARENT_DIR}"                    # Parent of script directory
    "$HOME/src/rcforge"                # Common developer location
    "$HOME/Projects/rcforge"           # Alternative project location
    "$HOME/Development/rcforge"        # Another alternative
    "/usr/share/rcforge"               # System-wide location (Linux/Debian)
    "/opt/homebrew/share/rcforge"      # Homebrew on Apple Silicon
    "$(brew --prefix 2>/dev/null)/share/rcforge" # Homebrew (generic)
    "/opt/local/share/rcforge"         # MacPorts
    "/usr/local/share/rcforge"         # Alternative system location
    "$HOME/.config/rcforge"            # User configuration directory
  )

  for dir in "${possible_roots[@]}"; do
    if [[ -n "$dir" && -d "$dir" && -f "$dir/rcforge.sh" ]]; then
      echo "$dir"
      return 0
    fi
  done

  # If not found, default to user configuration directory
  echo "$HOME/.config/rcforge"
  return 0
}

# Detect if we're running in development mode
if [[ -n "${RCFORGE_DEV:-}" ]]; then
  # Development mode
  RCFORGE_DIR=$(detect_project_root)
  SCRIPTS_DIR="${RCFORGE_DIR}/scripts"
else
  # Production mode - Default to user configuration directory
  RCFORGE_DIR="${HOME}/.config/rcforge"
  SCRIPTS_DIR="${RCFORGE_DIR}/scripts"
  
  # Check if running from system installation
  if [[ "$SCRIPT_DIR" == "/usr/share/rcforge/core" || 
        "$SCRIPT_DIR" == "/opt/homebrew/share/rcforge/core" || 
        "$SCRIPT_DIR" == "/opt/local/share/rcforge/core" || 
        "$SCRIPT_DIR" == "/usr/local/share/rcforge/core" ]]; then
    # Still use user's scripts directory for checking conflicts
    SCRIPTS_DIR="${RCFORGE_DIR}/scripts"
  fi
fi

# Parse command line arguments
target_hostname=""
target_shell=""
check_all=0
fix_conflicts=0

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --hostname=*)
      target_hostname="${1#*=}"
      ;;
    --shell=*)
      target_shell="${1#*=}"
      ;;
    --all)
      check_all=1
      ;;
    --fix)
      fix_conflicts=1
      ;;
    --help)
      echo "Usage: $0 [--hostname=<name>] [--shell=bash|zsh] [--all] [--fix]"
      echo ""
      echo "Options:"
      echo "  --hostname=<name>  Check for conflicts from this hostname's perspective"
      echo "  --shell=bash|zsh   Check for conflicts in this shell"
      echo "  --all              Check all possible execution paths"
      echo "  --fix              Interactively fix conflicts by renumbering"
      echo "  --help             Show this help message"
      echo ""
      echo "If no options are provided, checks for conflicts in the current shell and hostname."
      exit 0
      ;;
    *)
      echo "Unknown parameter: $1"
      echo "Use --help for usage information."
      exit 1
      ;;
  esac
  shift
done

# Function to detect current shell
detect_shell() {
  if [[ -n "$ZSH_VERSION" ]]; then
    echo "zsh"
  elif [[ -n "$BASH_VERSION" ]]; then
    echo "bash"
  else
    # Fallback to checking $SHELL
    basename "$SHELL"
  fi
}

# Function to get the hostname, with fallback
get_hostname() {
  if command -v hostname >/dev/null 2>&1; then
    hostname | cut -d. -f1
  else
    # Fallback if hostname command not available
    hostname=${HOSTNAME:-$(uname -n | cut -d. -f1)}
    echo "$hostname"
  fi
}

# Get current shell and hostname if not specified
if [[ -z "$target_shell" ]]; then
  target_shell=$(detect_shell)
fi

if [[ -z "$target_hostname" ]]; then
  target_hostname=$(get_hostname)
fi

# Check if shell is valid
if [[ "$target_shell" != "bash" && "$target_shell" != "zsh" ]]; then
  echo -e "${RED}Error: Invalid shell specified: $target_shell${RESET}"
  echo "Valid shells: bash, zsh"
  exit 1
fi

# Function to display a nice warning header
display_warning_header() {
  echo
  echo -e "${YELLOW}██╗    ██╗ █████╗ ██████╗ ███╗   ██╗██╗███╗   ██╗ ██████╗ ${RESET}"
  echo -e "${YELLOW}██║    ██║██╔══██╗██╔══██╗████╗  ██║██║████╗  ██║██╔════╝ ${RESET}"
  echo -e "${YELLOW}██║ █╗ ██║███████║██████╔╝██╔██╗ ██║██║██╔██╗ ██║██║  ███╗${RESET}"
  echo -e "${YELLOW}██║███╗██║██╔══██║██╔══██╗██║╚██╗██║██║██║╚██╗██║██║   ██║${RESET}"
  echo -e "${YELLOW}╚███╔███╔╝██║  ██║██║  ██║██║ ╚████║██║██║ ╚████║╚██████╔╝${RESET}"
  echo -e "${YELLOW} ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝╚═╝  ╚═══╝ ╚═════╝ ${RESET}"
  echo
}

# Function to check for conflicts in a specific execution path
check_execution_path() {
  local check_hostname="$1"
  local check_shell="$2"
  local show_header="$3"
  local conflicts_found=0
  local -A sequence_files
  local conflict_list=()

  # Title for the execution path
  local path_title="${check_hostname}/${check_shell}"
  
  if [[ $show_header -eq 1 ]]; then
    echo -e "${BLUE}Checking sequence numbers for: ${CYAN}$path_title${RESET}"
  fi
  
  # Find all script files that would be included in this execution path
  while IFS= read -r file; do
    # Extract sequence number and target info from filename
    local filename=$(basename "$file")
    local seq_num="${filename%%_*}"
    local parts=(${filename//_/ })
    local hostname="${parts[1]}"
    local environment="${parts[2]}"
    
    # Check if file applies to this execution path
    if [[ "$environment" == "common" || "$environment" == "$check_shell" ]] && 
       [[ "$hostname" == "global" || "$hostname" == "$check_hostname" ]]; then
      # Check for conflicts
      if [[ -n "${sequence_files[$seq_num]}" ]]; then
        if [[ $conflicts_found -eq 0 && $show_header -eq 1 ]]; then
          display_warning_header
          echo -e "${YELLOW}Sequence number conflicts detected in path: $path_title${RESET}"
          conflicts_found=1
        elif [[ $conflicts_found -eq 0 ]]; then
          echo -e "${YELLOW}Conflicts in: $path_title${RESET}"
          conflicts_found=1
        fi
        
        echo -e "  ${RED}⚠️  Conflict: ${YELLOW}$seq_num${RESET} used by both:"
        echo -e "     - ${CYAN}${sequence_files[$seq_num]}${RESET}"
        echo -e "     - ${CYAN}$filename${RESET}"
        
        # Add to conflict list for potential fixing
        conflict_list+=("$seq_num:${sequence_files[$seq_num]}:$filename")
      fi
      sequence_files[$seq_num]="$filename"
    fi
  done < <(find "$SCRIPTS_DIR" -type f -name "[0-9]*_*_*_*.sh" | sort)
  
  # No conflicts found
  if [[ $conflicts_found -eq 0 && $show_header -eq 1 ]]; then
    echo -e "${GREEN}✓ No conflicts found in execution path: $path_title${RESET}"
  fi
  
  # Fix conflicts if requested
  if [[ $fix_conflicts -eq 1 && $conflicts_found -eq 1 ]]; then
    fix_path_conflicts "$check_hostname" "$check_shell" "${conflict_list[@]}"
  fi
  
  return $conflicts_found
}

# Function to fix conflicts by renumbering files
fix_path_conflicts() {
  local fix_hostname="$1"
  local fix_shell="$2"
  shift 2
  local conflict_list=("$@")
  
  echo -e "${CYAN}Fixing conflicts in execution path: $fix_hostname/$fix_shell...${RESET}"
  
  # Process each conflict
  for conflict in "${conflict_list[@]}"; do
    local seq_num=$(echo "$conflict" | cut -d: -f1)
    local file1=$(echo "$conflict" | cut -d: -f2)
    local file2=$(echo "$conflict" | cut -d: -f3)
    
    echo ""
    echo -e "${YELLOW}Conflict for sequence $seq_num:${RESET}"
    echo -e "  1. ${CYAN}$file1${RESET}"
    echo -e "  2. ${CYAN}$file2${RESET}"
    
    # Get the full paths
    local file1_path="$SCRIPTS_DIR/$file1"
    local file2_path="$SCRIPTS_DIR/$file2"
    
    # Ask which file should load first
    echo -e "${YELLOW}Which file should load first? (1/2/s[kip]): ${RESET}"
    read -r choice
    
    case "$choice" in
      1)
        # File 1 first, increment File 2's sequence number
        increment_sequence "$file2_path"
        ;;
      2)
        # File 2 first, increment File 1's sequence number
        increment_sequence "$file1_path"
        ;;
      s|S|skip)
        echo -e "${YELLOW}Skipping this conflict.${RESET}"
        ;;
      *)
        echo -e "${RED}Invalid choice. Skipping this conflict.${RESET}"
        ;;
    esac
  done
  
  echo -e "${GREEN}✓ Conflict resolution completed for $fix_hostname/$fix_shell${RESET}"
}

# Function to increment a file's sequence number
increment_sequence() {
  local file_path="$1"
  local filename=$(basename "$file_path")
  local seq_num="${filename%%_*}"
  local rest="${filename#*_}"
  
  # Find a new sequence number that's not in use
  local new_seq_num=$((10#$seq_num + 1))
  while [[ -f "$SCRIPTS_DIR/${new_seq_num}_${rest}" ]]; do
    ((new_seq_num++))
  done
  
  # Format the new sequence number with leading zeros
  new_seq_num=$(printf "%03d" $new_seq_num)
  
  # Rename the file
  local new_filename="${new_seq_num}_${rest}"
  local new_path="$SCRIPTS_DIR/$new_filename"
  
  mv "$file_path" "$new_path"
  echo -e "${GREEN}✓ Renamed: $filename -> $new_filename${RESET}"
}

# Check the specified execution path or all paths
any_conflicts=0

if [[ $check_all -eq 1 ]]; then
  echo -e "${BLUE}Checking all possible execution paths...${RESET}"
  
  # Get all hostnames used in the scripts
  hostnames=(global $(find "$SCRIPTS_DIR" -name "[0-9]*_*_*_*.sh" | grep -v "_global_" | sed -E 's/.*\/[0-9]+_([^_]+)_.*/\1/g' | sort -u))
  
  # Get all shells used in the scripts
  shells=("bash" "zsh")
  
  # Check each combination of hostname and shell
  for hostname in "${hostnames[@]}"; do
    for shell in "${shells[@]}"; do
      check_execution_path "$hostname" "$shell" 0
      if [[ $? -eq 1 ]]; then
        any_conflicts=1
      fi
    done
  done
else
  # Check only the specified or current execution path
  check_execution_path "$target_hostname" "$target_shell" 1
  if [[ $? -eq 1 ]]; then
    any_conflicts=1
  fi
fi

# Final message
if [[ $any_conflicts -eq 1 ]]; then
  if [[ $fix_conflicts -eq 0 ]]; then
    echo ""
    echo -e "${YELLOW}To fix these conflicts interactively, run:${RESET}"
    echo "  $0 --fix"
    echo ""
  else
    echo ""
    echo -e "${GREEN}Done fixing conflicts. Some files have been renamed.${RESET}"
    echo -e "${YELLOW}You may want to run this check again to ensure all conflicts are resolved.${RESET}"
    echo ""
  fi
else
  if [[ $check_all -eq 1 ]]; then
    echo -e "${GREEN}✓ No conflicts found in any execution path!${RESET}"
  fi
fi

exit $any_conflicts
# EOF
