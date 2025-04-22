#!/usr/bin/env bash
# test_shell_colors.sh - Unit tests for shell-colors.sh
# Author: rcForge Team
# Date: 2025-04-22
# Version: 0.5.0
# Category: tests/unit
# Description: Unit tests for the shell-colors library functions

# Path configuration for tests
RCFORGE_ROOT="${RCFORGE_DATA_ROOT:-${XDG_DATA_HOME:-$HOME/.local/share}/rcforge}"
RCFORGE_LIB="${RCFORGE_ROOT}/system/lib"
RCFORGE_TEST_ROOT="${RCFORGE_ROOT}/tests"

# Source the test framework
source "${RCFORGE_TEST_ROOT}/lib/shunit2"
source "${RCFORGE_LIB}/shunit2.sh"

# Source the module under test 
source "${RCFORGE_LIB}/shell-colors.sh"

# ============================================================================
# TEST SETUP & TEARDOWN
# ============================================================================

# Called once before any tests run
oneTimeSetUp() {
    # Save original environment variables
    _original_color_output_enabled="${COLOR_OUTPUT_ENABLED:-true}"
    _original_color_background="${COLOR_BACKGROUND:-}"
    
    # Create a test output file
    _test_output_file="/tmp/rcforge_test_shell_colors_$$.txt"
    > "${_test_output_file}"
}

# Called once after all tests complete
oneTimeTearDown() {
    # Restore original environment variables
    export COLOR_OUTPUT_ENABLED="${_original_color_output_enabled}"
    if [[ -n "${_original_color_background}" ]]; then
        export COLOR_BACKGROUND="${_original_color_background}"
    else
        unset COLOR_BACKGROUND
    fi
    
    # Clean up test files
    rm -f "${_test_output_file}"
}

# Called before each test
setUp() {
    # Reset color output settings for each test
    export COLOR_OUTPUT_ENABLED="true"
    unset COLOR_BACKGROUND
    
    # Clear test output file
    > "${_test_output_file}"
}

# Called after each test
tearDown() {
    # Clean up anything needed between tests
    :
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Helper to check if a string contains ANSI color codes
contains_color_codes() {
    [[ "$1" =~ \\\[[0-9]+m ]]
}

# Helper to capture function output
capture_output() {
    eval "$@" > "${_test_output_file}" 2>&1
    cat "${_test_output_file}"
}

# Helper to test for ANSI color codes
test_for_colors() {
    local output
    output=$(capture_output "$@")
    
    contains_color_codes "$output"
    return $?
}

# ============================================================================
# TEST FUNCTIONS
# ============================================================================

# Test color initialization
test_color_variables_initialization() {
    # Reset any existing environment first
    COLOR_OUTPUT_ENABLED="true"
    unset COLOR_BACKGROUND
    
    # Re-source to initialize colors
    source "${RCFORGE_LIB}/shell-colors.sh"
    
    # Verify that basic color variables were set
    assertNotNull "RED should be defined" "${RED:-}"
    assertNotNull "GREEN should be defined" "${GREEN:-}"
    assertNotNull "RESET should be defined" "${RESET:-}"
    assertNotNull "BOLD should be defined" "${BOLD:-}"
}

# Test color output enabling/disabling
test_color_output_enabling() {
    # Enable colors
    EnableColorOutput
    assertEquals "COLOR_OUTPUT_ENABLED should be true" "true" "$COLOR_OUTPUT_ENABLED"
    
    # Test that color output functions produce color codes
    local output
    output=$(InfoMessage "Test message")
    contains_color_codes "$output"
    assertTrue "InfoMessage should contain color codes when enabled" $?
    
    # Disable colors
    DisableColorOutput
    assertEquals "COLOR_OUTPUT_ENABLED should be false" "false" "$COLOR_OUTPUT_ENABLED"
    
    # Test that color output functions don't produce color codes
    output=$(InfoMessage "Test message")
    contains_color_codes "$output"
    assertFalse "InfoMessage should not contain color codes when disabled" $?
}

# Test background detection
test_background_detection() {
    # Test default (should be dark)
    unset COLOR_BACKGROUND
    local detected
    detected=$(DetectTerminalBackground)
    assertNotNull "Background detection should return a value" "$detected"
    
    # Test with explicit setting
    export COLOR_BACKGROUND="light"
    detected=$(DetectTerminalBackground)
    assertEquals "Background detection should return user setting" "light" "$detected"
    
    export COLOR_BACKGROUND="dark"
    detected=$(DetectTerminalBackground)
    assertEquals "Background detection should return user setting" "dark" "$detected"
}

# Test color scheme setting based on background
test_color_scheme_setting() {
    # Save original background
    local original_background="${COLOR_BACKGROUND:-}"
    
    # Test with light background
    export COLOR_BACKGROUND="light"
    SetColorScheme "light"
    assertNotNull "INFO_COLOR should be set for light background" "${INFO_COLOR:-}"
    assertNotNull "HEADER_FG should be set for light background" "${HEADER_FG:-}"
    
    # Test with dark background
    export COLOR_BACKGROUND="dark"
    SetColorScheme "dark"
    assertNotNull "INFO_COLOR should be set for dark background" "${INFO_COLOR:-}"
    assertNotNull "HEADER_FG should be set for dark background" "${HEADER_FG:-}"
    
    # Verify dark and light backgrounds have different values
    export COLOR_BACKGROUND="light"
    SetColorScheme "light"
    local light_info_color="${INFO_COLOR:-}"
    
    export COLOR_BACKGROUND="dark"
    SetColorScheme "dark"
    local dark_info_color="${INFO_COLOR:-}"
    
    assertNotEquals "Color schemes should differ between light and dark backgrounds" \
        "$light_info_color" "$dark_info_color"
    
    # Restore original background
    if [[ -n "$original_background" ]]; then
        export COLOR_BACKGROUND="$original_background"
    else
        unset COLOR_BACKGROUND
    fi
}

# Test InfoMessage function
test_InfoMessage() {
    # Test with color enabled
    export COLOR_OUTPUT_ENABLED="true"
    local output
    output=$(InfoMessage "Test info message")
    
    # Should contain the message
    assertStrContains "$output" "Test info message"
    
    # Should contain color codes
    contains_color_codes "$output"
    assertTrue "InfoMessage should contain color codes when enabled" $?
    
    # Test with color disabled
    export COLOR_OUTPUT_ENABLED="false"
    output=$(InfoMessage "Test info message")
    
    # Should still contain the message
    assertStrContains "$output" "Test info message"
    
    # Should contain INFO: prefix instead of color codes
    assertStrContains "$output" "INFO:"
    
    # Should not contain color codes
    contains_color_codes "$output"
    assertFalse "InfoMessage should not contain color codes when disabled" $?
}

# Test SuccessMessage function
test_SuccessMessage() {
    # Test with color enabled
    export COLOR_OUTPUT_ENABLED="true"
    local output
    output=$(SuccessMessage "Test success message")
    
    # Should contain the message
    assertStrContains "$output" "Test success message"
    
    # Should contain color codes
    contains_color_codes "$output"
    assertTrue "SuccessMessage should contain color codes when enabled" $?
    
    # Test with color disabled
    export COLOR_OUTPUT_ENABLED="false"
    output=$(SuccessMessage "Test success message")
    
    # Should still contain the message
    assertStrContains "$output" "Test success message"
    
    # Should contain SUCCESS: prefix instead of color codes
    assertStrContains "$output" "SUCCESS:"
    
    # Should not contain color codes
    contains_color_codes "$output"
    assertFalse "SuccessMessage should not contain color codes when disabled" $?
}

# Test WarningMessage function
test_WarningMessage() {
    # Test with color enabled
    export COLOR_OUTPUT_ENABLED="true"
    local output
    output=$(WarningMessage "Test warning message" 2>&1)
    
    # Should contain the message
    assertStrContains "$output" "Test warning message"
    
    # Should contain color codes
    contains_color_codes "$output"
    assertTrue "WarningMessage should contain color codes when enabled" $?
    
    # Test with color disabled
    export COLOR_OUTPUT_ENABLED="false"
    output=$(WarningMessage "Test warning message" 2>&1)
    
    # Should still contain the message
    assertStrContains "$output" "Test warning message"
    
    # Should contain WARNING: prefix instead of color codes
    assertStrContains "$output" "WARNING:"
    
    # Should not contain color codes
    contains_color_codes "$output"
    assertFalse "WarningMessage should not contain color codes when disabled" $?
}

# Test ErrorMessage function
test_ErrorMessage() {
    # Test with color enabled
    export COLOR_OUTPUT_ENABLED="true"
    local output
    output=$(ErrorMessage "Test error message" 2>&1)
    
    # Should contain the message
    assertStrContains "$output" "Test error message"
    
    # Should contain color codes
    contains_color_codes "$output"
    assertTrue "ErrorMessage should contain color codes when enabled" $?
    
    # Test with color disabled
    export COLOR_OUTPUT_ENABLED="false"
    output=$(ErrorMessage "Test error message" 2>&1)
    
    # Should still contain the message
    assertStrContains "$output" "Test error message"
    
    # Should contain ERROR: prefix instead of color codes
    assertStrContains "$output" "ERROR:"
    
    # Should not contain color codes
    contains_color_codes "$output"
    assertFalse "ErrorMessage should not contain color codes when disabled" $?
}

# Test VerboseMessage function
test_VerboseMessage() {
    # Test when verbose is true
    export COLOR_OUTPUT_ENABLED="true"
    local output
    output=$(VerboseMessage true "Test verbose message")
    
    # Should contain the message
    assertStrContains "$output" "Test verbose message"
    
    # Should contain color codes
    contains_color_codes "$output"
    assertTrue "VerboseMessage should contain color codes when enabled and verbose is true" $?
    
    # Test when verbose is false
    output=$(VerboseMessage false "Test verbose message")
    
    # Should be empty (message not printed)
    assertEquals "VerboseMessage should produce no output when verbose is false" "" "$output"
    
    # Test with color disabled
    export COLOR_OUTPUT_ENABLED="false"
    output=$(VerboseMessage true "Test verbose message")
    
    # Should still contain the message
    assertStrContains "$output" "Test verbose message"
    
    # Should contain VERBOSE: prefix instead of color codes
    assertStrContains "$output" "VERBOSE:"
    
    # Should not contain color codes
    contains_color_codes "$output"
    assertFalse "VerboseMessage should not contain color codes when disabled" $?
}

# Test SectionHeader function
test_SectionHeader() {
    # Test with color enabled
    export COLOR_OUTPUT_ENABLED="true"
    local output
    output=$(SectionHeader "Test Section")
    
    # Should contain the section title
    assertStrContains "$output" "Test Section"
    
    # Should contain color codes
    contains_color_codes "$output"
    assertTrue "SectionHeader should contain color codes when enabled" $?
    
    # Test with color disabled
    export COLOR_OUTPUT_ENABLED="false"
    output=$(SectionHeader "Test Section")
    
    # Should still contain the section title
    assertStrContains "$output" "Test Section"
    
    # Should contain === formatting instead of color codes
    assertStrContains "$output" "==="
    
    # Should not contain color codes
    contains_color_codes "$output"
    assertFalse "SectionHeader should not contain color codes when disabled" $?
}

# Test TextBlock function
test_TextBlock() {
    # Test with color enabled
    export COLOR_OUTPUT_ENABLED="true"
    local output
    output=$(TextBlock "Test Block")
    
    # Should contain the block text
    assertStrContains "$output" "Test Block"
    
    # Should contain color codes
    contains_color_codes "$output"
    assertTrue "TextBlock should contain color codes when enabled" $?
    
    # Test with color disabled
    export COLOR_OUTPUT_ENABLED="false"
    output=$(TextBlock "Test Block")
    
    # Should still contain the block text
    assertStrContains "$output" "Test Block"
    
    # Should contain [ ] formatting instead of color codes
    assertStrContains "$output" "[ Test Block ]"
    
    # Should not contain color codes
    contains_color_codes "$output"
    assertFalse "TextBlock should not contain color codes when disabled" $?
}

# Test StripColors function
test_StripColors() {
    # Create a string with color codes
    local colored_text="${RED}This is ${GREEN}colored ${BLUE}text${RESET}"
    
    # Strip colors
    local plain_text
    plain_text=$(StripColors "$colored_text")
    
    # Should contain the text
    assertStrContains "$plain_text" "This is colored text"
    
    # Should not contain color codes
    contains_color_codes "$plain_text"
    assertFalse "StripColors should remove all color codes" $?
    
    # Length should be shorter
    assertTrue "Plain text should be shorter than colored text" \
        "[ ${#plain_text} -lt ${#colored_text} ]"
}

# Test terminal width detection
test_GetTerminalWidth() {
    # Test that it returns a number
    local width
    width=$(GetTerminalWidth)
    
    # Should be a positive number
    assertTrue "Terminal width should be a positive number" \
        "[ $width -gt 0 ]"
    
    # Should be at least 40 (minimum reasonable width)
    assertTrue "Terminal width should be at least 40" \
        "[ $width -ge 40 ]"
    
    # Test with explicit COLUMNS variable
    local original_columns="${COLUMNS:-}"
    export COLUMNS=120
    
    width=$(GetTerminalWidth)
    assertEquals "Terminal width should match COLUMNS variable" "120" "$width"
    
    # Restore original COLUMNS
    if [[ -n "$original_columns" ]]; then
        export COLUMNS="$original_columns"
    else
        unset COLUMNS
    fi
}

# Run the tests
RunTestSuite
