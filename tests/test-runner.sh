#!/usr/bin/env bash
# run_tests.sh - Run rcForge test suites
# Author: rcForge Team
# Date: 2025-04-22
# Version: 0.5.0
# Category: tests
# Description: Runs specified test suites or all discovered tests

# Source required libraries
RCFORGE_ROOT="${RCFORGE_DATA_ROOT:-${XDG_DATA_HOME:-$HOME/.local/share}/rcforge}"
RCFORGE_LIB="${RCFORGE_ROOT}/system/lib"
RCFORGE_TEST_ROOT="${RCFORGE_ROOT}/tests"

source "${RCFORGE_LIB}/utility-functions.sh"
source "${RCFORGE_LIB}/shunit2.sh"

# Set strict error handling
set -o nounset
set -o pipefail

# Global constants
readonly UTILITY_NAME="run_tests"

# ============================================================================
# Function: ShowHelp
# Description: Display help information for this script.
# Usage: ShowHelp
# Arguments: None
# Returns: None. Exits with status 0.
# ============================================================================
ShowHelp() {
    echo "rcForge Test Runner (v${gc_version:-0.5.0})"
    echo ""
    echo "Description:"
    echo "  Runs specified test suites or discovers and runs all tests."
    echo ""
    echo "Usage:"
    echo "  $(basename "$0") [options] [test_suite_path...]"
    echo ""
    echo "Options:"
    echo "  --unit              Run all unit tests"
    echo "  --integration       Run all integration tests"
    echo "  --all               Run all tests (default if no paths specified)"
    echo "  --verbose, -v       Show verbose output"
    echo "  --help, -h          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0")                 # Run all tests"
    echo "  $(basename "$0") --unit          # Run only unit tests"
    echo "  $(basename "$0") tests/unit/test_shell_colors.sh  # Run specific test suite"
    exit 0
}

# ============================================================================
# Function: FindTestSuites
# Description: Find test suites in a directory
# Usage: FindTestSuites directory
# Arguments:
#   $1 (required) - Directory to search for tests
# Returns: Path to each test suite, one per line
# ============================================================================
FindTestSuites() {
    local test_dir="$1"
    
    if [[ ! -d "$test_dir" ]]; then
        ErrorMessage "Test directory not found: $test_dir"
        return 1
    fi
    
    # Find executable test files
    find "$test_dir" -type f -name "test_*.sh" -perm -u+x | sort
}

# ============================================================================
# Function: RunTestSuite
# Description: Run a single test suite
# Usage: RunTestSuite test_suite_path
# Arguments:
#   $1 (required) - Path to test suite
# Returns: 0 on success, test result code otherwise
# ============================================================================
RunTestSuite() {
    local test_file="$1"
    local result=0
    
    if [[ ! -f "$test_file" || ! -x "$test_file" ]]; then
        ErrorMessage "Test suite not found or not executable: $test_file"
        return 1
    fi
    
    SectionHeader "Running Test Suite: $(basename "$test_file")"
    # Run with bash regardless of shell
    bash "$test_file"
    result=$?
    
    echo "" # Add spacing
    if [[ $result -eq 0 ]]; then
        SuccessMessage "Test suite passed: $(basename "$test_file")"
    else
        ErrorMessage "Test suite failed: $(basename "$test_file")"
    fi
    
    return $result
}

# ============================================================================
# Function: main
# Description: Main execution logic.
# Usage: main "$@"
# Arguments: Command-line arguments
# Returns: 0 on success, non-zero on error.
# ============================================================================
main() {
    local run_unit=false
    local run_integration=false
    local run_all=false
    local verbose=false
    local explicit_paths=()
    local exit_code=0
    
    # Process command-line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                ShowHelp
                ;;
            --unit)
                run_unit=true
                shift
                ;;
            --integration)
                run_integration=true
                shift
                ;;
            --all)
                run_all=true
                shift
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -*)
                ErrorMessage "Unknown option: $1"
                echo "Use --help for usage information."
                return 1
                ;;
            *)
                # Treat as a path to a test suite
                explicit_paths+=("$1")
                shift
                ;;
        esac
    done
    
    # Default to --all if no specific options
    if [[ "$run_unit" == "false" && "$run_integration" == "false" && "$run_all" == "false" && ${#explicit_paths[@]} -eq 0 ]]; then
        run_all=true
    fi
    
    # Build list of test suites to run
    local test_suites=()
    
    # Add explicitly specified paths
    if [[ ${#explicit_paths[@]} -gt 0 ]]; then
        for path in "${explicit_paths[@]}"; do
            test_suites+=("$path")
        done
    else
        # Add tests based on options
        if [[ "$run_unit" == "true" || "$run_all" == "true" ]]; then
            while IFS= read -r suite; do
                [[ -n "$suite" ]] && test_suites+=("$suite")
            done < <(FindTestSuites "${RCFORGE_TEST_ROOT}/unit")
        fi
        
        if [[ "$run_integration" == "true" || "$run_all" == "true" ]]; then
            while IFS= read -r suite; do
                [[ -n "$suite" ]] && test_suites+=("$suite")
            done < <(FindTestSuites "${RCFORGE_TEST_ROOT}/integration")
        fi
    fi
    
    # Check if we found any test suites
    if [[ ${#test_suites[@]} -eq 0 ]]; then
        WarningMessage "No test suites found to run."
        return 0
    fi
    
    # Set up environment for tests
    if [[ "$verbose" == "true" ]]; then
        export DEBUG_MODE=true
    fi
    
    # Output test plan
    SectionHeader "rcForge Test Runner"
    InfoMessage "Found ${#test_suites[@]} test suites to run:"
    for suite in "${test_suites[@]}"; do
        InfoMessage "  - $(basename "$suite")"
    done
    echo "" # Add spacing
    
    # Run the test suites
    local passed=0
    local failed=0
    local skipped=0
    local all_passed=true
    local failed_tests=()
    
    for suite in "${test_suites[@]}"; do
        if [[ -x "$suite" ]]; then
            RunTestSuite "$suite"
            local result=$?
            
            if [[ $result -eq 0 ]]; then
                passed=$((passed + 1))
            else
                failed=$((failed + 1))
                all_passed=false
                failed_tests+=("$(basename "$suite")")
            fi
        else
            WarningMessage "Skipping non-executable test: $(basename "$suite")"
            skipped=$((skipped + 1))
        fi
    done
    
    # Show summary
    SectionHeader "Test Run Summary"
    InfoMessage "Total test suites: ${#test_suites[@]}"
    InfoMessage "  Passed:  $passed"
    if [[ $failed -gt 0 ]]; then
        ErrorMessage "  Failed:  $failed"
    else
        InfoMessage "  Failed:  $failed"
    fi
    if [[ $skipped -gt 0 ]]; then
        WarningMessage "  Skipped: $skipped"
    else
        InfoMessage "  Skipped: $skipped"
    fi
    
    # Show failed tests
    if [[ ${#failed_tests[@]} -gt 0 ]]; then
        echo "" # Add spacing
        ErrorMessage "Failed tests:"
        for test in "${failed_tests[@]}"; do
            ErrorMessage "  - $test"
        done
        exit_code=1
    else
        echo "" # Add spacing
        SuccessMessage "All tests passed!"
        exit_code=0
    fi
    
    return $exit_code
}

# Execute main function if run directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
    exit $? # Exit with status from main
fi

# EOF
