#!/bin/bash
# diagram-config.sh - Creates a diagram of rcForge configuration loading order
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
  echo "rcForge v0.2.0 - Configuration Diagram Utility"
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
  echo "  --hostname=HOST     Specify hostname for diagram (defaults to current)"
  echo "  --shell=SHELL       Specify shell type (bash or zsh, defaults to current)"
  echo "  --output=FILE       Specify output file for diagram"
  echo "  --rcforge-dir=DIR   Use specified rcForge directory"
  echo "  --help, -h          Show this help message"
  echo "  --version, -v       Show version information"
  echo ""
  echo "Examples:"
  echo "  $script_name                            # Current hostname and shell"
  echo "  $script_name --hostname=server --shell=bash  # Specific hostname and shell"
  echo "  $script_name --output=~/config-diagram.md    # Custom output file"
  echo ""
}

# Determine rcForge paths
determine_paths() {
  # Detect if we're running in development mode
  if [[ -n "${RCFORGE_DEV}" ]]; then
    # Development mode
    RCFORGE_DIR="$HOME/src/rcforge"
  else
    # Production mode - Detect system installation first, then user installation
    if [[ -n "${RCFORGE_ROOT}" ]]; then
      # Use explicitly set RCFORGE_ROOT if available
      RCFORGE_DIR="${RCFORGE_ROOT}"
    elif [[ -d "$HOME/.config/rcforge" && -f "$HOME/.config/rcforge/rcforge.sh" ]]; then
      # User installation
      RCFORGE_DIR="$HOME/.config/rcforge"
    elif [[ -d "/usr/share/rcforge" ]]; then
      # System installation on Linux
      RCFORGE_DIR="/usr/share/rcforge"
    elif [[ -d "/opt/homebrew/share/rcforge" ]]; then
      # Homebrew installation on Apple Silicon
      RCFORGE_DIR="/opt/homebrew/share/rcforge"
    elif [[ -n "$(which brew 2>/dev/null)" && -d "$(brew --prefix 2>/dev/null)/share/rcforge" ]]; then
      # Homebrew installation (generic)
      RCFORGE_DIR="$(brew --prefix)/share/rcforge"
    else
      # Fallback to expected user location
      RCFORGE_DIR="$HOME/.config/rcforge"
    fi
  fi
  
  # Set up directory paths
  SCRIPTS_DIR="${RCFORGE_SCRIPTS:-$RCFORGE_DIR/scripts}"
  OUTPUT_DIR="${RCFORGE_OUTPUT:-$RCFORGE_DIR/docs}"
  OUTPUT_FILE="$OUTPUT_DIR/loading_order_diagram.md"
}

# Parse command line arguments
target_hostname=""
target_shell=""
output_file=""
rcforge_dir=""

# Process command-line arguments
process_args() {
  while [[ "$#" -gt 0 ]]; do
    case $1 in
      --hostname=*)
        target_hostname="${1#*=}"
        ;;
      --shell=*)
        target_shell="${1#*=}"
        ;;
      --output=*)
        output_file="${1#*=}"
        ;;
      --rcforge-dir=*)
        rcforge_dir="${1#*=}"
        RCFORGE_DIR="${1#*=}"
        SCRIPTS_DIR="$RCFORGE_DIR/scripts"
        OUTPUT_DIR="$RCFORGE_DIR/docs"
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
        echo "Use --help for usage information."
        exit 1
        ;;
    esac
    shift
  done
}

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

# Function to get all applicable files
get_applicable_files() {
  local hostname="$1"
  local shell="$2"
  local files=()
  
  # Find all script files
  while IFS= read -r file; do
    # Extract target info from filename
    local filename=$(basename "$file")
    local parts=(${filename//_/ })
    local file_hostname="${parts[1]}"
    local environment="${parts[2]}"
    
    # Check if file applies to this execution path
    if [[ "$environment" == "common" || "$environment" == "$shell" ]] && 
       [[ "$file_hostname" == "global" || "$file_hostname" == "$hostname" ]]; then
      files+=("$file")
    fi
  done < <(find "$SCRIPTS_DIR" -type f -name "[0-9]*_*_*_*.sh" | sort)
  
  echo "${files[@]}"
}

# Function to generate Mermaid diagram
generate_mermaid_diagram() {
  local files=($@)
  local num_files=${#files[@]}
  
  # Create output directory if it doesn't exist
  mkdir -p "$(dirname "$OUTPUT_FILE")"
  
  # Start the diagram
  cat > "$OUTPUT_FILE" << EOF
# rcForge Loading Order Diagram for $target_hostname/$target_shell

This diagram shows the loading order of configuration files for the current execution path.

## Execution Path Information
- **Hostname:** $target_hostname
- **Shell:** $target_shell
- **Total Configuration Files:** $num_files
- **Generated:** $(date)

## Loading Order Diagram

\`\`\`mermaid
flowchart TD
    classDef global fill:#f9f,stroke:#333,stroke-width:2px
    classDef hostname fill:#bbf,stroke:#333,stroke-width:2px
    classDef common fill:#dfd,stroke:#333,stroke-width:1px
    classDef shell fill:#ffd,stroke:#333,stroke-width:1px
    
    Start([Start rcForge]) --> FirstFile
EOF

  # Add each file to the diagram
  local prev_node="FirstFile"
  local first_file=true
  
  for file in "${files[@]}"; do
    local filename=$(basename "$file")
    local seq_num="${filename%%_*}"
    local parts=(${filename//_/ })
    local hostname="${parts[1]}"
    local environment="${parts[2]}"
    local description="${filename#*_*_*_}"
    description="${description%.sh}"
    
    # Create node ID from filename (remove special chars)
    local node_id="${filename//[^a-zA-Z0-9]/}"
    
    # Set appropriate class based on hostname and environment
    local node_class=""
    if [[ "$hostname" == "global" ]]; then
      node_class="global"
    else
      node_class="hostname"
    fi
    
    if [[ "$environment" == "common" ]]; then
      node_class="${node_class},common"
    else
      node_class="${node_class},shell"
    fi
    
    # Add node to diagram
    if [[ "$first_file" == true ]]; then
      echo "    FirstFile[$seq_num: $hostname/$environment<br>$description] --> $node_id" >> "$OUTPUT_FILE"
      first_file=false
    else
      echo "    $prev_node --> $node_id[$seq_num: $hostname/$environment<br>$description]" >> "$OUTPUT_FILE"
    fi
    
    # Add class to node
    echo "    class $node_id $node_class" >> "$OUTPUT_FILE"
    
    prev_node="$node_id"
  done
  
  # Add the final node
  echo "    $prev_node --> End([End rcForge])" >> "$OUTPUT_FILE"
  
  # End the diagram
  cat >> "$OUTPUT_FILE" << 'EOF'
```

## Legend
- **Pink Nodes**: Global configurations (apply to all machines)
- **Blue Nodes**: Machine-specific configurations (only apply to this hostname)
- **Green Background**: Common configurations (apply to both Bash and Zsh)
- **Yellow Background**: Shell-specific configurations (only apply to the current shell)

## File Details

| Sequence | Hostname | Environment | Description | Full Path |
|----------|----------|-------------|-------------|-----------|
EOF

  # Add file details to the table
  for file in "${files[@]}"; do
    local filename=$(basename "$file")
    local seq_num="${filename%%_*}"
    local parts=(${filename//_/ })
    local hostname="${parts[1]}"
    local environment="${parts[2]}"
    local description="${filename#*_*_*_}"
    description="${description%.sh}"
    
    echo "| $seq_num | $hostname | $environment | $description | \`$file\` |" >> "$OUTPUT_FILE"
  done
}

# Main function
main() {
  # Determine paths
  determine_paths
  
  # Process command line arguments
  process_args "$@"
  
  # Override output file if specified
  if [[ -n "$output_file" ]]; then
    OUTPUT_FILE="$output_file"
  fi
  
  echo -e "${BLUE}┌──────────────────────────────────────────────────────┐${RESET}"
  echo -e "${BLUE}│ Generating rcForge Loading Order Diagram             │${RESET}"
  echo -e "${BLUE}└──────────────────────────────────────────────────────┘${RESET}"
  echo ""
  
  # Check if the scripts directory exists
  if [[ ! -d "$SCRIPTS_DIR" ]]; then
    echo -e "${RED}Error: Scripts directory not found.${RESET}"
    echo "Expected location: $SCRIPTS_DIR"
    echo "Please run the installation script first."
    exit 1
  fi
  
  # Determine which shell and hostname to diagram
  if [[ -z "$target_shell" ]]; then
    target_shell=$(detect_shell)
    echo -e "${CYAN}No shell specified, using current shell: $target_shell${RESET}"
  else
    echo -e "${CYAN}Using specified shell: $target_shell${RESET}"
  fi
  
  if [[ -z "$target_hostname" ]]; then
    target_hostname=$(get_hostname)
    echo -e "${CYAN}No hostname specified, using current hostname: $target_hostname${RESET}"
  else
    echo -e "${CYAN}Using specified hostname: $target_hostname${RESET}"
  fi
  
  # Validate shell
  if [[ "$target_shell" != "bash" && "$target_shell" != "zsh" ]]; then
    echo -e "${RED}Error: Unsupported shell: $target_shell${RESET}"
    echo "Supported shells: bash, zsh"
    exit 1
  fi
  
  # Get applicable files and generate the diagram
  applicable_files=($(get_applicable_files "$target_hostname" "$target_shell"))
  file_count=${#applicable_files[@]}
  
  if [[ $file_count -eq 0 ]]; then
    echo -e "${RED}Error: No applicable configuration files found for $target_hostname/$target_shell.${RESET}"
    exit 1
  fi
  
  echo -e "${GREEN}Found $file_count applicable configuration files.${RESET}"
  generate_mermaid_diagram "${applicable_files[@]}"
  
  echo -e "${GREEN}✓ Configuration diagram generated: $OUTPUT_FILE${RESET}"
  echo ""
  echo -e "${YELLOW}To view this diagram:${RESET}"
  echo "  • Use a Markdown viewer that supports Mermaid diagrams"
  echo "  • Import it into a tool that supports Mermaid (like GitHub, GitLab, VS Code)"
  echo ""
  echo -e "${YELLOW}If you're using VS Code, you can install the Markdown Preview Mermaid Support extension${RESET}"
  echo ""
}

# Run main function if executed directly
if is_executed_directly; then
  main "$@"
fi
# EOF
