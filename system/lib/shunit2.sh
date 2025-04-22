#!/usr/bin/env bash
# shunit2.sh - rcForge wrapper for shUnit2 testing framework
# Author: rcForge Team
# Date: 2025-04-22
# Version: 0.5.0
# Category: system/library
# Description: Wrapper for shUnit2 testing framework to integrate with
#              rcForge standards and provide additional utilities.

# --- Include Guard ---
if [[ -n "${_RCFORGE_SHUNIT2_SH_SOURCED:-}" ]]; then
    return 0
fi
_RCFORGE_SHUNIT2_SH_SOURCED=true

# Source utility functions if available
if [[ -f "${RCFORGE_LIB:-$HOME/.local/share/rcforge/system/lib}/utility-functions.sh" ]]; then
    # shellcheck disable=SC1090
    source "${RCFORGE_LIB:-$HOME/.local/share/rcforge/system/lib}/utility-functions.sh"
fi

# Global constants
[ -v gc_version ]  || readonly gc_version="${RCFORGE_VERSION:-0.5.0}"
[ -v gc_app_name ] || readonly gc_app_name="${RCFORGE_APP_NAME:-rcForge}"
readonly SHUNIT2_VERSION="2.1.8"
readonly SHUNIT2_URL="https://raw.githubusercontent.com/kward/shunit2/v${SHUNIT2_VERSION}/shunit2"
readonly SHUNIT2_RCFORGE_PATH="${RCFORGE_DATA_ROOT:-${XDG_DATA_HOME:-$HOME/.local/share}/rcforge}/tests/lib/shunit2"

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Function: FindShunit2
# Description: Find the shUnit2 library path
# Usage: path=$(FindShunit2)
# Returns: Path to shUnit2 library or empty string if not found
FindShunit2() {
    local paths=(
        # Check rcForge installation first
        "${SHUNIT2_RCFORGE_PATH}"
        # Check common system paths
        "/usr/local/lib/shunit2/shunit2"
        "/usr/share/shunit2/shunit2"
        # Check home directory installation
        "$HOME/.local/lib/shunit2/shunit2"
        # Check current directory
        "./shunit2"
        "./tests/lib/shunit2"
    )
    
    for path in "${paths[@]}"; do
        if [[ -f "$path" && -r "$path" ]]; then
            echo "$path"
            return 0
        fi
    done
    
    return 1
}

# Function: InstallShunit2
# Description: Install shUnit2 to rcForge tests directory
# Usage: InstallShunit2 [force]
# Returns: 0 on success, non-zero on error
InstallShunit2() {
    local force="${1:-false}"
    
    # Check if already installed (unless force update)
    if [[ -f "$SHUNIT2_RCFORGE_PATH" && "$force" == "false" ]]; then
        if command -v InfoMessage &>/dev/null; then
            InfoMessage "shUnit2 is already installed at: $SHUNIT2_RCFORGE_PATH"
        else
            echo "INFO: shUnit2 is already installed at: $SHUNIT2_RCFORGE_PATH"
        fi
        return 0
    fi
    
    # Ensure directory exists
    local install_dir
    install_dir="$(dirname "$SHUNIT2_RCFORGE_PATH")"
    mkdir -p "$install_dir" || {
        if command -v ErrorMessage &>/dev/null; then
            ErrorMessage "Failed to create directory: $install_dir"
        else
            echo "ERROR: Failed to create directory: $install_dir" >&2
        fi
        return 1
    }
    
    # Download shUnit2
    if command -v InfoMessage &>/dev/null; then
        InfoMessage "Downloading shUnit2 v${SHUNIT2_VERSION}..."
    else
        echo "INFO: Downloading shUnit2 v${SHUNIT2_VERSION}..."
    fi
    
    if ! command -v curl &>/dev/null; then
        if command -v ErrorMessage &>/dev/null; then
            ErrorMessage "curl command not found. Please install curl and try again."
        else
            echo "ERROR: curl command not found. Please install curl and try again." >&2
        fi
        return 1
    fi
    
    if ! curl --fail --silent --location --output "$SHUNIT2_RCFORGE_PATH" "$SHUNIT2_URL"; then
        if command -v ErrorMessage &>/dev/null; then
            ErrorMessage "Failed to download shUnit2 from: $SHUNIT2_URL"
        else
            echo "ERROR: Failed to download shUnit2 from: $SHUNIT2_URL" >&2
        fi
        return 1
    fi
    
    # Set permissions
    chmod 700 "$SHUNIT2_RCFORGE_PATH" || {
        if command -v WarningMessage &>/dev/null; then
            WarningMessage "Failed to set executable permissions on: $SHUNIT2_RCFORGE_PATH"
        else
            echo "WARNING: Failed to set executable permissions on: $SHUNIT2_RCFORGE_PATH" >&2
        fi
    }
    
    if command -v SuccessMessage &>/dev/null; then
        SuccessMessage "shUnit2 installed successfully to: $SHUNIT2_RCFORGE_PATH"
    else
        echo "SUCCESS: shUnit2 installed successfully to: $SHUNIT2_RCFORGE_PATH"
    fi
    
    return 0
}

# ============================================================================
# TEST ENHANCEMENT FUNCTIONS
# ============================================================================

# Function: OneTimeSetUp
# Description: Default implementation for oneTimeSetUp
# Usage: Define your own oneTimeSetUp function if needed
oneTimeSetUp() {
    # Default implementation does nothing
    :
}

# Function: OneTimeTearDown
# Description: Default implementation for oneTimeTearDown
# Usage: Define your own oneTimeTearDown function if needed
oneTimeTearDown() {
    # Default implementation does nothing
    :
}

# Function: SetupSuite
# Description: Prepare the test suite before running
# Usage: Define this in your test file, it will be called automatically
setupSuite() {
    # Default implementation does nothing
    :
}

# Function: TeardownSuite
# Description: Clean up after the test suite
# Usage: Define this in your test file, it will be called automatically
teardownSuite() {
    # Default implementation does nothing
    :
}

# Function: _ASSERT_STR_CONTAINS
# Description: Assert that a string contains a substring
# Usage: _ASSERT_STR_CONTAINS "haystack" "needle" ["message"]
_ASSERT_STR_CONTAINS() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-Expected '$haystack' to contain '$needle'}"
    
    if [[ "$haystack" == *"$needle"* ]]; then
        return 0
    else
        fail "$message"
        return 1
    fi
}

# Function: _ASSERT_STR_NOT_CONTAINS
# Description: Assert that a string does not contain a substring
# Usage: _ASSERT_STR_NOT_CONTAINS "haystack" "needle" ["message"]
_ASSERT_STR_NOT_CONTAINS() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-Expected '$haystack' to not contain '$needle'}"
    
    if [[ "$haystack" != *"$needle"* ]]; then
        return 0
    else
        fail "$message"
        return 1
    fi
}

# Function: _ASSERT_FILE_EXISTS
# Description: Assert that a file exists
# Usage: _ASSERT_FILE_EXISTS "/path/to/file" ["message"]
_ASSERT_FILE_EXISTS() {
    local file="$1"
    local message="${2:-File not found: $file}"
    
    if [[ -f "$file" ]]; then
        return 0
    else
        fail "$message"
        return 1
    fi
}

# Function: _ASSERT_FILE_NOT_EXISTS
# Description: Assert that a file does not exist
# Usage: _ASSERT_FILE_NOT_EXISTS "/path/to/file" ["message"]
_ASSERT_FILE_NOT_EXISTS() {
    local file="$1"
    local message="${2:-File exists: $file}"
    
    if [[ ! -f "$file" ]]; then
        return 0
    else
        fail "$message"
        return 1
    fi
}

# Function: _ASSERT_DIR_EXISTS
# Description: Assert that a directory exists
# Usage: _ASSERT_DIR_EXISTS "/path/to/dir" ["message"]
_ASSERT_DIR_EXISTS() {
    local dir="$1"
    local message="${2:-Directory not found: $dir}"
    
    if [[ -d "$dir" ]]; then
        return 0
    else
        fail "$message"
        return 1
    fi
}

# Function: _ASSERT_COMMAND_EXISTS
# Description: Assert that a command exists in PATH
# Usage: _ASSERT_COMMAND_EXISTS "command" ["message"]
_ASSERT_COMMAND_EXISTS() {
    local cmd="$1"
    local message="${2:-Command not found: $cmd}"
    
    if command -v "$cmd" &>/dev/null; then
        return 0
    else
        fail "$message"
        return 1
    fi
}

# Function: _ASSERT_EXIT_CODE
# Description: Assert that a command exits with an expected code
# Usage: _ASSERT_EXIT_CODE expected_code "command" ["message"]
_ASSERT_EXIT_CODE() {
    local expected="$1"
    local command="$2"
    local message="${3:-Expected exit code $expected, but got }"
    
    eval "$command"
    local actual=$?
    
    if [[ "$actual" -eq "$expected" ]]; then
        return 0
    else
        fail "${message}${actual}"
        return 1
    fi
}

# ============================================================================
# TEST RUNNER SUPPORT
# ============================================================================

# Function: RunTestSuite
# Description: Run a test suite with shUnit2
# Usage: RunTestSuite [test_file]
RunTestSuite() {
    local test_file="${1:-${0}}"
    local shunit2_path
    
    # Find shUnit2
    shunit2_path=$(FindShunit2)
    
    # Install if not found
    if [[ -z "$shunit2_path" ]]; then
        if command -v InfoMessage &>/dev/null; then
            InfoMessage "shUnit2 not found. Installing..."
        else
            echo "INFO: shUnit2 not found. Installing..."
        fi
        
        if ! InstallShunit2; then
            if command -v ErrorMessage &>/dev/null; then
                ErrorMessage "Failed to install shUnit2. Cannot run tests."
            else
                echo "ERROR: Failed to install shUnit2. Cannot run tests." >&2
            fi
            return 1
        fi
        
        shunit2_path="$SHUNIT2_RCFORGE_PATH"
    fi
    
    # Run suite setup if defined
    if declare -f setupSuite >/dev/null; then
        setupSuite
    fi
    
    # Export extended assert functions
    for func in _ASSERT_STR_CONTAINS _ASSERT_STR_NOT_CONTAINS _ASSERT_FILE_EXISTS _ASSERT_FILE_NOT_EXISTS _ASSERT_DIR_EXISTS _ASSERT_COMMAND_EXISTS _ASSERT_EXIT_CODE; do
        if command -v IsBash &>/dev/null && IsBash; then
            export -f "$func"
        fi
    done
    
    # Source shUnit2
    # shellcheck disable=SC1090
    . "$shunit2_path"
    
    # Run suite teardown if defined
    if declare -f teardownSuite >/dev/null; then
        teardownSuite
    fi
}

# Make common assertion functions available with standard names
assertStrContains() { _ASSERT_STR_CONTAINS "$@"; }
assertStrNotContains() { _ASSERT_STR_NOT_CONTAINS "$@"; }
assertFileExists() { _ASSERT_FILE_EXISTS "$@"; }
assertFileNotExists() { _ASSERT_FILE_NOT_EXISTS "$@"; }
assertDirExists() { _ASSERT_DIR_EXISTS "$@"; }
assertCommandExists() { _ASSERT_COMMAND_EXISTS "$@"; }
assertExitCode() { _ASSERT_EXIT_CODE "$@"; }

# Export public functions for Bash
if command -v IsBash &>/dev/null && IsBash; then
    export -f FindShunit2
    export -f InstallShunit2
    export -f RunTestSuite
    export -f assertStrContains
    export -f assertStrNotContains
    export -f assertFileExists
    export -f assertFileNotExists
    export -f assertDirExists
    export -f assertCommandExists
    export -f assertExitCode
fi

# EOF
