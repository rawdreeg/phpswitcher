#!/usr/bin/env bash

# Unit tests for phpswitcher features that don't require real PHP installations.
# These tests use a temporary PHPSWITCHER_DIR and exercise the CLI's argument
# parsing, file-based state, version detection, and output formatting.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PHPSWITCHER="$SCRIPT_DIR/bin/phpswitcher"

# --- Test Helpers ---
TEST_COUNT=0
FAIL_COUNT=0
TEST_TMPDIR=""

setup() {
    TEST_TMPDIR=$(mktemp -d "${TMPDIR:-/tmp}/phpswitcher-unit.XXXXXXXX")
    export PHPSWITCHER_DIR="$TEST_TMPDIR"
    mkdir -p "$PHPSWITCHER_DIR"
    echo "0.3.1" > "$PHPSWITCHER_DIR/VERSION"
}

teardown() {
    rm -rf "$TEST_TMPDIR" 2>/dev/null || true
}

trap teardown EXIT

test_case() {
    TEST_COUNT=$((TEST_COUNT + 1))
    echo "--- TEST: $1 ---"
}

report_success() {
    echo "✅ PASS: $1"
}

report_failure() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "❌ FAIL: $1"
}

assert_success() {
    local exit_code="$1"; shift
    if [ "$exit_code" -eq 0 ]; then
        report_success "$*"
    else
        report_failure "$* (exit $exit_code)"
    fi
}

assert_failure() {
    local exit_code="$1"; shift
    if [ "$exit_code" -ne 0 ]; then
        report_success "$*"
    else
        report_failure "$* (expected non-zero exit)"
    fi
}

assert_contains() {
    local string="$1"
    local substring="$2"
    local message="$3"
    if echo "$string" | grep -qF -- "$substring"; then
        report_success "$message"
    else
        report_failure "$message"
        echo "  Expected to find '$substring' in:"
        echo "  $string"
    fi
}

assert_not_contains() {
    local string="$1"
    local substring="$2"
    local message="$3"
    if ! echo "$string" | grep -qF -- "$substring"; then
        report_success "$message"
    else
        report_failure "$message"
        echo "  Did NOT expect to find '$substring' in:"
        echo "  $string"
    fi
}

assert_file_contents() {
    local file="$1"
    local expected="$2"
    local message="$3"
    if [ -f "$file" ] && [ "$(cat "$file")" = "$expected" ]; then
        report_success "$message"
    else
        report_failure "$message"
        if [ -f "$file" ]; then
            echo "  Expected: '$expected', got: '$(cat "$file")'"
        else
            echo "  File does not exist: $file"
        fi
    fi
}

assert_file_not_exists() {
    local file="$1"
    local message="$2"
    if [ ! -f "$file" ]; then
        report_success "$message"
    else
        report_failure "$message"
        echo "  File should not exist: $file"
    fi
}

# =============================================
# DEFAULT COMMAND TESTS
# =============================================

test_default_set() {
    setup
    test_case "default: set version writes file"
    local output
    output=$("$PHPSWITCHER" default 8.2 2>&1)
    assert_success $? "default 8.2 exits successfully"
    assert_file_contents "$PHPSWITCHER_DIR/default_version" "8.2" "default_version file contains 8.2"
    assert_contains "$output" "Global default PHP version set to 8.2" "Output confirms default was set"
    teardown
}

test_default_show() {
    setup
    echo "8.1" > "$PHPSWITCHER_DIR/default_version"

    test_case "default: show current default"
    local output
    output=$("$PHPSWITCHER" default 2>&1)
    assert_success $? "default (no args) exits successfully"
    assert_contains "$output" "8.1" "Output shows 8.1"
    assert_contains "$output" "Global default PHP version:" "Output has label"
    teardown
}

test_default_show_none() {
    setup
    test_case "default: show when none set"
    local output
    output=$("$PHPSWITCHER" default 2>&1)
    assert_success $? "default (no args, no file) exits successfully"
    assert_contains "$output" "No global default PHP version is set" "Output says none set"
    teardown
}

test_default_unset() {
    setup
    echo "8.1" > "$PHPSWITCHER_DIR/default_version"

    test_case "default: unset removes file"
    local output
    output=$("$PHPSWITCHER" default --unset 2>&1)
    assert_success $? "default --unset exits successfully"
    assert_file_not_exists "$PHPSWITCHER_DIR/default_version" "default_version file removed"
    teardown
}

test_default_unset_when_none() {
    setup
    test_case "default: unset when none set"
    local output
    output=$("$PHPSWITCHER" default --unset 2>&1)
    assert_success $? "default --unset (no file) exits successfully"
    assert_contains "$output" "No global default version is set" "Output says none set"
    teardown
}

test_default_invalid_version() {
    setup
    test_case "default: rejects invalid version format"
    local output
    output=$("$PHPSWITCHER" default "abc" 2>&1 || true)
    assert_contains "$output" "Invalid version format" "Rejects 'abc'"

    output=$("$PHPSWITCHER" default "8" 2>&1 || true)
    assert_contains "$output" "Invalid version format" "Rejects '8'"

    output=$("$PHPSWITCHER" default "8.1.2" 2>&1 || true)
    assert_contains "$output" "Invalid version format" "Rejects '8.1.2'"
    teardown
}

test_default_overwrite() {
    setup
    test_case "default: overwrite existing default"
    "$PHPSWITCHER" default 7.4 2>&1
    "$PHPSWITCHER" default 8.2 2>&1
    assert_file_contents "$PHPSWITCHER_DIR/default_version" "8.2" "default_version updated to 8.2"
    teardown
}

# =============================================
# STATUS COMMAND TESTS
# =============================================

test_status_header() {
    setup
    test_case "status: shows header"
    local output
    output=$("$PHPSWITCHER" status 2>&1)
    assert_success $? "status exits successfully"
    assert_contains "$output" "PHP Switcher Status" "Has title"
    assert_contains "$output" "===================" "Has separator"
    teardown
}

test_status_shows_active_version() {
    setup
    echo "8.1" > "$PHPSWITCHER_DIR/active_version"

    test_case "status: shows active version from file"
    local output
    output=$("$PHPSWITCHER" status 2>&1)
    assert_contains "$output" "Active PHP version: 8.1" "Shows active version 8.1"
    teardown
}

test_status_unknown_active_version() {
    setup
    test_case "status: shows unknown when no active_version file"
    local output
    output=$("$PHPSWITCHER" status 2>&1)
    assert_contains "$output" "Active PHP version: unknown" "Shows unknown"
    teardown
}

test_status_shows_default() {
    setup
    echo "8.2" > "$PHPSWITCHER_DIR/default_version"

    test_case "status: shows global default"
    local output
    output=$("$PHPSWITCHER" status 2>&1)
    assert_contains "$output" "Global default:     8.2" "Shows global default"
    teardown
}

test_status_no_default() {
    setup
    test_case "status: shows (not set) when no default"
    local output
    output=$("$PHPSWITCHER" status 2>&1)
    assert_contains "$output" "Global default:     (not set)" "Shows not set"
    teardown
}

test_status_detects_php_version_file() {
    setup
    local test_dir="$TEST_TMPDIR/project"
    mkdir -p "$test_dir"
    echo "7.4" > "$test_dir/.php-version"

    test_case "status: detects .php-version in current directory"
    local output
    output=$(cd "$test_dir" && "$PHPSWITCHER" status 2>&1)
    assert_contains "$output" "Detected version: 7.4" "Detects 7.4"
    assert_contains "$output" ".php-version" "Source is .php-version"
    teardown
}

test_status_detects_composer_json() {
    setup
    local test_dir="$TEST_TMPDIR/project"
    mkdir -p "$test_dir"
    echo '{"require": {"php": ">=8.1"}}' > "$test_dir/composer.json"

    test_case "status: detects composer.json constraint"
    local output
    output=$(cd "$test_dir" && "$PHPSWITCHER" status 2>&1)
    assert_contains "$output" "Detected version: 8.1" "Detects 8.1 from composer"
    assert_contains "$output" "composer.json" "Source is composer.json"
    teardown
}

test_status_detects_default_fallback() {
    setup
    echo "8.0" > "$PHPSWITCHER_DIR/default_version"
    local test_dir="$TEST_TMPDIR/empty_project"
    mkdir -p "$test_dir"

    test_case "status: falls back to global default"
    local output
    output=$(cd "$test_dir" && "$PHPSWITCHER" status 2>&1)
    assert_contains "$output" "Detected version: 8.0" "Detects 8.0 from default"
    assert_contains "$output" "global default" "Source is global default"
    teardown
}

test_status_no_detection() {
    setup
    local test_dir="$TEST_TMPDIR/bare"
    mkdir -p "$test_dir"

    test_case "status: no version detected"
    local output
    output=$(cd "$test_dir" && "$PHPSWITCHER" status 2>&1)
    assert_contains "$output" "No version detected" "Says no version detected"
    teardown
}

test_status_php_version_priority() {
    setup
    local test_dir="$TEST_TMPDIR/project"
    mkdir -p "$test_dir"
    echo "7.4" > "$test_dir/.php-version"
    echo '{"require": {"php": ">=8.1"}}' > "$test_dir/composer.json"
    echo "8.2" > "$PHPSWITCHER_DIR/default_version"

    test_case "status: .php-version takes priority over composer.json and default"
    local output
    output=$(cd "$test_dir" && "$PHPSWITCHER" status 2>&1)
    assert_contains "$output" "Detected version: 7.4" ".php-version wins"
    assert_contains "$output" ".php-version" "Source is .php-version"
    teardown
}

# =============================================
# EXTENSIONS COMMAND TESTS
# =============================================

test_extensions_no_version_no_active() {
    setup
    test_case "extensions: errors when no version and no active version"
    local output
    output=$("$PHPSWITCHER" extensions 2>&1 || true)
    assert_contains "$output" "Could not determine PHP version" "Error message shown"
    teardown
}

test_extensions_uses_active_version() {
    setup
    echo "8.1" > "$PHPSWITCHER_DIR/active_version"

    test_case "extensions: uses active version when none specified"
    # This will fail because PHP isn't actually installed, but it should
    # show the version it's trying to use
    local output
    output=$(timeout 5 "$PHPSWITCHER" extensions 2>&1 || true)
    assert_contains "$output" "8.1" "References active version 8.1"
    teardown
}

test_extensions_invalid_version() {
    setup
    test_case "extensions: rejects invalid version"
    local output
    output=$("$PHPSWITCHER" extensions "abc" 2>&1 || true)
    assert_contains "$output" "Unknown extensions subcommand: abc" "Rejects non-version non-subcommand"
    teardown
}

test_extensions_install_no_extension() {
    setup
    test_case "extensions install: errors when no extension specified"
    local output
    output=$("$PHPSWITCHER" extensions install 2>&1 || true)
    assert_contains "$output" "Please specify an extension to install" "Error for missing extension"
    teardown
}

test_extensions_install_no_version() {
    setup
    test_case "extensions install: errors when no version and no active version"
    local output
    output=$("$PHPSWITCHER" extensions install xdebug 2>&1 || true)
    assert_contains "$output" "Could not determine PHP version" "Error for missing version"
    teardown
}

test_extensions_install_uses_active() {
    setup
    echo "8.1" > "$PHPSWITCHER_DIR/active_version"

    test_case "extensions install: picks up active version (message check)"
    # We can't run the actual install (requires sudo/brew), but we can verify
    # the script resolves the active version by checking the message output.
    # Use timeout to avoid hanging on sudo prompts.
    local output
    output=$(timeout 5 "$PHPSWITCHER" extensions install xdebug 2>&1 || true)
    assert_contains "$output" "8.1" "References active version 8.1"
    teardown
}

test_extensions_install_invalid_version() {
    setup
    test_case "extensions install: rejects invalid version format"
    local output
    output=$(timeout 5 "$PHPSWITCHER" extensions install xdebug "bad" 2>&1 || true)
    assert_contains "$output" "Invalid version format" "Rejects 'bad'"
    teardown
}

test_extensions_list_subcommand() {
    setup
    test_case "extensions list: accepts explicit 'list' subcommand"
    local output
    # PHP may not be installed, so it'll error — but it should reference the version
    output=$(timeout 5 "$PHPSWITCHER" extensions list 8.1 2>&1 || true)
    assert_contains "$output" "8.1" "References version 8.1"
    teardown
}

# =============================================
# VERSION DETECTION FALLBACK TESTS
# =============================================

test_detect_version_php_version_file() {
    setup
    local test_dir="$TEST_TMPDIR/project"
    mkdir -p "$test_dir"
    echo "7.4" > "$test_dir/.php-version"

    test_case "detect_version: finds .php-version file"
    # The 'use' command triggers detect_version when no arg given.
    # It will fail at the actual switch but the detection message is enough.
    local output
    output=$(cd "$test_dir" && timeout 5 "$PHPSWITCHER" use 2>&1 || true)
    assert_contains "$output" "7.4" "Detected 7.4"
    assert_contains "$output" ".php-version" "Source is .php-version"
    teardown
}

test_detect_version_composer_json() {
    setup
    local test_dir="$TEST_TMPDIR/project"
    mkdir -p "$test_dir"
    echo '{"require": {"php": "^8.0"}}' > "$test_dir/composer.json"

    test_case "detect_version: finds composer.json constraint"
    local output
    output=$(cd "$test_dir" && timeout 5 "$PHPSWITCHER" use 2>&1 || true)
    assert_contains "$output" "8.0" "Detected 8.0"
    assert_contains "$output" "composer.json" "Source is composer.json"
    teardown
}

test_detect_version_default_fallback() {
    setup
    echo "8.2" > "$PHPSWITCHER_DIR/default_version"
    local test_dir="$TEST_TMPDIR/empty"
    mkdir -p "$test_dir"

    test_case "detect_version: falls back to global default"
    local output
    output=$(cd "$test_dir" && timeout 5 "$PHPSWITCHER" use 2>&1 || true)
    assert_contains "$output" "8.2" "Detected 8.2"
    assert_contains "$output" "global default" "Source is global default"
    teardown
}

test_detect_version_no_detection() {
    setup
    local test_dir="$TEST_TMPDIR/bare"
    mkdir -p "$test_dir"

    test_case "detect_version: fails when nothing found"
    local output
    output=$(cd "$test_dir" && timeout 5 "$PHPSWITCHER" use 2>&1 || true)
    assert_contains "$output" "could not be detected" "Shows detection failure"
    teardown
}

test_detect_version_priority_order() {
    setup
    local test_dir="$TEST_TMPDIR/project"
    mkdir -p "$test_dir"
    echo "7.4" > "$test_dir/.php-version"
    echo '{"require": {"php": ">=8.1"}}' > "$test_dir/composer.json"
    echo "8.2" > "$PHPSWITCHER_DIR/default_version"

    test_case "detect_version: .php-version wins over composer.json and default"
    local output
    output=$(cd "$test_dir" && timeout 5 "$PHPSWITCHER" use 2>&1 || true)
    assert_contains "$output" "7.4" ".php-version version 7.4 wins"
    assert_contains "$output" ".php-version" "Source is .php-version"
    teardown
}

test_detect_version_composer_over_default() {
    setup
    local test_dir="$TEST_TMPDIR/project"
    mkdir -p "$test_dir"
    echo '{"require": {"php": ">=8.1"}}' > "$test_dir/composer.json"
    echo "8.2" > "$PHPSWITCHER_DIR/default_version"

    test_case "detect_version: composer.json wins over default"
    local output
    output=$(cd "$test_dir" && timeout 5 "$PHPSWITCHER" use 2>&1 || true)
    assert_contains "$output" "8.1" "composer.json version 8.1 wins"
    assert_contains "$output" "composer.json" "Source is composer.json"
    teardown
}

# =============================================
# HELP COMMAND TESTS
# =============================================

test_help_includes_new_commands() {
    setup
    test_case "help: includes all new commands"
    local output
    output=$("$PHPSWITCHER" help 2>&1)
    assert_contains "$output" "default" "Help mentions default"
    assert_contains "$output" "status" "Help mentions status"
    assert_contains "$output" "extensions" "Help mentions extensions"
    assert_contains "$output" "phpswitcher default 8.2" "Help has default example"
    assert_contains "$output" "phpswitcher status" "Help has status example"
    assert_contains "$output" "phpswitcher extensions" "Help has extensions example"
    teardown
}

test_help_mentions_default_in_detection() {
    setup
    test_case "help: mentions default in version detection descriptions"
    local output
    output=$("$PHPSWITCHER" help 2>&1)
    assert_contains "$output" ".php-version, composer.json, or default" "Detection docs include default"
    teardown
}

# =============================================
# VERSION COMMAND TEST
# =============================================

test_version_command() {
    setup
    test_case "version: reads from VERSION file"
    local output
    output=$("$PHPSWITCHER" version 2>&1)
    assert_success $? "version exits successfully"
    assert_contains "$output" "phpswitcher version 0.3.1" "Shows correct version"
    teardown
}

# =============================================
# UNKNOWN COMMAND TEST
# =============================================

test_unknown_command() {
    setup
    test_case "unknown command: shows error and help"
    local output
    output=$("$PHPSWITCHER" foobar 2>&1 || true)
    assert_contains "$output" "Unknown command: foobar" "Shows unknown command error"
    assert_contains "$output" "Usage:" "Shows help"
    teardown
}

# =============================================
# QUIET MODE TEST
# =============================================

test_quiet_mode_default() {
    setup
    test_case "quiet mode: suppresses messages for default command"
    local output
    output=$("$PHPSWITCHER" default 8.1 --quiet 2>&1)
    assert_success $? "default with --quiet exits successfully"
    assert_file_contents "$PHPSWITCHER_DIR/default_version" "8.1" "File still written in quiet mode"
    assert_not_contains "$output" "Global default PHP version set to" "Message suppressed"
    teardown
}

# =============================================
# FISH SCRIPT FILE TESTS
# =============================================

test_fish_init_exists() {
    test_case "fish init: script file exists"
    if [ -f "$SCRIPT_DIR/bin/phpswitcher-init.fish" ]; then
        report_success "phpswitcher-init.fish exists"
    else
        report_failure "phpswitcher-init.fish missing"
    fi
}

test_fish_completion_exists() {
    test_case "fish completion: script file exists"
    if [ -f "$SCRIPT_DIR/bin/phpswitcher-completion.fish" ]; then
        report_success "phpswitcher-completion.fish exists"
    else
        report_failure "phpswitcher-completion.fish missing"
    fi
}

test_fish_init_contents() {
    test_case "fish init: contains auto-switch function"
    local content
    content=$(cat "$SCRIPT_DIR/bin/phpswitcher-init.fish")
    assert_contains "$content" "_phpswitcher_auto_switch" "Has auto-switch function"
    assert_contains "$content" "--on-variable PWD" "Uses PWD variable event"
    assert_contains "$content" ".php-version" "Checks .php-version"
    assert_contains "$content" "composer.json" "Checks composer.json"
    assert_contains "$content" "default_version" "Checks default version"
}

test_fish_completion_contents() {
    test_case "fish completion: contains all commands"
    local content
    content=$(cat "$SCRIPT_DIR/bin/phpswitcher-completion.fish")
    assert_contains "$content" "install" "Has install"
    assert_contains "$content" "uninstall" "Has uninstall"
    assert_contains "$content" "use" "Has use"
    assert_contains "$content" "default" "Has default"
    assert_contains "$content" "status" "Has status"
    assert_contains "$content" "extensions" "Has extensions"
    assert_contains "$content" "self-update" "Has self-update"
}

# =============================================
# BASH/ZSH COMPLETION SCRIPT TESTS
# =============================================

test_completion_commands_list() {
    test_case "completion: command list includes new commands"
    local content
    content=$(cat "$SCRIPT_DIR/bin/phpswitcher-completion.sh")
    assert_contains "$content" "default" "Completion has default"
    assert_contains "$content" "status" "Completion has status"
    assert_contains "$content" "extensions" "Completion has extensions"
}

# =============================================
# MAIN RUNNER
# =============================================

main() {
    echo "============================================"
    echo "  Running phpswitcher Unit Tests            "
    echo "============================================"
    echo ""

    # Default command
    test_default_set
    test_default_show
    test_default_show_none
    test_default_unset
    test_default_unset_when_none
    test_default_invalid_version
    test_default_overwrite

    # Status command
    test_status_header
    test_status_shows_active_version
    test_status_unknown_active_version
    test_status_shows_default
    test_status_no_default
    test_status_detects_php_version_file
    test_status_detects_composer_json
    test_status_detects_default_fallback
    test_status_no_detection
    test_status_php_version_priority

    # Extensions command
    test_extensions_no_version_no_active
    test_extensions_uses_active_version
    test_extensions_invalid_version
    test_extensions_install_no_extension
    test_extensions_install_no_version
    test_extensions_install_uses_active
    test_extensions_install_invalid_version
    test_extensions_list_subcommand

    # Version detection
    test_detect_version_php_version_file
    test_detect_version_composer_json
    test_detect_version_default_fallback
    test_detect_version_no_detection
    test_detect_version_priority_order
    test_detect_version_composer_over_default

    # Help
    test_help_includes_new_commands
    test_help_mentions_default_in_detection

    # Version
    test_version_command

    # Error handling
    test_unknown_command

    # Quiet mode
    test_quiet_mode_default

    # Fish scripts
    test_fish_init_exists
    test_fish_completion_exists
    test_fish_init_contents
    test_fish_completion_contents

    # Bash/Zsh completion
    test_completion_commands_list

    echo ""
    echo "--------------------------------------------"
    if [ "$FAIL_COUNT" -eq 0 ]; then
        echo "🎉 All $TEST_COUNT unit tests passed!"
        exit 0
    else
        echo "🔥 $FAIL_COUNT out of $TEST_COUNT unit tests failed."
        exit 1
    fi
}

main
