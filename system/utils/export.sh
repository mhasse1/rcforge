#!/usr/bin/env bash
# export.sh - Export shell configurations for remote servers
# Author: rcForge Team
# Date: 2025-04-06
# Version: 0.3.0
# RC Summary: Exports rcForge shell configurations for use on remote systems
# Description: Exports shell configurations with flexible options for use on remote servers

# Source necessary libraries
if [[ -f "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/shell-colors.sh" ]]; then
  source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/shell-colors.sh"
else
  # Minimal color definitions if shell-colors.sh is not available
  export RED='\033[0;31m'
  export GREEN='\033[0;32m'
  export YELLOW='\033[0;33m'
  export BLUE='\033[0;34m'
  export CYAN='\033[0;36m'
  export RESET='\033[0m'
  
  # Minimal message functions
  ErrorMessage() { echo -e "${RED}ERROR:${RESET} $1" >&2; }
  WarningMessage() { echo -e "${YELLOW}WARNING:${RESET} $1" >&2; }
  InfoMessage() { echo -e "${BLUE}INFO:${RESET} $1"; }
  SuccessMessage() { echo -e "${GREEN}SUCCESS:${RESET} $1"; }
fi

if [[ -f "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/utility-functions.sh" ]]; then
  source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/utility-functions.sh"
fi

# Set strict error handling
set -o nounset  # Treat unset variables as errors
set -o errexit  # Exit immediately if a command exits with a non-zero status

# ============================================================================
# CONFIGURATION VARIABLES
# ============================================================================

# Default export directory
readonly gc_default_export_dir="${HOME}/.config/rcforge/exports"

# Configuration variables
SHELL_TYPE=""
HOSTNAME=""
OUTPUT_FILE=""
VERBOSE_MODE=false
KEEP_DEBUG=false
STRIP_COMMENTS=true
FORCE_OVERWRITE=false

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Function: ShowSummary
# Description: Display one-line summary for rc help
# Usage: ShowSummary
ShowSummary() {
  echo "Exports rcForge shell configurations for use on remote systems"
}

# Function: ShowHelp
# Description: Display help information
# Usage: ShowHelp
ShowHelp() {
  echo "export - rcForge Configuration Export Utility"
  echo ""
  echo "Description:"
  echo "  Exports shell configurations with flexible options for use on remote servers"
  echo "  allowing you to create portable configuration files."
  echo ""
  echo "Usage:"
  echo "  rc export [options]"
  echo ""
  echo "Options:"
  echo "  --shell=TYPE         Specify shell type (bash or zsh) [REQUIRED]"
  echo "  --hostname=NAME      Filter configurations for specific hostname"
  echo "  --output=FILE        Specify output file path"
  echo "  --verbose, -v        Enable verbose output"
  echo "  --keep-debug         Preserve debug statements"
  echo "  --force, -f          Overwrite existing output file"
  echo "  --help, -h           Show this help message"
  echo "  --summary            Show a one-line description (for rc help)"
  echo ""
  echo "Examples:"
  echo "  rc export --shell=bash                 # Export all Bash configurations"
  echo "  rc export --shell=zsh --hostname=laptop # Export Zsh configs for 'laptop'"
  echo "  rc export --shell=bash --output=~/bashrc.exported"
}

# Function: DetectProjectRoot
# Description: Dynamically detect the rcForge base directory
# Usage: DetectProjectRoot
# Returns: Path to the project root directory
DetectProjectRoot() {
  echo "${RCFORGE_ROOT:-$HOME/.config/rcforge}"
}

# Function: ValidateShellType
# Description: Validate shell type is supported
# Usage: ValidateShellType shell_type
# Returns: 0 if valid, 1 if invalid
ValidateShellType() {
  local shell="$1"
  if [[ "$shell" != "bash" && "$shell" != "zsh" ]]; then
    ErrorMessage "Invalid shell type. Must be 'bash' or 'zsh'."
    return 1
  fi
  return 0
}

# Function: FindConfigFiles
# Description: Find config files matching criteria 
# Usage: FindConfigFiles shell_type [hostname]
# Returns: List of config files
FindConfigFiles() {
  local shell_type="$1"
  local hostname="${2:-}"
  local scripts_dir="${RCFORGE_DIR}/rc-scripts"

  # Build pattern for file matching
  local patterns=(
    "[0-9]*_global_common_*.sh"
    "[0-9]*_global_${shell_type}_*.sh"
  )

  # Add hostname-specific patterns if provided
  if [[ -n "$hostname" ]]; then
    patterns+=(
      "[0-9]*_${hostname}_common_*.sh"
      "[0-9]*_${hostname}_${shell_type}_*.sh"
    )
  fi

  # Find matching files
  local config_files=()
  for pattern in "${patterns[@]}"; do
    while IFS= read -r -d '' file; do
      [[ -f "$file" ]] && config_files+=("$file")
    done < <(find "$scripts_dir" -maxdepth 1 -type f -name "$pattern" -print0 2>/dev/null)
  done

  # Validate found files
  if [[ ${#config_files[@]} -eq 0 ]]; then
    ErrorMessage "No configuration files found for shell: $shell_type${hostname:+ (hostname: $hostname)}"
    return 1
  fi

  # Sort files to ensure consistent order
  IFS=$'\n' config_files=($(sort <<< "${config_files[*]}"))
  unset IFS

  # Print found files in verbose mode
  if [[ "$VERBOSE_MODE" == true ]]; then
    InfoMessage "Found ${#config_files[@]} configuration files:"
    printf '  %s\n' "${config_files[@]}"
  fi

  # Output array of files
  printf '%s\n' "${config_files[@]}"
}

# Function: ProcessConfigFiles
# Description: Process configuration files
# Usage: ProcessConfigFiles file1 [file2...]
# Returns: Processed configuration content
ProcessConfigFiles() {
  local files=("$@")
  local output_content=""

  # Add header
  output_content+="#!/usr/bin/env bash\n"
  output_content+="# Exported rcForge Configuration\n"
  output_content+="# Generated: $(date)\n"
  output_content+="# Shell: $SHELL_TYPE\n"
  [[ -n "$HOSTNAME" ]] && output_content+="# Hostname filter: $HOSTNAME\n"
  output_content+="\n"

  # Process each file
  for file in "${files[@]}"; do
    local file_content
    file_content=$(cat "$file")

    # Optional: Strip debug statements
    if [[ "$KEEP_DEBUG" == false ]]; then
      file_content=$(echo "$file_content" | grep -v '^\s*debug_echo' | grep -v '^\s*#.*debug')
    fi

    # Optional: Strip comments
    if [[ "$STRIP_COMMENTS" == true ]]; then
      file_content=$(echo "$file_content" | sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d')
    fi

    # Add separator and file content
    output_content+="# Source: $(basename "$file")\n"
    output_content+="$file_content\n\n"
  done

  echo -e "$output_content"
}

# Function: ExportConfiguration
# Description: Export configuration to file
# Usage: ExportConfiguration
ExportConfiguration() {
  # Determine output file
  local output_path="${OUTPUT_FILE:-$gc_default_export_dir/$(hostname)_${SHELL_TYPE}rc}"

  # Create export directory if it doesn't exist
  mkdir -p "$(dirname "$output_path")"

  # Check if file exists and handle overwrite
  if [[ -f "$output_path" && "$FORCE_OVERWRITE" == false ]]; then
    ErrorMessage "Output file already exists: $output_path"
    echo "Use --force to overwrite."
    return 1
  fi

  # Find and process configuration files
  local config_files
  mapfile -t config_files < <(FindConfigFiles "$SHELL_TYPE" "$HOSTNAME")

  # Generate exported configuration
  local exported_config
  exported_config=$(ProcessConfigFiles "${config_files[@]}")

  # Write to output file
  echo -e "$exported_config" > "$output_path"

  # Set correct permissions
  chmod 600 "$output_path"

  # Confirmation message
  SuccessMessage "Configuration exported to: $output_path"
  
  if [[ "$VERBOSE_MODE" == true ]]; then
    echo "Exported ${#config_files[@]} configuration files"
  fi
}

# ============================================================================
# MAIN FUNCTIONALITY
# ============================================================================

# Parse command-line arguments
# Usage: ParseArguments "$@"
ParseArguments() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --help|-h)
        ShowHelp
        return 0
        ;;
      --summary)
        ShowSummary
        return 0
        ;;
      --shell=*)
        SHELL_TYPE="${1#*=}"
        ValidateShellType "$SHELL_TYPE" || return 1
        ;;
      --hostname=*)
        HOSTNAME="${1#*=}"
        ;;
      --output=*)
        OUTPUT_FILE="${1#*=}"
        ;;
      --verbose|-v)
        VERBOSE_MODE=true
        ;;
      --keep-debug)
        KEEP_DEBUG=true
        STRIP_COMMENTS=false
        ;;
      --force|-f)
        FORCE_OVERWRITE=true
        ;;
      *)
        ErrorMessage "Unknown parameter: $1"
        echo "Use --help to see available options."
        return 1
        ;;
    esac
    shift
  done

  # Validate required parameters
  if [[ -z "$SHELL_TYPE" ]]; then
    ErrorMessage "Shell type must be specified (--shell=bash or --shell=zsh)"
    return 1
  fi

  return 0
}

# Main function
main() {
  # Detect project root
  local RCFORGE_DIR
  RCFORGE_DIR=$(DetectProjectRoot)

  # Parse command-line arguments
  if ! ParseArguments "$@"; then
    return 1
  fi

  # Display header
  SectionHeader "rcForge Configuration Export"

  # Execute export
  ExportConfiguration
}

# Execute main function if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
  exit $?
elif [[ "${BASH_SOURCE[0]}" != "${0}" && "$0" == *"rc"* ]]; then
  # Also execute if called via the rc command
  main "$@"
  exit $?
fi

# EOF
