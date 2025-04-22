#!/usr/bin/env bash
# export.sh - Export shell configurations for remote servers
# Author: rcForge Team
# Date: 2025-04-21
# Version: 0.5.0
# Category: system/utility
# RC Summary: Exports shell configurations for use on remote systems
# Description: Creates portable shell configuration files by combining RC scripts

# Source necessary library
source "${RCFORGE_LIB:-$HOME/.local/share/rcforge/system/lib}/utility-functions.sh"

# Set strict error handling
set -o nounset
set -o pipefail

# Global constants
[[ -v gc_version ]]  || readonly gc_version="${RCFORGE_VERSION:-0.5.0}"
[[ -v gc_app_name ]] || readonly gc_app_name="${RCFORGE_APP_NAME:-rcForge}"
readonly UTILITY_NAME="export"
readonly DEFAULT_EXPORT_DIR="${RCFORGE_CONFIG_ROOT:-$HOME/.config/rcforge}/exports"

# ============================================================================
# Function: ShowHelp
# Description: Display help information for the export command.
# Usage: ShowHelp
# Arguments: None
# Returns: None. Exits with status 0.
# ============================================================================
ShowHelp() {
    echo "${UTILITY_NAME} - ${gc_app_name} Configuration Export Utility (v${gc_version})"
    echo ""
    echo "Description:"
    echo "  Exports shell configurations for use on remote systems"
    echo ""
    echo "Usage:"
    echo "  rc ${UTILITY_NAME} [options]"
    echo "  $(basename "$0") [options]"
    echo ""
    echo "Options:"
    echo "  --shell=TYPE      Specify shell type (bash or zsh) [REQUIRED]"
    echo "  --hostname=NAME   Filter for specific hostname (default: global)"
    echo "  --output=FILE     Specify output file path (default: exports directory)"
    echo "  --keep-debug      Preserve debug statements (default: removed)"
    echo "  --force, -f       Overwrite existing output file"
    echo "  --verbose, -v     Enable verbose output"
    echo "  --help, -h        Show this help message"
    echo "  --summary         Show one-line description"
    echo "  --version         Show version information"
    echo ""
    echo "Examples:"
    echo "  rc export --shell=bash                     # Export bash configs"
    echo "  rc export --shell=zsh --hostname=laptop    # Export zsh for laptop" 
    echo "  rc export --shell=bash --output=~/bashrc   # Export to specific file"
    exit 0
}

# ============================================================================
# Function: ProcessConfigFiles
# Description: Process configuration files for export
# Usage: ProcessConfigFiles shell [hostname] [keep_debug] file1 [file2...]
# Returns: Processed config content on stdout
# ============================================================================
ProcessConfigFiles() {
    local shell="${1:-bash}"
    local hostname="${2:-}"
    local keep_debug="${3:-false}"
    shift 3
    local -a files=("$@")
    
    # Start with shebang and header
    printf "#!/usr/bin/env %s\n" "${shell}"
    printf "# Exported %s Configuration (v%s)\n" "${gc_app_name}" "${gc_version}"
    printf "# Generated: %s\n" "$(date)"
    printf "# Target Shell: %s\n" "${shell}"
    [[ -n "$hostname" ]] && printf "# Hostname Filter: %s\n" "${hostname}"
    printf "# WARNING: This is a generated file. Do not edit directly.\n\n"
    
    # Process each file
    for file in "${files[@]}"; do
        [[ ! -r "$file" ]] && continue
        
        local content
        content=$(<"$file") || continue
        
        # Remove debug lines if requested
        if [[ "$keep_debug" == "false" ]]; then
            # Remove debug_echo lines and debug comments
            content=$(printf '%s\n' "$content" | grep -Ev '^[[:space:]]*debug_echo|^\s*#.*debug')
            
            # Remove comments and blank lines in non-debug mode
            content=$(printf '%s\n' "$content" | sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d')
        fi
        
        # Only include if content remains
        if [[ -n "$content" ]]; then
            printf "# --- Source: %s ---\n" "$(basename "$file")"
            printf "%s\n\n" "$content"
        fi
    done
    
    printf "# EOF\n"
}

# ============================================================================
# Function: main
# Description: Main execution flow
# Usage: main "$@"
# Returns: 0 on success, non-zero on failure
# ============================================================================
main() {
    # Define required and optional parameters
    declare -A options=(
        ["shell_type"]=""
        ["hostname"]=""
        ["output_file"]=""
        ["keep_debug"]=false
        ["force_overwrite"]=false
        ["verbose_mode"]=false
    )
    
    # Process command line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                ShowHelp
                ;;
            --summary)
                ExtractSummary "$0"
                exit $?
                ;;
            --version)
                echo "${UTILITY_NAME} v${gc_version}"
                exit 0
                ;;
            --shell=*)
                options["shell_type"]="${1#*=}"
                shift
                ;;
            --shell)
                shift
                if [[ -z "${1:-}" || "$1" == -* ]]; then
                    ErrorMessage "--shell requires a value (bash or zsh)"
                    return 1
                fi
                options["shell_type"]="$1"
                shift
                ;;
            --hostname=*)
                options["hostname"]="${1#*=}"
                shift
                ;;
            --hostname)
                shift
                options["hostname"]="${1:-}"
                shift
                ;;
            --output=*)
                options["output_file"]="${1#*=}"
                shift
                ;;
            --output)
                shift
                options["output_file"]="${1:-}"
                shift
                ;;
            --keep-debug)
                options["keep_debug"]=true
                shift
                ;;
            -f|--force)
                options["force_overwrite"]=true
                shift
                ;;
            -v|--verbose)
                options["verbose_mode"]=true
                shift
                ;;
            *)
                ErrorMessage "Unknown option: $1"
                InfoMessage "Use --help for usage information"
                return 1
                ;;
        esac
    done
    
    # Validate shell type
    if [[ -z "${options[shell_type]}" ]]; then
        ErrorMessage "Shell type must be specified (--shell=bash or --shell=zsh)"
        return 1
    fi
    
    case "${options[shell_type]}" in
        bash|zsh) ;;
        *)
            ErrorMessage "Invalid shell type: ${options[shell_type]}"
            InfoMessage "Supported shells: bash, zsh"
            return 1
            ;;
    esac
    
    # Section header
    SectionHeader "rcForge Configuration Export"
    
    # Determine output path
    local output_path
    if [[ -n "${options[output_file]}" ]]; then
        output_path="${options[output_file]}"
    else
        # Create default filename based on shell and hostname
        local filename="rcforge_${options[hostname]:-global}_${options[shell_type]}.sh"
        output_path="${DEFAULT_EXPORT_DIR}/${filename}"
    fi
    
    # Check for existing file
    if [[ -f "$output_path" && "${options[force_overwrite]}" != "true" ]]; then
        ErrorMessage "Output file already exists: $output_path"
        InfoMessage "Use --force to overwrite existing file"
        return 1
    fi
    
    # Create output directory if needed
    local output_dir
    output_dir=$(dirname "$output_path")
    if [[ ! -d "$output_dir" ]]; then
        if ! mkdir -p "$output_dir"; then
            ErrorMessage "Failed to create output directory: $output_dir"
            return 1
        fi
        chmod 700 "$output_dir"
    fi
    
    # Find matching configuration files
    local -a config_files
    mapfile -t config_files < <(FindRcScripts "${options[shell_type]}" "${options[hostname]}")
    
    # Check if we found anything
    if [[ ${#config_files[@]} -eq 0 ]]; then
        InfoMessage "No configuration files found for ${options[shell_type]}${options[hostname]:+ (hostname: ${options[hostname]})}"
        return 0
    fi
    
    if [[ "${options[verbose_mode]}" == "true" ]]; then
        InfoMessage "Found ${#config_files[@]} configuration files to process"
    fi
    
    # Process configuration files
    if ! ProcessConfigFiles "${options[shell_type]}" "${options[hostname]}" "${options[keep_debug]}" "${config_files[@]}" > "$output_path"; then
        ErrorMessage "Failed to write to output file: $output_path"
        rm -f "$output_path" 2>/dev/null
        return 1
    fi
    
    # Set permissions on output file
    chmod 600 "$output_path"
    
    SuccessMessage "Configuration exported to: $output_path"
    if [[ "${options[verbose_mode]}" == "true" ]]; then
        InfoMessage "Exported ${#config_files[@]} configuration files for ${options[shell_type]}"
    fi
    
    return 0
}

# Execute main function if run directly or via rc command
if IsExecutedDirectly || [[ "$0" == *"rc"* ]]; then
    main "$@"
    exit $?
fi

# EOF
