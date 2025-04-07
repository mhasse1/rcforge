#!/usr/bin/env bash
# diag.sh - Visualize rcForge configuration loading order
# Author: rcForge Team
# Date: 2025-04-06
# Version: 0.3.0
# Category: system/utility
# RC Summary: Creates diagrams of rcForge configuration loading sequence
# Description: Generates visual representations of shell configuration loading sequence

# Source necessary libraries
source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/shell-colors.sh"
source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/utility-functions.sh" # Assuming SectionHeader is here

# Set strict error handling
set -o nounset  # Treat unset variables as errors
 # set -o errexit  # Exit immediately if a command exits with a non-zero status

# ============================================================================
# GLOBAL CONSTANTS
# ============================================================================
[ -v gc_version ]  || readonly gc_version="${RCFORGE_VERSION:-ENV_ERROR}"
[ -v gc_app_name ] || readonly gc_app_name="${RCFORGE_APP_NAME:-ENV_ERROR}"
readonly gc_default_output_dir="${HOME}/.config/rcforge/docs" # Default output dir

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# ============================================================================
# Function: ShowSummary
# Description: Display one-line summary for rc help command.
# Usage: ShowSummary
# Returns: Echoes summary string.
# ============================================================================
ShowSummary() {
    grep '^# RC Summary:' "$0" | sed 's/^# RC Summary: //'
}

# ============================================================================
# Function: ShowHelp
# Description: Display detailed help information for the diag command.
# Usage: ShowHelp
# Returns: None. Prints help text to stdout.
# ============================================================================
ShowHelp() {
    echo "diag - rcForge Configuration Diagram Generator (v${gc_version})"
    echo ""
    echo "Description:"
    echo "  Generates visual representations of shell configuration loading sequence"
    echo "  to help understand the order in which scripts are loaded."
    echo ""
    echo "Usage:"
    echo "  rc diag [options]"
    echo "  $0 [options]"
    echo ""
    echo "Options:"
    echo "  --hostname=NAME   Specify hostname (default: current hostname)"
    echo "  --shell=TYPE      Specify shell type (bash or zsh, default: current shell)"
    echo "  --output=FILE     Specify output file path (optional, defaults to docs dir)"
    echo "  --format=FORMAT   Output format (mermaid, graphviz, ascii; default: mermaid)"
    echo "  --verbose, -v     Enable verbose output"
    echo "  --help, -h        Show this help message"
    echo "  --summary         Show a one-line description (for rc help)"
    echo ""
    echo "Examples:"
    echo "  rc diag                                      # Diagram for current shell/hostname"
    echo "  rc diag --shell=bash                         # Generate Bash diagram"
    echo "  rc diag --hostname=laptop --shell=zsh      # Diagram for laptop's Zsh config"
    echo "  rc diag --format=ascii --output=~/diag.txt # Output ASCII to specific file"
}

# ============================================================================
# Function: DetermineRcforgeDir
# Description: Determine the effective rcForge root directory.
# Usage: DetermineRcforgeDir
# Returns: Echoes the path to the rcForge configuration directory.
# ============================================================================
DetermineRcforgeDir() {
    if [[ -n "${RCFORGE_ROOT:-}" && -d "${RCFORGE_ROOT}" ]]; then
        echo "${RCFORGE_ROOT}"
    else
        echo "$HOME/.config/rcforge"
    fi
}

# ============================================================================
# Function: ValidateShellType
# Description: Validate shell type ('bash' or 'zsh').
# Usage: ValidateShellType shell_type
# Returns: 0 if valid, 1 if invalid.
# ============================================================================
ValidateShellType() {
    local shell="$1"
    if [[ "$shell" != "bash" && "$shell" != "zsh" ]]; then
        ErrorMessage "Invalid shell type specified: '$shell'. Must be 'bash' or 'zsh'."
        return 1
    fi
    return 0
}

# ============================================================================
# Function: ValidateFormat
# Description: Validate the requested diagram output format.
# Usage: ValidateFormat format
# Returns: 0 if valid, 1 if invalid.
# ============================================================================
ValidateFormat() {
    local format="$1"
    local supported_formats=("mermaid" "graphviz" "ascii")
    local supported="" # Loop variable

    for supported in "${supported_formats[@]}"; do
        if [[ "$format" == "$supported" ]]; then
            return 0 # Format is supported
        fi
    done

    ErrorMessage "Unsupported diagram format specified: '$format'."
    WarningMessage "Supported formats are: ${supported_formats[*]}"
    return 1
}

# ============================================================================
# Function: DetectCurrentShell
# Description: Detect the name of the currently running interactive shell.
# Usage: DetectCurrentShell
# Returns: Echoes 'bash', 'zsh', or the basename of $SHELL as a fallback.
# ============================================================================
DetectCurrentShell() {
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        echo "zsh"
    elif [[ -n "${BASH_VERSION:-}" ]]; then
        echo "bash"
    else
        basename "${SHELL:-unknown}"
    fi
}


# ============================================================================
# Function: FindConfigFiles
# Description: Wrapper function to call the shared FindRcScripts library function.
# Usage: FindConfigFiles rcforge_dir shell_type hostname is_verbose (rcforge_dir/is_verbose unused)
# Arguments:
#   $1 (unused) - rcforge_dir path (info now comes from env var used by library fn).
#   $2 (required) - Shell type ('bash' or 'zsh').
#   $3 (required) - Hostname.
#   $4 (unused) - is_verbose flag.
# Returns: Echoes newline-separated list from FindRcScripts. Passes through exit status.
# ============================================================================
FindConfigFiles() {
    # local rcforge_dir="$1" # No longer needed
    local shell_type="$2"
    local hostname="$3"
    # local is_verbose="${4:-false}" # No longer needed

    # Call the shared library function (ensure utility-functions.sh is sourced first)
    FindRcScripts "$shell_type" "$hostname"
    return $? # Return the exit status of FindRcScripts
}


# ============================================================================
# Diagram Generation Functions (PascalCase)
# ============================================================================

# ============================================================================
# Function: GenerateMermaidDiagram
# Description: Generate a Mermaid flowchart diagram from a list of files.
# Usage: GenerateMermaidDiagram file1 [file2...]
# Arguments: One or more sorted config file paths.
# Returns: Echoes Mermaid diagram markdown text.
# ============================================================================
GenerateMermaidDiagram() {
    local -a files=("$@")
    local diagram=""
    local file=""
    local filename=""
    local seq_num=""
    local -a parts
    local hostname=""
    local environment=""
    local description=""
    local node_id=""
    local node_class=""
    local prev_node="StartNode"
    local is_first_node=true # Not currently used, keep for structure

    diagram+="# rcForge Configuration Loading Order (Mermaid Diagram)\n"
    diagram+="\`\`\`mermaid\n"
    diagram+="flowchart TD\n"
    diagram+="    classDef global fill:#f9f,stroke:#333,stroke-width:2px\n"
    diagram+="    classDef hostname fill:#bbf,stroke:#333,stroke-width:2px\n"
    diagram+="    classDef common fill:#dfd,stroke:#333,stroke-width:1px\n"
    diagram+="    classDef shell fill:#ffd,stroke:#333,stroke-width:1px\n\n"
    diagram+="    StartNode([Start rcForge])\n"

    for file in "${files[@]}"; do
        filename=$(basename "$file")
        seq_num="${filename%%_*}"
        IFS='_' read -r -a parts <<< "${filename%.sh}"
        hostname="${parts[1]:-unknown}"
        environment="${parts[2]:-unknown}"
        description="${filename#*_*_*_}"
        description="${description%.sh}"

        node_id="Node_${seq_num}_${hostname}_${environment}"
        node_id="${node_id//[^a-zA-Z0-9_]/_}"

        node_class=""
        [[ "$hostname" == "global" ]] && node_class+=" global" || node_class+=" hostname"
        [[ "$environment" == "common" ]] && node_class+=" common" || node_class+=" shell"
        node_class=$(echo "$node_class" | xargs)

        diagram+="    ${node_id}[\"${seq_num}: ${hostname}/${environment}<br>${description}\"]\n"
        diagram+="    $prev_node --> $node_id\n"
        diagram+="    class $node_id $node_class\n"

        prev_node="$node_id"
        is_first_node=false
    done

    diagram+="    EndNode([End rcForge])\n"
    diagram+="    $prev_node --> EndNode\n"
    diagram+=" \`\`\`\n"

    printf '%s' "$diagram"
}

# ============================================================================
# Function: GenerateGraphvizDiagram
# Description: Generate a Graphviz DOT diagram from a list of files.
# Usage: GenerateGraphvizDiagram file1 [file2...]
# Arguments: One or more sorted config file paths.
# Returns: Echoes Graphviz DOT diagram text suitable for 'dot' command.
# ============================================================================
GenerateGraphvizDiagram() {
    local -a files=("$@")
    local diagram=""
    local file=""
    local filename=""
    local seq_num=""
    local -a parts
    local hostname=""
    local environment=""
    local description=""
    local node_id=""
    local fill_color=""
    local prev_node="start_node"

    diagram+="// rcForge Configuration Loading Order (Graphviz DOT Diagram)\n"
    diagram+="digraph rcForgeLoadingOrder {\n"
    diagram+="    rankdir=TD;\n"
    diagram+="    node [shape=box, style=filled, fontname=\"Helvetica,Arial,sans-serif\"];\n"
    diagram+="    edge [fontname=\"Helvetica,Arial,sans-serif\"];\n\n"
    diagram+="    start_node [label=\"Start rcForge\", shape=oval];\n"
    diagram+="    end_node [label=\"End rcForge\", shape=oval];\n\n"

    for file in "${files[@]}"; do
        filename=$(basename "$file")
        seq_num="${filename%%_*}"
        IFS='_' read -r -a parts <<< "${filename%.sh}"
        hostname="${parts[1]:-unknown}"
        environment="${parts[2]:-unknown}"
        description="${filename#*_*_*_}"
        description="${description%.sh}"

        node_id="Node_${seq_num}_${hostname}_${environment}"
        node_id="${node_id//[^a-zA-Z0-9_]/_}"

        if [[ "$hostname" == "global" ]]; then
            [[ "$environment" == "common" ]] && fill_color="#f9f" || fill_color="#ffdddd"
        else
            [[ "$environment" == "common" ]] && fill_color="#ddddff" || fill_color="#ddffdd"
        fi

        description="${description//\"/\\\"}"
        diagram+="    ${node_id} [label=\"${seq_num}: ${hostname}/${environment}\\n${description}\", fillcolor=\"${fill_color}\"];\n"
        diagram+="    ${prev_node} -> ${node_id};\n"

        prev_node="$node_id"
    done

    diagram+="    ${prev_node} -> end_node;\n"
    diagram+="}\n"

    printf '%s' "$diagram"
}

# ============================================================================
# Function: GenerateAsciiDiagram
# Description: Generate a simple ASCII text diagram from a list of files.
# Usage: GenerateAsciiDiagram file1 [file2...]
# Arguments: One or more sorted config file paths.
# Returns: Echoes ASCII diagram text.
# ============================================================================
GenerateAsciiDiagram() {
    local -a files=("$@")
    local diagram=""
    local file=""
    local filename=""
    local seq_num=""
    local -a parts
    local hostname=""
    local environment=""
    local description=""

    diagram+="# rcForge Configuration Loading Order (ASCII Diagram)\n"
    diagram+="\`\`\`\n"
    diagram+="START rcForge\n"
    diagram+="   |\n"
    diagram+="   V\n"

    for file in "${files[@]}"; do
        filename=$(basename "$file")
        seq_num="${filename%%_*}"
        IFS='_' read -r -a parts <<< "${filename%.sh}"
        hostname="${parts[1]:-unknown}"
        environment="${parts[2]:-unknown}"
        description="${filename#*_*_*_}"
        description="${description%.sh}"

        diagram+="[${seq_num}] ${hostname}/${environment} - ${description}\n"
        diagram+="   |\n"
        diagram+="   V\n"
    done

    diagram+="END rcForge\n"
    diagram+="\`\`\`\n"

    printf '%s' "$diagram"
}

# ============================================================================
# Function: GenerateDiagram
# Description: Generate diagram in specified format and write to output file.
# Usage: GenerateDiagram format output_file is_verbose file1 [file2...]
# Arguments: Passed positionally.
# Returns: 0 on success, 1 on failure.
# ============================================================================
GenerateDiagram() {
    local format="$1"
    local output_file="$2"
    local is_verbose="$3"
    shift 3
    local -a files=("$@")
    local output_dir

    output_dir=$(dirname "$output_file")
    if ! mkdir -p "$output_dir"; then
        ErrorMessage "Failed to create output directory: $output_dir"
        return 1
    fi

    InfoMessage "Generating diagram (format: $format)..."

    # Call appropriate PascalCase generation function
    case "$format" in
        mermaid)
            if ! GenerateMermaidDiagram "${files[@]}" > "$output_file"; then
                ErrorMessage "Failed to generate Mermaid diagram." ; return 1; fi
            ;;
        graphviz)
            if ! GenerateGraphvizDiagram "${files[@]}" > "$output_file"; then
                 ErrorMessage "Failed to generate Graphviz diagram." ; return 1; fi
            ;;
        ascii)
            if ! GenerateAsciiDiagram "${files[@]}" > "$output_file"; then
                 ErrorMessage "Failed to generate ASCII diagram." ; return 1; fi
            ;;
        *)
            ErrorMessage "Internal error: Unsupported format '$format' in GenerateDiagram."
            return 1
            ;;
    esac

    chmod 600 "$output_file"

    SuccessMessage "Diagram generated successfully: $output_file"
    if [[ "$is_verbose" == "true" ]]; then
        InfoMessage "  Format: $format"
        InfoMessage "  Based on ${#files[@]} configuration files."
        if command -v open &> /dev/null; then
            open "$output_file" &
        elif command -v xdg-open &> /dev/null; then
            xdg-open "$output_file" &
        else
            InfoMessage "Could not automatically open the diagram file."
        fi
    fi

    return 0
}


# ============================================================================
# Function: ParseArguments
# Description: Parse command-line arguments for the diag script.
# Usage: declare -A options; ParseArguments options "$@"
# Returns: Populates associative array. Returns 0 on success, 1 on error or if help/summary shown.
# ============================================================================
ParseArguments() {
    local -n options_ref="$1" # Use nameref
    shift

    # Call PascalCase functions for defaults
    options_ref["target_hostname"]="$(DetectCurrentHostname)"
    options_ref["target_shell"]="$(DetectCurrentShell)"
    options_ref["output_file"]=""
    options_ref["format"]="mermaid"
    options_ref["verbose_mode"]=false

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --help|-h) ShowHelp; return 1 ;; # Call PascalCase
            --summary) ShowSummary; return 1 ;; # Call PascalCase
            --hostname=*) options_ref["target_hostname"]="${1#*=}" ;;
            --shell=*)
                options_ref["target_shell"]="${1#*=}"
                if ! ValidateShellType "${options_ref["target_shell"]}"; then return 1; fi # Call PascalCase
                ;;
            --output=*) options_ref["output_file"]="${1#*=}" ;;
            --format=*)
                options_ref["format"]="${1#*=}"
                if ! ValidateFormat "${options_ref["format"]}"; then return 1; fi # Call PascalCase
                ;;
            --verbose|-v) options_ref["verbose_mode"]=true ;;
            *)
                ErrorMessage "Unknown parameter: $1"
                echo "Use --help to see available options."
                return 1
                ;;
        esac
        shift
    done

    # Final validation after defaults
    if ! ValidateShellType "${options_ref["target_shell"]}"; then # Call PascalCase
         WarningMessage "Default shell detection failed or resulted in unsupported shell."
         return 1
    fi

    return 0 # Success
}


# ============================================================================
# Function: main
# Description: Main execution logic for the diag script.
# Usage: main "$@"
# Returns: 0 on success, 1 on failure.
# ============================================================================
main() {
    local rcforge_dir
    rcforge_dir=$(DetermineRcforgeDir) # Call PascalCase
    declare -A options
    local -a config_files
    local default_filename="" # Temp var for default name construction

    # Call PascalCase. Exit if parsing failed or help/summary displayed.
    if ! ParseArguments options "$@"; then
        return 1
    fi

    # Determine default output file path if not provided
    if [[ -z "${options[output_file]}" ]]; then
         default_filename="loading_order_${options[target_hostname]}_${options[target_shell]}.${options[format]}"
         if [[ "${options[format]}" == "mermaid" ]]; then default_filename="${default_filename%.*}.md"; fi
         if [[ "${options[format]}" == "graphviz" ]]; then default_filename="${default_filename%.*}.dot"; fi
         if [[ "${options[format]}" == "ascii" ]]; then default_filename="${default_filename%.*}.txt"; fi
         options[output_file]="${gc_default_output_dir}/${default_filename}"
    fi

    SectionHeader "rcForge Configuration Diagram Generation (v${gc_version})" # Call PascalCase

    # Call PascalCase. Use process substitution and mapfile.
    mapfile -t config_files < <(FindConfigFiles "$rcforge_dir" "${options[target_shell]}" "${options[target_hostname]}" "${options[verbose_mode]}") || {
        # find_config_files already prints message, just return failure status
        return 1
    }


    # Call PascalCase function to generate the diagram
    GenerateDiagram \
        "${options[format]}" \
        "${options[output_file]}" \
        "${options[verbose_mode]}" \
        "${config_files[@]}"

    return $? # Return status of GenerateDiagram
}


# Execute main function if run directly or via rc command
if [[ "${BASH_SOURCE[0]}" == "${0}" ]] || [[ "${BASH_SOURCE[0]}" != "${0}" && "$0" == *"rc"* ]]; then
    main "$@"
    exit $?
fi

# EOF