#!/bin/bash
# include-functions.sh - Core functions for the rcForge include system
# Author: Mark Hasse
# Date: March 30, 2025
#
# This file provides the core functionality for the include system,
# enabling efficient loading and management of modular shell functions.

# Set strict error handling for this script
set -o nounset  # Treat unset variables as errors
set -o errexit  # Exit on error

# ============================================================================
# BOOTSTRAP COLORS
# Minimalist color definitions directly embedded to avoid circular dependencies
# ============================================================================
readonly c_RED='\033[0;31m'
readonly c_GREEN='\033[0;32m'
readonly c_YELLOW='\033[0;33m'
readonly c_BLUE='\033[0;34m'
readonly c_CYAN='\033[0;36m'
readonly c_RESET='\033[0m'

# ============================================================================
# INITIALIZATIONS AND DECLARATIONS
# ============================================================================

# Initialize tracking for included functions (will be populated later)
if [[ "${BASH_VERSION:-0}" =~ ^[4-9] ]]; then
    # Only declare associative array if using Bash 4.0+
    declare -A RCFORGE_INCLUDE_HASH
    RCFORGE_INCLUDE_SYSTEM_ENABLED=true
else
    # For older Bash versions, we'll use a fallback approach
    RCFORGE_INCLUDE_SYSTEM_ENABLED=false
fi

# Path variables - these will be set by DetectBasePaths()
RCFORGE_BASE=""
RCFORGE_USER_INCLUDE=""
RCFORGE_SYS_INCLUDE=""
RCFORGE_LIB=""
RCFORGE_UTILS=""
RCFORGE_CORE=""

# ============================================================================
# ERROR HANDLING AND UTILITY FUNCTIONS
# ============================================================================

# Display an error message
# Usage: ErrorMessage "Error message text"
ErrorMessage() {
    echo -e "${c_RED}ERROR: $1${c_RESET}" >&2
}

# Display a warning message
# Usage: WarningMessage "Warning message text"
WarningMessage() {
    echo -e "${c_YELLOW}WARNING: $1${c_RESET}" >&2
}

# Display an info message
# Usage: InfoMessage "Informational message text"
InfoMessage() {
    echo -e "${c_BLUE}INFO: $1${c_RESET}" >&2
}

# Display a debug message if debug mode is enabled
# Usage: DebugMessage "Debug message text"
DebugMessage() {
    if [[ -n "${SHELL_DEBUG:-}" ]]; then
        echo -e "${c_CYAN}DEBUG: $1${c_RESET}" >&2
    fi
}

# ============================================================================
# CORE INCLUDE SYSTEM FUNCTIONS
# ============================================================================

# Detect the rcForge base directory and related paths
# This is called once during initialization to establish the core paths
# It handles user installations, system installations, and development mode
# Usage: DetectBasePaths
DetectBasePaths() {
    DebugMessage "Detecting rcForge base directory..."
    
    # Check for explicitly set base directory via environment variables
    if [[ -n "${RCFORGE_DEV:-}" ]]; then
        # Development mode
        RCFORGE_BASE="${RCFORGE_ROOT:-$HOME/src/rcforge}"
        DebugMessage "Development mode: Using $RCFORGE_BASE as base"
    elif [[ -n "${RCFORGE_ROOT:-}" ]]; then
        # Explicitly set root directory
        RCFORGE_BASE="${RCFORGE_ROOT}"
        DebugMessage "Explicit root: Using $RCFORGE_BASE as base"
    else
        # Auto-detection of installation paths
        local possible_bases=(
            "$HOME/.config/rcforge"                # User installation
            "/usr/share/rcforge"                   # System installation (Linux/Debian)
            "/opt/homebrew/share/rcforge"          # Homebrew on Apple Silicon
            "$(brew --prefix 2>/dev/null)/share/rcforge" # Homebrew (generic)
            "/opt/local/share/rcforge"             # MacPorts
            "/usr/local/share/rcforge"             # Alternative system location
            "$HOME/src/rcforge"                    # Common developer location
            "$HOME/Projects/rcforge"               # Alternative project location
        )
        
        # Try each possible location
        for base in "${possible_bases[@]}"; do
            if [[ -n "$base" && -d "$base" && -f "$base/rcforge.sh" ]]; then
                RCFORGE_BASE="$base"
                DebugMessage "Auto-detected base: $RCFORGE_BASE"
                break
            fi
        done
        
        # If no base found, use a default
        if [[ -z "$RCFORGE_BASE" ]]; then
            RCFORGE_BASE="$HOME/.config/rcforge"
            WarningMessage "Could not detect rcForge base directory, using default: $RCFORGE_BASE"
        fi
    fi
    
    # Calculate related directories relative to the base
    RCFORGE_USER_INCLUDE="$HOME/.config/rcforge/include"
    RCFORGE_LIB="${RCFORGE_BASE}/lib"
    RCFORGE_UTILS="${RCFORGE_BASE}/utils"
    RCFORGE_CORE="${RCFORGE_BASE}/core"
    
    # Detect system include directory
    if [[ "$RCFORGE_BASE" == "/usr/share/rcforge" ]]; then
        RCFORGE_SYS_INCLUDE="/usr/share/rcforge/include"
    elif [[ "$RCFORGE_BASE" == "/opt/homebrew/share/rcforge" ]]; then
        RCFORGE_SYS_INCLUDE="/opt/homebrew/share/rcforge/include"
    elif [[ "$RCFORGE_BASE" =~ .*/share/rcforge$ ]]; then
        RCFORGE_SYS_INCLUDE="${RCFORGE_BASE}/include"
    else
        RCFORGE_SYS_INCLUDE="${RCFORGE_BASE}/include"
    fi
    
    # Export path variables for use by other scripts
    export RCFORGE_BASE RCFORGE_USER_INCLUDE RCFORGE_SYS_INCLUDE RCFORGE_LIB RCFORGE_UTILS RCFORGE_CORE
    
    DebugMessage "Base paths detected:"
    DebugMessage "  RCFORGE_BASE: $RCFORGE_BASE"
    DebugMessage "  RCFORGE_USER_INCLUDE: $RCFORGE_USER_INCLUDE"
    DebugMessage "  RCFORGE_SYS_INCLUDE: $RCFORGE_SYS_INCLUDE"
    DebugMessage "  RCFORGE_LIB: $RCFORGE_LIB"
    DebugMessage "  RCFORGE_UTILS: $RCFORGE_UTILS"
    DebugMessage "  RCFORGE_CORE: $RCFORGE_CORE"
    
    # Create user include directory if it doesn't exist
    if [[ ! -d "$RCFORGE_USER_INCLUDE" ]]; then
        mkdir -p "$RCFORGE_USER_INCLUDE"
        DebugMessage "Created user include directory: $RCFORGE_USER_INCLUDE"
    fi
    
    return 0
}

# Build a hash table of all available include functions for fast lookups
# This scans all include directories and builds a mapping of category/function to file path
# Usage: BuildIncludeHash
BuildIncludeHash() {
    # Skip if include system is disabled (older Bash)
    if [[ "$RCFORGE_INCLUDE_SYSTEM_ENABLED" != "true" ]]; then
        DebugMessage "Include system disabled (Bash version < 4.0)"
        return 0
    fi
    
    DebugMessage "Building include hash table..."
    
    # Initialize counters
    local total_functions=0
    local user_functions=0
    local system_functions=0
    
    # First, check system include directory
    if [[ -d "$RCFORGE_SYS_INCLUDE" ]]; then
        for category_dir in "$RCFORGE_SYS_INCLUDE"/*; do
            if [[ -d "$category_dir" ]]; then
                local category=$(basename "$category_dir")
                
                for func_file in "$category_dir"/*.sh; do
                    if [[ -f "$func_file" ]]; then
                        local function_name=$(basename "$func_file" .sh)
                        local key="${category}/${function_name}"
                        
                        # Only add system functions if not overridden by user
                        if [[ -z "${RCFORGE_INCLUDE_HASH[$key]:-}" ]]; then
                            RCFORGE_INCLUDE_HASH["$key"]="$func_file"
                            ((system_functions++))
                            ((total_functions++))
                        fi
                    fi
                done
            fi
        done
    fi
    
    # Then check user include directory (overrides system functions)
    if [[ -d "$RCFORGE_USER_INCLUDE" ]]; then
        for category_dir in "$RCFORGE_USER_INCLUDE"/*; do
            if [[ -d "$category_dir" ]]; then
                local category=$(basename "$category_dir")
                
                for func_file in "$category_dir"/*.sh; do
                    if [[ -f "$func_file" ]]; then
                        local function_name=$(basename "$func_file" .sh)
                        local key="${category}/${function_name}"
                        
                        # User functions override system functions
                        RCFORGE_INCLUDE_HASH["$key"]="$func_file"
                        ((user_functions++))
                        
                        # Only increment total if this is a new function
                        if [[ ! -f "$RCFORGE_SYS_INCLUDE/$category/$function_name.sh" ]]; then
                            ((total_functions++))
                        fi
                    fi
                done
            fi
        done
    fi
    
    DebugMessage "Include hash table built with $total_functions functions ($user_functions user, $system_functions system)"
    
    # Return success
    return 0
}

# Source a include function by category and name
# This uses the hash table for O(1) lookups
# Usage: SourceInclude category function_name
SourceInclude() {
    local category="$1"
    local function_name="$2"
    local quiet="${3:-false}"
    
    # Skip if include system is disabled (older Bash)
    if [[ "$RCFORGE_INCLUDE_SYSTEM_ENABLED" != "true" ]]; then
        [[ "$quiet" == "false" ]] && WarningMessage "Include system is disabled (requires Bash 4.0+)"
        return 1
    fi
    
    # Build the lookup key
    local key="${category}/${function_name}"
    
    # Check if function exists in hash table
    if [[ -n "${RCFORGE_INCLUDE_HASH[$key]:-}" ]]; then
        local func_file="${RCFORGE_INCLUDE_HASH[$key]}"
        
        [[ "$quiet" == "false" ]] && DebugMessage "Loading function: $function_name from $func_file"
        
        # Source the function file
        if source "$func_file"; then
            return 0
        else
            [[ "$quiet" == "false" ]] && ErrorMessage "Failed to source function: $function_name from $func_file"
            return 1
        fi
    else
        [[ "$quiet" == "false" ]] && WarningMessage "Function not found: $category/$function_name"
        return 1
    fi
}

# Source a utility script from the rcforge utility directory
# Usage: SourceUtil util_name
SourceUtil() {
    local util_name="$1"
    local quiet="${2:-false}"
    
    # Build the file path
    local util_file="${RCFORGE_UTILS}/${util_name}"
    
    # Add .sh extension if not already present
    if [[ ! "$util_file" =~ \.sh$ ]]; then
        util_file="${util_file}.sh"
    fi
    
    # Check if the file exists
    if [[ -f "$util_file" ]]; then
        [[ "$quiet" == "false" ]] && DebugMessage "Loading utility: $util_name from $util_file"
        
        # Source the utility file
        if source "$util_file"; then
            return 0
        else
            [[ "$quiet" == "false" ]] && ErrorMessage "Failed to source utility: $util_name from $util_file"
            return 1
        fi
    else
        [[ "$quiet" == "false" ]] && WarningMessage "Utility script not found: $util_name"
        return 1
    fi
}

# Include a specific function from the include system
# This is the primary function that users will call
# Usage: IncludeFunction category function_name
IncludeFunction() {
    local category="$1"
    local function_name="$2"
    local quiet="${3:-false}"
    
    # Validate inputs
    if [[ -z "$category" || -z "$function_name" ]]; then
        [[ "$quiet" == "false" ]] && ErrorMessage "IncludeFunction requires both category and function name"
        return 1
    fi
    
    # Skip if include system is disabled (older Bash)
    if [[ "$RCFORGE_INCLUDE_SYSTEM_ENABLED" != "true" ]]; then
        [[ "$quiet" == "false" ]] && WarningMessage "Include system is disabled (requires Bash 4.0+)"
        [[ "$quiet" == "false" ]] && WarningMessage "Attempted to include: $category/$function_name"
        return 1
    fi
    
    # Source the function
    SourceInclude "$category" "$function_name" "$quiet"
    return $?
}

# Include all functions in a category
# Usage: IncludeCategory category
IncludeCategory() {
    local category="$1"
    local quiet="${2:-false}"
    
    # Validate inputs
    if [[ -z "$category" ]]; then
        [[ "$quiet" == "false" ]] && ErrorMessage "IncludeCategory requires a category name"
        return 1
    fi
    
    # Skip if include system is disabled (older Bash)
    if [[ "$RCFORGE_INCLUDE_SYSTEM_ENABLED" != "true" ]]; then
        [[ "$quiet" == "false" ]] && WarningMessage "Include system is disabled (requires Bash 4.0+)"
        [[ "$quiet" == "false" ]] && WarningMessage "Attempted to include category: $category"
        return 1
    fi
    
    local count=0
    
    # Loop through all functions in the hash table
    for key in "${!RCFORGE_INCLUDE_HASH[@]}"; do
        # Check if this key belongs to the requested category
        if [[ "$key" =~ ^${category}/ ]]; then
            local function_name="${key#*/}"
            SourceInclude "$category" "$function_name" true
            ((count++))
        fi
    done
    
    [[ "$quiet" == "false" ]] && DebugMessage "Included $count functions from category: $category"
    
    return 0
}

# List all available include functions
# This provides a user-friendly view of all available functions
# Usage: ListAvailableFunctions [category]
ListAvailableFunctions() {
    local target_category="$1"
    
    # Skip if include system is disabled (older Bash)
    if [[ "$RCFORGE_INCLUDE_SYSTEM_ENABLED" != "true" ]]; then
        echo "Include system is disabled (requires Bash 4.0+)"
        return 1
    fi
    
    echo "Available Include Functions:"
    echo "==========================="
    
    # If category is specified, only list that category
    if [[ -n "$target_category" ]]; then
        echo "Category: $target_category"
        echo "------------------"
        
        # Get functions for this category
        for key in "${!RCFORGE_INCLUDE_HASH[@]}"; do
            # Check if this key belongs to the requested category
            if [[ "$key" =~ ^${target_category}/ ]]; then
                local function_name="${key#*/}"
                local file_path="${RCFORGE_INCLUDE_HASH[$key]}"
                
                # Determine if it's a user function or system function
                if [[ "$file_path" == "$RCFORGE_USER_INCLUDE"* ]]; then
                    echo "  $function_name (user)"
                else
                    echo "  $function_name (system)"
                fi
            fi
        done
        
        return 0
    fi
    
    # List all categories and functions
    local categories=()
    
    # Build unique list of categories
    for key in "${!RCFORGE_INCLUDE_HASH[@]}"; do
        local category="${key%%/*}"
        local found=false
        
        # Check if category is already in list
        for existing in "${categories[@]}"; do
            if [[ "$existing" == "$category" ]]; then
                found=true
                break
            fi
        done
        
        # Add if not found
        if [[ "$found" == "false" ]]; then
            categories+=("$category")
        fi
    done
    
    # Sort categories
    IFS=$'\n' categories=($(sort <<<"${categories[*]}"))
    unset IFS
    
    # List functions by category
    for category in "${categories[@]}"; do
        echo "Category: $category"
        echo "------------------"
        
        # Get functions for this category
        for key in "${!RCFORGE_INCLUDE_HASH[@]}"; do
            # Check if this key belongs to the current category
            if [[ "$key" =~ ^${category}/ ]]; then
                local function_name="${key#*/}"
                local file_path="${RCFORGE_INCLUDE_HASH[$key]}"
                
                # Determine if it's a user function or system function
                if [[ "$file_path" == "$RCFORGE_USER_INCLUDE"* ]]; then
                    echo "  $function_name (user)"
                else
                    echo "  $function_name (system)"
                fi
            fi
        done
        
        echo ""
    done
}

# ============================================================================
# COMPATIBILITY ALIASES
# ============================================================================

# These alias the Pascal case function names to the old style for backward compatibility
include_function() { IncludeFunction "$@"; }
include_category() { IncludeCategory "$@"; }
list_available_functions() { ListAvailableFunctions "$@"; }
source_include() { SourceInclude "$@"; }
source_util() { SourceUtil "$@"; }

# ============================================================================
# INITIALIZATION
# ============================================================================

# Initialize the include system
InitializeIncludeSystem() {
    # Check if we're running in Bash
    if [[ -z "${BASH_VERSION:-}" ]]; then
        WarningMessage "Include system not fully supported in non-Bash shells"
        RCFORGE_INCLUDE_SYSTEM_ENABLED=false
        return 1
    fi
    
    # Check minimum Bash version
    if [[ ! "${BASH_VERSION:-0}" =~ ^[4-9] ]]; then
        WarningMessage "Include system requires Bash 4.0+ (your version: ${BASH_VERSION:-unknown})"
        RCFORGE_INCLUDE_SYSTEM_ENABLED=false
        return 1
    fi
    
    # Verify we can use associative arrays (requires Bash 4.0+)
    if ! declare -A test_array &>/dev/null; then
        WarningMessage "Associative arrays not supported (requires Bash 4.0+)"
        RCFORGE_INCLUDE_SYSTEM_ENABLED=false
        return 1
    fi
    
    # Detect base paths for rcForge
    DetectBasePaths
    
    # Build the include hash table
    BuildIncludeHash
    
    DebugMessage "Include system initialization complete"
    
    return 0
}

# Run initialization when the file is sourced
InitializeIncludeSystem

# Export functions so they're available to other scripts
export -f IncludeFunction include_function
export -f IncludeCategory include_category
export -f ListAvailableFunctions list_available_functions
export -f SourceInclude source_include
export -f SourceUtil source_util
export -f ErrorMessage WarningMessage InfoMessage DebugMessage

# EOF
