# ============================================================================
# Function: DetectRcForgeDir
# Description: Determine the effective rcForge root directory. Checks RCFORGE_ROOT
#              environment variable first, then defaults to standard user config path.
# Usage: local dir; dir=$(DetectRcForgeDir)
# Arguments: None
# Returns: Echoes the path to the rcForge configuration directory.
# ============================================================================
DetectRcForgeDir() {
    # Updated for XDG structure in v0.5.0+
    # Check for RCFORGE_CONFIG_ROOT and RCFORGE_LOCAL_ROOT first (new structure)
    if [[ -n "${RCFORGE_CONFIG_ROOT:-}" && -d "${RCFORGE_CONFIG_ROOT}" ]]; then
        echo "${RCFORGE_CONFIG_ROOT}"
    # Fallback to RCFORGE_ROOT for compatibility with pre-0.5.0
    elif [[ -n "${RCFORGE_ROOT:-}" && -d "${RCFORGE_ROOT}" ]]; then
        echo "${RCFORGE_ROOT}"
    # Default to standard XDG config path
    else
        echo "$HOME/.config/rcforge"
    fi
}

# ============================================================================
# Function: FindRcScripts
# Description: Finds rcForge configuration scripts based on shell and hostname patterns.
#              Sorts the found files numerically based on sequence prefix.
# Usage: local -a files; mapfile -t files < <(FindRcScripts "bash" "myhost")
#        local files_str; files_str=$(FindRcScripts "zsh")
# Arguments:
#   $1 (required) - Target shell ('bash' or 'zsh').
#   $2 (optional) - Target hostname. Defaults to current hostname.
# Returns: Echoes a newline-separated list of matching script paths, sorted numerically.
#          Returns status 0 on success (even if no files found), 1 on error (e.g., dir missing).
# ============================================================================
FindRcScripts() {
    local shell="${1:?Shell type required for FindRcScripts}" # Exit if not provided
    local hostname="${2:-}"
    
    # Updated for XDG structure in v0.5.0+
    local scripts_dir=""
    if [[ -n "${RCFORGE_SCRIPTS:-}" ]]; then
        scripts_dir="${RCFORGE_SCRIPTS}"
    elif [[ -n "${RCFORGE_CONFIG_ROOT:-}" ]]; then
        scripts_dir="${RCFORGE_CONFIG_ROOT}/rc-scripts"
    else
        scripts_dir="$HOME/.config/rcforge/rc-scripts"
    fi
    
    local -a patterns
    local pattern=""
    local find_cmd_output="" # Variable to store find output
    local find_status=0      # Variable to store find status
    local -a config_files=() # Array to hold results

    # Default to current hostname if not provided
    if [[ -z "$hostname" ]]; then
        hostname=$(DetectCurrentHostname)
    fi

    # Define filename patterns to search for
    patterns=(
        "${scripts_dir}/[0-9][0-9][0-9]_global_common_*.sh"       # Global common
        "${scripts_dir}/[0-9][0-9][0-9]_global_${shell}_*.sh"      # Global shell-specific
        "${scripts_dir}/[0-9][0-9][0-9]_${hostname}_common_*.sh"   # Hostname common
        "${scripts_dir}/[0-9][0-9][0-9]_${hostname}_${shell}_*.sh"  # Hostname shell-specific
    )

    # Check if the scripts directory exists
    if [[ ! -d "$scripts_dir" ]]; then
        WarningMessage "rc-scripts directory not found: $scripts_dir"
        return 1 # Indicate error
    fi

    # Build the find command arguments safely to handle potential spaces/special chars
    local -a find_args=("$scripts_dir" -maxdepth 1 \( -false ) # Start with a false condition for OR grouping
    for pattern in "${patterns[@]}"; do
        local filename_pattern="${pattern##*/}" # Extract just the filename pattern
        find_args+=(-o -name "$filename_pattern")
    done
    find_args+=(\) -type f -print) # End OR grouping and specify file type

    # Execute find, capture output and status
    find_cmd_output=$(find "${find_args[@]}" 2>/dev/null)
    find_status=$?

    if [[ $find_status -ne 0 ]]; then
        WarningMessage "Find command failed searching rc-scripts (status: $find_status)."
        # DebugMessage "Find arguments were: ${find_args[*]}" # Optional debug
        return 1 # Indicate error
    fi

    # Populate the config_files array using the appropriate shell method
    if [[ -n "$find_cmd_output" ]]; then # Only process if find actually found something
        if IsZsh; then
            config_files=( ${(f)find_cmd_output} ) # Zsh: Use field splitting on newlines
        elif IsBash; then
            mapfile -t config_files <<< "$find_cmd_output" # Bash: Use mapfile
        else
            # Basic fallback (may break with spaces/newlines in names)
            config_files=( $(echo "$find_cmd_output") )
        fi
    else
        config_files=() # Ensure array is empty if find returned nothing
    fi

    # Check if any files were found
    if [[ ${#config_files[@]} -eq 0 ]]; then
        return 0 # Not an error if no files match
    fi

    # Sort the found files numerically and print
    printf '%s\n' "${config_files[@]}" | sort -n

    return 0 # Success
}