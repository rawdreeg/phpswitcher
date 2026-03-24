#!/usr/bin/env bash

# This script runs a series of tests against the phpswitcher tool.
# It is intended to be run in a CI environment after install.sh has been executed.

set -uo pipefail # Track unset variables and pipe failures; we handle exit codes manually

# Cleanup test artifacts on exit
cleanup() {
    rm -rf test_project 2>/dev/null || true
}
trap cleanup EXIT

# --- Setup ---
# Update Homebrew on macOS to ensure latest formulae (including icu4c@78 for PHP 7.4)
if [[ "$(uname)" == "Darwin" ]]; then
    echo "Updating Homebrew formulae database..."
    brew update
fi

# --- Test Helpers ---
# These functions help in asserting test outcomes.

# A counter for the number of tests run
TEST_COUNT=0
# A counter for the number of tests failed
FAIL_COUNT=0

# Function to begin a new test case
test_case() {
    TEST_COUNT=$((TEST_COUNT + 1))
    echo "--- TEST: $1 ---"
}

# Function to report a success
report_success() {
    echo "✅ PASS: $1"
}

# Function to report a failure
report_failure() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "❌ FAIL: $1"
    # If we are in a CI environment, we should exit on first failure
    if [ -n "${CI-}" ]; then
        exit 1
    fi
}

# Assert that a command succeeded: first arg = exit code, rest = message
assert_success() {
    local exit_code="$1"; shift
    local message="$*"
    if [ "$exit_code" -eq 0 ]; then
        report_success "$message"
    else
        report_failure "$message (exit $exit_code)"
    fi
}

# Asserts that a string contains a substring
assert_contains() {
    local string="$1"
    local substring="$2"
    local message="$3"
    if echo "$string" | grep -qF -- "$substring"; then
        report_success "$message"
    else
        report_failure "$message"
        echo "Expected to find '$substring' in the output:"
        echo "$string"
    fi
}

# --- Test Cases ---

# Test the 'install' command
test_install_command() {
    test_case "Install PHP 8.1"
    phpswitcher install 8.1
    assert_success $? "phpswitcher install 8.1"

    test_case "Verify PHP 8.1 installation"
    if [[ "$(uname)" == "Linux" ]]; then
        # On Linux (Ubuntu), check if the package is installed
        dpkg -l | grep -q "php8.1"
    else
        # On macOS, check if the formula is installed by Homebrew
        brew list php@8.1 >/dev/null
    fi
    assert_success $? "PHP 8.1 is present in the system"
}

# Test the 'list' command
test_list_command() {
    test_case "List installed versions"
    local output
    output=$(phpswitcher list)
    assert_contains "$output" "8.1" "List command shows installed PHP 8.1"
}

# Test the 'use' command
test_use_command() {
    test_case "Switch to PHP 8.1"
    phpswitcher use 8.1
    assert_success $? "phpswitcher use 8.1"

    test_case "Verify active PHP version is 8.1"
    # Rehash the shell to pick up the new version immediately
    hash -r 2>/dev/null || true
    local active_version
    active_version=$(php --version | head -n 1 | grep -o -E '[0-9]+\.[0-9]+' | head -n 1)
    assert_contains "$active_version" "8.1" "php --version reports 8.1"
}

# Test the .php-version file detection
test_php_version_file_detection() {
    test_case "Install PHP 7.4 for .php-version test"
    phpswitcher install 7.4
    assert_success $? "phpswitcher install 7.4"

    test_case "Auto-detection with 'use' command"
    mkdir -p test_project
    (
        cd test_project
        echo "7.4" > .php-version
        # The 'use' command without a version should detect it
        phpswitcher use
        assert_success $? "phpswitcher use (with .php-version)"

        # Verify the switch
        local active_version
        active_version=$(php --version | head -n 1 | grep -o -E '[0-9]+\.[0-9]+' | head -n 1)
        assert_contains "$active_version" "7.4" "Active version is 7.4 after detection"
    )
}

# Test that uninstalling the active version is blocked
test_uninstall_active_version_blocked() {
    test_case "Uninstall active version is blocked"
    local output
    output=$(phpswitcher uninstall 7.4 2>&1 || true)
    assert_contains "$output" "currently active version" "Cannot uninstall active PHP version"
}

# Test error handling for invalid version format
test_invalid_version_format() {
    test_case "Reject invalid version format"
    local output
    output=$(phpswitcher use "abc" 2>&1 || true)
    assert_contains "$output" "Invalid version format" "Invalid version format is rejected"
}

# Test that 'version' command works
test_version_command() {
    test_case "Version command"
    local output
    output=$(phpswitcher version 2>&1)
    assert_contains "$output" "phpswitcher version" "Version command produces output"
}

# Test that 'help' command works
test_help_command() {
    test_case "Help command"
    local output
    output=$(phpswitcher help 2>&1)
    assert_contains "$output" "Usage:" "Help command shows usage"
}

# Test running without arguments shows help
test_no_args() {
    test_case "No arguments shows help"
    local output
    output=$(phpswitcher 2>&1 || true)
    assert_contains "$output" "Usage:" "No arguments shows usage info"
}


# --- Main Test Runner ---
main() {
    echo "========================================"
    echo "  Running phpswitcher Integration Tests "
    echo "========================================"

    # Run all test functions
    test_install_command
    test_list_command
    test_use_command
    test_php_version_file_detection
    test_invalid_version_format
    test_uninstall_active_version_blocked
    test_version_command
    test_help_command
    test_no_args

    echo "----------------------------------------"
    if [ "$FAIL_COUNT" -eq 0 ]; then
        echo "🎉 All $TEST_COUNT tests passed!"
        exit 0
    else
        echo "🔥 $FAIL_COUNT out of $TEST_COUNT tests failed."
        exit 1
    fi
}

main
