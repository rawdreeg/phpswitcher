#!/usr/bin/env bash

# This script runs a series of tests against the phpswitcher tool.
# It is intended to be run in a CI environment after install.sh has been executed.

set -euo pipefail # Exit on error, unset variable, or pipe failure

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

# Asserts that the last command executed successfully (exit code 0)
assert_success() {
    if [ $? -eq 0 ]; then
        report_success "$1"
    else
        report_failure "$1"
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
    assert_success "phpswitcher install 8.1"

    test_case "Verify PHP 8.1 installation"
    if [[ "$(uname)" == "Linux" ]]; then
        # On Linux (Ubuntu), check if the package is installed
        dpkg -l | grep -q "php8.1"
    else
        # On macOS, check if the formula is installed by Homebrew
        brew list php@8.1 >/dev/null
    fi
    assert_success "PHP 8.1 is present in the system"
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
    assert_success "phpswitcher use 8.1"

    test_case "Verify active PHP version is 8.1"
    # Give the shell a moment to recognize the new version
    sleep 1
    local active_version
    active_version=$(php --version | head -n 1 | grep -o -E '[0-9]+\.[0-9]+' | head -n 1)
    assert_contains "$active_version" "8.1" "php --version reports 8.1"
}

# Test the .php-version file detection
test_php_version_file_detection() {
    test_case "Install PHP 7.4 for .php-version test"
    phpswitcher install 7.4
    assert_success "phpswitcher install 7.4"

    test_case "Auto-detection with 'use' command"
    mkdir -p test_project
    (
        cd test_project
        echo "7.4" > .php-version
        # The 'use' command without a version should detect it
        phpswitcher use
        assert_success "phpswitcher use (with .php-version)"

        # Verify the switch
        local active_version
        active_version=$(php --version | head -n 1 | grep -o -E '[0-9]+\.[0-9]+' | head -n 1)
        assert_contains "$active_version" "7.4" "Active version is 7.4 after detection"
    )
    rm -rf test_project
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
