#!/usr/bin/env bash
# diag.sh - Visualize rcForge configuration loading order
# Author: rcForge Team
# Date: 2025-04-07 # Updated Date - Fix summary exit, explicit source
# Version: 0.4.1
# Category: system/utility
# RC Summary: Creates diagrams of rcForge configuration loading sequence
# Description: Generates visual representations of shell configuration loading sequence

# Source necessary libraries explicitly
source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/shell-colors.sh"
source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/utility-functions.sh"

# Set strict error handling
# set -o nounset # Keep disabled for now, review later
set -o pipefail # Good practice for pipelines like grep|sed
# set -o errexit # Let functions handle errors

# ============================================================================
# GLOBAL CONSTANTS
# ============================================================================
# Use sourced constants, provide fallback just in case
[ -v gc_version ]  || readonly gc_version="${RCFORGE_VERSION:-0.4.1}"
[ -v gc_app_name ] || readonly gc_app_name="${RCFORGE_APP_NAME:-rcForge}"
readonly gc_default_output_dir="${HOME}/.config/rcforge/docs" # Default output dir

# ============================================================================
# UTILITY FUNCTIONS (Local to diag.sh or Sourced)
# ============================================================================

# ============================================================================
# Function: ShowSummary
# Description: Echos summary string and exits 0. Called for 'rc list'.
# Usage: ShowSummary
# Exits: 0
# ============================================================================
ShowSummary() {
    # grep potentially fails if line missing - handle with || true
    grep '^# RC Summary:' "$0" | sed 's/^# RC Summary: //' || true
    exit 0 # Exit successfully after printing summary
}

# ============================================================================
# Function: ShowHelp
# Description: Display detailed help information for the diag command.
# Usage: ShowHelp
# Exits: 0
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
    echo "  $(basename "$0") [options]" # Show direct usage too
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
    echo "  rc diag                                  # Diagram for current shell/hostname"
    echo "  rc diag --shell=bash                         # Generate Bash diagram"
    echo "  rc diag --hostname=laptop --shell=zsh      # Diagram for laptop's Zsh config"
    echo "  rc diag --format=ascii --output=~/diag.txt # Output ASCII to specific file"
    exit 0 # Exit after showing help
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
# Diagram Generation Functions
# ============================================================================

# ============================================================================
# Function: GenerateMermaidDiagram
# Description: Generate a Mermaid flowchart diagram from a list of files.
# Usage: GenerateMermaidDiagram file1 [file2...]
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
    local node_label=""
    local prev_node_id="StartNode"
    declare -A seq_counts
    declare -A conflicting_seqs
    declare -A node_id_to_seq_num
    local -A defined_nodes
    local -a defined_links_source=()
    local -a defined_links_target=()

    # Pass 1: Identify Conflicts and Store Node Seq Info
    for file in "${files[@]}"; do
        filename=$(basename "$file")
        seq_num="${filename%%_*}"
        if ! [[ "$seq_num" =~ ^[0-9]{3}$ ]]; then
             WarningMessage "Skipping file with invalid sequence format in diagram: $filename"
             continue
        fi
        seq_counts["$seq_num"]=$(( ${seq_counts[$seq_num]:-0} + 1 ))
        local sanitized_filename="${filename//[^a-zA-Z0-9._-]/_}"
        local current_node_id="Node_${sanitized_filename}"
        node_id_to_seq_num["$current_node_id"]="$seq_num"
    done

    for seq_num in "${!seq_counts[@]}"; do
        if [[ "${seq_counts[$seq_num]}" -gt 1 ]]; then conflicting_seqs["$seq_num"]=true; fi
    done

    # Start Building Diagram String
    diagram+="# rcForge Configuration Loading Order (Mermaid Diagram)\n"
    diagram+=" \`\`\`mermaid\n" # Use triple backticks
    diagram+="flowchart TD\n"
    diagram+="    StartNode([Start rcForge])\n"
    diagram+="    EndNode([End rcForge])\n\n"

    # Pass 2: Define nodes and sequential links
    local processed_a_node=false
    for file in "${files[@]}"; do
        filename=$(basename "$file")
        seq_num="${filename%%_*}"
        if ! [[ "$seq_num" =~ ^[0-9]{3}$ ]]; then continue; fi

        IFS='_' read -r -a parts <<< "${filename%.sh}"
        hostname="${parts[1]:-unknown}"
        environment="${parts[2]:-unknown}"
        description=$(printf "%s" "${parts[@]:3}" | sed 's/_/ /g') # Join remaining parts

        local sanitized_filename="${filename//[^a-zA-Z0-9._-]/_}"
        node_id="Node_${sanitized_filename}"
        description="${description//\"/&quot;}"; # Escape quotes for Mermaid label
        node_label="${seq_num}: ${hostname}/${environment}<br>${description}"

        diagram+="    ${node_id}[\"${node_label}\"]\n"
        diagram+="    $prev_node_id --> $node_id\n"
        defined_links_source+=("$prev_node_id")
        defined_links_target+=("$node_id")
        defined_nodes["$node_id"]=1
        prev_node_id="$node_id"
        processed_a_node=true
    done

    # Final Link to EndNode
    if [[ "$processed_a_node" == "true" ]]; then
        diagram+="    $prev_node_id --> EndNode\n"
        defined_links_source+=("$prev_node_id")
        defined_links_target+=("EndNode")
    else
        diagram+="    StartNode --> EndNode\n"
        defined_links_source+=("StartNode")
        defined_links_target+=("EndNode")
    fi
    diagram+="\n"

    # Pass 3: Apply Link Styles for Conflicts
    local conflict_link_style="stroke:red,stroke-width:2px"
    local link_index=0
    for (( link_index=0; link_index < ${#defined_links_source[@]}; link_index++ )); do
         local source_node_id="${defined_links_source[$link_index]}"
         local target_node_id="${defined_links_target[$link_index]}"
         local source_seq_num="${node_id_to_seq_num[$source_node_id]:-}"
         local target_seq_num="${node_id_to_seq_num[$target_node_id]:-}"
         local apply_style=false
         if [[ -n "$source_seq_num" && -v "conflicting_seqs[$source_seq_num]" ]]; then apply_style=true; fi
         if [[ -n "$target_seq_num" && -v "conflicting_seqs[$target_seq_num]" ]]; then apply_style=true; fi
         if [[ "$apply_style" == "true" ]]; then
              diagram+="    linkStyle $link_index $conflict_link_style\n"
         fi
    done

    diagram+=" \`\`\`\n" # Use triple backticks
    printf '%b' "$diagram"
}

# ============================================================================
# Function: GenerateAsciiDiagram
# Description: Generate a simple ASCII text diagram from a list of files.
# Usage: GenerateAsciiDiagram file1 [file2...]
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
    local conflict_marker=""
    declare -A seq_counts
    declare -A conflicting_seqs

    # Identify Conflicts
    for file in "${files[@]}"; do
        filename=$(basename "$file")
        seq_num="${filename%%_*}"
        if ! [[ "$seq_num" =~ ^[0-9]{3}$ ]]; then
             WarningMessage "Skipping file with invalid sequence format in diagram: $filename"
             continue
        fi
        seq_counts["$seq_num"]=$(( ${seq_counts[$seq_num]:-0} + 1 ))
    done
    for seq_num in "${!seq_counts[@]}"; do
        if [[ "${seq_counts[$seq_num]}" -gt 1 ]]; then conflicting_seqs["$seq_num"]=true; fi
    done

    # Build Diagram
    diagram+=" \`\`\`text\n" # Use triple backticks
    diagram+="# rcForge Configuration Loading Order (ASCII Diagram)\n\n"
    diagram+="START rcForge\n   |\n   V\n"
    local processed_a_node=false
    for file in "${files[@]}"; do
        filename=$(basename "$file")
        seq_num="${filename%%_*}"
        if ! [[ "$seq_num" =~ ^[0-9]{3}$ ]]; then continue; fi

        IFS='_' read -r -a parts <<< "${filename%.sh}"
        hostname="${parts[1]:-unknown}"
        environment="${parts[2]:-unknown}"
        description=$(printf "%s" "${parts[@]:3}" | sed 's/_/ /g')

        conflict_marker=""
        if [[ -v "conflicting_seqs[$seq_num]" ]]; then conflict_marker=" (CONFLICT)"; fi

        diagram+="[${seq_num}] ${hostname}/${environment} - ${description}${conflict_marker}\n   |\n   V\n"
        processed_a_node=true
    done

    if [[ "$processed_a_node" != "true" ]]; then
         diagram="${diagram%   |\n   V\n}"
    fi
    diagram+="END rcForge\n \`\`\`\n" # Use triple backticks
    printf '%b' "$diagram"
}

# ============================================================================
# Function: GenerateGraphvizDiagram
# Description: Generate a Graphviz DOT diagram from a list of files.
# Usage: GenerateGraphvizDiagram file1 [file2...]
# Returns: Echoes Graphviz DOT diagram text.
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
    local quoted_node_id=""
    local node_label=""
    local node_attrs=""
    local quoted_prev_node_id="\"start_node\""
    declare -A seq_counts
    declare -A conflicting_seqs

    # Identify Conflicts
    for file in "${files[@]}"; do
        filename=$(basename "$file")
        seq_num="${filename%%_*}"
        if ! [[ "$seq_num" =~ ^[0-9]{3}$ ]]; then
             WarningMessage "Skipping file with invalid sequence format in diagram: $filename"
             continue
        fi
        seq_counts["$seq_num"]=$(( ${seq_counts[$seq_num]:-0} + 1 ))
    done
    for seq_num in "${!seq_counts[@]}"; do
        if [[ "${seq_counts[$seq_num]}" -gt 1 ]]; then conflicting_seqs["$seq_num"]=true; fi
    done

    # Build Diagram
    diagram+="// rcForge Configuration Loading Order (Graphviz DOT Diagram)\n"
    diagram+="digraph rcForgeLoadingOrder {\n"
    diagram+="    rankdir=TD;\n"
    diagram+="    node [shape=box, style=filled, fontname=\"Helvetica,Arial,sans-serif\"];\n"
    diagram+="    edge [fontname=\"Helvetica,Arial,sans-serif\"];\n\n"
    diagram+="    \"start_node\" [label=\"Start rcForge\", shape=oval, style=\"\", fillcolor=\"none\"];\n"
    diagram+="    \"end_node\" [label=\"End rcForge\", shape=oval, style=\"\", fillcolor=\"none\"];\n\n"
    local processed_a_node=false
    for file in "${files[@]}"; do
        filename=$(basename "$file")
        seq_num="${filename%%_*}"
        if ! [[ "$seq_num" =~ ^[0-9]{3}$ ]]; then continue; fi

        IFS='_' read -r -a parts <<< "${filename%.sh}"
        hostname="${parts[1]:-unknown}"
        environment="${parts[2]:-unknown}"
        description=$(printf "%s" "${parts[@]:3}" | sed 's/_/ /g')

        local sanitized_filename="${filename//[^a-zA-Z0-9._-]/_}"
        node_id="Node_${sanitized_filename}"
        quoted_node_id="\"${node_id}\""

        description="${description//\"/\\\"}" # Escape quotes for DOT label
        node_label="${seq_num}: ${hostname}/${environment}\\n${description}" # Use \\n

        node_attrs=""
        if [[ -v "conflicting_seqs[$seq_num]" ]]; then
             node_attrs="fillcolor=\"#fdd\", color=\"red\", style=\"filled,bold\""
        else
             node_attrs="fillcolor=\"#eeeeee\""
        fi

        diagram+="    ${quoted_node_id} [label=\"${node_label}\", ${node_attrs}];\n"
        diagram+="    ${quoted_prev_node_id} -> ${quoted_node_id};\n"
        quoted_prev_node_id="$quoted_node_id"
        processed_a_node=true
    done

    if [[ "$processed_a_node" == "true" ]]; then
        diagram+="    ${quoted_prev_node_id} -> \"end_node\";\n"
    else
        diagram+="    \"start_node\" -> \"end_node\";\n"
    fi
    diagram+="}\n"
    printf '%b' "$diagram"
}

# ============================================================================
# Function: GenerateDiagram
# Description: Generate diagram in specified format and write to output file.
# Usage: GenerateDiagram format output_file is_verbose file1 [file2...]
# ============================================================================
GenerateDiagram() {
    local format="$1"
    local output_file="$2"
    local is_verbose="$3"
    shift 3
    local -a files=("$@")
    local output_dir
    local diagram_output=""

    output_dir=$(dirname "$output_file")
    mkdir -p "$output_dir" || { ErrorMessage "Failed to create output directory: $output_dir"; return 1; }
    chmod 700 "$output_dir" || WarningMessage "Could not set permissions (700) on $output_dir"

    InfoMessage "Generating diagram (format: $format)..."

    case "$format" in
        mermaid) diagram_output=$(GenerateMermaidDiagram "${files[@]}") ;;
        graphviz) diagram_output=$(GenerateGraphvizDiagram "${files[@]}") ;;
        ascii) diagram_output=$(GenerateAsciiDiagram "${files[@]}") ;;
        *) ErrorMessage "Internal error: Unsupported format '$format' in GenerateDiagram."; return 1 ;;
    esac

    if printf '%s\n' "$diagram_output" > "$output_file"; then
        chmod 600 "$output_file" || WarningMessage "Could not set permissions (600) on $output_file"
        SuccessMessage "Diagram generated successfully: $output_file"
        if [[ "$is_verbose" == "true" ]]; then
            InfoMessage "  Format: $format"
            InfoMessage "  Based on ${#files[@]} configuration files."
            if command -v open &> /dev/null; then open "$output_file" &
            elif command -v xdg-open &> /dev/null; then xdg-open "$output_file" &
            else InfoMessage "Could not automatically open the diagram file."; fi
        fi
        return 0
    else
        ErrorMessage "Failed to write diagram to: $output_file"
        [[ ! -s "$output_file" ]] && rm -f "$output_file" &>/dev/null
        return 1
    fi
}

ParseArguments() {
    local -n options_ref="$1"; shift
    if [[ "${BASH_VERSINFO[0]}" -lt 4 || ( "${BASH_VERSINFO[0]}" -eq 4 && "${BASH_VERSINFO[1]}" -lt 3 ) ]]; then ErrorMessage "Internal Error: ParseArguments requires Bash 4.3+ for namerefs."; return 1; fi

    # --- FIX: Call functions outside command substitution for assignment ---
    local default_host; default_host=$(DetectCurrentHostname)
    options_ref["target_hostname"]="${default_host}"

    local default_shell; default_shell=$(DetectShell) # <<< Use correct function name
    options_ref["target_shell"]="${default_shell}"
    # --- End FIX ---

    options_ref["output_file"]=""
    options_ref["format"]="mermaid"
    options_ref["verbose_mode"]=false

    # Check for help/summary first (ShowHelp/ShowSummary exit directly)
    if [[ "$#" -gt 0 ]]; then case "$1" in --help|-h) ShowHelp ;; --summary) ShowSummary ;; esac; fi

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --help|-h) ShowHelp ;; # Exits
            --summary) ShowSummary ;; # Exits
            --hostname=*) options_ref["target_hostname"]="${1#*=}"; shift ;;
            --shell=*)
                options_ref["target_shell"]="${1#*=}"
                 if ! ValidateShellType "${options_ref["target_shell"]}"; then return 1; fi
                shift ;;
            --output=*) options_ref["output_file"]="${1#*=}"; shift ;;
            --format=*)
                options_ref["format"]="${1#*=}"
                 if ! ValidateFormat "${options_ref["format"]}"; then return 1; fi
                shift ;;
            --verbose|-v) options_ref["verbose_mode"]=true; shift ;;
            *) ErrorMessage "Unknown parameter or unexpected argument: $1"; ShowHelp; return 1 ;;
        esac
    done

    # Final validation
     if ! ValidateShellType "${options_ref["target_shell"]}"; then WarningMessage "Default shell detection failed or resulted in unsupported shell."; return 1; fi
    return 0
}

# ============================================================================
# Function: main
# ============================================================================
main() {
    local rcforge_dir
    rcforge_dir=$(DetermineRcForgeDir) # Use sourced function
    declare -A options
    local -a config_files
    local default_filename=""

    # Parse Arguments, exit if error or help/summary shown by ParseArguments
    ParseArguments options "$@" || exit 1

    # Determine default output file path
    if [[ -z "${options[output_file]}" ]]; then
         default_filename="loading_order_${options[target_hostname]}_${options[target_shell]}"
         case "${options[format]}" in
             mermaid) default_filename+=".md" ;;
             graphviz) default_filename+=".dot" ;;
             ascii) default_filename+=".txt" ;;
         esac
         options[output_file]="${gc_default_output_dir}/${default_filename}"
    fi

    SectionHeader "rcForge Configuration Diagram Generation (v${gc_version})"

    # Find config files using the *sourced* FindRcScripts function directly
    # Need to handle potential error return from FindRcScripts (dir missing)
    local find_output
    find_output=$(FindRcScripts "${options[target_shell]}" "${options[target_hostname]}")
    local find_status=$?

    if [[ $find_status -ne 0 ]]; then
        # Error message printed by FindRcScripts
        return 1 # Propagate error
    elif [[ -z "$find_output" ]]; then
        InfoMessage "No configuration files found for ${options[target_shell]}/${options[target_hostname]}. Diagram not generated."
        return 0 # Not an error if no files found
    fi

    # Load file list into array using mapfile
    mapfile -t config_files <<< "$find_output"

    # Generate the diagram
    GenerateDiagram \
        "${options[format]}" \
        "${options[output_file]}" \
        "${options[verbose_mode]}" \
        "${config_files[@]}"

    return $?
}


# Execute main function if run directly or via rc command wrapper
# Check if IsExecutedDirectly is defined before calling it
if command -v IsExecutedDirectly &> /dev/null ; then
    if IsExecutedDirectly || [[ "$0" == *"rc"* ]]; then
        main "$@"
        exit $?
    fi
else
    # Fallback if library sourcing failed completely
    echo "ERROR: Cannot determine execution context (IsExecutedDirectly not found)." >&2
    if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
         main "$@"
         exit $?
    fi
fi

# EOF
