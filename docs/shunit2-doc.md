# rcForge Testing Guide: shUnit2 Integration

## Overview

This guide covers how to write and run tests for rcForge using the shUnit2 testing framework. The rcForge integration with shUnit2 provides a structured approach to testing shell scripts with a familiar xUnit-style interface.

## Installation

shUnit2 is automatically installed with rcForge v0.5.0+. If you need to install or update it manually, you can use the following command:

```bash
rc shunit2-install
```

## Test Directory Structure

The rcForge testing framework uses the following directory structure:

```
${RCFORGE_DATA_ROOT}/tests/
├── lib/                  # Testing libraries 
│   └── shunit2           # shUnit2 library
├── unit/                 # Unit tests
│   └── test_*.sh         # Individual unit test suites
├── integration/          # Integration tests
│   └── test_*.sh         # Individual integration test suites
├── scripts/              # Test helper scripts
└── run_tests.sh          # Main test runner
```

## Creating a Test Suite

### 1. Create a Test File

Create a new test file in the appropriate directory:

```bash
vim "${RCFORGE_DATA_ROOT}/tests/unit/test_my_module.sh"
```

### 2. Basic Test Structure

```bash
#!/usr/bin/env bash
# test_my_module.sh - Tests for my_module.sh

# Path configuration for tests
RCFORGE_ROOT="${RCFORGE_DATA_ROOT:-${XDG_DATA_HOME:-$HOME/.local/share}/rcforge}"
RCFORGE_LIB="${RCFORGE_ROOT}/system/lib"
RCFORGE_TEST_ROOT="${RCFORGE_ROOT}/tests"

# Source the test framework
source "${RCFORGE_LIB}/shunit2.sh"

# Source the module under test 
source "${RCFORGE_LIB}/my_module.sh"

# Test setup and teardown
oneTimeSetUp() {
    # Run once before all tests
    # Set up global test fixtures here
}

oneTimeTearDown() {
    # Run once after all tests
    # Clean up global test fixtures here
}

setUp() {
    # Run before each test
    # Set up per-test fixtures here
}

tearDown() {
    # Run after each test
    # Clean up per-test fixtures here
}

# Test functions
test_my_function() {
    # Arrange
    local input="test input"
    local expected="expected output"
    
    # Act
    local actual=$(MyFunction "$input")
    
    # Assert
    assertEquals "MyFunction should transform input correctly" \
        "$expected" "$actual"
}

# Run tests
RunTestSuite
```

### 3. Make the Test Executable

```bash
chmod 700 "${RCFORGE_DATA_ROOT}/tests/unit/test_my_module.sh"
```

## Writing Tests

### Naming Conventions

- Test files should be named `test_*.sh` 
- Test functions should be named `test*`
- Only functions named `test*` will be automatically executed as tests

### Test Structure

Each test function should follow the Arrange-Act-Assert pattern:

1. **Arrange**: Set up the test inputs and environment
2. **Act**: Call the function or code being tested
3. **Assert**: Verify the results using assertion functions

### Assertion Functions

#### Basic Assertions

| Function | Description |
|----------|-------------|
| `assertEquals [message] expected actual` | Assert that two values are equal |
| `assertNotEquals [message] unexpected actual` | Assert that two values are not equal |
| `assertTrue [message] condition` | Assert that a condition is true |
| `assertFalse [message] condition` | Assert that a condition is false |
| `assertNull [message] value` | Assert that a value is null/empty |
| `assertNotNull [message] value` | Assert that a value is not null/empty |

#### Extended Assertions

The rcForge shUnit2 integration adds these additional assertions:

| Function | Description |
|----------|-------------|
| `assertStrContains haystack needle [message]` | Assert that a string contains a substring |
| `assertStrNotContains haystack needle [message]` | Assert that a string does not contain a substring |
| `assertFileExists file [message]` | Assert that a file exists |
| `assertFileNotExists file [message]` | Assert that a file does not exist |
| `assertDirExists dir [message]` | Assert that a directory exists |
| `assertCommandExists command [message]` | Assert that a command exists in PATH |
| `assertExitCode expected_code command [message]` | Assert that a command exits with the expected code |

### Setup and Teardown

shUnit2 provides several functions to set up and tear down test fixtures:

- `oneTimeSetUp`: Runs once before all tests
- `oneTimeTearDown`: Runs once after all tests
- `setUp`: Runs before each test
- `tearDown`: Runs after each test

Additionally, rcForge adds:

- `setupSuite`: Runs once at the very beginning
- `teardownSuite`: Runs once at the very end

## Running Tests

### Running an Individual Test Suite

Run an individual test file directly:

```bash
bash "${RCFORGE_DATA_ROOT}/tests/unit/test_my_module.sh"
```

### Using the Test Runner

Use the test runner to run multiple test suites:

```bash
# Run all tests
"${RCFORGE_DATA_ROOT}/tests/run_tests.sh"

# Run all unit tests
"${RCFORGE_DATA_ROOT}/tests/run_tests.sh" --unit

# Run all integration tests
"${RCFORGE_DATA_ROOT}/tests/run_tests.sh" --integration

# Run specific test suites
"${RCFORGE_DATA_ROOT}/tests/run_tests.sh" \
    "${RCFORGE_DATA_ROOT}/tests/unit/test_my_module.sh" \
    "${RCFORGE_DATA_ROOT}/tests/unit/test_another_module.sh"
```

## Best Practices

### Isolate Tests

Each test should be independent and not rely on the state from other tests:

- Use `setUp` and `tearDown` to restore the environment
- Avoid global state when possible
- Mock external dependencies

### Capture and Verify Output

To test functions that produce output:

```bash
# Capture stdout
output=$(MyFunction "input")
assertStrContains "$output" "expected part"

# Capture stderr
error_output=$(MyFunction "invalid input" 2>&1)
assertStrContains "$error_output" "error message"

# Test exit code
MyFunction "input"
assertEquals "MyFunction should succeed" 0 $?

# Using assertExitCode
assertExitCode 0 "MyFunction 'input'"
```

### Test Edge Cases

Be sure to test:

- Empty inputs
- Invalid inputs
- Boundary conditions
- Error handling

### Mock External Commands

For unit tests, you may need to mock external commands:

```bash
# Create test directory
test_dir="/tmp/rcforge_test_$$"
mkdir -p "$test_dir"

# Create mock command
cat > "$test_dir/curl" << 'EOF'
#!/bin/bash
echo "Mock curl output"
exit 0
EOF
chmod +x "$test_dir/curl"

# Add to path
original_path="$PATH"
PATH="$test_dir:$PATH"

# Test with mock
output=$(FunctionThatUsesCurl)
assertStrContains "$output" "Mock curl output"

# Restore path
PATH="$original_path"

# Clean up
rm -rf "$test_dir"
```

## Debugging Tests

### Verbose Output

Run tests with verbose output:

```bash
DEBUG_MODE=true bash "${RCFORGE_DATA_ROOT}/tests/unit/test_my_module.sh"
```

Or use the test runner with the verbose flag:

```bash
"${RCFORGE_DATA_ROOT}/tests/run_tests.sh" --verbose
```

### Common Issues

1. **Test doesn't run**:
   - Check that the function name starts with `test`
   - Ensure the test file is executable

2. **Failures in setUp/tearDown**:
   - These will often mask the real issue
   - Add echo statements to debug

3. **Path issues**:
   - Make sure paths are correctly set for testing context
   - Use absolute paths when necessary

## Example: Testing a Utility

Here's an example of a test suite for a utility function:

```bash
#!/usr/bin/env bash
# test_clean_string.sh - Tests for string cleaning function

# Path configuration for tests
RCFORGE_ROOT="${RCFORGE_DATA_ROOT:-${XDG_DATA_HOME:-$HOME/.local/share}/rcforge}"
RCFORGE_LIB="${RCFORGE_ROOT}/system/lib"
RCFORGE_TEST_ROOT="${RCFORGE_ROOT}/tests"

# Source the test framework
source "${RCFORGE_LIB}/shunit2.sh"

# Source the module under test (assuming it exists in the utility functions)
source "${RCFORGE_LIB}/utility-functions.sh"

# Define the function we're testing (normally this would be in another file)
CleanString() {
    local input="$1"
    # Remove special characters, convert to lowercase
    echo "$input" | tr -dc '[:alnum:] ' | tr '[:upper:]' '[:lower:]'
}

# Test functions
test_CleanString_basic() {
    local input="Hello, World!"
    local expected="hello world"
    
    local actual=$(CleanString "$input")
    
    assertEquals "Basic cleaning should work" "$expected" "$actual"
}

test_CleanString_special_chars() {
    local input="Test@#$%^&*()_+="
    local expected="test"
    
    local actual=$(CleanString "$input")
    
    assertEquals "Special characters should be removed" "$expected" "$actual"
}

test_CleanString_empty() {
    local input=""
    local expected=""
    
    local actual=$(CleanString "$input")
    
    assertEquals "Empty string should remain empty" "$expected" "$actual"
}

# Run the tests
RunTestSuite
```

## Continuous Integration

To integrate tests into your development workflow:

1. **Pre-commit Hook**: Run tests before commits:

```bash
#!/bin/bash
# .git/hooks/pre-commit
"${RCFORGE_DATA_ROOT}/tests/run_tests.sh" --unit
if [ $? -ne 0 ]; then
    echo "Tests failed! Commit aborted."
    exit 1
fi
```

2. **Automated Testing**: Set up scheduled test runs:

```bash
# Run tests daily and log results
0 4 * * * "${RCFORGE_DATA_ROOT}/tests/run_tests.sh" --all > "${RCFORGE_DATA_ROOT}/logs/daily_tests_$(date +\%Y\%m\%d).log"
```

## Testing Specific Components

### Testing Shell Colors

To test shell color utilities:

```bash
test_color_output() {
    # Enable colors for testing
    export COLOR_OUTPUT_ENABLED="true"
    
    # Capture output
    local output=$(InfoMessage "Test message")
    
    # Check for ANSI color codes
    assertStrContains "$output" "\033["
    
    # Check for message content
    assertStrContains "$output" "Test message"
    
    # Disable colors
    export COLOR_OUTPUT_ENABLED="false"
    
    # Capture output again
    output=$(InfoMessage "Test message")
    
    # There should be no color codes
    assertStrNotContains "$output" "\033["
    
    # Should still contain the message
    assertStrContains "$output" "Test message"
}
```

### Testing File Operations

```bash
test_file_operations() {
    # Create temporary file
    local temp_file="/tmp/rcforge_test_$.txt"
    echo "test content" > "$temp_file"
    
    # Test file existence
    assertFileExists "$temp_file"
    
    # Test file content
    local content=$(cat "$temp_file")
    assertEquals "File content should match" "test content" "$content"
    
    # Clean up
    rm -f "$temp_file"
    
    # Test file was removed
    assertFileNotExists "$temp_file"
}
```

### Testing Exit Codes

```bash
test_exit_codes() {
    # Success case
    SuccessfulFunction
    assertEquals "Function should succeed" 0 $?
    
    # Error case
    FailingFunction
    assertEquals "Function should fail" 1 $?
    
    # Using the extension
    assertExitCode 0 "SuccessfulFunction"
    assertExitCode 1 "FailingFunction"
}
```

## Advanced Testing Techniques

### Test Parameterization

You can simulate parameterized tests using loops:

```bash
test_parameterized() {
    local -a inputs=("test" "Test@#$" "  spaces  ")
    local -a expected=("test" "test" "spaces")
    
    for i in "${!inputs[@]}"; do
        local input="${inputs[$i]}"
        local expected_output="${expected[$i]}"
        
        local actual=$(CleanString "$input")
        
        assertEquals "Test case $i should pass" \
            "$expected_output" "$actual"
    done
}
```

### Mocking Functions

You can mock functions to isolate your tests:

```bash
test_with_mock() {
    # Save the original function
    eval "original_function() $(declare -f SomeFunction)"
    
    # Override the function
    SomeFunction() {
        echo "mocked output"
    }
    
    # Use the mocked function
    local output=$(FunctionThatCallsSomeFunction)
    assertStrContains "$output" "mocked output"
    
    # Restore the original
    eval "SomeFunction() $(declare -f original_function)"
}
```

### Testing Logging

To test functions that log via standard error:

```bash
test_logging() {
    # Capture stderr
    local error_output=$(ErrorFunction 2>&1)
    
    # Check error message
    assertStrContains "$error_output" "Expected error message"
}
```

## Conclusion

Using shUnit2 with rcForge provides a solid foundation for testing your shell scripts. By following the practices in this guide, you can create robust, well-tested utilities that maintain the high quality standards of the rcForge project.

For more information on shUnit2, visit the [official documentation](https://github.com/kward/shunit2).
