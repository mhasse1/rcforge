#!/usr/bin/env bash
# test-include.sh - Test utility for the rcForge include system
# Author: Mark Hasse
# Copyright: Analog Edge LLC
# Date: 2025-03-30
# Version: 0.2.1
# Description: Comprehensive testing tool for the rcForge include system functionality

# Import core utility libraries
source shell-colors.sh

# Set strict error handling
set -o nounset  # Treat unset variables as errors
set -o errexit  # Exit immediately if a command exits with a non-zero status

# Global constants
readonly gc_app_name="rcForge"
readonly gc_version="0.2.1"
readonly gc_min_bash_version="4.0"

# Configuration variables
export VERBOSE_MODE=false
export SPECIFIC_CATEGORY=""
export SPECIFIC_FUNCTION=""
export EXIT_ON_FIRST_ERROR=false

# Detect project root dynamically
DetectProjectRoot() {
    local possible_roots=(
        "${RCFORGE_ROOT:-}"
        "$HOME/src/rcforge"
        "$HOME/Projects/rcforge"
        "/usr/share/rcforge"
        "/opt/homebrew/share/rcforge"
        "$(brew --prefix 2>/dev/null)/share/rcforge"
        "/opt/local/share/rcforge"
        "/usr/local/share/rcforge"
        "$HOME/.config/rcforge"
    )

    for dir in "${possible_roots[@]}"; do
        if [[ -n "$dir" && -d "$dir" && -f "$dir/rcforge.sh" ]]; then
            echo "$dir"
            return 0
        fi
    done

    # Fallback to user configuration directory
    echo "$HOME/.config/rcforge"
}

# Validate Bash version compatibility
ValidateBashVersion() {
    local current_version="$1"
    local major_version=${current_version%%.*}

    if [[ "$major_version" -lt 4 ]]; then
        ErrorMessage "rcForge include system requires Bash 4.0+ (current: $current_version)"
        return 1
    fi
    return 0
}

# Parse command-line arguments
ParseArguments() {
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --verbose|-v)
                VERBOSE_MODE=true
                ;;
            --category=*)
                SPECIFIC_CATEGORY="${1#*=}"
                ;;
            --function=*)
                SPECIFIC_FUNCTION="${1#*=}"
                ;;
            --exit-first|-x)
                EXIT_ON_FIRST_ERROR=true
                ;;
            --help|-h)
                DisplayHelp
                exit 0
                ;;
            --version)
                DisplayVersion
                exit 0
                ;;
            *)
                ErrorMessage "Unknown parameter: $1"
                DisplayHelp
                exit 1
                ;;
        esac
        shift
    done
}

# Display help information
DisplayHelp() {
    SectionHeader "${gc_app_name} Include System Test Utility"
    
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --verbose, -v        Enable verbose output"
    echo "  --category=CAT       Test specific include category"
    echo "  --function=FUNC      Test specific include function"
    echo "  --exit-first, -x     Exit on first error"
    echo "  --help, -h           Show this help message"
    echo "  --version            Show version information"
    echo ""
    echo "Examples:"
    echo "  $0                   Run all include system tests"
    echo "  $0 --category=path   Test only path category"
    echo "  $0 --function=add_to_path  Test specific function"
}

# Display version information
DisplayVersion() {
    TextBlock "${gc_app_name} Include System Test Utility" "$CYAN"
    echo "Version: ${gc_version}"
    echo "Copyright: Analog Edge LLC"
    echo "License: MIT"
}

# Detect system include directories
DetectIncludeDirectories() {
    local base_dir="$1"
    local user_include_dir="$HOME/.config/rcforge/include"
    local system_include_dir="${base_dir}/include"

    # Verify and set include directories
    if [[ ! -d "$user_include_dir" ]]; then
        WarningMessage "User include directory not found: $user_include_dir"
        mkdir -p "$user_include_dir"
    fi

    if [[ ! -d "$system_include_dir" ]]; then
        ErrorMessage "System include directory not found: $system_include_dir"
        return 1
    fi

    # Export directories for testing
    export RCFORGE_USER_INCLUDE="$user_include_dir"
    export RCFORGE_SYS_INCLUDE="$system_include_dir"
}

# Test include function loading
TestIncludeFunction() {
    local category="$1"
    local function_name="$2"

    InfoMessage "Testing include function: $category/$function_name"

    # Attempt to source the function
    if include_function "$category" "$function_name"; then
        SuccessMessage "Successfully loaded function: $function_name"
        
        # Verify function availability
        if type -t "$function_name" >/dev/null 2>&1; then
            if [[ "$VERBOSE_MODE" == true ]]; then
                echo "Function output:"
                "$function_name" || WarningMessage "Function returned non-zero exit code"
            fi
        else
            ErrorMessage "Function $function_name not available after loading"
            return 1
        fi
    else
        ErrorMessage "Failed to load function: $category/$function_name"
        return 1
    fi
}

# Test entire include category
TestIncludeCategory() {
    local category="$1"
    local test_count=0
    local error_count=0

    InfoMessage "Testing include category: $category"

    # Get all functions in the category
    local functions=()
    while IFS= read -r -d '' func_file; do
        local func_name
        func_name=$(basename "$func_file" .sh)
        functions+=("$func_name")
    done < <(find "$RCFORGE_SYS_INCLUDE/$category" -type f -name "*.sh" -print0 2>/dev/null)

    # Test each function
    for func in "${functions[@]}"; do
        ((test_count++))
        if ! TestIncludeFunction "$category" "$func"; then
            ((error_count++))
            if [[ "$EXIT_ON_FIRST_ERROR" == true ]]; then
                break
            fi
        fi
    done

    # Summary
    if [[ $error_count -eq 0 ]]; then
        SuccessMessage "All functions in $category category tested successfully"
    else
        ErrorMessage "$error_count out of $test_count functions failed in $category category"
        return 1
    fi
}

# Main test execution
Main() {
    # Validate Bash version
    ValidateBashVersion "$BASH_VERSION" || exit 1

    # Detect project root
    local RCFORGE_DIR
    RCFORGE_DIR=$(DetectProjectRoot)

    # Detect include directories
    DetectIncludeDirectories "$RCFORGE_DIR"

    # Parse command-line arguments
    ParseArguments "$@"

    # Display header
    SectionHeader "${gc_app_name} Include System Tests"

    # Source include functions
    source "$RCFORGE_DIR/lib/include-functions.sh"

    # Perform testing based on arguments
    if [[ -n "$SPECIFIC_FUNCTION" && -n "$SPECIFIC_CATEGORY" ]]; then
        # Test specific function
        TestIncludeFunction "$SPECIFIC_CATEGORY" "$SPECIFIC_FUNCTION"
    elif [[ -n "$SPECIFIC_CATEGORY" ]]; then
        # Test entire category
        TestIncludeCategory "$SPECIFIC_CATEGORY"
    else
        # Run comprehensive tests
        # List of default categories to test
        local default_categories=("path" "common")
        
        for category in "${default_categories[@]}"; do
            TestIncludeCategory "$category"
        done
    fi

    # Final success message
    SuccessMessage "Include system tests completed"
}

# Entry point - execute only if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    Main "$@"
fi
