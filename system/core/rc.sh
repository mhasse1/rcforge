#!/usr/bin/env bash
# rc.sh - Core rc command dispatcher (Standalone Script)
# Author: rcForge Team
# Date: 2025-04-07 # Updated for refactor
# Version: 0.5.0
# Category: system/core
# RC Summary: Finds and executes user or system utility scripts
# Description: Finds and executes user or system utility scripts, handles help and conflicts.
#              Runs as a standalone script invoked by the 'rc' wrapper function.

# Source required libraries explicitly
# Default paths used in case RCFORGE_LIB is not set (e.g., direct execution)
source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/utility-functions.sh"

# Set strict modes
set -o nounset
set -o pipefail

# Ensure necessary environment variables are available, using defaults if not set
: "${RCFORGE_USER_UTILS:=$HOME/.config/rcforge/utils}"
: "${RCFORGE_UTILS:=$HOME/.config/rcforge/system/utils}"
: "${gc_version:=${RCFORGE_VERSION:-0.5.0}}"

# ============================================================================
# SIMPLIFIED COMMAND RESOLUTION
# ============================================================================
FindCommand() {
    local command="$1"
    local force_system="$2"
    local user_dir="${RCFORGE_USER_UTILS:-}"
    local sys_dir="${RCFORGE_UTILS:-}"
    local found_scripts=()

    # Determine search paths based on force_system flag
    local search_dirs=("$user_dir" "$sys_dir")
    [[ "$force_system" == "true" ]] && search_dirs=("$sys_dir")

    # Search for matching command
    for dir in "${search_dirs[@]}"; do
        [[ ! -d "$dir" ]] && continue

        while IFS= read -r -d '' file; do
            [[ -x "$file" ]] && found_scripts+=("$file")
        done < <(find "$dir" -maxdepth 1 \( -name "${command}" -o -name "${command}.*" \) -type f -print0 2>/dev/null)

        # Stop if we found something in user dir (unless forcing system)
        [[ ${#found_scripts[@]} -gt 0 && "$force_system" == "false" && "$dir" == "$user_dir" ]] && break
    done

    # Handle results
    if [[ ${#found_scripts[@]} -eq 0 ]]; then
        echo "command_not_found"
    elif [[ ${#found_scripts[@]} -eq 1 ]]; then
        echo "${found_scripts[0]}"
    else
        echo "ambiguous_command:$(
            IFS=$','
            echo "${found_scripts[*]}"
        )"
    fi
}

# ============================================================================
# SIMPLIFIED COMMAND SCANNING
# ============================================================================
ScanUtilities() {
    local -n commands_map_ref="$1"
    local -n overrides_map_ref="$2"
    local -n conflict_map_ref="$3"

    local user_dir="${RCFORGE_USER_UTILS:-}"
    local sys_dir="${RCFORGE_UTILS:-}"
    declare -A system_cmds=() user_cmds=() all_cmds=() overrides=() conflicts=()

    # Clear output maps
    commands_map_ref=()
    overrides_map_ref=()
    conflict_map_ref=()

    # Scan system utilities
    if [[ -d "$sys_dir" ]]; then
        while IFS= read -r -d '' file; do
            [[ ! -x "$file" ]] && continue
            local name=$(basename "${file%.*}")
            [[ -z "$name" || "$name" == .* ]] && continue
            system_cmds["$name"]="$file"
        done < <(find "$sys_dir" -maxdepth 1 -type f -print0 2>/dev/null)
    fi

    # Scan user utilities
    if [[ -d "$user_dir" ]]; then
        while IFS= read -r -d '' file; do
            [[ ! -x "$file" ]] && continue
            local name=$(basename "${file%.*}")
            [[ -z "$name" || "$name" == .* ]] && continue

            if [[ -v "user_cmds[$name]" ]]; then
                conflicts["$name"]="${user_cmds[$name]},${file}"
            else
                user_cmds["$name"]="$file"
            fi
        done < <(find "$user_dir" -maxdepth 1 -type f -print0 2>/dev/null)
    fi

    # Build final command map
    for name in "${!system_cmds[@]}"; do
        commands_map_ref["$name"]="${system_cmds[$name]}"
    done

    # Add/override with user commands
    for name in "${!user_cmds[@]}"; do
        # For conflicts, use first found file (per documentation)
        if [[ -v "conflicts[$name]" ]]; then
            local first_file="${conflicts[$name]%%,*}"
            commands_map_ref["$name"]="$first_file"
            conflict_map_ref["$name"]="${conflicts[$name]}"
        else
            commands_map_ref["$name"]="${user_cmds[$name]}"
            # Mark as override if system also has this
            if [[ -v "system_cmds[$name]" ]]; then
                overrides_map_ref["$name"]="${system_cmds[$name]}"
            fi
        fi
    done

    return 0
}

# ============================================================================
# SIMPLIFIED HELP AND LIST FUNCTIONS
# ============================================================================
ShowFrameworkHelp() {
    local version_to_display="${gc_version:-unknown}"

    echo "rcForge Command Framework (v${version_to_display})"
    echo ""
    echo "Usage: rc [--system|-s] <command> [command-options] [arguments...]"
    echo ""
    echo "Description:"
    echo "  The 'rc' command provides access to rcForge system and user utilities."
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
    echo "  rc httpheaders example.com"
}

ListCommands() {
    declare -A commands_map overrides_map conflict_map
    ScanUtilities commands_map overrides_map conflict_map

    echo "rcForge Utility Commands (v${gc_version:-unknown})"
    echo ""

    if [[ ${#commands_map[@]} -eq 0 ]]; then
        echo "No commands found."
        return 0
    fi

    # Sort commands for display
    local sorted_cmds=($(printf '%s\n' "${!commands_map[@]}" | sort))

    for cmd in "${sorted_cmds[@]}"; do
        local path="${commands_map[$cmd]}"
        local summary=""
        local cmd_display="$cmd"
        local cmd_color=""

        # Get summary if possible
        if [[ -x "$path" ]]; then
            summary=$(bash "$path" --summary 2>/dev/null) || summary="No summary available"
        else
            summary="Error: Invalid script path"
        fi

        # Format display based on status
        if [[ -v "conflict_map[$cmd]" ]]; then
            cmd_color="${RED}"
            cmd_display="${cmd} (CONFLICT)"
            summary="Multiple executables found - see 'rc --conflicts'"
        elif [[ -v "overrides_map[$cmd]" ]]; then
            cmd_color="${YELLOW}"
            cmd_display="${cmd}"
            summary="(user override) $summary"
        else
            cmd_color="${GREEN}"
            cmd_display="${cmd}"
        fi

        printf "  %b%-15s%b : %s\n" $cmd_color "$cmd_display" $RESET "$summary"
    done

    # Show conflicts note if needed
    if [[ ${#overrides_map[@]} -gt 0 || ${#conflict_map[@]} -gt 0 ]]; then
        echo "Note: Run 'rc --conflicts' to see details on overrides and conflicts."
    fi

    return 0
}

ShowConflicts() {
    declare -A commands_map overrides_map conflict_map
    ScanUtilities commands_map overrides_map conflict_map

    if [[ ${#overrides_map[@]} -eq 0 && ${#conflict_map[@]} -eq 0 ]]; then
        if command -v SuccessMessage &>/dev/null; then
            SuccessMessage "No user overrides or execution conflicts detected."
        else
            echo "No user overrides or execution conflicts detected."
        fi
        return 0
    fi

    # Show overrides
    if [[ ${#overrides_map[@]} -gt 0 ]]; then
        echo "User Overrides:"
        echo ""

        for cmd in $(printf '%s\n' "${!overrides_map[@]}" | sort); do
            local user_path="${commands_map[$cmd]}"
            local system_path="${overrides_map[$cmd]}"

            if command -v WarningMessage &>/dev/null; then
                WarningMessage "User utility '${cmd}' overrides system utility:"
            else
                echo "Warning: User utility '${cmd}' overrides system utility:"
            fi
            echo "  User:   ${user_path}"
            echo "  System: ${system_path}"
            echo ""
        done
    fi

    # Show conflicts
    if [[ ${#conflict_map[@]} -gt 0 ]]; then
        echo "Execution Conflicts (Ambiguous Commands):"
        echo ""

        for cmd in $(printf '%s\n' "${!conflict_map[@]}" | sort); do
            local conflict_paths="${conflict_map[$cmd]}"
            local first_path="${conflict_paths%%,*}"
            local conflict_dir=$(dirname "$first_path")

            if command -v ErrorMessage &>/dev/null; then
                ErrorMessage "Conflict for command '${cmd}' in ${conflict_dir}:"
            else
                echo "Error: Conflict for command '${cmd}' in ${conflict_dir}:"
            fi
            echo "$conflict_paths" | tr ',' '\n' | sed 's/^/  - /'
            echo ""
        done
    fi

    return 0
}

# ============================================================================
# SIMPLIFIED MAIN FUNCTION
# ============================================================================
main() {
    local force_system=false
    local command=""
    local -a cmd_args=()

    # Process command-line options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --system | -s)
                force_system=true
                shift
                ;;
            --help | -h)
                command="help"
                shift
                break
                ;;
            --conflicts)
                command="conflicts"
                shift
                break
                ;;
            list)
                command="list"
                shift
                cmd_args=("$@")
                break
                ;;
            --summary)
                echo "rc - rcForge command execution framework."
                exit 0
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

    # Default to list if no command
    [[ -z "$command" ]] && command="list"

    # Handle built-in commands
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
            [[ ${#cmd_args[@]} -gt 0 ]] && echo "Note: Additional arguments ignored: ${cmd_args[*]}"
            return 0
            ;;
        conflicts)
            ShowConflicts
            [[ ${#cmd_args[@]} -gt 0 ]] && echo "Note: Additional arguments ignored: ${cmd_args[*]}"
            return 0
            ;;
    esac

    # Find command script
    local target=$(FindCommand "$command" "$force_system")

    # Execute command or handle errors
    if [[ "$target" == "command_not_found" ]]; then
        if command -v ErrorMessage &>/dev/null; then
            ErrorMessage "rc command not found: '$command'"
        else
            echo "Error: rc command not found: '$command'" >&2
        fi
        return 127
    elif [[ "$target" == ambiguous_command:* ]]; then
        local found_files="${target#ambiguous_command:}"
        if command -v ErrorMessage &>/dev/null; then
            ErrorMessage "Ambiguous command '$command'. Found multiple executables:"
        else
            echo "Error: Ambiguous command '$command'. Found multiple executables:" >&2
        fi
        echo "$found_files" | tr ',' '\n' | sed 's/^/  - /' >&2
        echo "Use '--system' flag if applicable, or rename conflicting files." >&2
        return 1
    else
        bash "$target" "${cmd_args[@]}"
        return $?
    fi
}

# Execute main function, passing all script arguments "$@"
main "$@"
exit $? # Exit with the return code from main

# EOF
