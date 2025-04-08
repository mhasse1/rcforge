#!/usr/bin/env bash
# seqcheck.sh - Detect and resolve sequence number conflicts in rcForge configurations
# Author: rcForge Team
# Date: 2025-04-06
# Version: 0.4.0
# Category: system/utility
# RC Summary: Checks for sequence number conflicts in rcForge configuration scripts
# Description: Identifies and offers to resolve sequence number conflicts in shell configuration scripts

# Source necessary libraries
source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/shell-colors.sh"
source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/utility-functions.sh"

# Set strict error handling
set -o nounset  # Treat unset variables as errors
 # set -o errexit  # Exit immediately if a command exits with a non-zero status

# ============================================================================
# GLOBAL CONSTANTS
# ============================================================================
readonly gc_supported_shells=("bash" "zsh")
[ -v gc_version ]  || readonly gc_version="${RCFORGE_VERSION:-ENV_ERROR}"
[ -v gc_app_name ] || readonly gc_app_name="${RCFORGE_APP_NAME:-ENV_ERROR}"

# ============================================================================
# UTILITY FUNCTIONS (PascalCase)
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
# Description: Display detailed help information for the seqcheck command.
# Usage: ShowHelp
# Returns: None. Prints help text to stdout.
# ============================================================================
ShowHelp() {
    echo "seqcheck - rcForge Sequence Conflict Detection Utility (v${gc_version})"
    echo ""
    echo "Description:"
    echo "  Identifies and offers to resolve sequence number conflicts in"
    echo "  shell configuration scripts based on hostname and shell."
    echo ""
    echo "Usage:"
    echo "  rc seqcheck [options]"
    echo "  $0 [options]" # Direct usage
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
    echo ""
    echo "Examples:"
    echo "  rc seqcheck                    # Check current hostname and shell"
    echo "  rc seqcheck --hostname=laptop  # Check conflicts for 'laptop'"
    echo "  rc seqcheck --shell=bash       # Check Bash configuration conflicts"
    echo "  rc seqcheck --all              # Check all possible execution paths"
    echo "  rc seqcheck --fix              # Interactively fix conflicts for current context"
    echo "  rc seqcheck --all --dry-run    # Show potential conflicts everywhere"

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
# Function: ValidateShell
# Description: Validate if the provided shell name is supported ('bash' or 'zsh').
# Usage: ValidateShell shell_name
# Returns: 0 if valid, 1 if invalid.
# ============================================================================
ValidateShell() {
    local shell="$1"
    local supported_shell=""
    for supported_shell in "${gc_supported_shells[@]}"; do
        if [[ "$shell" == "$supported_shell" ]]; then
            return 0
        fi
    done
    ErrorMessage "Invalid shell specified: '$shell'. Supported are: ${gc_supported_shells[*]}"
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
# Function: GetSequenceNumber
# Description: Extract the 3-digit sequence number prefix from a filename.
# Usage: GetSequenceNumber filename
# Returns: Echoes the sequence number (e.g., "050").
# ============================================================================
GetSequenceNumber() {
    local filename="$1"
    echo "${filename%%_*}"
}

# ============================================================================
# Function: FindConfigFiles
# Description: Find rcForge configuration files matching shell and hostname criteria.
# Usage: FindConfigFiles rcforge_dir shell hostname
# Returns: Echoes newline-separated list of sorted, found config file paths. Returns 1 if none found.
# ============================================================================
FindConfigFiles() {
    local rcforge_dir="$1"
    local shell="$2"
    local hostname="$3"
    local scripts_dir="${rcforge_dir}/rc-scripts"
    local -a patterns
    local -a config_files
    local find_pattern="" # Temp build variables
    local first=true
    local pattern=""

    patterns=(
        "[0-9][0-9][0-9]_global_common_*.sh"
        "[0-9][0-9][0-9]_global_${shell}_*.sh"
        "[0-9][0-9][0-9]_${hostname}_common_*.sh"
        "[0-9][0-9][0-9]_${hostname}_${shell}_*.sh"
    )

    if [[ ! -d "$scripts_dir" ]]; then
        ErrorMessage "rc-scripts directory not found: $scripts_dir"
        return 1
    fi

    # Build find pattern dynamically
    for pattern in "${patterns[@]}"; do
         if [[ "$first" == true ]]; then
             find_pattern="-name '$pattern'"
             first=false
         else
             find_pattern+=" -o -name '$pattern'"
         fi
    done

    mapfile -t config_files < <(find "$scripts_dir" -maxdepth 1 -type f \( $find_pattern \) -print0 | sort -z -n | xargs -0 -r printf '%s\n')

    # Output files, one per line
    printf '%s\n' "${config_files[@]}"

    if [[ ${#config_files[@]} -eq 0 ]]; then
        return 1 # Indicate no files found
    fi
    return 0
}

# ============================================================================
# Function: SuggestNewSeqNum
# Description: Suggest the next available 3-digit sequence number.
# Usage: SuggestNewSeqNum current_seq_str all_used_seqs_str
# Returns: Echoes suggested 3-digit sequence number or "ERR".
# ============================================================================
SuggestNewSeqNum() {
    local current_seq_str="$1"
    local all_used_seqs_str="$2"
    local current_seq_num=$((10#$current_seq_str))
    local suggestion=""
    local i=0
    local formatted_seq=""
    local range_start=$(( (current_seq_num / 100) * 100 ))
    local range_end=$(( range_start + 99 ))

    for (( i = current_seq_num + 1; i <= range_end; i++ )); do
        printf -v formatted_seq "%03d" "$i"
        if [[ ! ",${all_used_seqs_str}," =~ ",${formatted_seq}," ]]; then
            suggestion="$formatted_seq"; break; fi
    done

    if [[ -z "$suggestion" ]]; then
        for (( i = range_start; i < current_seq_num; i++ )); do
             printf -v formatted_seq "%03d" "$i"
             if [[ ! ",${all_used_seqs_str}," =~ ",${formatted_seq}," ]]; then
                 suggestion="$formatted_seq"; break; fi
        done
    fi

    if [[ -z "$suggestion" ]]; then
         local next_range_start=$(( range_start + 100 ))
         if [[ $next_range_start -ge 1000 ]]; then next_range_start=0; fi
         local next_range_end=$(( next_range_start + 99 ))
         for (( i = next_range_start; i <= next_range_end; i++ )); do
              printf -v formatted_seq "%03d" "$i"
              if [[ ! ",${all_used_seqs_str}," =~ ",${formatted_seq}," ]]; then
                  suggestion="$formatted_seq"; break; fi
         done
    fi

    if [[ -z "$suggestion" ]]; then
         ErrorMessage "Could not find an available sequence number (000-999)."
         echo "ERR"
    else
         echo "$suggestion"
    fi
}

# ============================================================================
# Function: FixSeqConflicts
# Description: Interactively guides user to fix sequence number conflicts by renaming files.
# Usage: FixSeqConflicts rcforge_dir shell hostname sequence_map is_interactive is_dry_run
# Arguments: Assumes sequence_map is passed by name (requires Bash 4.3+).
# Returns: 0 if all prompted conflicts addressed/dry-run, 1 otherwise.
# Requires: Bash 4.3+ for nameref (`local -n`).
# ============================================================================
FixSeqConflicts() {
    local rcforge_dir="$1"
    local shell="$2"
    local hostname="$3"
    local -n seq_map_ref="$4" # Nameref (Bash 4.3+)
    local is_interactive="$5"
    local is_dry_run="$6"
    local scripts_dir="${rcforge_dir}/rc-scripts"
    local all_fixed_or_skipped=true
    local seq_num=""
    local files_string=""
    local all_used_seqs_str=""
    local -a conflict_files
    local i=0
    local file_to_rename=""
    local suggested_seq=""
    local new_seq_input=""
    local new_seq_num_str=""
    local current_path=""
    local new_filename=""
    local new_path=""

    if [[ "$is_interactive" == "false" ]]; then
        WarningMessage "Non-interactive conflict fixing (--fix --non-interactive) is not supported."
        WarningMessage "Conflicts remain for ${hostname}/${shell}."
        return 1
    fi

    SectionHeader "Interactive Conflict Resolution for ${hostname}/${shell}" # Call PascalCase

    all_used_seqs_str=$(IFS=,; echo "${!seq_map_ref[*]}")

    for seq_num in "${!seq_map_ref[@]}"; do
        files_string="${seq_map_ref[$seq_num]}"
        if [[ "$files_string" != *,* ]]; then continue; fi

        echo -e "\n${CYAN}Resolving conflict for sequence $seq_num:${RESET}"
        IFS=',' read -r -a conflict_files <<< "$files_string"

        InfoMessage "Keeping '${conflict_files[0]}' at sequence $seq_num."

        for ((i = 1; i < ${#conflict_files[@]}; i++)); do
            file_to_rename="${conflict_files[$i]}"
            # Call PascalCase function
            suggested_seq=$(SuggestNewSeqNum "$seq_num" "$all_used_seqs_str")

            if [[ "$suggested_seq" == "ERR" ]]; then
                 ErrorMessage "Cannot suggest a number for '$file_to_rename'. Skipping."
                 all_fixed_or_skipped=false
                 continue
            fi

            echo -e "\nFile to renumber: ${CYAN}$file_to_rename${RESET}"
            echo -e "  Current sequence: ${RED}$seq_num${RESET}"
            echo -e "  Suggested sequence: ${GREEN}$suggested_seq${RESET}"

            if [[ "$is_dry_run" == "true" ]]; then
                InfoMessage "[DRY RUN] Would suggest renaming '$file_to_rename' to sequence $suggested_seq."
                all_used_seqs_str+=",${suggested_seq}"
                continue
            fi

            read -p "Enter new sequence (3 digits), 's' to skip, or Enter for suggestion [$suggested_seq]: " new_seq_input
            new_seq_input="${new_seq_input:-$suggested_seq}"

            if [[ "$new_seq_input" == "s" || "$new_seq_input" == "S" ]]; then
                 WarningMessage "Skipping rename for '$file_to_rename'."
                 all_fixed_or_skipped=false
                 continue
            fi

            if ! [[ "$new_seq_input" =~ ^[0-9]{3}$ ]]; then
                WarningMessage "Invalid input '$new_seq_input'. Must be 3 digits. Using suggestion '$suggested_seq'."
                new_seq_num_str="$suggested_seq"
            elif [[ ",${all_used_seqs_str}," =~ ",${new_seq_input}," ]]; then
                 WarningMessage "Sequence '$new_seq_input' is already in use. Using suggestion '$suggested_seq'."
                 new_seq_num_str="$suggested_seq"
            else
                 new_seq_num_str="$new_seq_input"
            fi

            new_filename="${new_seq_num_str}_${file_to_rename#*_}"
            current_path="${scripts_dir}/${file_to_rename}"
            new_path="${scripts_dir}/${new_filename}"

            InfoMessage "Attempting rename: '$file_to_rename' -> '$new_filename'"
            if mv -v "$current_path" "$new_path"; then
                 SuccessMessage "File renamed successfully."
                 all_used_seqs_str+=",${new_seq_num_str}"
            else
                 ErrorMessage "Failed to rename file '$file_to_rename'."
                 all_fixed_or_skipped=false
            fi
        done
    done

    echo ""
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
# Usage: CheckSeqConflicts rcforge_dir shell hostname fix_conflicts is_interactive is_dry_run
# Returns: 0 if no conflicts, 1 if conflicts found (or fix attempt failed).
# ============================================================================
CheckSeqConflicts() {
    local rcforge_dir="$1"
    local shell="$2"
    local hostname="$3"
    local fix_conflicts="$4"
    local is_interactive="$5"
    local is_dry_run="$6"
    local -a config_files
    local has_conflicts=false
    local file=""
    local filename=""
    local seq_num=""
    local files_string=""

    declare -A sequence_map

    InfoMessage "Checking sequence conflicts for ${hostname}/${shell}..."

    # Call PascalCase function
    mapfile -t config_files < <(FindConfigFiles "$rcforge_dir" "$shell" "$hostname") || {
         InfoMessage "No configuration files found for ${hostname}/${shell}. Skipping check."
         return 0
    }


    for file in "${config_files[@]}"; do
        [[ -z "$file" ]] && continue

        filename=$(basename "$file")
        seq_num=$(GetSequenceNumber "$filename") # Call PascalCase

        # --- Add Check ---
        if ! [[ "$seq_num" =~ ^[0-9]{3}$ ]]; then
             WarningMessage "Skipping file with invalid sequence format: $filename (seq='$seq_num')"
             continue # Skip this file
        fi
        # --- End Add Check ---

        if [[ -n "${sequence_map[$seq_num]:-}" ]]; then
            sequence_map["$seq_num"]="${sequence_map[$seq_num]},$filename"
            has_conflicts=true
        else
            sequence_map["$seq_num"]="$filename"
        fi
    done

    if [[ "$has_conflicts" == "false" ]]; then
        SuccessMessage "No sequence conflicts found for ${hostname}/${shell}."
        return 0
    else
        TextBlock "Sequence Conflicts Detected for ${hostname}/${shell}" "$RED" "${BG_WHITE:-}" # Call PascalCase
        echo ""

        for seq_num in "${!sequence_map[@]}"; do
            files_string="${sequence_map[$seq_num]}"
            if [[ "$files_string" == *,* ]]; then
                echo -e "${RED}Conflict at sequence ${BOLD}${seq_num}${RESET}${RED}:${RESET}"
                echo "$files_string" | tr ',' '\n' | sed 's/^/  /'
                echo ""
            fi
        done

        if [[ "$fix_conflicts" == "true" ]]; then
            # Call PascalCase function
            if FixSeqConflicts "$rcforge_dir" "$shell" "$hostname" sequence_map "$is_interactive" "$is_dry_run"; then
                 return 0
            else
                 return 1
            fi
        else
            WarningMessage "Run with --fix to attempt interactive resolution."
            return 1
        fi
    fi
}

# ============================================================================
# Function: CheckAllSeqConflicts
# Description: Check sequence conflicts across all detected hostnames and supported shells.
# Usage: CheckAllSeqConflicts rcforge_dir fix_conflicts is_interactive is_dry_run
# Returns: 0 if no conflicts found anywhere, 1 otherwise.
# ============================================================================
CheckAllSeqConflicts() {
    local rcforge_dir="$1"
    local fix_conflicts="$2"
    local is_interactive="$3"
    local is_dry_run="$4"
    local any_conflicts_found=false
    local -a hostnames=("global")
    local scripts_dir="${rcforge_dir}/rc-scripts"
    local file=""
    local filename=""
    local hostname_part=""
    local shell="" # Loop variable
    local hostname="" # Loop variable

    InfoMessage "Detecting hostnames from scripts in ${scripts_dir}..."

    if [[ -d "$scripts_dir" ]]; then
        while IFS= read -r -d '' file; do
            filename=$(basename "$file")
            hostname_part=$(echo "$filename" | cut -d '_' -f 2)
            if [[ "$hostname_part" != "global" && ! " ${hostnames[*]} " =~ " ${hostname_part} " ]]; then
                hostnames+=("$hostname_part")
            fi
        done < <(find "$scripts_dir" -maxdepth 1 -type f -name "[0-9][0-9][0-9]_*_*_*.sh" -print0 2>/dev/null || true)
    else
        WarningMessage "rc-scripts directory not found: $scripts_dir. Cannot detect hostnames."
    fi

    # Always add current hostname to the list to check
    local current_hostname
    current_hostname=$(DetectCurrentHostname) # Call PascalCase
    if [[ ! " ${hostnames[*]} " =~ " ${current_hostname} " ]]; then
         hostnames+=("$current_hostname")
    fi

    InfoMessage "Checking combinations for shells: ${gc_supported_shells[*]}"
    InfoMessage "Checking combinations for hostnames: ${hostnames[*]}"
    echo ""

    for shell in "${gc_supported_shells[@]}"; do
        for hostname in "${hostnames[@]}"; do
            # Call PascalCase function
            if ! CheckSeqConflicts "$rcforge_dir" "$shell" "$hostname" "$fix_conflicts" "$is_interactive" "$is_dry_run"; then
                any_conflicts_found=true
            fi
            echo ""
        done
    done

    if [[ "$any_conflicts_found" == "true" ]]; then
        WarningMessage "Sequence conflicts were detected in one or more execution paths."
        return 1
    else
        SuccessMessage "No sequence conflicts found in any detected execution paths."
        return 0
    fi
}

# ============================================================================
# Function: ParseArguments
# Description: Parse command-line arguments for the seqcheck script.
# Usage: declare -A options; ParseArguments options "$@"
# Returns: Populates associative array. Returns 0 on success, 1 on error or if help/summary shown.
# ============================================================================
ParseArguments() {
    local -n options_ref="$1" # Use nameref [cite: 869]
    shift

    # Call PascalCase functions for defaults
    options_ref["target_hostname"]="$(DetectCurrentHostname)" # [cite: 870]
    options_ref["target_shell"]="$(DetectCurrentShell)" # [cite: 870]
    options_ref["check_all"]=false # [cite: 870]
    options_ref["fix_conflicts"]=false # [cite: 870]
    options_ref["is_interactive"]=true # [cite: 870]
    options_ref["is_dry_run"]=false # [cite: 870]
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

    while [[ "$#" -gt 0 ]]; do # [cite: 872]
        case "$1" in
            --help|-h) ShowHelp; return 1 ;; # [cite: 873]
            --summary) ShowSummary; return 0 ;; # [cite: 874]
            --hostname=*) options_ref["target_hostname"]="${1#*=}"; shift ;; # [cite: 874]
            --shell=*)
                options_ref["target_shell"]="${1#*=}"
                if ! ValidateShell "${options_ref["target_shell"]}"; then return 1; fi # Call PascalCase [cite: 876]
                shift ;;
            --all) options_ref["check_all"]=true; shift ;; # [cite: 877]
            --fix) options_ref["fix_conflicts"]=true; shift ;; # [cite: 877]
            --non-interactive) options_ref["is_interactive"]=false; shift ;; # [cite: 877]
            --dry-run) options_ref["is_dry_run"]=true; shift ;; # [cite: 877]
            *)
                # Assume any other arg is an error for seqcheck
                ErrorMessage "Unknown parameter or unexpected argument: $1" # [cite: 878]
                ShowHelp
                return 1 # [cite: 879]
                # If seqcheck ever takes positional args, capture them here:
                # options_ref["args"]+=("$1"); shift ;;
                ;;
        esac
    done

    # --- Post-parsing validation and info messages ---
    # Final validation of potentially defaulted shell
    if ! ValidateShell "${options_ref["target_shell"]}"; then return 1; fi # Call PascalCase [cite: 881]

    # Handle interaction between --fix and --non-interactive
    if [[ "${options_ref["fix_conflicts"]}" == "true" && "${options_ref["is_interactive"]}" == "false" ]]; then # [cite: 881]
        WarningMessage "--fix requires interactive mode. Conflicts will be reported but not fixed." # [cite: 882]
        # Automatically disable fix if non-interactive to avoid issues later
        options_ref["fix_conflicts"]=false # [cite: 883]
    fi

    if [[ "${options_ref["is_dry_run"]}" == "true" && "${options_ref["fix_conflicts"]}" == "true" ]]; then # [cite: 883]
         InfoMessage "Running with --dry-run. --fix is enabled but no changes will be made." # [cite: 884]
    elif [[ "${options_ref["is_dry_run"]}" == "true" ]]; then # [cite: 884]
         InfoMessage "Running with --dry-run. No changes will be made." # [cite: 885]
    fi

    return 0 # Success [cite: 885]
}

# ============================================================================
# Function: main
# Description: Main execution logic for the seqcheck script.
# Usage: main "$@"
# Returns: 0 on success/no conflicts, 1 on failure/conflicts found.
# ============================================================================
main() {
    local rcforge_dir
    rcforge_dir=$(DetermineRcforgeDir) # Call PascalCase [cite: 887]
    declare -A options
    local overall_status=0

    # Call ParseArguments function. Exit if parsing failed or help/summary displayed.
    ParseArguments options "$@" || exit $? # [cite: 888]

    SectionHeader "rcForge Sequence Conflict Check (v${gc_version})" # Call PascalCase [cite: 889]

    # Determine whether to check all or specific context based on options array
    if [[ "${options[check_all]}" == "true" ]]; then # [cite: 890]
        # Call CheckAllSeqConflicts function
        CheckAllSeqConflicts \
            "$rcforge_dir" \
            "${options[fix_conflicts]}" \
            "${options[is_interactive]}" \
            "${options[is_dry_run]}" # [cite: 890]
        overall_status=$?
    else
        # Call CheckSeqConflicts function
        CheckSeqConflicts \
            "$rcforge_dir" \
            "${options[target_shell]}" \
            "${options[target_hostname]}" \
            "${options[fix_conflicts]}" \
            "${options[is_interactive]}" \
            "${options[is_dry_run]}" # [cite: 891]
        overall_status=$? # [cite: 892]
    fi

    return $overall_status # [cite: 892]
}

# Execute main function if run directly or via rc command
if [[ "${BASH_SOURCE[0]}" == "${0}" ]] || [[ "${BASH_SOURCE[0]}" != "${0}" && "$0" == *"rc"* ]]; then
    main "$@"
    exit $?
fi

# EOF