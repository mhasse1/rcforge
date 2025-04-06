#!/usr/bin/env bash
# diagram-config.sh - Creates a diagram of rcForge configuration loading order
# Author: Mark Hasse
# Copyright: Analog Edge LLC
# Date: 2025-03-30
# Version: 0.2.1
# Description: Generates visual representation of shell configuration loading sequence

# Import core utility libraries
source shell-colors.sh

# Set strict error handling
set -o nounset  # Treat unset variables as errors
set -o errexit  # Exit immediately if a command exits with a non-zero status

# Global constants
readonly gc_app_name="rcForge"
readonly gc_version="0.2.1"
readonly gc_default_output_dir="${HOME}/.config/rcforge/docs"

# Configuration variables
export TARGET_HOSTNAME=""
export TARGET_SHELL=""
export OUTPUT_FILE=""
export VERBOSE_MODE=false
export FORMAT="mermaid"  # Default output format

# Detect project root dynamically
DetectProjectRoot() {
    local possible_roots=(
        "${RCFORGE_ROOT:-}"
        "$HOME/src/rcforge"
        "$HOME/Projects/rcforge"
        "/usr/share/rcforge"
        "/opt/homebrew/share/rcforge"
        "$(brew --prefix 2>/dev/null)/share/rcforge"
        "/opt/local/share/rcforge"
        "/usr/local/share/rcforge"
        "$HOME/.config/rcforge"
    )

    for dir in "${possible_roots[@]}"; do
        if [[ -n "$dir" && -d "$dir" && -f "$dir/rcforge.sh" ]]; then
            echo "$dir"
            return 0
        fi
    done

    # Fallback to user configuration directory
    echo "$HOME/.config/rcforge"
}

# Validate shell type
ValidateShellType() {
    local shell="$1"
    if [[ "$shell" != "bash" && "$shell" != "zsh" ]]; then
        ErrorMessage "Invalid shell type. Must be 'bash' or 'zsh'."
        return 1
    fi
    return 0
}

# Parse command-line arguments
ParseArguments() {
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --hostname=*)
                TARGET_HOSTNAME="${1#*=}"
                ;;
            --shell=*)
                TARGET_SHELL="${1#*=}"
                ValidateShellType "$TARGET_SHELL" || exit 1
                ;;
            --output=*)
                OUTPUT_FILE="${1#*=}"
                ;;
            --format=*)
                FORMAT="${1#*=}"
                ValidateFormat "$FORMAT" || exit 1
                ;;
            --verbose|-v)
                VERBOSE_MODE=true
                ;;
            --help|-h)
                DisplayHelp
                exit 0
                ;;
            --version)
                DisplayVersion
                exit 0
                ;;
            *)
                ErrorMessage "Unknown parameter: $1"
                DisplayHelp
                exit 1
                ;;
        esac
        shift
    done

    # Set defaults if not specified
    TARGET_HOSTNAME="${TARGET_HOSTNAME:-$(hostname | cut -d. -f1)}"
    TARGET_SHELL="${TARGET_SHELL:-$(DetectCurrentShell)}"
}

# Validate output format
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

# Detect current shell
DetectCurrentShell() {
    if [[ -n "$BASH_VERSION" ]]; then
        echo "bash"
    elif [[ -n "$ZSH_VERSION" ]]; then
        echo "zsh"
    else
        ErrorMessage "Unable to detect current shell"
        exit 1
    fi
}

# Display help information
DisplayHelp() {
    SectionHeader "${gc_app_name} Configuration Diagram Generator"
    
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --hostname=NAME      Specify hostname (default: current hostname)"
    echo "  --shell=TYPE         Specify shell type (bash or zsh, default: current shell)"
    echo "  --output=FILE        Specify output file path"
    echo "  --format=FORMAT      Output format (mermaid, graphviz, ascii)"
    echo "  --verbose, -v        Enable verbose output"
    echo "  --help, -h           Show this help message"
    echo "  --version            Show version information"
    echo ""
    echo "Examples:"
    echo "  $0                   Generate diagram for current shell/hostname"
    echo "  $0 --shell=bash      Generate Bash configuration diagram"
    echo "  $0 --hostname=laptop --shell=zsh  Diagram for laptop's Zsh config"
}

# Display version information
DisplayVersion() {
    TextBlock "${gc_app_name} Configuration Diagram Generator" "$CYAN"
    echo "Version: ${gc_version}"
    echo "Copyright: Analog Edge LLC"
    echo "License: MIT"
}

# Find configuration files
FindConfigFiles() {
    local shell_type="$1"
    local hostname="$2"
    local scripts_dir="${RCFORGE_DIR}/scripts"

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

# Generate Mermaid diagram
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

# Generate diagram in different formats
GenerateDiagram() {
    local files=("$@")

    # Create output directory if it doesn't exist
    mkdir -p "$(dirname "$OUTPUT_FILE")"

    # Generate diagram based on format
    case "$FORMAT" in
        mermaid)
            GenerateMermaidDiagram "${files[@]}" > "$OUTPUT_FILE"
            ;;
        # Future format support can be added here
        *)
            ErrorMessage "Format $FORMAT not yet implemented"
            return 1
            ;;
    esac

    # Confirmation message
    SuccessMessage "Diagram generated: $OUTPUT_FILE"
}

# Main script execution
Main() {
    # Detect project root
    local RCFORGE_DIR
    RCFORGE_DIR=$(DetectProjectRoot)

    # Parse command-line arguments
    ParseArguments "$@"

    # Display header
    SectionHeader "${gc_app_name} Configuration Loading Order"

    # Set default output file if not specified
    if [[ -z "$OUTPUT_FILE" ]]; then
        mkdir -p "$gc_default_output_dir"
        OUTPUT_FILE="${gc_default_output_dir}/loading_order_${TARGET_HOSTNAME}_${TARGET_SHELL}.md"
    fi

    # Find configuration files
    local config_files
    mapfile -t config_files < <(FindConfigFiles "$TARGET_SHELL" "$TARGET_HOSTNAME")

    # Generate diagram
    GenerateDiagram "${config_files[@]}"
}

# Entry point - execute only if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    Main "$@"
fi
