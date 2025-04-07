#!/usr/bin/env bash
# rc-command.sh - Core rc command dispatcher (Full Implementation)
# Author: rcForge Team
# Date: 2025-04-07 # Updated
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
# Function: _rc_scan_utils (Unchanged)
# Description: Scans user and system util dirs, populates maps for commands, overrides, conflicts.
# Usage: declare -A commands_map overrides_map conflict_map; _rc_scan_utils commands_map overrides_map conflict_map
# Arguments: $1=command map name, $2=override map name, $3=conflict map name
# Returns: 0 on success, populates arrays by reference. (Requires Bash 4.3+)
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
# Function: _rc_show_framework_help (NEW - Replaces part of old _rc_show_help)
# Description: Displays help information about the rc command framework itself.
# Usage: _rc_show_framework_help
# ============================================================================
_rc_show_framework_help() {
    # Use gc_version if available, fallback to RCFORGE_VERSION
    local version_to_display="${gc_version:-${RCFORGE_VERSION:-unknown}}"
    echo "rcForge Command Framework (v${version_to_display})"
    echo ""
    echo "Usage: rc [--system|-s] <command> [command-options] [arguments...]"
    echo ""
    echo "Description:"
    echo "  The 'rc' command provides access to rcForge system and user utilities."
    echo "  User utilities in ~/.config/rcforge/utils/ override system utilities"
    echo "  in ~/.config/rcforge/system/utils/ with the same name."
    echo ""
    echo "Common Commands:"
    printf "  %-18s %s\n" "list" "List all available rc commands and their summaries."
    printf "  %-18s %s\n" "help" "Show this help message about the rc framework."
    printf "  %-18s %s\n" "<command> help" "Show detailed help for a specific <command>."
    printf "  %-18s %s\n" "--conflicts" "Show user overrides and execution conflicts."
    # printf "  %-18s %s\n" "search <term>" "Search for commands (Not Yet Implemented)."
    echo ""
    echo "Global Options:"
    printf "  %-18s %s\n" "--system, -s" "Force execution of the system version of a command,"
    printf "  %-18s %s\n" "" "bypassing any user override."
    echo ""
    echo "Example:"
    echo "  rc list                 # See available commands"
    echo "  rc httpheaders help     # Get help for the httpheaders command"
    echo "  rc httpheaders example.com"
    echo "  rc -s diag              # Run the system version of diag"
}

# ============================================================================
# Function: _rc_list_commands (NEW - Replaces part of old _rc_show_help)
# Description: Scans and lists available commands with summaries and override notes.
# Usage: _rc_list_commands
# ============================================================================
_rc_list_commands() {
    # Use gc_version if available, fallback to RCFORGE_VERSION
    local version_to_display="${gc_version:-${RCFORGE_VERSION:-unknown}}"
    declare -A commands_map overrides_map conflict_map
    _rc_scan_utils commands_map overrides_map conflict_map # Populate the maps

    echo "rcForge Utility Commands (v${version_to_display})"
    echo ""
    echo "Available commands:"

    local cmd=""
    local summary=""
    local script_path=""
    local override_note=""
    local conflict_note=""
    local display_name=""

    # Sort commands alphabetically for display
    for cmd in $(printf "%s\n" "${!commands_map[@]}" | sort); do
        script_path="${commands_map[$cmd]}"
        summary=$("$script_path" summary 2>/dev/null || echo "Error fetching summary")

        # Check for override indicator
        override_note=""
        if [[ -v "overrides_map[$cmd]" ]]; then
            override_note=" ${YELLOW}(user override)${RESET}" # Add color
        fi

        # Check for execution conflict indicator
        conflict_note=""
        display_name="$cmd"
        if [[ -v "conflict_map[$cmd]" ]]; then
            conflict_note=" ${RED}(CONFLICT)${RESET}" # Add color
            summary="Multiple executables found - see 'rc --conflicts'" # Override summary for conflicts
            display_name="${RED}${cmd}${RESET}" # Colorize command name
        fi

        # Format and print
        printf "  %-25b %s%s%s\n" "$display_name" "$summary" "$override_note" "$conflict_note" # Adjusted padding
    done

    echo ""

    # Add conditional footer for conflicts/overrides
    if [[ "${#overrides_map[@]}" -gt 0 || "${#conflict_map[@]}" -gt 0 ]]; then
        InfoMessage "[Note: User overrides and/or execution conflicts detected. Run 'rc --conflicts' for details.]" #
    fi

    echo "Use 'rc <command> help' for detailed information about a command."
    # echo "Use 'rc search <term>' to find commands (Not Yet Implemented)."
}


# ============================================================================
# Function: _rc_show_conflicts (Unchanged)
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
             WarningMessage "User utility '${cmd}' overrides system utility:" # Clarified message
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
             ErrorMessage "Conflict for command '${cmd}' in ${conflict_dir}:" #
             echo "$conflicting_paths" | tr ',' '\n' | sed 's/^/  - /' #
             echo ""
        done
    fi

    if [[ "$found_issue" == "false" ]]; then
        SuccessMessage "No user overrides or execution conflicts detected."
    fi
}


# ============================================================================
# Function: rc (Full Implementation - Updated Dispatch Logic)
# ============================================================================
rc() {
    # --- Argument Parsing ---
    local force_system=false
    local command=""
    local -a cmd_args=() # Store remaining args

    # Handle global options like --system first
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --system|-s)
                force_system=true
                shift
                ;;
            --help|-h) # Treat help as a potential command
                command="help"
                shift
                cmd_args=("$@") # Capture remaining args for potential 'rc help <command>'
                break # Stop option processing
                ;;
            --conflicts) # Treat as a command
                command="--conflicts"
                shift
                # Conflicts command doesn't take args, but capture for consistency
                cmd_args=("$@")
                break # Stop option processing
                ;;
             list) # Treat list as a command
                 command="list"
                 shift
                 # List command doesn't take args
                 cmd_args=("$@")
                 break
                 ;;
            --summary) # Treat summary as a command (internal use mostly)
                 command="summary"
                 shift
                 cmd_args=("$@")
                 break
                 ;;
            # Add --version maybe?

            # Stop processing global options if a non-option is encountered
            # or if '--' is encountered
            -- | -*)
                # If it's '--', consume it and stop option processing
                # If it's an unknown option starting with '-', error out later
                # If it's not starting with '-', assume it's the command
                if [[ "$1" == "--" ]]; then
                    shift
                    break # Stop option processing
                fi
                # Check if it looks like an unknown *global* option
                if [[ "$1" == --* || "$1" == -[^-]* ]]; then
                     # Let the command dispatch handle it later if it's not a known global one
                     # This allows commands to have their own options starting with '-'
                     break # Assume it might be a command or command option
                else
                    # Doesn't start with '-', assume it's the command
                    command="$1"
                    shift
                    cmd_args=("$@")
                    break # Stop option processing
                fi
                ;;
            *) # First non-option argument is the command
                command="$1"
                shift
                cmd_args=("$@") # The rest are args for the command
                break # Stop option processing
                ;;
        esac
    done

    # Default to 'list' if no command was provided after option processing
    [[ -z "$command" ]] && command="list"

    # --- Core Command Handling ---
    case "$command" in
        help)
            # Check if 'help' was followed by a command name
            if [[ ${#cmd_args[@]} -gt 0 && "${cmd_args[0]}" != --* && "${cmd_args[0]}" != -* ]]; then
                # User wants help for a specific command: rc help <utility_command>
                local target_cmd="${cmd_args[0]}"
                shift # Remove target command from args list
                # Now dispatch normally, but force the argument 'help'
                # Re-run dispatch logic (could be cleaner with a goto or function)
                command="$target_cmd" # Set command to the utility name
                cmd_args=("help" "${cmd_args[@]:1}") # Prepend 'help', pass rest of original args
                # Fall through to the *) case below
            else
                # User wants help about the 'rc' framework itself
                _rc_show_framework_help # Call NEW help function
                return 0
            fi
            ;; # End of specific 'help' case, fall through requires removing this or restructuring

        list)
            _rc_list_commands # Call NEW list function
             # Check for extraneous arguments to 'list'
            if [[ ${#cmd_args[@]} -gt 0 ]]; then
                WarningMessage "'rc list' does not accept additional arguments. Ignoring: ${cmd_args[*]}"
            fi
            return 0
            ;;

        --conflicts)
             _rc_show_conflicts # Call existing conflicts function
             # Check for extraneous arguments to '--conflicts'
            if [[ ${#cmd_args[@]} -gt 0 ]]; then
                WarningMessage "'rc --conflicts' does not accept additional arguments. Ignoring: ${cmd_args[*]}"
            fi
             return 0
             ;;
        summary)
             # This shouldn't typically be called directly by user
             echo "rc - rcForge command execution framework."
             return 0
             ;;
        search)
             ErrorMessage "Search functionality not yet implemented."
             return 1
             ;;
    esac # End of core command case statement


    # --- Utility Script Dispatch Logic ---
    # This part only runs if the command wasn't list, help, conflicts, etc.
    local target_script=""
    local user_dir="${RCFORGE_USER_UTILS:-/invalid_path}"
    local sys_dir="${RCFORGE_UTILS:-/invalid_path}"
    local -a search_dirs=()
    local -a found_scripts=()
    local dir=""
    local file=""
    local base_name="" # Need basename for conflict check

    # Determine search order based on --system flag
    if [[ "$force_system" == "true" ]]; then
        InfoMessage "Forcing use of system utility for '$command'..." # Inform user
        search_dirs=("$sys_dir")
    else
        search_dirs=("$user_dir" "$sys_dir")
    fi


    # Find executable files matching command basename
    for dir in "${search_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            # Use find to locate executables matching pattern "command.*" or just "command"
            # Need to handle potential errors from find if dir is unreadable
             while IFS= read -r -d '' file; do
                 found_scripts+=("$file")
             done < <(find "$dir" -maxdepth 1 -name "${command}" -type f -executable -print0 2>/dev/null ; \
                      find "$dir" -maxdepth 1 -name "${command}.*" -type f -executable -print0 2>/dev/null )
        fi
        # If we found scripts in the first directory (user dir, unless --system) and we are not forcing system, stop searching
        if [[ ${#found_scripts[@]} -gt 0 && "$force_system" == "false" && "$dir" == "$user_dir" ]]; then
            break
        fi
    done

     # --- Handle Results ---
    if [[ ${#found_scripts[@]} -eq 0 ]]; then
        # No command found
        ErrorMessage "rc command not found: '$command'" 127 # Exit 127: Command not found
    elif [[ ${#found_scripts[@]} -eq 1 ]]; then
        # Exactly one found, execute it
        target_script="${found_scripts[0]}"
         # Check verbosity - requires VerboseMessage to be available
         # VerboseMessage "true" "Executing: $target_script ${cmd_args[*]:-(no args)}"
        "$target_script" "${cmd_args[@]}" # Pass remaining args
        return $? # Return the script's exit code
    else
        # Conflict: Multiple executables found for the command name in the *chosen* directory level (user or system)
         ErrorMessage "Ambiguous command '$command'. Found multiple executables:"
         printf '  - %s\n' "${found_scripts[@]}" >&2
         InfoMessage "Please rename or remove conflicting files, or use '--system' flag if applicable."
         return 1 # Indicate error
    fi
    # --- End Utility Script Dispatch ---

}
# Ensure the full implementation is also exported if sourced directly somehow
export -f rc

# EOF