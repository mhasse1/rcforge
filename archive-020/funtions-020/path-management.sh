#!/usr/bin/env bash
# PathManagement.sh - Path manipulation and management utilities
# Category: path
# Author: Mark Hasse
# Date: 2025-03-31
#
# This file provides a comprehensive set of utilities for managing
# the PATH environment variable across different platforms.

# Set strict error handling
set -o nounset  # Treat unset variables as errors
 # set -o errexit  # Exit immediately if a command exits with a non-zero status

#--------------------------------------------------------------
# Path Manipulation Functions
#--------------------------------------------------------------

# Function: AddToPath
# Description: Adds a directory to the beginning of PATH if it exists and isn't already there
# Usage: AddToPath /path/to/directory
# Arguments:
#   $1 - Directory path to add
# Returns: 0 on success, 1 if directory doesn't exist or is already in PATH
AddToPath() {
    # Validate input
    if [[ $# -eq 0 ]]; then
        echo "ERROR: No directory specified to add to PATH" >&2
        return 1
    fi

    local dir="$1"

    # Check if directory exists
    if [[ ! -d "$dir" ]]; then
        echo "ERROR: Directory does not exist: $dir" >&2
        return 1
    fi

    # Check if directory is already in PATH
    if [[ ":$PATH:" == *":$dir:"* ]]; then
        # Already in PATH, no need to modify
        return 1
    fi

    # Add to beginning of PATH
    export PATH="$dir:$PATH"
    return 0
}

# Function: AppendToPath
# Description: Adds a directory to the end of PATH if it exists and isn't already there
# Usage: AppendToPath /path/to/directory
# Arguments:
#   $1 - Directory path to append
# Returns: 0 on success, 1 if directory doesn't exist or is already in PATH
AppendToPath() {
    # Validate input
    if [[ $# -eq 0 ]]; then
        echo "ERROR: No directory specified to append to PATH" >&2
        return 1
    fi

    local dir="$1"

    # Check if directory exists
    if [[ ! -d "$dir" ]]; then
        echo "ERROR: Directory does not exist: $dir" >&2
        return 1
    fi

    # Check if directory is already in PATH
    if [[ ":$PATH:" == *":$dir:"* ]]; then
        # Already in PATH, no need to modify
        return 1
    fi

    # Add to end of PATH
    export PATH="$PATH:$dir"
    return 0
}

# Function: ShowPath
# Description: Displays the current PATH variable in a readable format
# Usage: ShowPath
# Arguments: None
# Returns: None (displays PATH to stdout)
ShowPath() {
    echo "Current PATH:"
    echo "$PATH" | tr ':' '\n' | nl
}

# Function: RemoveFromPath
# Description: Removes a directory from PATH if it exists
# Usage: RemoveFromPath /path/to/directory
# Arguments:
#   $1 - Directory path to remove
# Returns: 0 on success, 1 if directory isn't in PATH
RemoveFromPath() {
    # Validate input
    if [[ $# -eq 0 ]]; then
        echo "ERROR: No directory specified to remove from PATH" >&2
        return 1
    fi

    local dir="$1"
    local new_path=""

    # Check if directory is in PATH
    if [[ ":$PATH:" != *":$dir:"* ]]; then
        # Not in PATH, nothing to do
        echo "WARNING: Directory not found in PATH: $dir" >&2
        return 1
    fi

    # Remove directory from PATH
    new_path=$(echo "$PATH" | tr ':' '\n' | grep -v "^$dir\$" | tr '\n' ':' | sed 's/:$//')
    export PATH="$new_path"
    return 0
}

# Function: CleanPath
# Description: Cleans the PATH by removing duplicate entries and non-existent directories
# Usage: CleanPath
# Arguments: None
# Returns: 0 on success
CleanPath() {
    local old_path="$PATH"
    local new_path=""
    local item=""

    # Split PATH by colon and process each directory
    while IFS= read -r item; do
        # Skip empty entries
        if [[ -z "$item" ]]; then
            continue
        fi

        # Skip non-existent directories
        if [[ ! -d "$item" ]]; then
            continue
        fi

        # Add to new PATH if not already there
        if [[ ":$new_path:" != *":$item:"* ]]; then
            if [[ -z "$new_path" ]]; then
                new_path="$item"
            else
                new_path="$new_path:$item"
            fi
        fi
    done < <(echo "$old_path" | tr ':' '\n')

    # Set the new PATH
    export PATH="$new_path"
    return 0
}

# Function: MoveToFront
# Description: Moves a directory to the front of PATH if it exists and is in PATH
# Usage: MoveToFront /path/to/directory
# Arguments:
#   $1 - Directory path to move to front
# Returns: 0 on success, 1 if directory doesn't exist or isn't in PATH
MoveToFront() {
    # Validate input
    if [[ $# -eq 0 ]]; then
        echo "ERROR: No directory specified to move to front of PATH" >&2
        return 1
    fi

    local dir="$1"

    # Check if directory exists
    if [[ ! -d "$dir" ]]; then
        echo "ERROR: Directory does not exist: $dir" >&2
        return 1
    fi

    # Check if directory is in PATH
    if [[ ":$PATH:" != *":$dir:"* ]]; then
        echo "ERROR: Directory not found in PATH: $dir" >&2
        return 1
    fi

    # Remove from current position and add to front
    RemoveFromPath "$dir"
    AddToPath "$dir"
    return 0
}

# Function: PathContains
# Description: Checks if the PATH contains a specified directory
# Usage: PathContains /path/to/directory
# Arguments:
#   $1 - Directory path to check
# Returns: 0 if directory is in PATH, 1 otherwise
PathContains() {
    # Validate input
    if [[ $# -eq 0 ]]; then
        echo "ERROR: No directory specified to check in PATH" >&2
        return 1
    fi

    local dir="$1"

    # Check if directory is in PATH
    if [[ ":$PATH:" == *":$dir:"* ]]; then
        return 0
    else
        return 1
    fi
}

# Function: GetPathCount
# Description: Returns the number of directories in PATH
# Usage: GetPathCount
# Arguments: None
# Returns: Number of directories in PATH
GetPathCount() {
    echo "$PATH" | tr ':' '\n' | wc -l
}

# Export all functions
export -f AddToPath
export -f AppendToPath
export -f ShowPath
export -f RemoveFromPath
export -f CleanPath
export -f MoveToFront
export -f PathContains
export -f GetPathCount
# EOF
