#!/usr/bin/env bash
# rc.sh - Core rc command dispatcher (Standalone Script)
# Author: rcForge Team
# Date: 2025-04-07 # Updated for refactor
# Version: 0.4.1
# Category: system/core
# Description: Finds and executes user or system utility scripts, handles help and conflicts. Runs as a standalone script invoked by the 'rc' wrapper function.

# --- START DEBUG ---
echo "[DEBUG rc.sh] Starting execution."
echo "[DEBUG rc.sh] RCFORGE_LIB is: '${RCFORGE_LIB:-NOT SET}'"
# --- END DEBUG ---

# Source required libraries explicitly
# Default paths used in case RCFORGE_LIB is not set (e.g., direct execution)
source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/utility-functions.sh"

# --- START DEBUG ---
echo "[DEBUG rc.sh] Sourced libraries."
echo "[DEBUG rc.sh] GREEN is: '${GREEN:-UNBOUND}'"
echo "[DEBUG rc.sh] RESET is: '${RESET:-UNBOUND}'"
echo "[DEBUG rc.sh] InfoMessage is: '$(declare -f InfoMessage &>/dev/null && echo "Defined" || echo "UNDEFINED")'"
# --- END DEBUG ---


# Set strict modes
# set -o nounset # <<< TEMPORARILY COMMENTED OUT FOR DEBUGGING
set -o pipefail
# set -o errexit # Let functions handle their own errors

# Ensure necessary environment variables are available, using defaults if not set
: "${RCFORGE_USER_UTILS:=$HOME/.config/rcforge/utils}"
: "${RCFORGE_UTILS:=$HOME/.config/rcforge/system/utils}"
: "${gc_version:=${RCFORGE_VERSION:-0.4.1}}"

# ============================================================================
# Helper Functions (Internal - Copied from rc-command.sh, kept PascalCase)
# ============================================================================
RcScanUtils() {
    # ... (rest of function definition unchanged) ...
    if [[ "${BASH_VERSINFO[0]}" -lt 4 || ( "${BASH_VERSINFO[0]}" -eq 4 && "${BASH_VERSINFO[1]}" -lt 3 ) ]]; then ErrorMessage "Internal Error: RcScanUtils requires Bash 4.3+ for namerefs."; return 1; fi
    local -n _commands_map="$1"; local -n _overrides_map="$2"; local -n _conflict_map="$3"; local user_dir="${RCFORGE_USER_UTILS:-}"; local sys_dir="${RCFORGE_UTILS:-}"; local file=""; local base_name=""; local ext=""; declare -A found_system_cmds; declare -A found_user_cmds; local find_exit_status=0
    if [[ -d "$sys_dir" ]]; then while IFS= read -r -d '' file; do if [[ -x "$file" ]]; then base_name=$(basename "$file"); if [[ "$base_name" == *.* ]]; then ext="${base_name##*.}"; base_name="${base_name%.*}"; else ext=""; fi; [[ -z "$base_name" || "$base_name" == .* ]] && continue; found_system_cmds["$base_name"]="$file"; fi; done < <(find "$sys_dir" -maxdepth 1 -type f -print0 2>/dev/null); fi
    if [[ -d "$user_dir" ]]; then while IFS= read -r -d '' file; do if [[ -x "$file" ]]; then base_name=$(basename "$file"); if [[ "$base_name" == *.* ]]; then ext="${base_name##*.}"; base_name="${base_name%.*}"; else ext=""; fi; [[ -z "$base_name" || "$base_name" == .* ]] && continue; if [[ -v "found_user_cmds[$base_name]" ]]; then found_user_cmds["$base_name"]+=",${file}"; else found_user_cmds["$base_name"]="$file"; fi; fi; done < <(find "$user_dir" -maxdepth 1 -type f -print0 2>/dev/null); fi
    _commands_map=(); _overrides_map=(); _conflict_map=()
    for base_name in "${!found_system_cmds[@]}"; do _commands_map["$base_name"]="${found_system_cmds[$base_name]}"; done
    for base_name in "${!found_user_cmds[@]}"; do local user_paths="${found_user_cmds[$base_name]}"; if [[ "$user_paths" == *,* ]]; then _conflict_map["$base_name"]="$user_paths"; _commands_map["$base_name"]="${user_paths%%,*}"; else _commands_map["$base_name"]="$user_paths"; if [[ -v "found_system_cmds[$base_name]" ]]; then _overrides_map["$base_name"]="${found_system_cmds[$base_name]}"; fi; fi; done
    return 0
}
RcShowFrameworkHelp() {
    # ... (function definition unchanged) ...
    local version_to_display="${gc_version:-unknown}"; echo "rcForge Command Framework (v${version_to_display})"; echo ""; echo "Usage: rc [--system|-s] <command> [command-options] [arguments...]"; echo ""; echo "Description:"; echo "  The 'rc' command provides access to rcForge system and user utilities."; echo "  User utilities in ~/.config/rcforge/utils/ override system utilities"; echo "  in ~/.config/rcforge/system/utils/ with the same name."; echo ""; echo "Common Commands:"; printf "  %-18s %s\n" "list" "List all available rc commands and their summaries."; printf "  %-18s %s\n" "help" "Show this help message about the rc framework."; printf "  %-18s %s\n" "<command> help" "Show detailed help for a specific <command>."; printf "  %-18s %s\n" "--conflicts" "Show user overrides and execution conflicts."; echo ""; echo "Global Options:"; printf "  %-18s %s\n" "--system, -s" "Force execution of the system version of a command,"; printf "  %-18s %s\n" "" "bypassing any user override."; echo ""; echo "Example:"; echo "  rc list                 # See available commands"; echo "  rc httpheaders help     # Get help for the httpheaders command"; echo "  rc httpheaders example.com"; echo "  rc -s diag              # Run the system version of diag"

}
RcListCommands() {
    # ... (function definition unchanged, relies on colors/utils) ...
    local version_to_display="${gc_version:-unknown}"; declare -A commands_map overrides_map conflict_map
    if ! RcScanUtils commands_map overrides_map conflict_map; then ErrorMessage "Error scanning utility directories. Cannot list commands."; return 1; fi
    echo "rcForge Utility Commands (v${version_to_display})"; echo ""; echo "Available commands:"
    local cmd=""; local summary=""; local script_path=""; local override_note=""; local conflict_note=""; local display_name=""; local term_width=80; local wrap_width=76; local fold_exists=false
    if command -v GetTerminalWidth &>/dev/null; then term_width=$(GetTerminalWidth); wrap_width=$(( term_width > 10 ? term_width - 4 : 76 )); fi; command -v fold >/dev/null && fold_exists=true
    if [[ ${#commands_map[@]} -eq 0 ]]; then InfoMessage "  (No commands found in system or user utility directories)"; echo ""; else
        for cmd in $(printf "%s\n" "${!commands_map[@]}" | sort); do
            script_path="${commands_map[$cmd]}"; summary=""; if [[ -z "$script_path" || ! -x "$script_path" ]]; then summary="Error: Invalid script path for '$cmd'"; else summary=$(bash "$script_path" --summary 2>/dev/null) || summary="Error fetching summary"; [[ -z "$summary" ]] && summary="(No summary provided)"; fi
            override_note=""; if [[ ${overrides_map[$cmd]+_} ]]; then override_note=" ${YELLOW}(user override)${RESET}"; fi
            conflict_note=""; display_name="$cmd"; if [[ ${conflict_map[$cmd]+_} ]]; then conflict_note=" ${RED}(CONFLICT)${RESET}"; summary="Multiple executables found - see 'rc --conflicts'"; display_name="${RED}${cmd}${RESET}"; else display_name="${GREEN}${cmd}${RESET}"; fi
            printf "  %b%b%b\n" "$display_name" "$override_note" "$conflict_note" # %b for colors
            if [[ "$fold_exists" == "true" ]]; then printf '%s\n' "$summary" | fold -s -w "$wrap_width" | while IFS= read -r line; do printf "    %s\n" "$line"; done; else printf "    %s\n" "$summary"; fi; echo ""
        done
    fi
    if [[ "${#overrides_map[@]}" -gt 0 || "${#conflict_map[@]}" -gt 0 ]]; then InfoMessage "[Note: User overrides and/or execution conflicts detected. Run 'rc --conflicts' for details.]"; echo ""; fi
    echo "Use 'rc <command> help' for detailed information about a command."

}
RcShowConflicts() {
    # ... (function definition unchanged) ...
    declare -A commands_map overrides_map conflict_map; RcScanUtils commands_map overrides_map conflict_map; local found_issue=false
    if [[ "${#overrides_map[@]}" -gt 0 ]]; then found_issue=true; SectionHeader "User Overrides"; local cmd=""; for cmd in $(printf "%s\n" "${!overrides_map[@]}" | sort); do local user_path="${commands_map[$cmd]}"; local system_path="${overrides_map[$cmd]}"; WarningMessage "User utility '${cmd}' overrides system utility:"; echo "  User:   ${user_path}"; echo "  System: ${system_path}"; echo ""; done; fi
    if [[ "${#conflict_map[@]}" -gt 0 ]]; then found_issue=true; SectionHeader "Execution Conflicts (Ambiguous Commands)"; local cmd=""; for cmd in $(printf "%s\n" "${!conflict_map[@]}" | sort); do local conflicting_paths="${conflict_map[$cmd]}"; local first_path="${conflicting_paths%%,*}"; local conflict_dir=$(dirname "$first_path"); ErrorMessage "Conflict for command '${cmd}' in ${conflict_dir}:"; echo "$conflicting_paths" | tr ',' '\n' | sed 's/^/  - /'; echo ""; done; fi
    if [[ "$found_issue" == "false" ]]; then SuccessMessage "No user overrides or execution conflicts detected."; fi
}

# ============================================================================
# Function: main
# ============================================================================
main() {
    # ... (argument parsing unchanged) ...
    local force_system=false; local command=""; local -a cmd_args=()
    while [[ $# -gt 0 ]]; do case "$1" in --system|-s) force_system=true; shift ;; --help|-h) command="help"; shift; cmd_args=("$@"); break ;; --conflicts) command="--conflicts"; shift; cmd_args=("$@"); break ;; list) command="list"; shift; cmd_args=("$@"); break ;; --summary) command="summary"; shift; cmd_args=("$@"); break ;; --) shift; cmd_args=("$@"); break ;; *) command="$1"; shift; cmd_args=("$@"); break ;; esac; done
    [[ -z "$command" ]] && command="list"

    # --- Core Command Handling ---
    case "$command" in
        help) if [[ ${#cmd_args[@]} -gt 0 && "${cmd_args[0]}" != --* && "${cmd_args[0]}" != -* ]]; then local target_cmd="${cmd_args[0]}"; command="$target_cmd"; cmd_args=("help" "${cmd_args[@]:1}"); else RcShowFrameworkHelp; return 0; fi ;;
        list) RcListCommands; if [[ ${#cmd_args[@]} -gt 0 ]]; then WarningMessage "'rc list' does not accept additional arguments. Ignoring: ${cmd_args[*]}"; fi; return 0 ;;
        --conflicts) RcShowConflicts; if [[ ${#cmd_args[@]} -gt 0 ]]; then WarningMessage "'rc --conflicts' does not accept additional arguments. Ignoring: ${cmd_args[*]}"; fi; return 0 ;;
        summary) echo "rc - rcForge command execution framework."; return 0 ;;
        search) ErrorMessage "Search functionality not yet implemented."; return 1 ;;
        *) # Dispatch logic unchanged
             local target_script=""; local user_dir="${RCFORGE_USER_UTILS:-/invalid_path}"; local sys_dir="${RCFORGE_UTILS:-/invalid_path}"; local -a search_dirs=(); local -a found_scripts=(); local dir=""; local file=""
             if [[ "$force_system" == "true" ]]; then search_dirs=("$sys_dir"); else search_dirs=("$user_dir" "$sys_dir"); fi
             for dir in "${search_dirs[@]}"; do if [[ -d "$dir" ]]; then while IFS= read -r -d '' file; do if [[ -x "$file" ]]; then found_scripts+=("$file"); fi; done < <(find "$dir" -maxdepth 1 \( -name "${command}" -o -name "${command}.*" \) -type f -print0 2>/dev/null); fi; if [[ ${#found_scripts[@]} -gt 0 && "$force_system" == "false" && "$dir" == "$user_dir" ]]; then break; fi; done
             if [[ ${#found_scripts[@]} -eq 0 ]]; then ErrorMessage "rc command not found: '$command'"; return 127; elif [[ ${#found_scripts[@]} -eq 1 ]]; then target_script="${found_scripts[0]}"; bash "$target_script" "${cmd_args[@]}"; return $?; else ErrorMessage "Ambiguous command '$command'. Found multiple executables:"; printf '  - %s\n' "${found_scripts[@]}" >&2; InfoMessage "Please rename or remove conflicting files, or use '--system' flag if applicable."; return 1; fi ;;
    esac
}

# Execute main function, passing all script arguments "$@"
main "$@"
exit $? # Exit with the return code from main

# EOF