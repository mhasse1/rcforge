#!/usr/bin/env bash
# diag.sh - Visualize rcForge configuration loading order
# Author: rcForge Team
# Date: 2025-04-06
# Version: 0.4.0
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
    exit 0
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

    exit 0
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
# Description: Generate a Mermaid flowchart diagram from a list of files,
#              showing nodes sequentially and highlighting sequence conflicts
#              using direct 'style' commands. Uses unique node IDs based on filenames.
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
    local node_id=""            # Will be based on sanitized filename
    local node_label=""         # Separate variable for the visible label
    local prev_node_id="StartNode" # Start linking from StartNode

    # --- Data Structures ---
    declare -A seq_counts
    declare -A conflicting_seqs
    declare -A node_id_to_seq_num # Map generated node ID back to its sequence number

    # --- Pass 1: Identify Conflicts and Store Node Seq Info ---
    for file in "${files[@]}"; do
        filename=$(basename "$file")
        seq_num="${filename%%_*}"
        [[ ! "$seq_num" =~ ^[0-9]{3}$ ]] && continue
        seq_counts["$seq_num"]=$(( ${seq_counts[$seq_num]:-0} + 1 ))

        # Construct node ID and store its sequence number
        if [[ "$filename" == *.sh ]]; then IFS='_' read -r -a parts <<< "${filename%.sh}"; else IFS='_' read -r -a parts <<< "$filename"; fi
        hostname="${parts[1]:-unknown}"
        environment="${parts[2]:-unknown}"
        local current_node_id="Node_${filename//[^a-zA-Z0-9._-]/_}" # Use sanitized filename for ID
        node_id_to_seq_num["$current_node_id"]="$seq_num"
    done

    # Mark conflicting sequences
    for seq_num in "${!seq_counts[@]}"; do
        if [[ "${seq_counts[$seq_num]}" -gt 1 ]]; then
            conflicting_seqs["$seq_num"]=true
        fi
    done
    # --- End Pass 1 ---

    # --- Start Building Diagram String ---
    diagram+="# rcForge Configuration Loading Order (Mermaid Diagram)\n"
    diagram+="\`\`\`mermaid\n"
    diagram+="flowchart TD\n"
    # Define standard node style implicitly, will override for conflicts later
    diagram+="    StartNode([Start rcForge])\n"
    diagram+="    EndNode([End rcForge])\n\n"
    # --- End Initial Definitions ---

    # --- Pass 2: Define nodes and sequential links ---
    local processed_a_node=false # Track if any nodes were processed
    local -A defined_nodes # Keep track of nodes already defined to apply style later

    for file in "${files[@]}"; do
        filename=$(basename "$file")
        seq_num="${filename%%_*}"
        [[ ! "$seq_num" =~ ^[0-9]{3}$ ]] && continue # Skip invalid sequence numbers

        # Extract parts
        if [[ "$filename" == *.sh ]]; then IFS='_' read -r -a parts <<< "${filename%.sh}"; description="${filename#*_*_*_}"; description="${description%.sh}"; else IFS='_' read -r -a parts <<< "$filename"; description="${filename#*_*_*_}"; fi
        hostname="${parts[1]:-unknown}"
        environment="${parts[2]:-unknown}"

        # Create Unique Node ID
        local sanitized_filename="${filename//[^a-zA-Z0-9._-]/_}"
        node_id="Node_${sanitized_filename}"

        # Sanitize description for Label
        description="${description//\"/ }"; description="${description//\`/ }"
        node_label="${seq_num}: ${hostname}/${environment}<br>${description}"

        # Define node
        diagram+="    ${node_id}[\"${node_label}\"]\n"
        # Link from previous node
        diagram+="    $prev_node_id --> $node_id\n"

        # Store this node ID for later styling if needed
        defined_nodes["$node_id"]=1

        # Update previous node for next link
        prev_node_id="$node_id"
        processed_a_node=true
    done
    # --- End Pass 2 ---

    # --- Final Link to EndNode ---
    if [[ "$processed_a_node" == "true" ]]; then
        diagram+="    $prev_node_id --> EndNode\n"
    else
        diagram+="    StartNode --> EndNode\n"
    fi
    diagram+="\n"
    # --- End Final Link ---

    # --- Pass 3: Apply Direct Styles for Conflicts ---
    local conflict_style="fill:#fdd,stroke:#f00,stroke-width:2px" # Pinkish fill, red border
    for node_id in "${!defined_nodes[@]}"; do
         local current_seq_num="${node_id_to_seq_num[$node_id]:-}"
         # Apply conflict style if the sequence number was marked as conflicting
         if [[ -n "$current_seq_num" && -v "conflicting_seqs[$current_seq_num]" ]]; then
              diagram+="    style $node_id $conflict_style\n"
         fi
    done
    # --- End Pass 3 ---


    diagram+=" \`\`\`\n"
    printf '%b' "$diagram"
}

# ============================================================================
# Function: GenerateAsciiDiagram
# Description: Generate a simple ASCII text diagram from a list of files,
#              indicating sequence conflicts with a text marker. Uses sequential layout.
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
    local conflict_marker=""

    # --- Identify Conflicting Sequence Numbers ---
    declare -A seq_counts
    declare -A conflicting_seqs

    for file in "${files[@]}"; do
        filename=$(basename "$file")
        seq_num="${filename%%_*}"
        [[ ! "$seq_num" =~ ^[0-9]{3}$ ]] && continue
        seq_counts["$seq_num"]=$(( ${seq_counts[$seq_num]:-0} + 1 ))
    done
    for seq_num in "${!seq_counts[@]}"; do
        if [[ "${seq_counts[$seq_num]}" -gt 1 ]]; then
            conflicting_seqs["$seq_num"]=true
        fi
    done
    # --- End Conflict Identification ---

    diagram+="# rcForge Configuration Loading Order (ASCII Diagram)\n"
    diagram+="\`\`\`\n"
    diagram+="START rcForge\n"
    diagram+="   |\n"
    diagram+="   V\n"

    local processed_a_node=false
    for file in "${files[@]}"; do
        filename=$(basename "$file")
        seq_num="${filename%%_*}"
        [[ ! "$seq_num" =~ ^[0-9]{3}$ ]] && continue

        # Extract parts
        if [[ "$filename" == *.sh ]]; then IFS='_' read -r -a parts <<< "${filename%.sh}"; description="${filename#*_*_*_}"; description="${description%.sh}"; else IFS='_' read -r -a parts <<< "$filename"; description="${filename#*_*_*_}"; fi
        hostname="${parts[1]:-unknown}"
        environment="${parts[2]:-unknown}"

        # Determine conflict marker
        conflict_marker=""
        if [[ -v "conflicting_seqs[$seq_num]" ]]; then
             conflict_marker=" (CONFLICT)"
        fi

        # Add line to diagram
        diagram+="[${seq_num}] ${hostname}/${environment} - ${description}${conflict_marker}\n"
        diagram+="   |\n"
        diagram+="   V\n"
        processed_a_node=true
    done

    if [[ "$processed_a_node" != "true" ]]; then
         # If no nodes were processed, remove the initial arrow
         # Use parameter expansion for robust removal of last two lines
         diagram="${diagram%   |\n   V\n}"
    fi

    diagram+="END rcForge\n"
    diagram+="\`\`\`\n"

    # --- CORRECTED: Use %b to interpret \n ---
    printf '%b' "$diagram"
    # --- END CORRECTED ---
}

# ============================================================================
# Function: GenerateMermaidDiagram
# Description: Generate a Mermaid flowchart diagram from a list of files,
#              showing nodes sequentially and highlighting sequence conflicts
#              by styling the connecting LINKS red. Uses unique node IDs based on filenames.
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
    local node_id=""            # Based on sanitized filename
    local node_label=""         # Separate variable for the visible label
    local prev_node_id="StartNode" # Start linking from StartNode

    # --- Data Structures ---
    declare -A seq_counts
    declare -A conflicting_seqs
    declare -A node_id_to_seq_num # Map generated node ID back to its sequence number
    local -A defined_nodes # Keep track of node IDs defined
    local -a defined_links_source=() # Store source node ID for each link
    local -a defined_links_target=() # Store target node ID for each link

    # --- Pass 1: Identify Conflicts and Store Node Seq Info ---
    for file in "${files[@]}"; do
        filename=$(basename "$file")
        seq_num="${filename%%_*}"
        [[ ! "$seq_num" =~ ^[0-9]{3}$ ]] && continue
        seq_counts["$seq_num"]=$(( ${seq_counts[$seq_num]:-0} + 1 ))

        # Construct node ID and store its sequence number
        local sanitized_filename="${filename//[^a-zA-Z0-9._-]/_}"
        local current_node_id="Node_${sanitized_filename}"
        node_id_to_seq_num["$current_node_id"]="$seq_num"
    done

    # Mark conflicting sequences
    for seq_num in "${!seq_counts[@]}"; do
        if [[ "${seq_counts[$seq_num]}" -gt 1 ]]; then
            conflicting_seqs["$seq_num"]=true
        fi
    done
    # --- End Pass 1 ---

    # --- Start Building Diagram String ---
    diagram+="# rcForge Configuration Loading Order (Mermaid Diagram)\n"
    diagram+="\`\`\`mermaid\n"
    diagram+="flowchart TD\n"
    diagram+="    StartNode([Start rcForge])\n"
    diagram+="    EndNode([End rcForge])\n\n"
    # --- End Initial Definitions ---

    # --- Pass 2: Define nodes and sequential links ---
    local processed_a_node=false # Track if any nodes were processed

    for file in "${files[@]}"; do
        filename=$(basename "$file")
        seq_num="${filename%%_*}"
        [[ ! "$seq_num" =~ ^[0-9]{3}$ ]] && continue # Skip invalid sequence numbers

        # Extract parts
        if [[ "$filename" == *.sh ]]; then IFS='_' read -r -a parts <<< "${filename%.sh}"; description="${filename#*_*_*_}"; description="${description%.sh}"; else IFS='_' read -r -a parts <<< "$filename"; description="${filename#*_*_*_}"; fi
        hostname="${parts[1]:-unknown}"
        environment="${parts[2]:-unknown}"

        # Create Unique Node ID
        local sanitized_filename="${filename//[^a-zA-Z0-9._-]/_}"
        node_id="Node_${sanitized_filename}"

        # Sanitize description for Label
        description="${description//\"/ }"; description="${description//\`/ }"
        node_label="${seq_num}: ${hostname}/${environment}<br>${description}"

        # Define node
        diagram+="    ${node_id}[\"${node_label}\"]\n"
        # Define Link from previous node AND store link info
        diagram+="    $prev_node_id --> $node_id\n"
        defined_links_source+=("$prev_node_id")
        defined_links_target+=("$node_id")

        # Store this node ID
        defined_nodes["$node_id"]=1

        # Update previous node for next link
        prev_node_id="$node_id"
        processed_a_node=true
    done
    # --- End Pass 2 ---

    # --- Final Link to EndNode ---
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
    # --- End Final Link ---

    # --- Pass 3: Apply Link Styles for Conflicts ---
    local conflict_link_style="stroke:red,stroke-width:2px"
    local link_index=0
    for (( link_index=0; link_index < ${#defined_links_source[@]}; link_index++ )); do
         local source_node_id="${defined_links_source[$link_index]}"
         local target_node_id="${defined_links_target[$link_index]}"

         # Get sequence numbers for source and target (if they are script nodes)
         local source_seq_num="${node_id_to_seq_num[$source_node_id]:-}"
         local target_seq_num="${node_id_to_seq_num[$target_node_id]:-}"

         # Apply conflict style if EITHER the source OR target node sequence is conflicting
         local apply_style=false
         if [[ -n "$source_seq_num" && -v "conflicting_seqs[$source_seq_num]" ]]; then
              apply_style=true
         fi
         if [[ -n "$target_seq_num" && -v "conflicting_seqs[$target_seq_num]" ]]; then
              apply_style=true
         fi

         if [[ "$apply_style" == "true" ]]; then
              # Mermaid linkStyle is 0-based index
              diagram+="    linkStyle $link_index $conflict_link_style\n"
         fi
    done
    # --- End Pass 3 ---

    diagram+=" \`\`\`\n"
    printf '%b' "$diagram"
}

# ============================================================================
# Function: GenerateGraphvizDiagram
# Description: Generate a Graphviz DOT diagram from a list of files,
#              highlighting sequence conflicts with color. Uses sequential layout.
#              Ensures Node IDs containing special characters are quoted.
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
    local node_id=""            # Based on sanitized filename
    local quoted_node_id=""     # Node ID enclosed in quotes if needed
    local node_label=""
    local node_attrs=""         # For fillcolor, color attributes
    local prev_node_id="start_node" # Match start/end node names used below
    local quoted_prev_node_id="start_node" # Quoted version for links

    # --- Identify Conflicting Sequence Numbers ---
    declare -A seq_counts
    declare -A conflicting_seqs

    for file in "${files[@]}"; do
        filename=$(basename "$file")
        seq_num="${filename%%_*}"
        [[ ! "$seq_num" =~ ^[0-9]{3}$ ]] && continue
        seq_counts["$seq_num"]=$(( ${seq_counts[$seq_num]:-0} + 1 ))
    done
    for seq_num in "${!seq_counts[@]}"; do
        if [[ "${seq_counts[$seq_num]}" -gt 1 ]]; then
            conflicting_seqs["$seq_num"]=true
        fi
    done
    # --- End Conflict Identification ---

    diagram+="// rcForge Configuration Loading Order (Graphviz DOT Diagram)\n"
    diagram+="digraph rcForgeLoadingOrder {\n"
    diagram+="    rankdir=TD;\n"
    diagram+="    node [shape=box, style=filled, fontname=\"Helvetica,Arial,sans-serif\"];\n"
    diagram+="    edge [fontname=\"Helvetica,Arial,sans-serif\"];\n\n"
    diagram+="    start_node [label=\"Start rcForge\", shape=oval, style=\"\", fillcolor=\"\"];\n" # No fill for start/end
    diagram+="    end_node [label=\"End rcForge\", shape=oval, style=\"\", fillcolor=\"\"];\n\n"

    local processed_a_node=false
    for file in "${files[@]}"; do
        filename=$(basename "$file")
        seq_num="${filename%%_*}"
        [[ ! "$seq_num" =~ ^[0-9]{3}$ ]] && continue

        # Extract parts
        if [[ "$filename" == *.sh ]]; then IFS='_' read -r -a parts <<< "${filename%.sh}"; description="${filename#*_*_*_}"; description="${description%.sh}"; else IFS='_' read -r -a parts <<< "$filename"; description="${filename#*_*_*_}"; fi
        hostname="${parts[1]:-unknown}"
        environment="${parts[2]:-unknown}"

        # Create Unique Node ID
        local sanitized_filename="${filename//[^a-zA-Z0-9._-]/_}" # Keep . and - for now
        node_id="Node_${sanitized_filename}"
        quoted_node_id="\"${node_id}\"" # Always quote generated IDs

        # Sanitize description for Label & escape for DOT
        description="${description//\"/\\\"}" # Escape double quotes for DOT label
        node_label="${seq_num}: ${hostname}/${environment}\\n${description}" # Use \\n for newline in DOT

        # Determine Node Attributes (Coloring)
        node_attrs=""
        if [[ -v "conflicting_seqs[$seq_num]" ]]; then
             # Conflicting node: light pink fill, red border
             node_attrs="fillcolor=\"#fdd\", color=\"red\", style=\"filled,bold\""
        else
             # Standard node: default fill (e.g., Light gray)
             node_attrs="fillcolor=\"#eeeeee\""
        fi

        # Define node with attributes (use quoted ID)
        diagram+="    ${quoted_node_id} [label=\"${node_label}\", ${node_attrs}];\n"
        # Link from previous node (use quoted IDs)
        diagram+="    ${quoted_prev_node_id} -> ${quoted_node_id};\n"

        # Update previous node for next link (store both quoted and unquoted)
        prev_node_id="$node_id"
        quoted_prev_node_id="$quoted_node_id"
        processed_a_node=true
    done

    # Final Link to EndNode (use quoted ID for last node)
    if [[ "$processed_a_node" == "true" ]]; then
        diagram+="    ${quoted_prev_node_id} -> end_node;\n"
    else
        diagram+="    start_node -> end_node;\n"
    fi
    diagram+="}\n"

    # Use %b to interpret escapes like \n and \\n
    printf '%b' "$diagram"
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
    local -n options_ref="$1" # Use nameref [cite: 742]
    shift

    # Call PascalCase functions for defaults
    options_ref["target_hostname"]="$(DetectCurrentHostname)" # [cite: 743]
    options_ref["target_shell"]="$(DetectCurrentShell)" # [cite: 743]
    options_ref["output_file"]="" # [cite: 743]
    options_ref["format"]="mermaid" # [cite: 743]
    options_ref["verbose_mode"]=false # [cite: 743]
    #options_ref["args"]=() # For any future positional args

    # --- Pre-parse checks for summary/help ---
     # Check BEFORE the loop if only summary/help is requested
     if [[ "$#" -eq 1 ]]; then
         case "$1" in
            --help|-h) ShowHelp; return 1 ;;
            --summary) ShowSummary; return 0 ;; # Handle summary
         esac
     # Also handle case where summary/help might be first but other args exist
     elif [[ "$#" -gt 0 ]]; then
          case "$1" in
             --help|-h) ShowHelp; return 1 ;;
             --summary) ShowSummary; return 0 ;; # Handle summary
         esac
     fi
    # --- End pre-parse ---

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --help|-h) ShowHelp; return 1 ;; # [cite: 744]
            --summary) ShowSummary; return 0 ;; # [cite: 745]
            --hostname=*) options_ref["target_hostname"]="${1#*=}"; shift ;; # [cite: 745]
            --shell=*)
                options_ref["target_shell"]="${1#*=}"
                if ! ValidateShellType "${options_ref["target_shell"]}"; then return 1; fi # Call PascalCase [cite: 747]
                shift ;;
            --output=*) options_ref["output_file"]="${1#*=}"; shift ;; # [cite: 748]
            --format=*)
                options_ref["format"]="${1#*=}"
                if ! ValidateFormat "${options_ref["format"]}"; then return 1; fi # Call PascalCase [cite: 749]
                shift ;;
            --verbose|-v) options_ref["verbose_mode"]=true; shift ;; # [cite: 750]
            *)
                # Assume any other arg is an error for diag
                ErrorMessage "Unknown parameter or unexpected argument: $1" # [cite: 751]
                ShowHelp
                return 1
                # If diag ever takes positional args, capture them here:
                # options_ref["args"]+=("$1"); shift ;;
                ;;
        esac
    done

    # Final validation after defaults
    if ! ValidateShellType "${options_ref["target_shell"]}"; then # Call PascalCase [cite: 753]
         WarningMessage "Default shell detection failed or resulted in unsupported shell." [cite: 753]
         return 1
    fi

    return 0 # Success [cite: 754]
}

# ============================================================================
# Function: main
# Description: Main execution logic for the diag script.
# Usage: main "$@"
# Returns: 0 on success, 1 on failure.
# ============================================================================
main() {
    local rcforge_dir
    rcforge_dir=$(DetermineRcforgeDir) # Call PascalCase [cite: 756]
    declare -A options
    local -a config_files
    local default_filename="" # Temp var for default name construction

    # Call ParseArguments. Exit if parsing failed or help/summary displayed.
    ParseArguments options "$@" || exit $? # [cite: 757]

    # Determine default output file path if not provided (using options array)
    if [[ -z "${options[output_file]}" ]]; then # [cite: 758]
         default_filename="loading_order_${options[target_hostname]}_${options[target_shell]}.${options[format]}" # [cite: 759]
         if [[ "${options[format]}" == "mermaid" ]]; then default_filename="${default_filename%.*}.md"; fi # [cite: 760]
         if [[ "${options[format]}" == "graphviz" ]]; then default_filename="${default_filename%.*}.dot"; fi # [cite: 761]
         if [[ "${options[format]}" == "ascii" ]]; then default_filename="${default_filename%.*}.txt"; fi # [cite: 762]
         options[output_file]="${gc_default_output_dir}/${default_filename}" # [cite: 762]
    fi

    SectionHeader "rcForge Configuration Diagram Generation (v${gc_version})" # Call PascalCase [cite: 762]

    # Call FindConfigFiles. Use process substitution and mapfile.
    mapfile -t config_files < <(FindConfigFiles "$rcforge_dir" "${options[target_shell]}" "${options[target_hostname]}" "${options[verbose_mode]}") || { # [cite: 763]
        # find_config_files already prints message, just return failure status
        return 1 # [cite: 764]
    }


    # Call GenerateDiagram function to generate the diagram (using options array)
    GenerateDiagram \
        "${options[format]}" \
        "${options[output_file]}" \
        "${options[verbose_mode]}" \
        "${config_files[@]}" # [cite: 764]

    return $? # Return status of GenerateDiagram [cite: 765]
}


# Execute main function if run directly or via rc command
if [[ "${BASH_SOURCE[0]}" == "${0}" ]] || [[ "${BASH_SOURCE[0]}" != "${0}" && "$0" == *"rc"* ]]; then
    main "$@"
    exit $?
fi

# EOF