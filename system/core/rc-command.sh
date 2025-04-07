#!/usr/bin/env bash
# rc-command.sh - Core rc command dispatcher (Full Implementation)
# Author: rcForge Team
# Date: 2025-04-07
# Version: 0.3.0
# Category: system/core
# Description: Finds and executes user or system utility scripts, handles help and conflicts.

# Ensure core libraries are available
[[ -z "${_RCFORGE_SHELL_COLORS_SH_SOURCED:-}" ]] && \
    source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/shell-colors.sh"
[[ -z "${_RCFORGE_UTILITY_FUNCTIONS_SH_SOURCED:-}" ]] && \
    source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/utility-functions.sh"

# Set strict modes for the implementation script
set -o nounset
# Consider pipefail?
# set -o errexit # Disable errexit to allow custom error handling below

# ============================================================================
# Helper Functions (Internal to rc-command.sh)
# ============================================================================

# ============================================================================
# Function: _rc_scan_utils
# Description: Scans user and system util dirs, populates maps for commands, overrides, conflicts.
# Usage: declare -A commands_map overrides_map conflict_map; _rc_scan_utils commands_map overrides_map conflict_map
# Arguments:
#   $1 - Name of assoc array for effective command map [basename]=fullpath
#   $2 - Name of assoc array for override map [basename]=system_fullpath
#   $3 - Name of assoc array for conflict map [basename]=comma_separated_paths
# Returns: 0 on success, populates arrays by reference.
# ============================================================================
_rc_scan_utils() {
    local -n _commands_map="$1"
    local -n _overrides_map="$2"
    local -n _conflict_map="$3"
    local user_dir="${RCFORGE_USER_UTILS:-}"
    local sys_dir="${RCFORGE_UTILS:-}"
    local file=""
    local base_name=""
    local ext=""
    declare -A found_system_cmds # Track system commands by basename
    declare -A found_user_cmds   # Track user commands by basename -> fullpath(s)

    # --- Scan System Utilities ---
    if [[ -d "$sys_dir" ]]; then
        while IFS= read -r -d '' file; do
            base_name=$(basename "$file")
            # Handle files with and without extensions for basename extraction
            if [[ "$base_name" == *.* ]]; then
                ext="${base_name##*.}"
                base_name="${base_name%.*}"
            else
                ext="" # No extension
            fi
            # Skip if basename is empty or starts with .
            [[ -z "$base_name" || "$base_name" == .* ]] && continue

            found_system_cmds["$base_name"]="$file" # Store full path
        done < <(find "$sys_dir" -maxdepth 1 -type f -executable -print0 2>/dev/null)
    fi

    # --- Scan User Utilities ---
    if [[ -d "$user_dir" ]]; then
        while IFS= read -r -d '' file; do
             base_name=$(basename "$file")
             if [[ "$base_name" == *.* ]]; then
                 ext="${base_name##*.}"
                 base_name="${base_name%.*}"
             else
                 ext=""
             fi
             [[ -z "$base_name" || "$base_name" == .* ]] && continue

            # Append to list for this basename (handling potential conflicts)
            if [[ -v "found_user_cmds[$base_name]" ]]; then
                found_user_cmds["$base_name"]+=",${file}" # Comma-separate conflicting paths
            else
                found_user_cmds["$base_name"]="$file"
            fi
        done < <(find "$user_dir" -maxdepth 1 -type f -executable -print0 2>/dev/null)
    fi

    # --- Build Final Maps ---
    # Add all system commands first
    for base_name in "${!found_system_cmds[@]}"; do
        _commands_map["$base_name"]="${found_system_cmds[$base_name]}"
    done

    # Add/Override with user commands and detect conflicts/overrides
    for base_name in "${!found_user_cmds[@]}"; do
        local user_paths="${found_user_cmds[$base_name]}"
        if [[ "$user_paths" == *,* ]]; then
            # Conflict (multiple user utils with same basename)
            _conflict_map["$base_name"]="$user_paths"
            # Decide which one to put in commands map? Arbitrarily first for now, but execution will fail.
             _commands_map["$base_name"]="${user_paths%%,*}"
        else
            # Single user util, add to commands map
             _commands_map["$base_name"]="$user_paths"
             # Check if it overrides a system command
             if [[ -v "found_system_cmds[$base_name]" ]]; then
                 _overrides_map["$base_name"]="${found_system_cmds[$base_name]}"
             fi
        fi
    done

    return 0
}


# ============================================================================
# Function: _rc_show_help (Internal Helper)
# ============================================================================
_rc_show_help() {
    declare -A commands_map overrides_map conflict_map
    _rc_scan_utils commands_map overrides_map conflict_map # Populate the maps

    echo "rcForge Utility Command (v${RCFORGE_VERSION:-$gc_version})"
    echo ""
    echo "Usage: rc <command> [options] [arguments...]"
    echo ""
    echo "Available commands:"
    # Print core commands first
    printf "  %-18s %s\n" "help" "Show this help message"
    printf "  %-18s %s\n" "--conflicts" "Show overrides and definition conflicts"
    printf "  %-18s %s\n" "--system (-s)" "Force use of system utility, bypassing user override"
    # printf "  %-18s %s\n" "search" "Search for commands (Not Yet Implemented)" # Add when implemented
    printf "  %-18s %s\n" "summary" "(Used internally)"


    # Print discovered commands
    local cmd=""
    local summary=""
    local script_path=""
    local override_note=""

    # Sort commands alphabetically for display
    for cmd in $(printf "%s\n" "${!commands_map[@]}" | sort); do
        script_path="${commands_map[$cmd]}"
        summary=$("$script_path" summary 2>/dev/null || echo "Error fetching summary")

        # Check for override indicator
        override_note=""
        if [[ -v "overrides_map[$cmd]" ]]; then
            override_note=" (user override)"
        fi

        # Format and print
        printf "  %-18s %s%s\n" "$cmd" "$summary" "$override_note"
    done

    echo ""

    # Add conditional footer for conflicts/overrides
    if [[ "${#overrides_map[@]}" -gt 0 || "${#conflict_map[@]}" -gt 0 ]]; then
        InfoMessage "[Note: User overrides/conflicts detected. Run 'rc --conflicts' for details.]"
    fi

    echo "Use 'rc <command> help' for detailed information about a command."
    # echo "Use 'rc search <term>' to find commands (Not Yet Implemented)." # Add when implemented
}

# ============================================================================
# Function: _rc_show_conflicts (Internal Helper)
# ============================================================================
_rc_show_conflicts() {
    declare -A commands_map overrides_map conflict_map
    _rc_scan_utils commands_map overrides_map conflict_map # Populate the maps

    local found_issue=false

    if [[ "${#overrides_map[@]}" -gt 0 ]]; then
        found_issue=true
        SectionHeader "User Overrides"
        local cmd=""
        for cmd in $(printf "%s\n" "${!overrides_map[@]}" | sort); do
             local user_path="${commands_map[$cmd]}" # User path is the effective path
             local system_path="${overrides_map[$cmd]}"
             WarningMessage "User utility '${cmd}'"
             echo "  User:   ${user_path}"
             echo "  System: ${system_path}"
             echo ""
        done
    fi

    if [[ "${#conflict_map[@]}" -gt 0 ]]; then
        found_issue=true
        SectionHeader "Execution Conflicts (Ambiguous Commands)"
        local cmd=""
        for cmd in $(printf "%s\n" "${!conflict_map[@]}" | sort); do
             local conflicting_paths="${conflict_map[$cmd]}"
             # Extract directory from first path
             local first_path="${conflicting_paths%%,*}"
             local conflict_dir=$(dirname "$first_path")
             ErrorMessage "Conflict for command '${cmd}' in ${conflict_dir}:"
             echo "$conflicting_paths" | tr ',' '\n' | sed 's/^/  - /'
             echo ""
        done
    fi

    if [[ "$found_issue" == "false" ]]; then
        SuccessMessage "No user overrides or execution conflicts detected."
    fi
}


# ============================================================================
# Function: rc (Full Implementation - Overwrites Stub)
# ============================================================================
rc() {
    # --- Argument Parsing ---
    local force_system=false
    local command=""
    local -a cmd_args=() # Store remaining args

    # Handle flags like --system before the command name
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --system|-s)
                force_system=true
                shift
                ;;
            --help|-h) # Treat help as a command
                command="help"
                shift
                # Keep remaining args in case of 'rc --system help' etc.
                cmd_args=("$@")
                break # Stop option processing
                ;;
            --conflicts)
                command="--conflicts"
                shift
                cmd_args=("$@")
                break # Stop option processing
                ;;
            --summary)
                 command="summary"
                 shift
                 cmd_args=("$@")
                 break
                 ;;
             # Add --version maybe?
            -*) # Unknown option
                ErrorMessage "Unknown option: $1"
                _rc_show_help
                return 1
                ;;
            *) # First non-option is the command
                command="$1"
                shift
                cmd_args=("$@") # The rest are args for the command
                break # Stop option processing
                ;;
        esac
    done

    # Default to 'help' if no command was found
     [[ -z "$command" ]] && command="help"

    # --- Core Command Handling ---
    case "$command" in
        help)
            _rc_show_help
            return 0
            ;;
        --conflicts)
             _rc_show_conflicts
             return 0
             ;;
        summary)
             # This shouldn't typically be called directly by user
             echo "rc - rcForge command execution framework."
             return 0
             ;;
        search)
             ErrorMessage "Search functionality not yet implemented." 1
             ;;
        *)
             # --- Utility Script Dispatch Logic ---
             local target_script=""
             local user_dir="${RCFORGE_USER_UTILS:-/invalid_path}"
             local sys_dir="${RCFORGE_UTILS:-/invalid_path}"
             local -a search_dirs=()
             local -a found_scripts=()
             local dir=""
             local file=""

             # Determine search order based on --system flag
             if [[ "$force_system" == "true" ]]; then
                 InfoMessage "Forcing use of system utility for '$command'..." # Inform user
                 search_dirs=("$sys_dir")
             else
                 search_dirs=("$user_dir" "$sys_dir")
             fi

             # Find executable files matching basename
             for dir in "${search_dirs[@]}"; do
                 if [[ -d "$dir" ]]; then
                     # Use find to locate executables matching pattern "command.*"
                     while IFS= read -r -d '' file; do
                         found_scripts+=("$file")
                     done < <(find "$dir" -maxdepth 1 -name "${command}.*" -type f -executable -print0 2>/dev/null)
                     # Also check for exact match without extension (e.g., binary)
                      if [[ -f "$dir/$command" && -x "$dir/$command" ]]; then
                          found_scripts+=("$dir/$command")
                      fi
                 fi
                 # If we found scripts in the first directory (user dir, unless --system) and we are not forcing system, stop searching
                 if [[ ${#found_scripts[@]} -gt 0 && "$force_system" == "false" && "$dir" == "$user_dir" ]]; then
                     break
                 fi
             done

             # --- Handle Results ---
             if [[ ${#found_scripts[@]} -eq 0 ]]; then
                 # No command found
                 ErrorMessage "rc command not found: '$command'" 127
             elif [[ ${#found_scripts[@]} -eq 1 ]]; then
                 # Exactly one found, execute it
                 target_script="${found_scripts[0]}"
                  VerboseMessage "true" "Executing: $target_script ${cmd_args[*]:-(no args)}" # Requires VerboseMessage definition
                 "$target_script" "${cmd_args[@]}" # Pass remaining args
                 return $? # Return the script's exit code
             else
                 # Conflict: Multiple executables found for the command name
                  ErrorMessage "Ambiguous command '$command'. Found multiple executables:"
                  printf '  - %s\n' "${found_scripts[@]}" >&2
                  InfoMessage "Please rename or remove conflicting files, or use '--system' flag if applicable."
                  return 1 # Indicate error
             fi
             ;;
    esac
}
# Ensure the full implementation is also exported if sourced directly somehow
export -f rc

# EOF