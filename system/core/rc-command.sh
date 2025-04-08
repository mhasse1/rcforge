#!/usr/bin/env bash
# rc-command.sh - Core rc command dispatcher (Full Implementation)
# Author: rcForge Team
# Date: 2025-04-07 # Updated
# Version: 0.4.0
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
# Helper Functions (Internal to rc-command.sh - Use PascalCase per Style Guide)
# ============================================================================

# ============================================================================
# Function: RcScanUtils
# Description: Scans user and system util dirs, populates maps for commands, overrides, conflicts.
# Usage: declare -A commands_map overrides_map conflict_map; RcScanUtils commands_map overrides_map conflict_map
# Arguments: $1=command map name, $2=override map name, $3=conflict map name
# Returns: 0 on success, 1 on major error, populates arrays by reference. (Requires Bash 4.3+)
# ============================================================================
RcScanUtils() {
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
    local find_exit_status=0 # Not currently used, but could be for stricter error checking

    # --- Scan System Utilities ---
    if [[ -d "$sys_dir" ]]; then
        # ---- Use portable find + shell -x check ----
        while IFS= read -r -d '' file; do
            # Check if executable using shell's -x test
            if [[ -x "$file" ]]; then
                base_name=$(basename "$file")
                if [[ "$base_name" == *.* ]]; then ext="${base_name##*.}"; base_name="${base_name%.*}"; else ext=""; fi
                [[ -z "$base_name" || "$base_name" == .* ]] && continue
                found_system_cmds["$base_name"]="$file"
            fi
        done < <(find "$sys_dir" -maxdepth 1 -type f -print0 2>/dev/null) # Removed non-portable -executable
        # find_exit_status=$? # Capture status if needed
    fi

    # --- Scan User Utilities ---
    if [[ -d "$user_dir" ]]; then
         # ---- Use portable find + shell -x check ----
        while IFS= read -r -d '' file; do
             # Check if executable using shell's -x test
             if [[ -x "$file" ]]; then
                 base_name=$(basename "$file")
                 if [[ "$base_name" == *.* ]]; then ext="${base_name##*.}"; base_name="${base_name%.*}"; else ext=""; fi
                 [[ -z "$base_name" || "$base_name" == .* ]] && continue
                if [[ -v "found_user_cmds[$base_name]" ]]; then
                    found_user_cmds["$base_name"]+=",${file}"
                else
                    found_user_cmds["$base_name"]="$file"
                fi
             fi
        done < <(find "$user_dir" -maxdepth 1 -type f -print0 2>/dev/null) # Removed non-portable -executable
        # find_exit_status=$? # Capture status if needed
    fi

    # --- Build Final Maps ---
    # Ensure maps are clear before populating (good practice if function might be called multiple times)
    _commands_map=()
    _overrides_map=()
    _conflict_map=()
    # Add system commands
    for base_name in "${!found_system_cmds[@]}"; do
        _commands_map["$base_name"]="${found_system_cmds[$base_name]}"
    done
    # Add/override with user commands
    for base_name in "${!found_user_cmds[@]}"; do
        local user_paths="${found_user_cmds[$base_name]}"
        if [[ "$user_paths" == *,* ]]; then
            _conflict_map["$base_name"]="$user_paths"
             _commands_map["$base_name"]="${user_paths%%,*}" # Keep first arbitrarily for map, conflict noted
        else
             _commands_map["$base_name"]="$user_paths" # Override system entry
             if [[ -v "found_system_cmds[$base_name]" ]]; then
                 _overrides_map["$base_name"]="${found_system_cmds[$base_name]}" # Note the override
             fi
        fi
    done

    return 0 # Success
}


# ============================================================================
# Function: RcShowFrameworkHelp
# Description: Displays help information about the rc command framework itself.
# Usage: RcShowFrameworkHelp
# ============================================================================
RcShowFrameworkHelp() {
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
# Function: RcListCommands
# Description: Scans and lists available commands with summaries and override notes.
# Usage: RcListCommands
# ============================================================================
RcListCommands() {
    # Use gc_version if available, fallback to RCFORGE_VERSION
    local version_to_display="${gc_version:-${RCFORGE_VERSION:-unknown}}"
    declare -A commands_map overrides_map conflict_map

    # Populate the maps AND check the exit status
    if ! RcScanUtils commands_map overrides_map conflict_map; then
        ErrorMessage "Error scanning utility directories. Cannot list commands."
        return 1 # Return error status
    fi

    # If RcScanUtils succeeded, maps should be populated (or empty)
    echo "rcForge Utility Commands (v${version_to_display})"
    echo ""
    echo "Available commands:"

    local cmd=""
    local summary=""
    local script_path=""
    local override_note=""
    local conflict_note=""
    local display_name=""
    local term_width=80 # Default width
    local wrap_width=76 # Default wrap width (80 - 4 for indent)
    local fold_exists=false

    # Try to get actual terminal width
    if command -v GetTerminalWidth &>/dev/null; then # Check if function from shell-colors exists
         term_width=$(GetTerminalWidth)
         wrap_width=$(( term_width > 10 ? term_width - 4 : 76 )) # Ensure wrap_width is reasonable
    fi
    # Check if fold command exists
    command -v fold >/dev/null && fold_exists=true

    # Check if commands_map is empty before trying to loop
    if [[ ${#commands_map[@]} -eq 0 ]]; then
        InfoMessage "  (No commands found in system or user utility directories)"
        echo "" # Add blank line after message
    else
        # Sort commands alphabetically for display
        for cmd in $(printf "%s\n" "${!commands_map[@]}" | sort); do
            script_path="${commands_map[$cmd]}"
            # Ensure script_path exists and is executable before calling summary
            if [[ -z "$script_path" || ! -x "$script_path" ]]; then
                 summary="Error: Invalid script path for '$cmd'"
            else
                 summary=$("$script_path" --summary 2>/dev/null || echo "Error fetching summary")
            fi

            # Check for override indicator
            override_note=""
            if [[ ${overrides_map[$cmd]+_} ]]; # Robust check
            then
                override_note=" ${YELLOW}(user override)${RESET}" # Add color
            fi

            # Check for execution conflict indicator
            conflict_note=""
            display_name="$cmd" # Default display name is plain command
            if [[ ${conflict_map[$cmd]+_} ]]; # Robust check
            then
                conflict_note=" ${RED}(CONFLICT)${RESET}" # Add color
                summary="Multiple executables found - see 'rc --conflicts'" # Override summary
                display_name="${RED}${cmd}${RESET}" # Colorize command name RED for conflict
            else
                # ---- ADDED: Make non-conflicting command name GREEN ----
                display_name="${GREEN}${cmd}${RESET}"
                # ---- END ADDED ----
            fi

            # --- Two-Line Output Format ---
            # Line 1: Command Name (now colored) + Notes (indented by 2 spaces)
            printf "  %b%b%b\n" "$display_name" "$override_note" "$conflict_note"

            # Line 2: Wrapped Summary (indented by 4 spaces)
            if [[ "$fold_exists" == "true" ]]; then
                # Wrap using fold
                 printf '%s\n' "$summary" | fold -s -w "$wrap_width" | while IFS= read -r line; do
                     printf "    %s\n" "$line"
                 done
            else
                # Print unwrapped if fold command is not available
                printf "    %s\n" "$summary"
            fi
            echo "" # Add blank line between entries
            # --- END Two-Line Output Format ---

        done
    fi # End check for empty commands_map

    # Add conditional footer for conflicts/overrides (keep as is)
    if [[ "${#overrides_map[@]}" -gt 0 || "${#conflict_map[@]}" -gt 0 ]]; then
        InfoMessage "[Note: User overrides and/or execution conflicts detected. Run 'rc --conflicts' for details.]"
        echo "" # Add spacing after note
    fi

    echo "Use 'rc <command> help' for detailed information about a command."
    # echo "Use 'rc search <term>' to find commands (Not Yet Implemented)."
}


# ============================================================================
# Function: RcShowConflicts
# Description: Shows user overrides and execution conflicts.
# Usage: RcShowConflicts
# ============================================================================
RcShowConflicts() {
    declare -A commands_map overrides_map conflict_map
    RcScanUtils commands_map overrides_map conflict_map # Populate the maps (Call updated name)

    local found_issue=false

    if [[ "${#overrides_map[@]}" -gt 0 ]]; then
        found_issue=true
        SectionHeader "User Overrides" # Assumes SectionHeader is available via utility-functions.sh
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
        SectionHeader "Execution Conflicts (Ambiguous Commands)" # Assumes SectionHeader is available
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
# Function: rc (Exported Command Implementation)
# Description: Main dispatcher function for the 'rc' command.
# Usage: rc <command> [options...]
# ============================================================================
rc() {
    # --- Argument Parsing ---
    local force_system=false
    local command=""
    local -a cmd_args=() # Store remaining args

    # (Argument parsing logic remains the same as before)
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --system|-s) force_system=true; shift ;;
            --help|-h) command="help"; shift; cmd_args=("$@"); break ;;
            --conflicts) command="--conflicts"; shift; cmd_args=("$@"); break ;;
             list) command="list"; shift; cmd_args=("$@"); break ;;
            --summary) command="summary"; shift; cmd_args=("$@"); break ;;
            -- | -*)
                if [[ "$1" == "--" ]]; then shift; break; fi
                if [[ "$1" == --* || "$1" == -[^-]* ]]; then break; else command="$1"; shift; cmd_args=("$@"); break; fi ;;
            *) command="$1"; shift; cmd_args=("$@"); break ;;
        esac
    done
    [[ -z "$command" ]] && command="list"
    # --- End Argument Parsing ---

    # --- Core Command Handling ---
    case "$command" in
        help)
            if [[ ${#cmd_args[@]} -gt 0 && "${cmd_args[0]}" != --* && "${cmd_args[0]}" != -* ]]; then
                local target_cmd="${cmd_args[0]}"
                command="$target_cmd"
                cmd_args=("help" "${cmd_args[@]:1}")
                # Fall through to the *) case below
            else
                RcShowFrameworkHelp
                return 0 # Return success after showing framework help
            fi
             # Fallthrough intended here if specific command help was requested
            ;; # Still need ;; here for syntax if fallthrough doesn't happen via *)

        list)
            RcListCommands
             if [[ ${#cmd_args[@]} -gt 0 ]]; then WarningMessage "'rc list' does not accept additional arguments. Ignoring: ${cmd_args[*]}"; fi
            return 0
            ;;

        --conflicts)
             RcShowConflicts
             if [[ ${#cmd_args[@]} -gt 0 ]]; then WarningMessage "'rc --conflicts' does not accept additional arguments. Ignoring: ${cmd_args[*]}"; fi
             return 0
             ;;
        summary)
             echo "rc - rcForge command execution framework."
             return 0
             ;;
        search)
             ErrorMessage "Search functionality not yet implemented." # No exit code needed, ErrorMessage just prints
             return 1 # Return error from rc function
             ;;
         *) # Handle dispatching to utility scripts
             # --- Utility Script Dispatch Logic ---
             local target_script=""
             local user_dir="${RCFORGE_USER_UTILS:-/invalid_path}"
             local sys_dir="${RCFORGE_UTILS:-/invalid_path}"
             local -a search_dirs=()
             local -a found_scripts=()
             local dir=""
             local file=""

             # Determine search order
             if [[ "$force_system" == "true" ]]; then search_dirs=("$sys_dir"); else search_dirs=("$user_dir" "$sys_dir"); fi

             # Find potential script files
             for dir in "${search_dirs[@]}"; do
                 if [[ -d "$dir" ]]; then
                      while IFS= read -r -d '' file; do
                          if [[ -x "$file" ]]; then found_scripts+=("$file"); fi
                      done < <(find "$dir" -maxdepth 1 \( -name "${command}" -o -name "${command}.*" \) -type f -print0 2>/dev/null)
                 fi
                 if [[ ${#found_scripts[@]} -gt 0 && "$force_system" == "false" && "$dir" == "$user_dir" ]]; then break; fi
             done

              # --- Handle Results ---
             if [[ ${#found_scripts[@]} -eq 0 ]]; then
                 # --- MODIFIED: Call ErrorMessage WITHOUT exit code, then RETURN ---
                 ErrorMessage "rc command not found: '$command'" # Just print the error
                 return 127 # Return code 127 from rc function
                 # --- END MODIFIED ---
             elif [[ ${#found_scripts[@]} -eq 1 ]]; then
                 target_script="${found_scripts[0]}"
                 bash "$target_script" "${cmd_args[@]}" # Execute using bash
                 return $? # Return the script's exit code
             else
                 # Conflict (Ambiguous command) - this already uses return, which is correct
                  ErrorMessage "Ambiguous command '$command'. Found multiple executables:"
                  printf '  - %s\n' "${found_scripts[@]}" >&2
                  InfoMessage "Please rename or remove conflicting files, or use '--system' flag if applicable."
                  return 1 # Return error from rc function
             fi
             # --- End Utility Script Dispatch ---
            ;; # End of default *) case

    esac # End of core command case statement
}
# Ensure the full implementation is also exported if sourced directly somehow
export -f rc

# EOF