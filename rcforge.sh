#!/usr/bin/env bash
# rcforge.sh - Universal Shell Configuration Loader
# Author: Mark Hasse
# Date: 2025-04-05
# Version: 0.3.0
# Description: Main loader script for rcForge shell configuration system

# ============================================================================
# CORE SYSTEM INITIALIZATION
# ============================================================================

# Set strict error handling
set -o nounset  # Treat unset variables as errors
set -o errexit  # Exit immediately if a command exits with a non-zero status

# ============================================================================
# Function: DetectShell
# Description: Determine the currently running shell
# Usage: DetectShell
# Arguments: None
# Returns:
#   Outputs the name of the current shell (bash or zsh)
# ============================================================================
DetectShell() {
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        echo "zsh"
    elif [[ -n "${BASH_VERSION:-}" ]]; then
        echo "bash"
    else
        # Fallback to $SHELL
        basename "$SHELL"
    fi
}

# ============================================================================
# Function: PerformIntegrityChecks
# Description: Verify the integrity of rcForge configuration system
# Usage: PerformIntegrityChecks
# Arguments: None
# Returns:
#   0 if all checks pass
#   1 if critical issues are detected
# Exits: 
#   Prompts user or exits if critical issues found
# ============================================================================
PerformIntegrityChecks() {
    local continue_flag=true
    local error_count=0

    # Display header
    echo -e "\n${BOLD}${CYAN}rcForge Integrity Checks${RESET}"
    echo -e "${CYAN}$(printf '=%.0s' {1..50})${RESET}\n"

    # Sequence Conflict Check
    if [[ -f "$RCFORGE_UTILS/seqcheck.sh" ]]; then
        if ! bash "$RCFORGE_UTILS/seqcheck.sh"; then
            echo -e "\n${RED}SEQUENCE CONFLICT DETECTED${RESET}"
            echo "Potential configuration loading conflicts found in RC scripts."
            error_count=$((error_count + 1))
            continue_flag=false
        fi
    fi

    # Checksum Verification
    if [[ -f "$RCFORGE_CORE/check-checksums.sh" ]]; then
        if ! bash "$RCFORGE_CORE/check-checksums.sh"; then
            echo -e "\n${RED}CHECKSUM VERIFICATION FAILED${RESET}"
            echo "Configuration files may have been modified unexpectedly."
            error_count=$((error_count + 1))
            continue_flag=false
        fi
    fi

    # Prompt user if errors were found
    if [[ "$continue_flag" == "false" ]]; then
        echo -e "\n${YELLOW}Potential system integrity issues detected.${RESET}"
        echo "Found $error_count potential configuration problems."
        
        echo -e "\n${BOLD}RECOMMENDED ACTION:${RESET}"
        echo "Consider reinstalling rcForge with the following command:"
        echo -e "${CYAN}curl -fsSL https://raw.githubusercontent.com/rcforge/install/main/install.sh | bash${RESET}"
        
        # Check if in non-interactive mode
        if [[ -n "${RCFORGE_NONINTERACTIVE:-}" ]]; then
            echo "Running in non-interactive mode. Exiting."
            return 1
        fi

        read -p "Do you want to continue loading rcForge? (y/N): " response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo "Shell configuration loading aborted."
            return 1
        else
            echo -e "\n${GREEN}Continuing with rcForge initialization...${RESET}"
        fi
    else
        echo -e "${GREEN}No integrity issues detected.${RESET}"
    fi

    return 0
}

# ============================================================================
# Function: DetermineLoadPath
# Description: Determine the appropriate RC script loading path
# Usage: DetermineLoadPath shell hostname
# Arguments:
#   shell (required) - The current shell type (bash or zsh)
#   hostname (optional) - Specific hostname to use for loading
# Returns:
#   List of matching configuration script paths
# ============================================================================
DetermineLoadPath() {
    local shell="${1:?Shell type is required}"
    local hostname="${2:-$(hostname | cut -d. -f1)}"

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
        done < <(find "$RCFORGE_SCRIPTS" -maxdepth 1 -type f -name "$pattern" -print0 2>/dev/null)
    done

    # Sort files by sequence number
    IFS=$'\n' config_files=($(sort <<< "${config_files[*]}"))
    unset IFS

    # Output files
    printf '%s\n' "${config_files[@]}"
}

# ============================================================================
# Function: SourceConfigFiles
# Description: Source shell configuration files in sequence
# Usage: SourceConfigFiles config_files
# Arguments:
#   config_files (required) - Array of configuration file paths
# ============================================================================
SourceConfigFiles() {
    local files=("$@")
    
    # Start timing for performance measurement
    local start_time
    if [[ -n "${SHELL_DEBUG:-}" ]]; then
        start_time=$(date +%s.%N 2>/dev/null) || start_time=$SECONDS
    fi

    # Source each configuration file
    for file in "${files[@]}"; do
        # Verbose debug output if enabled
        if [[ -n "${SHELL_DEBUG:-}" ]]; then
            echo "Loading configuration: $file"
        fi
        
        # Source the file
        # shellcheck disable=SC1090
        source "$file"
    done

    # Calculate and report loading time if debugging is enabled
    if [[ -n "${SHELL_DEBUG:-}" ]]; then
        local end_time
        if command -v date >/dev/null 2>&1 && [[ "$start_time" != "$SECONDS" ]]; then
            end_time=$(date +%s.%N 2>/dev/null)
            local elapsed
            elapsed=$(echo "$end_time - $start_time" | bc 2>/dev/null)
            echo "Shell configuration loaded in $elapsed seconds"
        else
            echo "Shell configuration loaded successfully"
        fi
    fi
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

# Main initialization function
Main() {
    # Detect current shell and hostname
    local current_shell
    current_shell=$(DetectShell)

    # Perform integrity checks
    if ! PerformIntegrityChecks; then
        echo "Integrity checks failed. Aborting rcForge initialization."
        return 1
    fi

    # Determine configuration files to load
    local config_files
    mapfile -t config_files < <(DetermineLoadPath "$current_shell")

    # Source configuration files
    SourceConfigFiles "${config_files[@]}"
}

# Execute main function
Main "$@"

# EOF
