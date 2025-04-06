#!/usr/bin/env bash
# seqcheck.sh - Detect and resolve sequence number conflicts in rcForge configurations
# Author: rcForge Team
# Date: 2025-04-06
# Version: 0.3.0
# RC Summary: Checks for sequence number conflicts in rcForge configuration scripts
# Description: Identifies and offers to resolve sequence number conflicts in shell configuration scripts

# Source necessary libraries
if [[ -f "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/shell-colors.sh" ]]; then
  source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/shell-colors.sh"
else
  # Minimal color definitions if shell-colors.sh is not available
  export RED='\033[0;31m'
  export GREEN='\033[0;32m'
  export YELLOW='\033[0;33m'
  export BLUE='\033[0;34m'
  export CYAN='\033[0;36m'
  export RESET='\033[0m'
  
  # Minimal message functions
  ErrorMessage() { echo -e "${RED}ERROR:${RESET} $1" >&2; }
  WarningMessage() { echo -e "${YELLOW}WARNING:${RESET} $1" >&2; }
  InfoMessage() { echo -e "${BLUE}INFO:${RESET} $1"; }
  SuccessMessage() { echo -e "${GREEN}SUCCESS:${RESET} $1"; }
fi

if [[ -f "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/utility-functions.sh" ]]; then
  source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/utility-functions.sh"
fi

# Set strict error handling
set -o nounset  # Treat unset variables as errors
set -o errexit  # Exit immediately if a command exits with a non-zero status

# ============================================================================
# CONFIGURATION VARIABLES
# ============================================================================

# List of supported shells
readonly gc_supported_shells=("bash" "zsh")

# Configuration variables
TARGET_HOSTNAME=""
TARGET_SHELL=""
CHECK_ALL=false
FIX_CONFLICTS=false
INTERACTIVE=true
DRY_RUN=false

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Function: ShowSummary
# Description: Display one-line summary for rc help
# Usage: ShowSummary
ShowSummary() {
  echo "Checks for sequence number conflicts in rcForge configuration scripts"
}

# Function: ShowHelp
# Description: Display help information
# Usage: ShowHelp
ShowHelp() {
  echo "seqcheck - rcForge Sequence Conflict Detection Utility"
  echo ""
  echo "Description:"
  echo "  Identifies and offers to resolve sequence number conflicts in"
  echo "  shell configuration scripts based on hostname and shell."
  echo ""
  echo "Usage:"
  echo "  rc seqcheck [options]"
  echo ""
  echo "Options:"
  echo "  --hostname=NAME      Check conflicts for specific hostname"
  echo "  --shell=bash|zsh     Check conflicts for specific shell"
  echo "  --all                Check all possible execution paths"
  echo "  --fix                Interactively fix conflicts"
  echo "  --non-interactive    Run without user interaction"
  echo "  --dry-run            Show what would be done without making changes"
  echo "  --help, -h           Show this help message"
  echo "  --summary            Show a one-line description (for rc help)"
  echo ""
  echo "Examples:"
  echo "  rc seqcheck                           # Check current hostname and shell"
  echo "  rc seqcheck --hostname=laptop         # Check conflicts for 'laptop'"
  echo "  rc seqcheck --shell=bash              # Check Bash configuration conflicts"
  echo "  rc seqcheck --all                     # Check all possible execution paths"
  echo "  rc seqcheck --fix                     # Interactively fix conflicts"
}

# Function: DetectProjectRoot
# Description: Dynamically detect the rcForge base directory
# Usage: DetectProjectRoot
# Returns: Path to the project root directory
DetectProjectRoot() {
  echo "${RCFORGE_ROOT:-$HOME/.config/rcforge}"
}

# Function: ValidateShell
# Description: Validate the provided shell
# Usage: ValidateShell shell_name
# Returns: 0 if valid, 1 if invalid
ValidateShell() {
  local shell="$1"
  for supported_shell in "${gc_supported_shells[@]}"; do
    if [[ "$shell" == "$supported_shell" ]]; then
      return 0
    fi
  done
  return 1
}

# Function: DetectCurrentShell
# Description: Determine the current shell
# Usage: DetectCurrentShell
# Returns: Name of the current shell
DetectCurrentShell() {
  if [[ -n "${ZSH_VERSION:-}" ]]; then
    echo "zsh"
  elif [[ -n "${BASH_VERSION:-}" ]]; then
    echo "bash"
  else
    # Fallback to $SHELL
    basename "$SHELL"
  fi
}

# Function: DetectCurrentHostname
# Description: Get the current hostname
# Usage: DetectCurrentHostname
# Returns: Current hostname
DetectCurrentHostname() {
  if command -v hostname >/dev/null 2>&1; then
    hostname | cut -d. -f1
  else
    # Fallback if hostname command not available
    echo "${HOSTNAME:-$(uname -n | cut -d. -f1)}"
  fi
}

# Function: GetSequenceNumber
# Description: Extract sequence number from a filename
# Usage: GetSequenceNumber filename
# Returns: Sequence number as string
GetSequenceNumber() {
  local filename="$1"
  echo "${filename%%_*}"
}

# Function: FindConfigFiles
# Description: Find configuration files for a given shell and hostname
# Usage: FindConfigFiles shell hostname
# Returns: List of files
FindConfigFiles() {
  local shell="$1"
  local hostname="$2"
  local scripts_dir="${RCFORGE_DIR}/rc-scripts"

  # Build file matching patterns
  local patterns=(
    "[0-9]*_global_common_*.sh"
    "[0-9]*_global_${shell}_*.sh"
    "[0-9]*_${hostname}_common_*.sh"
    "[0-9]*_${hostname}_${shell}_*.sh"
  )

  # Find and sort matching files
  local config_files=()
  for pattern in "${patterns[@]}"; do
    while IFS= read -r -d '' file; do
      [[ -f "$file" ]] && config_files+=("$file")
    done < <(find "$scripts_dir" -maxdepth 1 -type f -name "$pattern" -print0 2>/dev/null)
  done

  # Sort files by sequence number
  IFS=$'\n' config_files=($(sort <<< "${config_files[*]}"))
  unset IFS

  # Output files
  printf '%s\n' "${config_files[@]}"
}

# Function: CheckSeqConflicts
# Description: Check for sequence number conflicts
# Usage: CheckSeqConflicts shell hostname
# Returns: 0 if no conflicts, 1 if conflicts found
CheckSeqConflicts() {
  local shell="$1"
  local hostname="$2"
  local scripts_dir="${RCFORGE_DIR}/rc-scripts"
  local has_conflicts=false
  local seq_counts=()
  local conflict_groups=()
  
  # Get config files
  local config_files
  mapfile -t config_files < <(FindConfigFiles "$shell" "$hostname")
  
  # Check for sequence conflicts
  InfoMessage "Checking sequence conflicts for ${hostname}/${shell}"
  
  # Create an associative array to track sequence numbers
  declare -A sequence_map
  
  for file in "${config_files[@]}"; do
    local filename=$(basename "$file")
    local seq_num=$(GetSequenceNumber "$filename")
    
    if [[ -n "${sequence_map[$seq_num]:-}" ]]; then
      # Conflict found
      sequence_map["$seq_num"]="${sequence_map["$seq_num"]},$filename"
      has_conflicts=true
    else
      # First occurrence of this sequence
      sequence_map["$seq_num"]="$filename"
    fi
  done
  
  # Output results
  if [[ "$has_conflicts" == "false" ]]; then
    SuccessMessage "No sequence conflicts found for ${hostname}/${shell}"
    return 0
  else
    # Display conflicts
    TextBlock "Sequence Conflicts Detected" "$RED" "$BG_WHITE"
    echo ""
    
    # Print each conflict group
    for seq_num in "${!sequence_map[@]}"; do
      local files="${sequence_map[$seq_num]}"
      if [[ "$files" == *,* ]]; then
        echo -e "${RED}Conflict at sequence ${BOLD}$seq_num${RESET}${RED}:${RESET}"
        echo "$files" | tr ',' '\n' | sed 's/^/  /'
        echo ""
      fi
    done
    
    # Offer to fix if requested
    if [[ "$FIX_CONFLICTS" == "true" ]]; then
      FixSeqConflicts "$shell" "$hostname" sequence_map
    else
      echo "To fix conflicts, run: rc seqcheck --fix --hostname=$hostname --shell=$shell"
    fi
    
    return 1
  fi
}

# Function: CheckAllSeqConflicts
# Description: Check all possible execution paths for conflicts
# Usage: CheckAllSeqConflicts
# Returns: 0 if no conflicts, 1 if any conflicts found
CheckAllSeqConflicts() {
  local any_conflicts=false
  local hostnames=()
  local shells=("bash" "zsh")
  
  # Get list of hostnames from scripts
  while IFS= read -r -d '' file; do
    local filename=$(basename "$file")
    local hostname=$(echo "$filename" | cut -d '_' -f 2)
    if [[ "$hostname" != "global" && ! " ${hostnames[*]} " =~ " ${hostname} " ]]; then
      hostnames+=("$hostname")
    fi
  done < <(find "${RCFORGE_DIR}/rc-scripts" -maxdepth 1 -type f -name "[0-9]*_*_*_*.sh" -print0 2>/dev/null)
  
  # Always add the current hostname and "global"
  hostnames+=("global" "$(DetectCurrentHostname)")
  # Remove duplicates
  hostnames=($(echo "${hostnames[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
  
  # Check each shell/hostname combination
  for shell in "${shells[@]}"; do
    for hostname in "${hostnames[@]}"; do
      if ! CheckSeqConflicts "$shell" "$hostname"; then
        any_conflicts=true
      fi
      echo ""
    done
  done
  
  if [[ "$any_conflicts" == "true" ]]; then
    return 1
  else
    SuccessMessage "No sequence conflicts found in any execution paths"
    return 0
  fi
}

# Function: SuggestNewSeqNum
# Description: Suggest a new, unused sequence number in the same range
# Usage: SuggestNewSeqNum current_seq used_seqs
# Returns: New sequence number
SuggestNewSeqNum() {
  local current_seq="$1"
  local used_seqs="$2"
  
  # Determine range (first digit indicates range)
  local range="${current_seq:0:1}"
  local lower=$((range * 100))
  local upper=$((lower + 99))
  
  # Find available numbers in the range
  for ((i=lower; i<=upper; i++)); do
    # Check if this number is used
    if [[ ! "$used_seqs" =~ (^|,)$i(,|$) ]]; then
      echo "$i"
      return 0
    fi
  done
  
  # If no number is available in the preferred range, suggest the next range
  local next_range=$(( (range + 1) % 10 ))
  local next_lower=$((next_range * 100))
  
  echo "$next_lower"
  return 0
}

# Function: FixSeqConflicts
# Description: Interactively fix sequence conflicts
# Usage: FixSeqConflicts shell hostname sequence_map
# Returns: 0 if fixed, 1 if not fixed
FixSeqConflicts() {
  local shell="$1"
  local hostname="$2"
  local -n seq_map="$3"
  
  if [[ "$INTERACTIVE" == "false" ]]; then
    WarningMessage "Automatic conflict resolution not implemented"
    echo "Use --fix without --non-interactive to fix conflicts"
    return 1
  fi
  
  SectionHeader "Conflict Resolution"
  
  # Gather all used sequence numbers
  local all_used_seqs=""
  for seq in "${!seq_map[@]}"; do
    all_used_seqs+="$seq,"
  done
  all_used_seqs="${all_used_seqs%,}"
  
  # Process each conflict
  for seq_num in "${!seq_map[@]}"; do
    local files="${seq_map[$seq_num]}"
    if [[ "$files" != *,* ]]; then
      continue  # Not a conflict
    fi
    
    echo -e "\n${CYAN}Resolving conflict for sequence $seq_num:${RESET}"
    
    # Convert comma-separated list to array
    IFS=',' read -ra conflict_files <<< "$files"
    
    # Keep the first file at the original sequence, prompt for others
    echo "Keeping ${conflict_files[0]} at sequence $seq_num"
    
    for ((i=1; i<${#conflict_files[@]}; i++)); do
      local file="${conflict_files[$i]}"
      local suggested=$(SuggestNewSeqNum "$seq_num" "$all_used_seqs")
      
      echo -e "\nFile: ${CYAN}$file${RESET}"
      echo -e "Current sequence: ${RED}$seq_num${RESET}"
      echo -e "Suggested new sequence: ${GREEN}$suggested${RESET}"
      
      if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY RUN] Would change $file sequence to $suggested"
        continue
      fi
      
      read -p "Enter new sequence number or press Enter to use suggested [$suggested]: " new_seq
      new_seq="${new_seq:-$suggested}"
      
      # Validate input is a number
      if ! [[ "$new_seq" =~ ^[0-9]+$ ]]; then
        WarningMessage "Invalid input. Using suggested sequence $suggested instead."
        new_seq="$suggested"
      fi
      
      # Update the file
      local full_path="${RCFORGE_DIR}/rc-scripts/$file"
      local new_file="${new_seq}_${file#*_}"
      local new_path="${RCFORGE_DIR}/rc-scripts/$new_file"
      
      echo "Renaming to: $new_file"
      mv "$full_path" "$new_path"
      
      # Add the new sequence to used sequences
      all_used_seqs+=",$new_seq"
      
      SuccessMessage "File renamed successfully"
    done
  done
  
  SuccessMessage "All conflicts resolved"
  return 0
}

# ============================================================================
# MAIN FUNCTIONALITY
# ============================================================================

# Parse command-line arguments
# Usage: ParseArguments "$@"
ParseArguments() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --help|-h)
        ShowHelp
        return 0
        ;;
      --summary)
        ShowSummary
        return 0
        ;;
      --hostname=*)
        TARGET_HOSTNAME="${1#*=}"
        ;;
      --shell=*)
        TARGET_SHELL="${1#*=}"
        if ! ValidateShell "$TARGET_SHELL"; then
          ErrorMessage "Invalid shell specified: $TARGET_SHELL"
          echo "Supported shells: ${gc_supported_shells[*]}"
          return 1
        fi
        ;;
      --all)
        CHECK_ALL=true
        ;;
      --fix)
        FIX_CONFLICTS=true
        ;;
      --non-interactive)
        INTERACTIVE=false
        ;;
      --dry-run)
        DRY_RUN=true
        ;;
      *)
        ErrorMessage "Unknown parameter: $1"
        echo "Use --help to see available options."
        return 1
        ;;
    esac
    shift
  done

  # Set defaults if not provided
  : "${TARGET_HOSTNAME:=$(DetectCurrentHostname)}"
  : "${TARGET_SHELL:=$(DetectCurrentShell)}"

  # Validate shell
  if ! ValidateShell "$TARGET_SHELL"; then
    ErrorMessage "Invalid shell: $TARGET_SHELL"
    echo "Supported shells: ${gc_supported_shells[*]}"
    return 1
  fi

  return 0
}

# Main function
main() {
  # Detect project root
  local RCFORGE_DIR
  RCFORGE_DIR=$(DetectProjectRoot)

  # Parse command-line arguments
  if ! ParseArguments "$@"; then
    return 1
  fi

  # Display header
  SectionHeader "rcForge Sequence Conflict Check"

  # Run appropriate check based on options
  if [[ "$CHECK_ALL" == "true" ]]; then
    CheckAllSeqConflicts
  else
    CheckSeqConflicts "$TARGET_SHELL" "$TARGET_HOSTNAME"
  fi
}

# Execute main function if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
  exit $?
elif [[ "${BASH_SOURCE[0]}" != "${0}" && "$0" == *"rc"* ]]; then
  # Also execute if called via the rc command
  main "$@"
  exit $?
fi

# EOF
