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
# If running from the repo checkout, copy local scripts over the installed ones
# so that tests exercise the current branch code, not the latest release.
PHPSWITCHER_DIR="${PHPSWITCHER_DIR:-$HOME/.phpswitcher}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -f "$SCRIPT_DIR/bin/phpswitcher" ] && [ -d "$PHPSWITCHER_DIR/bin" ]; then
    echo "Copying local scripts to $PHPSWITCHER_DIR for testing..."
    cp "$SCRIPT_DIR/bin/phpswitcher" "$PHPSWITCHER_DIR/bin/phpswitcher"
    [ -f "$SCRIPT_DIR/bin/phpswitcher-init.sh" ] && cp "$SCRIPT_DIR/bin/phpswitcher-init.sh" "$PHPSWITCHER_DIR/phpswitcher-init.sh"
    [ -f "$SCRIPT_DIR/bin/phpswitcher-completion.sh" ] && cp "$SCRIPT_DIR/bin/phpswitcher-completion.sh" "$PHPSWITCHER_DIR/phpswitcher-completion.sh"
    [ -f "$SCRIPT_DIR/bin/phpswitcher-init.fish" ] && cp "$SCRIPT_DIR/bin/phpswitcher-init.fish" "$PHPSWITCHER_DIR/phpswitcher-init.fish"
    [ -f "$SCRIPT_DIR/bin/phpswitcher-completion.fish" ] && cp "$SCRIPT_DIR/bin/phpswitcher-completion.fish" "$PHPSWITCHER_DIR/phpswitcher-completion.fish"
fi

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


# Test the 'default' command
test_default_command() {
    test_case "Set global default version"
    phpswitcher default 8.1
    assert_success $? "phpswitcher default 8.1"

    test_case "Show global default version"
    local output
    output=$(phpswitcher default 2>&1)
    assert_contains "$output" "8.1" "Default command shows 8.1"

    test_case "Unset global default version"
    phpswitcher default --unset
    assert_success $? "phpswitcher default --unset"

    test_case "Default is unset"
    output=$(phpswitcher default 2>&1)
    assert_contains "$output" "No global default" "Default is unset"
}

# Test the 'status' command
test_status_command() {
    test_case "Status command"
    local output
    output=$(phpswitcher status 2>&1)
    assert_contains "$output" "PHP Switcher Status" "Status command shows header"
    assert_contains "$output" "Active PHP version:" "Status shows active version"
    assert_contains "$output" "Version detection" "Status shows detection info"
}

# Test the 'default' version detection fallback
test_default_version_detection() {
    test_case "Default version used when no .php-version or composer.json"
    phpswitcher default 8.1
    assert_success $? "Set default to 8.1 for detection test"

    # Create a directory without .php-version or composer.json
    mkdir -p test_project_empty
    (
        cd test_project_empty
        phpswitcher use
        assert_success $? "phpswitcher use (with default fallback)"
    )
    rm -rf test_project_empty

    # Clean up default
    phpswitcher default --unset
}

# Test the 'extensions' command (list only — install requires real packages)
test_extensions_command() {
    test_case "Extensions list command"
    local output
    output=$(phpswitcher extensions 8.1 2>&1)
    # Should either list extensions or show an error about the version
    assert_success $? "phpswitcher extensions 8.1 runs without crash"
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
    test_default_command
    test_status_command
    test_default_version_detection
    test_extensions_command

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
