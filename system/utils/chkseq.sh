#!/usr/bin/env bash
# chkseq.sh - Detect and resolve sequence number conflicts in rcForge configurations
# Author: rcForge Team
# Date: 2025-04-08 # Updated for full refactor
# Version: 0.4.1
# Category: system/utility
# RC Summary: Checks for sequence number conflicts in rcForge configuration scripts
# Description: Identifies and offers to resolve sequence number conflicts in shell configuration scripts

# Source necessary libraries (utility-functions sources shell-colors)
source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/utility-functions.sh"

# Set strict error handling
set -o nounset
set -o pipefail
# set -o errexit # Let functions handle errors

# ============================================================================
# GLOBAL CONSTANTS
# ============================================================================
readonly GC_SUPPORTED_SHELLS=("bash" "zsh")
# Use sourced constants, provide fallback just in case
[[ -v gc_version ]] || readonly gc_version="${RCFORGE_VERSION:-0.4.1}"
[[ -v gc_app_name ]] || readonly gc_app_name="${RCFORGE_APP_NAME:-rcForge}"

# ============================================================================
# LOCAL HELPER FUNCTIONS
# ============================================================================

# ============================================================================
# Function: ShowHelp
# Description: Display detailed help information for the chkseq command.
# Usage: ShowHelp
# Exits: 0
# ============================================================================
ShowHelp() {
    local script_name
    script_name=$(basename "$0")

    echo "chkseq - rcForge Sequence Conflict Detection Utility (v${gc_version})"
    echo ""
    echo "Description:"
    echo "  Identifies and offers to resolve sequence number conflicts in"
    echo "  shell configuration scripts based on hostname and shell."
    echo ""
    echo "Usage:"
    echo "  rc chkseq [options]"
    echo "  ${script_name} [options]"
    echo ""
    echo "Options:"
    echo "  --hostname=NAME   Check conflicts for specific hostname (default: current)"
    echo "  --shell=bash|zsh  Check conflicts for specific shell (default: current)"
    echo "  --all             Check all detected hostnames and both shells"
    echo "  --fix             Interactively offer to fix detected conflicts"
    echo "  --non-interactive Run checks without user interaction (no fixing)"
    echo "  --dry-run         Show what fixing would do without making changes"
    echo "  --help, -h        Show this help message"
    echo "  --summary         Show a one-line description (for rc help)"
    echo "  --version         Show version information"
    echo ""
    echo "Examples:"
    echo "  rc chkseq                    # Check current hostname and shell"
    echo "  rc chkseq --hostname=laptop  # Check conflicts for 'laptop'"
    echo "  rc chkseq --shell=bash       # Check Bash configuration conflicts"
    echo "  rc chkseq --all              # Check all possible execution paths"
    echo "  rc chkseq --fix              # Interactively fix conflicts for current context"
    echo "  rc chkseq --all --dry-run    # Show potential conflicts everywhere"
    exit 0
}

# ============================================================================
# Function: ValidateShell (Local validator specific to this script's needs)
# Description: Validate if the provided shell name is supported ('bash' or 'zsh').
# Usage: ValidateShell shell_name
# Returns: 0 if valid, 1 if invalid.
# ============================================================================
ValidateShell() {
    local shell_to_check="${1:-}"
    local supported_shell=""
    for supported_shell in "${GC_SUPPORTED_SHELLS[@]}"; do
        if [[ "$shell_to_check" == "$supported_shell" ]]; then
            return 0
        fi
    done
    ErrorMessage "Invalid shell specified: '$shell_to_check'. Supported are: ${GC_SUPPORTED_SHELLS[*]}"
    return 1
}

# ============================================================================
# Function: GetSequenceNumber
# Description: Extract the 3-digit sequence number prefix from a filename.
# Usage: GetSequenceNumber filename
# Returns: Echoes the sequence number (e.g., "050") or "INVALID".
# ============================================================================
GetSequenceNumber() {
    local filename="${1:-}"
    local seq="${filename%%_*}"
    # Validate it's 3 digits
    if [[ "$seq" =~ ^[0-9]{3}$ ]]; then
        echo "$seq"
    else
        echo "INVALID"
    fi
}

# ============================================================================
# Function: SuggestNewSeqNum
# Description: Suggest the next available 3-digit sequence number.
# Usage: SuggestNewSeqNum current_seq_str all_used_seqs_str
# Returns: Echoes suggested 3-digit sequence number or "ERR". Status 0 on success, 1 on error.
# ============================================================================
SuggestNewSeqNum() {
    local current_seq_str="${1:-}"
    local all_used_seqs_str="${2:-}"
    # Validate input format first
    if ! [[ "$current_seq_str" =~ ^[0-9]{3}$ ]]; then
        ErrorMessage "Internal error: Invalid current sequence '$current_seq_str' passed to SuggestNewSeqNum."
        echo "ERR"
        return 1
    fi
    local current_seq_num=$((10#$current_seq_str)) # Force base 10
    local suggestion=""
    local i=0
    local formatted_seq=""
    local range_start=$(((current_seq_num / 100) * 100))
    local range_end=$((range_start + 99))

    # 1. Search upwards within the current block
    for ((i = current_seq_num + 1; i <= range_end; i++)); do
        printf -v formatted_seq "%03d" "$i"
        if [[ ! ",${all_used_seqs_str}," =~ ",${formatted_seq}," ]]; then
            suggestion="$formatted_seq"
            break
        fi
    done

    # 2. Search downwards within the current block (if no upward match)
    if [[ -z "$suggestion" ]]; then
        for ((i = range_start; i < current_seq_num; i++)); do
            printf -v formatted_seq "%03d" "$i"
            if [[ ! ",${all_used_seqs_str}," =~ ",${formatted_seq}," ]]; then
                suggestion="$formatted_seq"
                break
            fi
        done
    fi

    # 3. Search upwards from the next block (wrapping around from 9xx)
    if [[ -z "$suggestion" ]]; then
        local next_range_start=$((range_end + 1))
        [[ $next_range_start -ge 1000 ]] && next_range_start=0
        for ((offset = 0; offset < 1000; offset++)); do
            i=$(((next_range_start + offset) % 1000))
            printf -v formatted_seq "%03d" "$i"
            if [[ ! ",${all_used_seqs_str}," =~ ",${formatted_seq}," ]]; then
                suggestion="$formatted_seq"
                break
            fi
        done
    fi

    if [[ -z "$suggestion" ]]; then
        ErrorMessage "Could not find an available sequence number (000-999)."
        echo "ERR"
        return 1
    else
        echo "$suggestion"
        return 0
    fi
}

# ============================================================================
# Function: FixSeqConflicts
# Description: Interactively guides user to fix sequence number conflicts.
# Usage: FixSeqConflicts rcforge_dir shell hostname sequence_map is_interactive is_dry_run
# Arguments: Assumes sequence_map is passed by name (requires Bash 4.3+).
# Returns: 0 if all prompted conflicts addressed/dry-run, 1 otherwise.
# ============================================================================
FixSeqConflicts() {
    local rcforge_dir="${1:-}"
    local shell="${2:-}"
    local hostname="${3:-}"
    local -n seq_map_ref="$4" # Nameref (Bash 4.3+)
    local is_interactive="${5:-false}"
    local is_dry_run="${6:-false}"

    local scripts_dir="${rcforge_dir}/rc-scripts"
    local all_fixed_or_skipped=true
    local seq_num=""
    local files_string=""
    local all_used_seqs_str="" # Comma-separated list of all sequence numbers in use
    local -a conflict_files
    local i=0
    local file_to_rename=""
    local suggested_seq=""
    local new_seq_input=""
    local new_seq_num_str=""
    local current_path=""
    local new_filename=""
    local new_path=""
    local suffix=""
    local response="" # User input variable
    local mv_status=0

    # Ensure Bash 4.3+ for namerefs (-n)
    if [[ "${BASH_VERSINFO[0]}" -lt 4 || ("${BASH_VERSINFO[0]}" -eq 4 && "${BASH_VERSINFO[1]}" -lt 3) ]]; then
        ErrorMessage "Internal Error: FixSeqConflicts requires Bash 4.3+ for namerefs."
        return 1
    fi

    if [[ "$is_interactive" == "false" ]]; then
        # This case should technically not be reached if ParseArguments disables fix_mode when non-interactive
        WarningMessage "Non-interactive conflict fixing (--fix --non-interactive) is not supported."
        WarningMessage "Conflicts remain for ${hostname}/${shell}."
        return 1
    fi

    SectionHeader "Interactive Conflict Resolution for ${hostname}/${shell}"

    # Build the string of all currently used sequence numbers in this context
    all_used_seqs_str=$(
        IFS=,
        echo "${!seq_map_ref[*]}"
    )

    # Sort the conflicting sequence numbers numerically for predictable processing
    local sorted_conflicting_seqs
    mapfile -t sorted_conflicting_seqs < <(
        for seq_num in "${!seq_map_ref[@]}"; do
            # Only process if it's actually a conflict (multiple files)
            if [[ "${seq_map_ref[$seq_num]}" == *,* ]]; then
                echo "$seq_num"
            fi
        done | sort -n
    )

    # Iterate through sorted conflicting sequence numbers
    for seq_num in "${sorted_conflicting_seqs[@]}"; do
        files_string="${seq_map_ref[$seq_num]}"

        echo # Blank line for spacing
        InfoMessage "${CYAN}Resolving conflict for sequence ${BOLD}${seq_num}${RESET}${CYAN}:${RESET}"
        IFS=',' read -r -a conflict_files <<<"$files_string"

        # Keep the first file listed in the conflict at the current sequence number
        InfoMessage "  Keeping: '${conflict_files[0]}'"

        # Iterate through the remaining files that need renumbering
        for ((i = 1; i < ${#conflict_files[@]}; i++)); do
            file_to_rename="${conflict_files[$i]}"
            suggested_seq=$(SuggestNewSeqNum "$seq_num" "$all_used_seqs_str")

            if [[ "$suggested_seq" == "ERR" ]]; then
                ErrorMessage "  Cannot suggest a new number for '$file_to_rename'. Skipping."
                all_fixed_or_skipped=false
                continue
            fi

            echo
            InfoMessage "  File to renumber: ${CYAN}${file_to_rename}${RESET}"
            InfoMessage "    Current sequence: ${RED}${seq_num}${RESET}"
            InfoMessage "    Suggested sequence: ${GREEN}${suggested_seq}${RESET}"

            if [[ "$is_dry_run" == "true" ]]; then
                InfoMessage "    [DRY RUN] Would rename to sequence ${suggested_seq}."
                all_used_seqs_str+=",${suggested_seq}" # Add for subsequent suggestions
                continue
            fi

            # Prompt user for input
            response="" # Clear response
            printf "%s" "    Enter new sequence (3 digits), 's' to skip, or Enter for suggestion [${suggested_seq}]: "
            read -r response
            response="${response:-$suggested_seq}" # Default to suggestion

            if [[ "$response" =~ ^[Ss]$ ]]; then
                WarningMessage "    Skipping rename for '$file_to_rename'."
                all_fixed_or_skipped=false
                continue
            fi

            # Validate user input or use suggestion
            if ! [[ "$response" =~ ^[0-9]{3}$ ]]; then
                WarningMessage "    Invalid input '$response'. Must be 3 digits. Using suggestion '$suggested_seq'."
                new_seq_num_str="$suggested_seq"
            elif [[ ",${all_used_seqs_str}," =~ ",${response}," ]]; then
                WarningMessage "    Sequence '$response' is already in use. Using suggestion '$suggested_seq'."
                new_seq_num_str="$suggested_seq"
            else
                new_seq_num_str="$response"
            fi

            # Construct new filename and paths
            suffix="${file_to_rename#*_}" # Get content after first underscore
            new_filename="${new_seq_num_str}_${suffix}"
            current_path="${scripts_dir}/${file_to_rename}"
            new_path="${scripts_dir}/${new_filename}"

            InfoMessage "    Attempting rename: '${file_to_rename}' -> '${new_filename}'"
            # Use -v for verbose move, check exit status
            if mv -v "$current_path" "$new_path"; then
                SuccessMessage "    File renamed successfully."
                all_used_seqs_str+=",${new_seq_num_str}" # Update used list
            else
                mv_status=$?
                ErrorMessage "    Failed to rename file '$file_to_rename' (mv exit status: $mv_status)."
                all_fixed_or_skipped=false
            fi
        done # End loop for files within a conflict
    done  # End loop for conflicting sequence numbers

    echo "" # Add final newline
    if [[ "$all_fixed_or_skipped" == "true" ]]; then
        if [[ "$is_dry_run" == "true" ]]; then
            SuccessMessage "[DRY RUN] Conflict resolution simulation complete."
        else
            SuccessMessage "Conflict resolution process complete for ${hostname}/${shell}."
        fi
        return 0
    else
        WarningMessage "Some conflicts were skipped or failed to resolve for ${hostname}/${shell}."
        return 1
    fi
}

# ============================================================================
# Function: CheckSeqConflicts
# Description: Check for sequence number conflicts for a specific shell/hostname pair.
# Usage: CheckSeqConflicts rcforge_dir shell hostname is_fix_mode is_interactive is_dry_run
# Returns: 0 if no conflicts, 1 if conflicts found (or fix attempt failed).
# ============================================================================
CheckSeqConflicts() {
    local rcforge_dir="${1:-}"
    local shell="${2:-}"
    local hostname="${3:-}"
    local is_fix_mode="${4:-false}"
    local is_interactive="${5:-true}"
    local is_dry_run="${6:-false}"

    local -a config_files=() # Initialize array
    local has_conflicts=false
    local file=""
    local filename=""
    local seq_num=""
    local files_string=""
    local find_output=""
    local find_status=0

    # Use associative array to store filenames for each sequence number
    declare -A sequence_map

    InfoMessage "Checking sequence conflicts for ${hostname}/${shell}..."

    # Find config files using the *sourced* FindRcScripts function directly
    find_output=$(FindRcScripts "$shell" "$hostname")
    find_status=$?

    if [[ $find_status -ne 0 ]]; then
        # Error message already printed by FindRcScripts
        return 1
    elif [[ -z "$find_output" ]]; then
        InfoMessage "No configuration files found for ${hostname}/${shell}. Skipping check."
        return 0 # Not an error if no files
    fi
    # Load file list into array using mapfile
    mapfile -t config_files <<<"$find_output"

    # Populate the sequence map
    for file in "${config_files[@]}"; do
        # Skip empty lines just in case mapfile had issues
        [[ -z "$file" ]] && continue

        filename=$(basename "$file")
        seq_num=$(GetSequenceNumber "$filename") # Use local helper

        if [[ "$seq_num" == "INVALID" ]]; then
            WarningMessage "Skipping file with invalid sequence format: $filename"
            continue # Skip this file
        fi

        # Check if key exists using -v (safer)
        if [[ -v "sequence_map[$seq_num]" ]]; then
            sequence_map["$seq_num"]+=",${filename}" # Append filename
            has_conflicts=true
        else
            sequence_map["$seq_num"]="$filename" # Add first filename
        fi
    done

    # Report or fix conflicts
    if [[ "$has_conflicts" == "false" ]]; then
        SuccessMessage "No sequence conflicts found for ${hostname}/${shell}."
        return 0
    else
        # Use sourced TextBlock
        TextBlock "Sequence Conflicts Detected for ${hostname}/${shell}" "$RED" "${BG_WHITE:-$BG_RED}" # Provide fallback BG
        echo ""

        # Sort sequence numbers for display
        local sorted_seqs
        mapfile -t sorted_seqs < <(printf "%s\n" "${!sequence_map[@]}" | sort -n)

        for seq_num in "${sorted_seqs[@]}"; do
            files_string="${sequence_map[$seq_num]}"
            # Only display if it's actually a conflict (multiple files)
            if [[ "$files_string" == *,* ]]; then
                # Use sourced colors/bold
                echo -e "${RED}Conflict at sequence ${BOLD}${seq_num}${RESET}${RED}:${RESET}"
                # Indent list using sed for consistency
                echo "$files_string" | tr ',' '\n' | sed 's/^/  /'
                echo ""
            fi
        done

        if [[ "$is_fix_mode" == "true" ]]; then
            # Call local FixSeqConflicts, passing map by name
            if FixSeqConflicts "$rcforge_dir" "$shell" "$hostname" sequence_map "$is_interactive" "$is_dry_run"; then
                return 0 # Fix successful or dry run complete
            else
                return 1 # Fix attempt failed or conflicts skipped
            fi
        else
            WarningMessage "Run with --fix to attempt interactive resolution."
            return 1 # Indicate conflicts were found but not fixed
        fi
    fi
}

# ============================================================================
# Function: CheckAllSeqConflicts
# Description: Check sequence conflicts across all detected hostnames and supported shells.
# Usage: CheckAllSeqConflicts rcforge_dir is_fix_mode is_interactive is_dry_run
# Returns: 0 if no conflicts found anywhere, 1 otherwise.
# ============================================================================
CheckAllSeqConflicts() {
    local rcforge_dir="${1:-}"
    local is_fix_mode="${2:-false}"
    local is_interactive="${3:-true}"
    local is_dry_run="${4:-false}"

    local any_conflicts_found_overall=false # Track status across all checks
    local -a hostnames=("global")           # Always check global context
    local scripts_dir="${rcforge_dir}/rc-scripts"
    local file=""
    local filename=""
    local hostname_part=""
    local shell=""    # Loop variable
    local hostname="" # Loop variable
    local -a detected_hosts

    InfoMessage "Detecting hostnames from scripts in ${scripts_dir}..."

    if [[ -d "$scripts_dir" ]]; then
        # Use find to get unique hostnames directly
        mapfile -t detected_hosts < <(
            find "$scripts_dir" -maxdepth 1 -type f -name "[0-9][0-9][0-9]_*_*_*.sh" -print0 |
                xargs -0 -r -n 1 basename |
                cut -d '_' -f 2 |
                grep -v '^global$' |
                sort -u || true # Prevent exit if grep finds nothing
        )
        # Add detected hosts to the list if any were found
        if [[ ${#detected_hosts[@]} -gt 0 ]]; then
            # Need careful handling if mapfile failed or produced empty lines
            local clean_hosts=()
            local host
            for host in "${detected_hosts[@]}"; do
                [[ -n "$host" ]] && clean_hosts+=("$host")
            done
            # Add unique cleaned hosts
            if [[ ${#clean_hosts[@]} -gt 0 ]]; then
                hostnames+=($(printf "%s\n" "${clean_hosts[@]}" | sort -u))
            fi
        fi
    else
        WarningMessage "rc-scripts directory not found: $scripts_dir. Cannot detect hostnames."
        # Continue checking global and current hostname at least
    fi

    # Always add current hostname to the list to check if not already present
    local current_hostname
    current_hostname=$(DetectCurrentHostname) # Use sourced function
    # Use loop to check existence instead of complex regex
    local found_current=false
    for hostname in "${hostnames[@]}"; do
        if [[ "$hostname" == "$current_hostname" ]]; then
            found_current=true
            break
        fi
    done
    if [[ "$found_current" == "false" ]]; then
        hostnames+=("$current_hostname")
    fi
    # Ensure uniqueness again after adding current hostname
    mapfile -t hostnames < <(printf "%s\n" "${hostnames[@]}" | sort -u)

    InfoMessage "Checking combinations for shells: ${GC_SUPPORTED_SHELLS[*]}"
    InfoMessage "Checking combinations for hostnames: ${hostnames[*]}"
    echo ""

    # Iterate through all combinations
    for shell in "${GC_SUPPORTED_SHELLS[@]}"; do
        for hostname in "${hostnames[@]}"; do
            # Call local CheckSeqConflicts
            if ! CheckSeqConflicts "$rcforge_dir" "$shell" "$hostname" "$is_fix_mode" "$is_interactive" "$is_dry_run"; then
                # CheckSeqConflicts returns 1 if conflicts exist (and weren't fixed/skipped)
                any_conflicts_found_overall=true
            fi
            echo # Add separator line
        done
    done

    # Report final overall status
    SectionHeader "Overall Summary" # Use sourced function
    if [[ "$any_conflicts_found_overall" == "true" ]]; then
        if [[ "$is_fix_mode" == "true" && "$is_dry_run" == "false" ]]; then
            WarningMessage "Sequence conflicts were detected. Some may not have been resolved. Review output above."
        elif [[ "$is_dry_run" == "true" ]]; then
            WarningMessage "[DRY RUN] Sequence conflicts were detected in one or more execution paths."
        else
            WarningMessage "Sequence conflicts were detected in one or more execution paths. Use --fix to resolve."
        fi
        return 1 # Indicate overall failure/conflicts present
    else
        SuccessMessage "No sequence conflicts found in any detected execution paths."
        return 0 # Indicate overall success
    fi
}

# ============================================================================
# Function: ParseArguments (Refactored Standard Loop)
# Description: Parse command-line arguments for chkseq script.
# Usage: declare -A options; ParseArguments options "$@"
# Returns: Populates associative array by reference. Returns 0 on success, 1 on error.
#          Exits directly for --help, --summary, --version.
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
    default_host=$(DetectCurrentHostname)
    options_ref["target_hostname"]="${default_host}"
    local default_shell
    default_shell=$(DetectShell)
    options_ref["target_shell"]="${default_shell}"

    options_ref["check_all"]=false
    options_ref["fix_conflicts"]=false
    options_ref["is_interactive"]=true # Default to interactive unless --non-interactive passed
    options_ref["is_dry_run"]=false

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
                _rcforge_show_version "$0"
                exit 0 # Call helper and exit
                ;;
            --hostname=*)
                options_ref["target_hostname"]="${key#*=}"
                shift
                ;;
            --hostname)
                shift
                if [[ -z "${1:-}" || "$1" == -* ]]; then
                    ErrorMessage "--hostname requires a value."
                    return 1
                fi
                options_ref["target_hostname"]="$1"
                shift
                ;;
            --shell=*)
                options_ref["target_shell"]="${key#*=}"
                if ! ValidateShell "${options_ref["target_shell"]}"; then return 1; fi
                shift
                ;;
            --shell)
                shift
                if [[ -z "${1:-}" || "$1" == -* ]]; then
                    ErrorMessage "--shell requires a value (bash or zsh)."
                    return 1
                fi
                options_ref["target_shell"]="$1"
                if ! ValidateShell "${options_ref["target_shell"]}"; then return 1; fi
                shift
                ;;
            --all)
                options_ref["check_all"]=true
                shift
                ;;
            --fix)
                options_ref["fix_conflicts"]=true
                shift
                ;;
            --non-interactive)
                options_ref["is_interactive"]=false
                shift
                ;;
            --dry-run)
                options_ref["is_dry_run"]=true
                shift
                ;;
            --) # End of options
                shift
                break
                ;;
            -*) # Unknown option
                ErrorMessage "Unknown option: $key"
                ShowHelp
                return 1
                ;;
            *) # Positional argument (none expected)
                ErrorMessage "Unexpected positional argument: $key"
                ShowHelp
                return 1
                ;;
        esac
    done

    # --- Post-parsing validation ---
    if ! ValidateShell "${options_ref["target_shell"]}"; then
        # Error already printed by ValidateShell if default was invalid
        return 1
    fi
    # Handle interaction between --fix and --non-interactive
    if [[ "${options_ref["fix_conflicts"]}" == "true" && "${options_ref["is_interactive"]}" == "false" ]]; then
        WarningMessage "--fix requires interactive mode. Disabling fix mode."
        # Automatically disable fix if non-interactive
        options_ref["fix_conflicts"]=false
    fi
    if [[ "${options_ref["is_dry_run"]}" == "true" ]]; then
        InfoMessage "Running with --dry-run. No changes will be made."
    fi
    return 0 # Success
}

# ============================================================================
# Function: main
# Description: Main execution logic for the chkseq script.
# Usage: main "$@"
# Returns: 0 on success/no conflicts, 1 on failure/conflicts found.
# ============================================================================
main() {
    local rcforge_dir
    rcforge_dir=$(DetectRcForgeDir) # Use sourced function
    # Use associative array for options (requires Bash 4+)
    declare -A options
    local overall_status=0

    # Parse Arguments, exit if ParseArguments returns non-zero (error or help/summary)
    ParseArguments options "$@" || exit $?

    SectionHeader "rcForge Sequence Conflict Check (v${gc_version})"

    # Determine whether to check all or specific context based on options array
    if [[ "${options[check_all]}" == "true" ]]; then
        # Call local CheckAllSeqConflicts function
        CheckAllSeqConflicts \
            "$rcforge_dir" \
            "${options[fix_conflicts]}" \
            "${options[is_interactive]}" \
            "${options[is_dry_run]}"
        overall_status=$?
    else
        # Call local CheckSeqConflicts function
        CheckSeqConflicts \
            "$rcforge_dir" \
            "${options[target_shell]}" \
            "${options[target_hostname]}" \
            "${options[fix_conflicts]}" \
            "${options[is_interactive]}" \
            "${options[is_dry_run]}"
        overall_status=$?
    fi

    # Return the final status code from the checks performed
    return $overall_status
}

# ============================================================================
# Script Execution
# ============================================================================
# Execute main function if run directly or via rc command wrapper
# Use sourced IsExecutedDirectly function
if IsExecutedDirectly || [[ "$0" == *"rc"* ]]; then
    main "$@"
    exit $? # Exit with status from main
fi

# EOF
