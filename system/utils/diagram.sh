#!/usr/bin/env bash
# diagram.sh - Visualize rcForge configuration loading order
# Author: rcForge Team
# Date: 2025-04-21
# Version: 0.5.0
# Category: system/utility
# RC Summary: Creates diagrams of rcForge configuration loading sequence
# Description: Generates visual representations of shell configuration loading sequence
#              using Mermaid or ASCII format.

# Source necessary libraries
source "${RCFORGE_LIB:-$HOME/.local/share/rcforge/system/lib}/utility-functions.sh"

# Set strict error handling
set -o nounset
set -o pipefail
# set -o errexit # Let functions handle errors and return status

# ============================================================================
# GLOBAL CONSTANTS
# ============================================================================
# Use sourced constants, provide fallback just in case
[[ -v gc_version ]] || readonly gc_version="${RCFORGE_VERSION:-0.5.0}"
[[ -v gc_app_name ]] || readonly gc_app_name="${RCFORGE_APP_NAME:-rcForge}"
readonly UTILITY_NAME="diagram"
readonly GC_DEFAULT_OUTPUT_DIR="${RCFORGE_CONFIG_ROOT}/docs"

# ============================================================================
# Function: ShowHelp
# Description: Display detailed help information for the diagram command.
# Usage: ShowHelp
# Exits: 0
# ============================================================================
ShowHelp() {
	local script_name
	script_name=$(basename "$0")

	echo "diagram - rcForge Configuration Diagram Generator (v${gc_version})"
	echo ""
	echo "Description:"
	echo "  Generates visual representations of shell configuration loading sequence"
	echo "  to help understand the order in which scripts are loaded."
	echo ""
	echo "Usage:"
	echo "  rc diagram [options]"
	echo "  ${script_name} [options]"
	echo ""
	echo "Options:"
	echo "  --hostname=NAME   Specify hostname (default: current hostname)"
	echo "  --shell=TYPE      Specify shell type (bash or zsh, default: current shell)"
	echo "  --output=FILE     Specify output file path (optional, defaults to docs dir)"
	echo "  --format=FORMAT   Output format (mermaid or ascii; default: mermaid)"
	echo "  --verbose, -v     Enable verbose output"
	echo "  --help, -h        Show this help message"
	echo "  --summary         Show a one-line description (for rc help)"
	echo "  --version         Show version information"
	echo ""
	echo "Examples:"
	echo "  rc diagram                             # Diagram for current shell/hostname"
	echo "  rc diagram --shell=bash                # Generate Bash diagram"
	echo "  rc diagram --hostname=laptop --shell=zsh # Diagram for laptop's Zsh config"
	echo "  rc diagram --format=ascii              # Output as ASCII art"
	exit 0
}

# ============================================================================
# Function: ValidateShellType
# Description: Validate shell type ('bash' or 'zsh').
# Usage: ValidateShellType shell_type
# Returns: 0 if valid, 1 if invalid.
# ============================================================================
ValidateShellType() {
	local shell_to_check="${1:-}"
	local -r supported_shells=("bash" "zsh")
	local supported=""

	for supported in "${supported_shells[@]}"; do
		if [[ "$shell_to_check" == "$supported" ]]; then
			return 0 # Format is supported
		fi
	done

	ErrorMessage "Invalid shell type specified: '$shell_to_check'. Must be 'bash' or 'zsh'."
	return 1
}

# ============================================================================
# Function: ValidateFormat
# Description: Validate the requested diagram output format.
# Usage: ValidateFormat format
# Returns: 0 if valid, 1 if invalid.
# ============================================================================
ValidateFormat() {
	local format_to_check="${1:-}"
	local -r supported_formats=("mermaid" "ascii")
	local supported=""

	for supported in "${supported_formats[@]}"; do
		if [[ "$format_to_check" == "$supported" ]]; then
			return 0 # Format is supported
		fi
	done

	ErrorMessage "Unsupported diagram format specified: '$format_to_check'."
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
		seq_counts["$seq_num"]=$((${seq_counts[$seq_num]:-0} + 1))
		local sanitized_filename="${filename//[^a-zA-Z0-9._-]/_}"
		local current_node_id="Node_${sanitized_filename}"
		node_id_to_seq_num["$current_node_id"]="$seq_num"
	done

	for seq_num in "${!seq_counts[@]}"; do
		if [[ "${seq_counts[$seq_num]}" -gt 1 ]]; then
			conflicting_seqs["$seq_num"]=true
		fi
	done

	# Start Building Diagram String
	diagram+="# rcForge Configuration Loading Order\n"
	diagram+="\`\`\`mermaid\nflowchart TD\n"
	diagram+="    StartNode\([Start rcForge script load]\)\n"
	diagram+="    EndNode\([End rcForge script load]\)\n\n"

	# Pass 2: Define nodes and sequential links
	local processed_a_node=false
	for file in "${files[@]}"; do
		filename=$(basename "$file")
		seq_num="${filename%%_*}"
		if ! [[ "$seq_num" =~ ^[0-9]{3}$ ]]; then continue; fi

		IFS='_' read -r -a parts <<<"${filename%.sh}"
		hostname="${parts[1]:-unknown}"
		environment="${parts[2]:-unknown}"
		# Join remaining parts for description, handle potential empty case
		description=$(printf "%s" "${parts[@]:3}" | sed 's/_/ /g') || description=""

		local sanitized_filename="${filename//[^a-zA-Z0-9._-]/_}"
		node_id="Node_${sanitized_filename}"
		description="${description//\"/\\\"}" # Escape quotes for Mermaid label
		node_label="${seq_num}: ${hostname}/${environment}<br>${description}"

		# Use proper Mermaid syntax for node labels
		diagram+="    ${node_id}[\"${node_label}\"]\n"
		diagram+="    ${prev_node_id} --> ${node_id}\n"
		defined_links_source+=("$prev_node_id")
		defined_links_target+=("$node_id")
		defined_nodes["$node_id"]=1
		prev_node_id="$node_id"
		processed_a_node=true
	done

	# Final Link to EndNode
	if [[ "$processed_a_node" == "true" ]]; then
		diagram+="    ${prev_node_id} --> EndNode\n"
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
	for ((link_index = 0; link_index < ${#defined_links_source[@]}; link_index++)); do
		local source_node_id="${defined_links_source[$link_index]}"
		local target_node_id="${defined_links_target[$link_index]}"
		local source_seq_num="${node_id_to_seq_num[$source_node_id]:-}"
		local target_seq_num="${node_id_to_seq_num[$target_node_id]:-}"
		local apply_style=false
		if [[ -n "$source_seq_num" && -v "conflicting_seqs[$source_seq_num]" ]]; then apply_style=true; fi
		if [[ -n "$target_seq_num" && -v "conflicting_seqs[$target_seq_num]" ]]; then apply_style=true; fi
		if [[ "$apply_style" == "true" ]]; then
			diagram+="    linkStyle ${link_index} ${conflict_link_style}\n"
		fi
	done

	diagram+="\`\`\`\n"
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
		seq_counts["$seq_num"]=$((${seq_counts[$seq_num]:-0} + 1))
	done
	for seq_num in "${!seq_counts[@]}"; do
		if [[ "${seq_counts[$seq_num]}" -gt 1 ]]; then
			conflicting_seqs["$seq_num"]=true
		fi
	done

	# Build Diagram
	diagram+="$()$(text\n"
    diagram+="# rcForge Configuration Loading Order\n\n"
    diagram+="START rcForge\n | \n V\n"
    local processed_a_node=false
    for file in "${files[@]}"; do
        filename=$(basename "$file")
        seq_num="${filename%%_*}"
        if ! [[ "$seq_num" =~ ^[0-9]{3}$ ]]; then continue; fi

        IFS='_' read -r -a parts <<<"${filename%.sh}"
        hostname="${parts[1]:-unknown}"
        environment="${parts[2]:-unknown}"
        description=$(printf "%s" "${parts[@]:3}" | sed 's/_/ /g') || description=""

        conflict_marker=""
        if [[ -v "conflicting_seqs[$seq_num]" ]]; then
            conflict_marker=" \(CONFLICT\)"
        fi

        diagram+="[${seq_num}] ${hostname}/${environment} - ${description}${conflict_marker}\n | \n V\n"
        processed_a_node=true
    done

    if [[ "$processed_a_node" != "true" ]]; then
        diagram="${diagram%   |\n   V\n}"
    fi
    diagram+="END rcForge\n)$()\n"
	printf '%b' "$diagram"
}

# ============================================================================
# Function: GenerateDiagram
# Description: Generate diagram in specified format and write to output file.
# Usage: GenerateDiagram format output_file is_verbose file_array
# Returns: 0 on success, 1 on failure.
# ============================================================================
GenerateDiagram() {
	local format="${1:-}"
	local output_file="${2:-}"
	local is_verbose="${3:-false}"
	shift 3
	local -a files=("$@")
	local output_dir
	local diagram_output=""

	# Validate essential arguments
	if [[ -z "$format" || -z "$output_file" ]]; then
		ErrorMessage "Internal error: Format and output file must be specified for GenerateDiagram."
		return 1
	fi

	output_dir=$(dirname "$output_file")
	# Check if directory creation is needed and possible
	if [[ ! -d "$output_dir" ]]; then
		if ! mkdir -p "$output_dir"; then
			ErrorMessage "Failed to create output directory: $output_dir"
			return 1
		fi
		if ! chmod 700 "$output_dir"; then
			WarningMessage "Could not set permissions (700) on newly created $output_dir"
		fi
	fi

	InfoMessage "Generating diagram (format: $format)..."

	case "$format" in
		mermaid)
			diagram_output=$(GenerateMermaidDiagram "${files[@]}")
			;;
		ascii)
			diagram_output=$(GenerateAsciiDiagram "${files[@]}")
			;;
		*)
			ErrorMessage "Internal error: Unsupported format '$format' in GenerateDiagram."
			return 1
			;;
	esac

	# Write output to file
	if printf '%s\n' "$diagram_output" >"$output_file"; then
		if ! chmod 600 "$output_file"; then
			WarningMessage "Could not set permissions (600) on $output_file"
		fi
		SuccessMessage "Diagram generated successfully: $output_file"
		if [[ "$is_verbose" == "true" ]]; then
			InfoMessage "  Format: $format"
			InfoMessage "  Based on ${#files[@]} configuration files."
			# Attempt to open file (background)
			if command -v open &>/dev/null; then
				open "$output_file" &
			elif command -v xdg-open &>/dev/null; then
				xdg-open "$output_file" &
			else
				InfoMessage "Could not automatically open the diagram file."
			fi
		fi
		return 0
	else
		ErrorMessage "Failed to write diagram to: $output_file"
		# Clean up empty file if write failed
		[[ ! -s "$output_file" ]] && rm -f "$output_file" &>/dev/null
		return 1
	fi
}

# ============================================================================
# Function: ParseArguments
# Description: Parse command-line arguments for diagram script.
# Usage: declare -A options; ParseArguments options "$@"
# Returns: Populates associative array by reference. Returns 0 on success, 1 on error.
# ============================================================================
ParseArguments() {
	local -n options_ref="$1"
	shift

	# Ensure Bash 4.3+ for namerefs (-n)
	if [[ "${BASH_VERSINFO[0]}" -lt 4 || ("${BASH_VERSINFO[0]}" -eq 4 && "${BASH_VERSINFO[1]}" -lt 3) ]]; then
		ErrorMessage "Internal Error: ParseArguments requires Bash 4.3+ for namerefs."
		return 1
	fi

	# Set defaults using sourced functions
	local default_host
	default_host=$(DetectHostname)
	options_ref["target_hostname"]="${default_host}"
	local default_shell
	default_shell=$(DetectShell)
	options_ref["target_shell"]="${default_shell}"
	options_ref["output_file"]=""
	options_ref["format"]="mermaid"
	options_ref["verbose_mode"]=false

	# Single loop for arguments
	while [[ $# -gt 0 ]]; do
		local key="$1"
		case "$key" in
			-h | --help)
				ShowHelp # Exits
				;;
			--summary)
				ExtractSummary "$0"
				exit $? # Call helper and exit
				;;
			--version)
				ShowVersionInfo "$0"
				exit 0 # Call helper and exit
				;;
			--hostname=*)
				options_ref["target_hostname"]="${key#*=}"
				shift
				;;
			--hostname)
				shift # Move past --hostname flag
				if [[ -z "${1:-}" || "$1" == -* ]]; then
					ErrorMessage "--hostname requires a value."
					return 1
				fi
				options_ref["target_hostname"]="$1"
				shift # Move past value
				;;
			--shell=*)
				options_ref["target_shell"]="${key#*=}"
				if ! ValidateShellType "${options_ref["target_shell"]}"; then return 1; fi
				shift
				;;
			--shell)
				shift # Move past --shell flag
				if [[ -z "${1:-}" || "$1" == -* ]]; then
					ErrorMessage "--shell requires a value (bash or zsh)."
					return 1
				fi
				options_ref["target_shell"]="$1"
				if ! ValidateShellType "${options_ref["target_shell"]}"; then return 1; fi
				shift # Move past value
				;;
			--output=*)
				options_ref["output_file"]="${key#*=}"
				shift
				;;
			--output)
				shift # Move past --output flag
				if [[ -z "${1:-}" || "$1" == -* ]]; then
					ErrorMessage "--output requires a filename."
					return 1
				fi
				options_ref["output_file"]="$1"
				shift # Move past value
				;;
			--format=*)
				options_ref["format"]="${key#*=}"
				if ! ValidateFormat "${options_ref["format"]}"; then return 1; fi
				shift
				;;
			--format)
				shift # Move past --format flag
				if [[ -z "${1:-}" || "$1" == -* ]]; then
					ErrorMessage "--format requires a value."
					return 1
				fi
				options_ref["format"]="$1"
				if ! ValidateFormat "${options_ref["format"]}"; then return 1; fi
				shift # Move past value
				;;
			-v | --verbose)
				options_ref["verbose_mode"]=true
				shift # Move past flag
				;;
			# End of options marker
			--)
				shift # Move past --
				break # Stop processing options
				;;
			# Unknown option
			-*)
				ErrorMessage "Unknown option: $key"
				return 1
				;;
			# Positional argument (none expected)
			*)
				ErrorMessage "Unexpected positional argument: $key"
				return 1
				;;
		esac
	done

	# Final validation of potentially defaulted shell type
	if ! ValidateShellType "${options_ref["target_shell"]}"; then
		# Error already printed by ValidateShellType
		return 1
	fi
	return 0 # Success
}

# ============================================================================
# Function: main
# Description: Main execution logic for the diagram script.
# Usage: main "$@"
# Returns: 0 on success, 1 on failure.
# ============================================================================
main() {
	# Use associative array for options
	declare -A options

	# Parse Arguments
	ParseArguments options "$@" || return 1

	# Determine default output file path if not provided
	if [[ -z "${options[output_file]:-}" ]]; then
		# Ensure default output dir exists
		mkdir -p "${GC_DEFAULT_OUTPUT_DIR}" || {
			ErrorMessage "Cannot create default output directory: ${GC_DEFAULT_OUTPUT_DIR}"
			return 1
		}
		chmod 700 "${GC_DEFAULT_OUTPUT_DIR}" 2>/dev/null || true

		# Build output filename
		local default_filename="loading_order_${options[target_hostname]}_${options[target_shell]}"

		# Add extension based on format
		case "${options[format]}" in
			mermaid) default_filename+=".md" ;;
			ascii) default_filename+=".txt" ;;
		esac

		options[output_file]="${GC_DEFAULT_OUTPUT_DIR}/${default_filename}"
	fi

	# Use sourced SectionHeader
	SectionHeader "rcForge Configuration Diagram Generator (v${gc_version})"

	# Find configuration files
	local -a config_files=()
	mapfile -t config_files < <(FindRcScripts "${options[target_shell]}" "${options[target_hostname]}")
	local find_status=$?

	if [[ $find_status -ne 0 ]]; then
		# Error message already printed by FindRcScripts
		return 1
	elif [[ ${#config_files[@]} -eq 0 ]]; then
		InfoMessage "No configuration files found for ${options[target_shell]}/${options[target_hostname]}."
		InfoMessage "Diagram not generated."
		return 0
	fi

	# Generate the diagram
	GenerateDiagram \
		"${options[format]}" \
		"${options[output_file]}" \
		"${options[verbose_mode]}" \
		"${config_files[@]}"

	return $?
}

# ============================================================================
# Script Execution
# ============================================================================
# Execute main function if run directly or via rc command wrapper
if IsExecutedDirectly || [[ "$0" == *"rc"* ]]; then
	main "$@"
	exit $? # Exit with status from main
fi

# EOF
