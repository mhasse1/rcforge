#!/usr/bin/env bash
# diag.sh - Visualize rcForge configuration loading order
# Author: rcForge Team
# Date: 2025-04-06
# Version: 0.3.0
# RC Summary: Creates diagrams of rcForge configuration loading sequence
# Description: Generates visual representations of shell configuration loading sequence

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

# Default output directory
readonly gc_default_output_dir="${HOME}/.config/rcforge/docs"

# Configuration variables
TARGET_HOSTNAME=""
TARGET_SHELL=""
OUTPUT_FILE=""
VERBOSE_MODE=false
FORMAT="mermaid"  # Default output format

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Function: ShowSummary
# Description: Display one-line summary for rc help
# Usage: ShowSummary
ShowSummary() {
  echo "Creates diagrams of rcForge configuration loading sequence"
}

# Function: ShowHelp
# Description: Display help information
# Usage: ShowHelp
ShowHelp() {
  echo "diag - rcForge Configuration Diagram Generator"
  echo ""
  echo "Description:"
  echo "  Generates visual representations of shell configuration loading sequence"
  echo "  to help understand the order in which scripts are loaded."
  echo ""
  echo "Usage:"
  echo "  rc diag [options]"
  echo ""
  echo "Options:"
  echo "  --hostname=NAME      Specify hostname (default: current hostname)"
  echo "  --shell=TYPE         Specify shell type (bash or zsh, default: current shell)"
  echo "  --output=FILE        Specify output file path"
  echo "  --format=FORMAT      Output format (mermaid, graphviz, ascii)"
  echo "  --verbose, -v        Enable verbose output"
  echo "  --help, -h           Show this help message"
  echo "  --summary            Show a one-line description (for rc help)"
  echo ""
  echo "Examples:"
  echo "  rc diag                        # Generate diagram for current shell/hostname"
  echo "  rc diag --shell=bash           # Generate Bash configuration diagram"
  echo "  rc diag --hostname=laptop --shell=zsh  # Diagram for laptop's Zsh config"
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

# Function: ValidateFormat
# Description: Validate output format
# Usage: ValidateFormat format
# Returns: 0 if valid, 1 if invalid
ValidateFormat() {
  local format="$1"
  local supported_formats=("mermaid" "graphviz" "ascii")
  
  for supported in "${supported_formats[@]}"; do
    if [[ "$format" == "$supported" ]]; then
      return 0
    fi
  done

  ErrorMessage "Unsupported format: $format"
  echo "Supported formats: ${supported_formats[*]}"
  return 1
}

# Function: DetectCurrentShell
# Description: Detect the current shell
# Usage: DetectCurrentShell
# Returns: Current shell name (bash or zsh)
DetectCurrentShell() {
  if [[ -n "${ZSH_VERSION:-}" ]]; then
    echo "zsh"
  elif [[ -n "${BASH_VERSION:-}" ]]; then
    echo "bash"
  else
    # Fallback to $SHELL
    local shell_name
    shell_name=$(basename "$SHELL")
    echo "$shell_name"
  fi
}

# Function: DetectCurrentHostname
# Description: Detect current hostname
# Usage: DetectCurrentHostname
# Returns: Current hostname
DetectCurrentHostname() {
  if command -v hostname >/dev/null 2>&1; then
    hostname | cut -d. -f1
  else
    # Fallback if hostname command not available
    echo "${HOSTNAME:-$(uname -n | cut -d. -f1)}"
  fi
}

# Function: FindConfigFiles
# Description: Find matching config files
# Usage: FindConfigFiles shell_type hostname
# Returns: Array of config file paths
FindConfigFiles() {
  local shell_type="$1"
  local hostname="$2"
  local scripts_dir="${RCFORGE_DIR}/rc-scripts"

  # Build file matching patterns
  local patterns=(
    "[0-9]*_global_common_*.sh"
    "[0-9]*_global_${shell_type}_*.sh"
    "[0-9]*_${hostname}_common_*.sh"
    "[0-9]*_${hostname}_${shell_type}_*.sh"
  )

  # Find and sort matching files
  local config_files=()
  for pattern in "${patterns[@]}"; do
    while IFS= read -r -d '' file; do
      [[ -f "$file" ]] && config_files+=("$file")
    done < <(find "$scripts_dir" -maxdepth 1 -type f -name "$pattern" -print0 2>/dev/null)
  done

  # Sort files by sequence number
  IFS=$'\n' config_files=($(sort <<< "${config_files[*]}"))
  unset IFS

  # Validate found files
  if [[ ${#config_files[@]} -eq 0 ]]; then
    ErrorMessage "No configuration files found for shell: $shell_type (hostname: $hostname)"
    return 1
  fi

  # Verbose output of found files
  if [[ "$VERBOSE_MODE" == true ]]; then
    InfoMessage "Found ${#config_files[@]} configuration files:"
    printf '  %s\n' "${config_files[@]}"
  fi

  # Output files
  printf '%s\n' "${config_files[@]}"
}

# Function: GenerateMermaidDiagram
# Description: Generate a Mermaid flowchart diagram
# Usage: GenerateMermaidDiagram file1 [file2...]
# Returns: Mermaid diagram markdown text
GenerateMermaidDiagram() {
  local files=("$@")
  local diagram=""

  # Start of Mermaid diagram
  diagram+="# Configuration Loading Order Diagram\n"
  diagram+="```mermaid\n"
  diagram+="flowchart TD\n"
  diagram+="    classDef global fill:#f9f,stroke:#333,stroke-width:2px\n"
  diagram+="    classDef hostname fill:#bbf,stroke:#333,stroke-width:2px\n"
  diagram+="    classDef common fill:#dfd,stroke:#333,stroke-width:1px\n"
  diagram+="    classDef shell fill:#ffd,stroke:#333,stroke-width:1px\n\n"
  diagram+="    Start([Start rcForge]) --> FirstFile\n"

  local prev_node="FirstFile"
  local first_file=true

  # Process each file
  for file in "${files[@]}"; do
    local filename
    filename=$(basename "$file")
    local seq_num="${filename%%_*}"
    local parts=(${filename//_/ })
    local hostname="${parts[1]}"
    local environment="${parts[2]}"
    local description="${filename#*_*_*_}"
    description="${description%.sh}"

    # Create node ID (remove special characters)
    local node_id
    node_id=$(echo "$filename" | tr -cd '[:alnum:]')

    # Determine node class
    local node_class=""
    if [[ "$hostname" == "global" ]]; then
      node_class="global"
    else
      node_class="hostname"
    fi

    if [[ "$environment" == "common" ]]; then
      node_class+=",common"
    else
      node_class+=",shell"
    fi

    # Add node to diagram
    if [[ "$first_file" == true ]]; then
      diagram+="    FirstFile[$seq_num: $hostname/$environment<br>$description] --> $node_id\n"
      first_file=false
    else
      diagram+="    $prev_node --> $node_id[$seq_num: $hostname/$environment<br>$description]\n"
    fi

    # Add class to node
    diagram+="    class $node_id $node_class\n"

    prev_node="$node_id"
  done

  # Add final node
  diagram+="    $prev_node --> End([End rcForge])\n"
  diagram+="```\n"

  # Output diagram
  echo -e "$diagram"
}

# Function: GenerateGraphvizDiagram
# Description: Generate a Graphviz DOT diagram
# Usage: GenerateGraphvizDiagram file1 [file2...]
# Returns: Graphviz DOT diagram text
GenerateGraphvizDiagram() {
  local files=("$@")
  local diagram=""

  # Start of Graphviz diagram
  diagram+="# Configuration Loading Order Diagram\n"
  diagram+="```dot\n"
  diagram+="digraph rcForge {\n"
  diagram+="    rankdir=TD;\n"
  diagram+="    node [shape=box, style=filled, fontname=\"Arial\"];\n"
  diagram+="    edge [fontname=\"Arial\"];\n\n"
  
  # Add start node
  diagram+="    start [label=\"Start rcForge\", shape=oval];\n\n"
  
  # Process each file
  local prev_node="start"
  
  for file in "${files[@]}"; do
    local filename
    filename=$(basename "$file")
    local seq_num="${filename%%_*}"
    local parts=(${filename//_/ })
    local hostname="${parts[1]}"
    local environment="${parts[2]}"
    local description="${filename#*_*_*_}"
    description="${description%.sh}"

    # Create node ID (remove special characters)
    local node_id
    node_id=$(echo "$filename" | tr -cd '[:alnum:]')

    # Determine node color
    local fill_color
    if [[ "$hostname" == "global" ]]; then
      if [[ "$environment" == "common" ]]; then
        fill_color="#ffccff"  # Light pink for global common
      else
        fill_color="#ffcccc"  # Light red for global shell-specific
      fi
    else
      if [[ "$environment" == "common" ]]; then
        fill_color="#ccccff"  # Light blue for hostname common
      else
        fill_color="#ccffcc"  # Light green for hostname shell-specific
      fi
    fi

    # Add node
    diagram+="    $node_id [label=\"$seq_num: $hostname/$environment\\n$description\", fillcolor=\"$fill_color\"];\n"
    
    # Add edge
    diagram+="    $prev_node -> $node_id;\n"
    
    prev_node="$node_id"
  done
  
  # Add end node
  diagram+="    end [label=\"End rcForge\", shape=oval];\n"
  diagram+="    $prev_node -> end;\n"
  
  # End diagram
  diagram+="}\n"
  diagram+="```\n"

  # Output diagram
  echo -e "$diagram"
}

# Function: GenerateAsciiDiagram
# Description: Generate a simple ASCII diagram
# Usage: GenerateAsciiDiagram file1 [file2...]
# Returns: ASCII diagram text
GenerateAsciiDiagram() {
  local files=("$@")
  local diagram=""

  # Start of ASCII diagram
  diagram+="# Configuration Loading Order Diagram\n"
  diagram+="```\n"
  diagram+="START rcForge\n"
  diagram+="  |\n"
  diagram+="  v\n"

  # Process each file
  for file in "${files[@]}"; do
    local filename
    filename=$(basename "$file")
    local seq_num="${filename%%_*}"
    local parts=(${filename//_/ })
    local hostname="${parts[1]}"
    local environment="${parts[2]}"
    local description="${filename#*_*_*_}"
    description="${description%.sh}"

    # Add node to diagram with alignment
    diagram+="[${seq_num}] ${hostname}/${environment} - ${description}\n"
    diagram+="  |\n"
    diagram+="  v\n"
  done

  # Add final node
  diagram+="END rcForge\n"
  diagram+="```\n"

  # Output diagram
  echo -e "$diagram"
}

# Function: GenerateDiagram
# Description: Generate diagram in the specified format
# Usage: GenerateDiagram format output_file file1 [file2...]
# Returns: 0 on success, 1 on failure
GenerateDiagram() {
  local format="$1"
  local output_file="$2"
  shift 2
  local files=("$@")

  # Create output directory if it doesn't exist
  mkdir -p "$(dirname "$output_file")"

  # Generate diagram based on format
  case "$format" in
    mermaid)
      GenerateMermaidDiagram "${files[@]}" > "$output_file"
      ;;
    graphviz)
      GenerateGraphvizDiagram "${files[@]}" > "$output_file"
      ;;
    ascii)
      GenerateAsciiDiagram "${files[@]}" > "$output_file"
      ;;
    *)
      ErrorMessage "Format $format not supported"
      return 1
      ;;
  esac

  # Confirmation message
  SuccessMessage "Diagram generated: $output_file"
  if [[ "$VERBOSE_MODE" == true ]]; then
    echo "Format: $format"
    echo "Configuration files: ${#files[@]}"
  fi
  
  return 0
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
      --hostname=*)
        TARGET_HOSTNAME="${1#*=}"
        ;;
      --shell=*)
        TARGET_SHELL="${1#*=}"
        ValidateShellType "$TARGET_SHELL" || return 1
        ;;
      --output=*)
        OUTPUT_FILE="${1#*=}"
        ;;
      --format=*)
        FORMAT="${1#*=}"
        ValidateFormat "$FORMAT" || return 1
        ;;
      --verbose|-v)
        VERBOSE_MODE=true
        ;;
      *)
        ErrorMessage "Unknown parameter: $1"
        echo "Use --help to see available options."
        return 1
        ;;
    esac
    shift
  done

  # Set defaults if not specified
  : "${TARGET_HOSTNAME:=$(DetectCurrentHostname)}"
  : "${TARGET_SHELL:=$(DetectCurrentShell)}"

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
  SectionHeader "rcForge Configuration Loading Order"

  # Set default output file if not specified
  if [[ -z "$OUTPUT_FILE" ]]; then
    mkdir -p "$gc_default_output_dir"
    OUTPUT_FILE="${gc_default_output_dir}/loading_order_${TARGET_HOSTNAME}_${TARGET_SHELL}.md"
  fi

  # Find configuration files
  local config_files
  mapfile -t config_files < <(FindConfigFiles "$TARGET_SHELL" "$TARGET_HOSTNAME")
  
  # Check if any files were found
  if [[ ${#config_files[@]} -eq 0 ]]; then
    return 1
  fi

  # Generate diagram
  GenerateDiagram "$FORMAT" "$OUTPUT_FILE" "${config_files[@]}"
  
  # Open file if possible
  if [[ "$VERBOSE_MODE" == true ]]; then
    if command -v open >/dev/null 2>&1; then
      open "$OUTPUT_FILE"
    elif command -v xdg-open >/dev/null 2>&1; then
      xdg-open "$OUTPUT_FILE"
    fi
  fi
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
