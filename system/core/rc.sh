#!/usr/bin/env bash
# rc.sh - Core rc command dispatcher (Standalone Script)
# Author: rcForge Team
# Date: 2025-04-07 # Updated for refactor
# Version: 0.4.1
# Category: system/core
# RC Summary: Finds and executes user or system utility scripts
# Description: Finds and executes user or system utility scripts, handles help and conflicts.
#              Runs as a standalone script invoked by the 'rc' wrapper function.
bash --version
# Source required libraries explicitly
# Default paths used in case RCFORGE_LIB is not set (e.g., direct execution)
source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/utility-functions.sh"

# Set strict modes
set -o nounset
set -o pipefail
# set -o errexit # Let functions handle their own errors

# Ensure necessary environment variables are available, using defaults if not set
: "${RCFORGE_USER_UTILS:=$HOME/.config/rcforge/utils}"
: "${RCFORGE_UTILS:=$HOME/.config/rcforge/system/utils}"
: "${gc_version:=${RCFORGE_VERSION:-0.4.1}}"

# ============================================================================
# Helper Functions (Internal)
# ============================================================================

# ============================================================================
# Function: _RcScanUtils (Internal)
# Description: Scans system and user utility directories to build command maps
# Usage: _RcScanUtils commands_map_ref overrides_map_ref conflict_map_ref
# Arguments:
#   commands_map_ref (required) - Nameref to associative array to store command paths
#   overrides_map_ref (required) - Nameref to associative array to store override info
#   conflict_map_ref (required) - Nameref to associative array to store conflict info
# Returns: 0 on success, 1 on error.
# ============================================================================
_RcScanUtils() {
    if [[ "${BASH_VERSINFO[0]}" -lt 4 || ("${BASH_VERSINFO[0]}" -eq 4 && "${BASH_VERSINFO[1]}" -lt 3) ]]; then
        ErrorMessage "Internal Error: _RcScanUtils requires Bash 4.3+ for namerefs."
        return 1
    fi

    local -n _commands_map="$1"
    local -n _overrides_map="$2"
    local -n _conflict_map="$3"
    local user_dir="${RCFORGE_USER_UTILS:-}"
    local sys_dir="${RCFORGE_UTILS:-}"
    local file=""
    local base_name=""
    local ext=""
    declare -A found_system_cmds
    declare -A found_user_cmds
    local find_exit_status=0

    # Scan system utilities directory
    if [[ -d "$sys_dir" ]]; then
        while IFS= read -r -d '' file; do
            if [[ -x "$file" ]]; then
                base_name=$(basename "$file")
                if [[ "$base_name" == *.* ]]; then
                    ext="${base_name##*.}"
                    base_name="${base_name%.*}"
                else
                    ext=""
                fi

                # Skip hidden files or empty basenames
                [[ -z "$base_name" || "$base_name" == .* ]] && continue
                found_system_cmds["$base_name"]="$file"
            fi
        done < <(find "$sys_dir" -maxdepth 1 -type f -print0 2>/dev/null)
    fi

    # Scan user utilities directory
    if [[ -d "$user_dir" ]]; then
        while IFS= read -r -d '' file; do
            if [[ -x "$file" ]]; then
                base_name=$(basename "$file")
                if [[ "$base_name" == *.* ]]; then
                    ext="${base_name##*.}"
                    base_name="${base_name%.*}"
                else
                    ext=""
                fi

                # Skip hidden files or empty basenames
                [[ -z "$base_name" || "$base_name" == .* ]] && continue

                # Check for multiple user utilities with same name
                if [[ -v "found_user_cmds[$base_name]" ]]; then
                    found_user_cmds["$base_name"]+=",${file}"
                else
                    found_user_cmds["$base_name"]="$file"
                fi
            fi
        done < <(find "$user_dir" -maxdepth 1 -type f -print0 2>/dev/null)
    fi

    # Clear output maps
    _commands_map=()
    _overrides_map=()
    _conflict_map=()

    # Populate command map with system commands first
    for base_name in "${!found_system_cmds[@]}"; do
        _commands_map["$base_name"]="${found_system_cmds[$base_name]}"
    done

    # Add/override with user commands and mark overrides/conflicts
    for base_name in "${!found_user_cmds[@]}"; do
        local user_paths="${found_user_cmds[$base_name]}"

        # Check for multiple user utilities with same name (conflict)
        if [[ "$user_paths" == *,* ]]; then
            _conflict_map["$base_name"]="$user_paths"
            # Use first one found in conflict scenario
            _commands_map["$base_name"]="${user_paths%%,*}"
        else
            # Add user command to commands map
            _commands_map["$base_name"]="$user_paths"

            # Mark as override if system also has this command
            if [[ -v "found_system_cmds[$base_name]" ]]; then
                _overrides_map["$base_name"]="${found_system_cmds[$base_name]}"
            fi
        fi
    done

    return 0
}

# ============================================================================
# Function: ShowFrameworkHelp
# Description: Display help information about the rc command framework.
# Usage: ShowFrameworkHelp
# Arguments: None
# Returns: None. Prints help to stdout and exits.
# ============================================================================
ShowFrameworkHelp() {
    local version_to_display="${gc_version:-unknown}"

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
# Function: ListCommands
# Description: List all available rc commands with summaries.
# Usage: ListCommands
# Arguments: None
# Returns: 0 on success, 1 on error.
# ============================================================================
ListCommands() {
    local version_to_display="${gc_version:-unknown}"
    declare -A commands_map overrides_map conflict_map

    if ! _RcScanUtils commands_map overrides_map conflict_map; then
        ErrorMessage "Error scanning utility directories. Cannot list commands."
        return 1
    fi

    echo "rcForge Utility Commands (v${version_to_display})"
    echo ""
    echo "Available commands:"

    local cmd=""
    local summary=""
    local script_path=""
    local override_note=""
    local conflict_note=""
    local display_name=""
    local term_width=80
    local wrap_width=76
    local fold_exists=false

    # Try to get terminal width if GetTerminalWidth is available
    if command -v GetTerminalWidth &>/dev/null; then
        term_width=$(GetTerminalWidth)
        wrap_width=$((term_width > 10 ? term_width - 4 : 76))
    fi

    # Check for fold command
    command -v fold >/dev/null && fold_exists=true

    # Handle case with no commands found
    if [[ ${#commands_map[@]} -eq 0 ]]; then
        InfoMessage "  (No commands found in system or user utility directories)"
        echo ""
    else
        # Iterate through commands in sorted order
        for cmd in $(printf "%s\n" "${!commands_map[@]}" | sort); do
            script_path="${commands_map[$cmd]}"

            # Get command summary
            summary=""
            if [[ -z "$script_path" || ! -x "$script_path" ]]; then
                summary="Error: Invalid script path for '$cmd'"
            else
                summary=$(bash "$script_path" --summary 2>/dev/null) || summary="Error fetching summary"
                [[ -z "$summary" ]] && summary="(No summary provided)"
            fi

            # Prepare display information (override/conflict notes)
            override_note=""
            if [[ ${overrides_map[$cmd]+_} ]]; then
                override_note=" ${YELLOW}(user override)${RESET}"
            fi

            conflict_note=""
            display_name="$cmd"
            if [[ ${conflict_map[$cmd]+_} ]]; then
                conflict_note=" ${RED}(CONFLICT)${RESET}"
                summary="Multiple executables found - see 'rc --conflicts'"
                display_name="${RED}${cmd}${RESET}"
            else
                display_name="${GREEN}${cmd}${RESET}"
            fi

            # Display command name with notes
            printf "  %b%b%b\n" "$display_name" "$override_note" "$conflict_note" # %b for colors

            # Display wrapped summary
            if [[ "$fold_exists" == "true" ]]; then
                printf '%s\n' "$summary" | fold -s -w "$wrap_width" | while IFS= read -r line; do
                    printf "    %s\n" "$line"
                done
            else
                printf "    %s\n" "$summary"
            fi

            echo ""
        done
    fi

    # Show note about overrides/conflicts if any exist
    if [[ "${#overrides_map[@]}" -gt 0 || "${#conflict_map[@]}" -gt 0 ]]; then
        InfoMessage "[Note: User overrides and/or execution conflicts detected. Run 'rc --conflicts' for details.]"
        echo ""
    fi

    echo "Use 'rc <command> help' for detailed information about a command."

    return 0
}

# ============================================================================
# Function: ShowConflicts
# Description: Show detected command conflicts and user overrides.
# Usage: ShowConflicts
# Arguments: None
# Returns: 0 on success.
# ============================================================================
ShowConflicts() {
    declare -A commands_map overrides_map conflict_map

    _RcScanUtils commands_map overrides_map conflict_map

    local found_issue=false

    # Display user overrides if any exist
    if [[ "${#overrides_map[@]}" -gt 0 ]]; then
        found_issue=true
        SectionHeader "User Overrides"

        local cmd=""
        for cmd in $(printf "%s\n" "${!overrides_map[@]}" | sort); do
            local user_path="${commands_map[$cmd]}"
            local system_path="${overrides_map[$cmd]}"

            WarningMessage "User utility '${cmd}' overrides system utility:"
            echo "  User:   ${user_path}"
            echo "  System: ${system_path}"
            echo ""
        done
    fi

    # Display execution conflicts if any exist
    if [[ "${#conflict_map[@]}" -gt 0 ]]; then
        found_issue=true
        SectionHeader "Execution Conflicts (Ambiguous Commands)"

        local cmd=""
        for cmd in $(printf "%s\n" "${!conflict_map[@]}" | sort); do
            local conflicting_paths="${conflict_map[$cmd]}"
            local first_path="${conflicting_paths%%,*}"
            local conflict_dir=$(dirname "$first_path")

            ErrorMessage "Conflict for command '${cmd}' in ${conflict_dir}:"
            echo "$conflicting_paths" | tr ',' '\n' | sed 's/^/  - /'
            echo ""
        done
    fi

    # Show success message if no issues found
    if [[ "$found_issue" == "false" ]]; then
        SuccessMessage "No user overrides or execution conflicts detected."
    fi

    return 0
}

# ============================================================================
# Function: main
# Description: Main execution logic for the rc command script.
# Usage: main "$@"
# Arguments: All arguments passed to the script
# Returns: 0 on success, other values on specific errors
# ============================================================================
main() {
    local force_system=false
    local command=""
    local -a cmd_args=()

    # Process command-line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --system | -s)
                force_system=true
                shift
                ;;
            --help | -h)
                command="help"
                shift
                cmd_args=("$@")
                break
                ;;
            --conflicts)
                command="--conflicts"
                shift
                cmd_args=("$@")
                break
                ;;
            list)
                command="list"
                shift
                cmd_args=("$@")
                break
                ;;
            --summary)
                command="summary"
                shift
                cmd_args=("$@")
                break
                ;;
            --)
                shift
                cmd_args=("$@")
                break
                ;;
            *)
                command="$1"
                shift
                cmd_args=("$@")
                break
                ;;
        esac
    done

    # Default to list if no command specified
    [[ -z "$command" ]] && command="list"

    # --- Core Command Handling ---
    case "$command" in
        help)
            if [[ ${#cmd_args[@]} -gt 0 && "${cmd_args[0]}" != --* && "${cmd_args[0]}" != -* ]]; then
                local target_cmd="${cmd_args[0]}"
                command="$target_cmd"
                cmd_args=("help" "${cmd_args[@]:1}")
            else
                ShowFrameworkHelp
                return 0
            fi
            ;;
        list)
            ListCommands
            if [[ ${#cmd_args[@]} -gt 0 ]]; then
                WarningMessage "'rc list' does not accept additional arguments. Ignoring: ${cmd_args[*]}"
            fi
            return 0
            ;;
        --conflicts)
            ShowConflicts
            if [[ ${#cmd_args[@]} -gt 0 ]]; then
                WarningMessage "'rc --conflicts' does not accept additional arguments. Ignoring: ${cmd_args[*]}"
            fi
            return 0
            ;;
        summary)
            echo "rc - rcForge command execution framework."
            return 0
            ;;
        search)
            ErrorMessage "Search functionality not yet implemented."
            return 1
            ;;
        *)
            # Command dispatch logic
            local target_script=""
            local user_dir="${RCFORGE_USER_UTILS:-/invalid_path}"
            local sys_dir="${RCFORGE_UTILS:-/invalid_path}"
            local -a search_dirs=()
            local -a found_scripts=()
            local dir=""
            local file=""

            # Determine search order based on --system flag
            if [[ "$force_system" == "true" ]]; then
                search_dirs=("$sys_dir")
            else
                search_dirs=("$user_dir" "$sys_dir")
            fi

            # Search for matching command executable
            for dir in "${search_dirs[@]}"; do
                if [[ -d "$dir" ]]; then
                    while IFS= read -r -d '' file; do
                        if [[ -x "$file" ]]; then
                            found_scripts+=("$file")
                        fi
                    done < <(find "$dir" -maxdepth 1 \( -name "${command}" -o -name "${command}.*" \) -type f -print0 2>/dev/null)
                fi

                # Break after finding user overrides if not forcing system version
                if [[ ${#found_scripts[@]} -gt 0 && "$force_system" == "false" && "$dir" == "$user_dir" ]]; then
                    break
                fi
            done

            # Handle command resolution results
            if [[ ${#found_scripts[@]} -eq 0 ]]; then
                ErrorMessage "rc command not found: '$command'"
                return 127
            elif [[ ${#found_scripts[@]} -eq 1 ]]; then
                target_script="${found_scripts[0]}"
                bash "$target_script" "${cmd_args[@]}"
                return $?
            else
                ErrorMessage "Ambiguous command '$command'. Found multiple executables:"
                printf '  - %s\n' "${found_scripts[@]}" >&2
                InfoMessage "Please rename or remove conflicting files, or use '--system' flag if applicable."
                return 1
            fi
            ;;
    esac
}

# Execute main function, passing all script arguments "$@"
main "$@"
exit $? # Exit with the return code from main

# EOF
