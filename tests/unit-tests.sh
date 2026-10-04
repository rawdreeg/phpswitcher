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
    if [ -n "${FEDORA_SAVED_PATH:-}" ]; then
        PATH="$FEDORA_SAVED_PATH"
        unset FEDORA_SAVED_PATH
    fi
    unset PHPSWITCHER_OS_RELEASE PHPSWITCHER_FEDORA_ROOT DNF_LOG SUDO_LOG RPM_LOG APT_LOG ALT_LOG ALT_TARGET
    unset DNF_FAIL_REMI SUDO_DENY_N SUDO_REQUIRE_N
    TEST_TMPDIR=$(mktemp -d "${TMPDIR:-/tmp}/phpswitcher-unit.XXXXXXXX")
    export PHPSWITCHER_DIR="$TEST_TMPDIR"
    export PHPSWITCHER_NO_UPDATE_CHECK=1
    mkdir -p "$PHPSWITCHER_DIR"
    echo "0.3.1" > "$PHPSWITCHER_DIR/VERSION"
}

teardown() {
    if [ -n "${FEDORA_SAVED_PATH:-}" ]; then
        PATH="$FEDORA_SAVED_PATH"
        unset FEDORA_SAVED_PATH
    fi
    unset PHPSWITCHER_OS_RELEASE PHPSWITCHER_FEDORA_ROOT DNF_LOG SUDO_LOG RPM_LOG APT_LOG ALT_LOG ALT_TARGET
    unset DNF_FAIL_REMI SUDO_DENY_N SUDO_REQUIRE_N
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
    # A here-string avoids a pipe. grep -q exits early, and pipefail would
    # treat the resulting SIGPIPE as a failed match on a long string.
    if grep -qF -- "$substring" <<< "$string"; then
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
    if ! grep -qF -- "$substring" <<< "$string"; then
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

test_extensions_install_invalid_name() {
    setup
    test_case "extensions install: rejects an unsafe extension name"
    local output
    output=$("$PHPSWITCHER" extensions install '../evil' 2>&1 || true)
    assert_contains "$output" "Invalid extension name" "Rejects a path-like name"
    teardown
}

test_extensions_uninstall_no_extension() {
    setup
    test_case "extensions uninstall: errors when no extension specified"
    local output
    output=$("$PHPSWITCHER" extensions uninstall 2>&1 || true)
    assert_contains "$output" "Please specify an extension to uninstall" "Error for missing extension"
    teardown
}

test_extensions_uninstall_no_version() {
    setup
    test_case "extensions uninstall: errors when no version and no active version"
    local output
    output=$("$PHPSWITCHER" extensions uninstall xdebug 2>&1 || true)
    assert_contains "$output" "Could not determine PHP version" "Error for missing version"
    teardown
}

test_extensions_uninstall_invalid_version() {
    setup
    test_case "extensions uninstall: rejects invalid version format"
    local output
    output=$("$PHPSWITCHER" extensions uninstall xdebug "bad" 2>&1 || true)
    assert_contains "$output" "Invalid version format" "Rejects 'bad'"
    teardown
}

test_extensions_uninstall_invalid_name() {
    setup
    test_case "extensions uninstall: rejects an unsafe extension name"
    local output
    output=$("$PHPSWITCHER" extensions uninstall 'xdebug;rm' 2>&1 || true)
    assert_contains "$output" "Invalid extension name" "Rejects a name with a shell metacharacter"
    teardown
}

test_extensions_uninstall_uses_active() {
    setup
    echo "8.1" > "$PHPSWITCHER_DIR/active_version"

    test_case "extensions uninstall: picks up active version (message check)"
    # Stop before apt/pecl can block. The active-version line is printed first.
    local output
    output=$(timeout 5 "$PHPSWITCHER" extensions uninstall xdebug 2>&1 || true)
    assert_contains "$output" "Using active PHP version 8.1" "References active version 8.1"
    assert_contains "$output" "8.1" "Mentions PHP 8.1"
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
    assert_contains "$output" "extensions uninstall" "Help has extensions uninstall"
    teardown
}

test_help_mentions_default_in_detection() {
    setup
    test_case "help: mentions default in version detection descriptions"
    local output
    output=$("$PHPSWITCHER" help 2>&1)
    assert_contains "$output" "config.platform.php" "Detection docs include platform.php"
    assert_contains "$output" "or default." "Detection docs include default"
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
    test_case "fish init: delegates detection to phpswitcher"
    local content
    content=$(cat "$SCRIPT_DIR/bin/phpswitcher-init.fish")
    assert_contains "$content" "_phpswitcher_auto_switch" "Has auto-switch function"
    assert_contains "$content" "--on-variable PWD" "Uses PWD variable event"
    assert_contains "$content" "phpswitcher status" "Asks phpswitcher for the detected version"
    assert_contains "$content" "phpswitcher use" "Switches through phpswitcher use"
    assert_contains "$content" "PHPSWITCHER_NO_UPDATE_CHECK" "Skips the update check on cd"
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
    assert_contains "$content" "Remove an extension" "Offers extensions uninstall"
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
    assert_contains "$content" "list install uninstall" "Bash completion offers extensions subcommands"
}

test_linux_switch_includes_fpm() {
    test_case "linux switch: sets phar.phar and php-fpm when present"
    local content
    content=$(cat "$SCRIPT_DIR/bin/phpswitcher")
    assert_contains "$content" "phar.phar" "Switches phar.phar"
    assert_contains "$content" "php-fpm" "Switches php-fpm"
    assert_contains "$content" "/usr/sbin/php-fpm" "Looks for the sbin php-fpm binary"
}

test_checksum_scripts_refuse_without_match() {
    test_case "checksum: install and self-update verify before extract"
    local install_sh phps
    install_sh=$(cat "$SCRIPT_DIR/install.sh")
    phps=$(cat "$SCRIPT_DIR/bin/phpswitcher")
    assert_contains "$install_sh" "sha256sum -c phpswitcher.tar.gz.sha256" "Installer uses sha256sum -c"
    assert_contains "$phps" "sha256sum -c phpswitcher.tar.gz.sha256" "self-update uses sha256sum -c"
    assert_contains "$install_sh" "Refusing to extract" "Installer refuses a bad download"
    assert_contains "$phps" "Refusing to extract" "self-update refuses a bad download"
}

write_archive_checksum() {
    local dir="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        (cd "$dir" && sha256sum phpswitcher.tar.gz > phpswitcher.tar.gz.sha256)
    else
        (cd "$dir" && shasum -a 256 phpswitcher.tar.gz > phpswitcher.tar.gz.sha256)
    fi
}

test_checksum_accepts_matching_archive() {
    setup
    local dir="$TEST_TMPDIR/archive"
    mkdir -p "$dir/payload"
    echo 'phpswitcher' > "$dir/payload/README.md"
    tar -czf "$dir/phpswitcher.tar.gz" -C "$dir" payload
    write_archive_checksum "$dir"

    test_case "checksum: matching archive passes sha256sum -c"
    (
        # shellcheck disable=SC1091
        source "$SCRIPT_DIR/install.sh"
        verify_archive_checksum "$dir"
    )
    assert_success $? "sha256sum -c accepts the archive"
    teardown
}

test_checksum_rejects_tampered_archive() {
    setup
    local dir="$TEST_TMPDIR/archive"
    mkdir -p "$dir/payload"
    echo 'phpswitcher' > "$dir/payload/README.md"
    tar -czf "$dir/phpswitcher.tar.gz" -C "$dir" payload
    write_archive_checksum "$dir"
    printf 'x' >> "$dir/phpswitcher.tar.gz"

    test_case "checksum: flipped byte fails sha256sum -c"
    (
        # shellcheck disable=SC1091
        source "$SCRIPT_DIR/install.sh"
        verify_archive_checksum "$dir"
    )
    assert_failure $? "sha256sum -c rejects the archive"
    teardown
}

test_release_workflow_updates_versions() {
    test_case "release workflow: publishes a checksum and opens version PRs"
    local content
    content=$(cat "$SCRIPT_DIR/.github/workflows/release.yml")
    assert_contains "$content" "sync_existing" "Can sync an already published release"
    assert_contains "$content" "TAP_GITHUB_TOKEN" "Requires a token for the Homebrew tap"
    assert_contains "$content" "phpswitcher.tar.gz.sha256" "Uploads the checksum file"
    assert_contains "$content" "PHPSWITCHER_VERSION_FALLBACK" "Updates the embedded fallback"
    assert_contains "$content" "homebrew-phpswitcher" "Opens a pull request on the tap"
    assert_contains "$content" "5beacccc9e73005dae5770d49f0947de73e9d7093f2f04f45238b1a402df72a3" "Checks the published v0.5.0 digest"
}

# =============================================
# COMPOSER DETECTION
# =============================================

test_detect_platform_over_require() {
    setup
    local test_dir="$TEST_TMPDIR/project"
    mkdir -p "$test_dir"
    cat > "$test_dir/composer.json" << 'EOF'
{
  "require": {
    "php": ">=7.4"
  },
  "config": {
    "platform": {
      "php": "8.2.9"
    }
  }
}
EOF

    test_case "detect_version: config.platform.php wins over require.php"
    local output
    output=$(cd "$test_dir" && "$PHPSWITCHER" status 2>&1)
    assert_contains "$output" "Detected version: 8.2" "Platform pin 8.2 wins"
    assert_contains "$output" "platform" "Source notes platform"
    assert_not_contains "$output" "Detected version: 7.4" "require.php is not selected"
    teardown
}

test_detect_parent_composer_json() {
    setup
    local test_dir="$TEST_TMPDIR/project"
    mkdir -p "$test_dir/subdir"
    echo '{"require":{"php":"^8.3"}}' > "$test_dir/composer.json"

    test_case "detect_version: finds composer.json in a parent directory"
    local output
    output=$(cd "$test_dir/subdir" && "$PHPSWITCHER" status 2>&1)
    assert_contains "$output" "Detected version: 8.3" "Detected 8.3 from parent composer.json"
    assert_contains "$output" "composer.json" "Source is composer.json"
    teardown
}

test_detect_nearest_composer_json() {
    setup
    local test_dir="$TEST_TMPDIR/project"
    mkdir -p "$test_dir/nested"
    echo '{"require":{"php":"^8.0"}}' > "$test_dir/composer.json"
    echo '{"require":{"php":"^8.3"}}' > "$test_dir/nested/composer.json"

    test_case "detect_version: nearest composer.json wins"
    local output
    output=$(cd "$test_dir/nested" && "$PHPSWITCHER" status 2>&1)
    assert_contains "$output" "Detected version: 8.3" "Nested composer.json wins"
    assert_not_contains "$output" "Detected version: 8.0" "Parent composer.json is ignored"
    teardown
}

# =============================================
# VERSION RESOLUTION
# =============================================

test_version_fallback() {
    setup
    rm -f "$PHPSWITCHER_DIR/VERSION"

    test_case "version: falls back when no VERSION file exists"
    local output
    output=$("$PHPSWITCHER" version 2>&1)
    assert_success $? "version exits successfully without a VERSION file"
    local fallback
    fallback=$(sed -n 's/^PHPSWITCHER_VERSION_FALLBACK="\([^"]*\)"/\1/p' "$PHPSWITCHER")
    assert_contains "$output" "phpswitcher version ${fallback}" "Uses the embedded fallback"
    teardown
}

test_version_beside_script() {
    setup
    rm -f "$PHPSWITCHER_DIR/VERSION"
    mkdir -p "$TEST_TMPDIR/bin"
    cp "$PHPSWITCHER" "$TEST_TMPDIR/bin/phpswitcher"
    chmod +x "$TEST_TMPDIR/bin/phpswitcher"
    echo "9.9.9" > "$TEST_TMPDIR/bin/VERSION"

    test_case "version: reads VERSION next to the script"
    local output
    output=$("$TEST_TMPDIR/bin/phpswitcher" version 2>&1)
    assert_contains "$output" "phpswitcher version 9.9.9" "Uses the sibling VERSION file"
    teardown
}

test_version_parent_of_script() {
    setup
    local state="$TEST_TMPDIR/state"
    mkdir -p "$state" "$TEST_TMPDIR/bin"
    export PHPSWITCHER_DIR="$state"
    cp "$PHPSWITCHER" "$TEST_TMPDIR/bin/phpswitcher"
    chmod +x "$TEST_TMPDIR/bin/phpswitcher"
    echo "8.8.8" > "$TEST_TMPDIR/VERSION"

    test_case "version: reads VERSION above the bin directory"
    local output
    output=$("$TEST_TMPDIR/bin/phpswitcher" version 2>&1)
    assert_contains "$output" "phpswitcher version 8.8.8" "Uses the parent VERSION file"
    teardown
}

# =============================================
# FEDORA / DNF
# =============================================

write_executable() {
    local path="$1"
    shift
    mkdir -p "$(dirname "$path")"
    printf '%s\n' "$@" > "$path"
    chmod +x "$path"
}

fedora_write_stubs() {
    local bindir="$1"
    mkdir -p "$bindir"

    cat > "$bindir/dnf" << 'EOF'
#!/bin/bash
printf '%s\n' "$*" >> "${DNF_LOG:?}"
cmd=""
pkg=""
for arg in "$@"; do
    case "$arg" in
        -q|-y|--enabled) ;;
        info|install|remove|repolist|list) cmd="$arg" ;;
        *)
            if [ -z "$pkg" ]; then
                pkg="$arg"
            fi
            ;;
    esac
done
if [ "$cmd" = "repolist" ]; then
    exit 1
fi
if [ "$cmd" = "install" ] && [[ "$pkg" == *remi-release* ]] && [ "${DNF_FAIL_REMI:-}" = "1" ]; then
    exit 1
fi
if [ "$cmd" = "install" ] && [ "${DNF_FAIL_PACKAGE:-}" = "$pkg" ]; then
    exit 1
fi
if [ "$cmd" = "info" ]; then
    case "$pkg" in
        php82-php-mbstring|php81-php-xml) exit 0 ;;
        php82-php-xdebug) exit 1 ;;
        php82-php-pecl-xdebug) exit 0 ;;
        *) exit 1 ;;
    esac
fi
exit 0
EOF

    cat > "$bindir/sudo" << 'EOF'
#!/bin/bash
printf 'sudo %s\n' "$*" >> "${SUDO_LOG:?}"
if [ "${1:-}" = "-n" ]; then
    if [ "${SUDO_DENY_N:-}" = "1" ]; then
        printf 'denied -n\n' >> "${SUDO_LOG}"
        exit 1
    fi
    shift
elif [ "${SUDO_REQUIRE_N:-}" = "1" ]; then
    printf 'plain sudo blocked\n' >> "${SUDO_LOG}"
    exit 99
fi
"$@"
EOF

    cat > "$bindir/rpm" << 'EOF'
#!/bin/bash
printf 'rpm %s\n' "$*" >> "${RPM_LOG:?}"
if [ "${1:-}" = "-q" ]; then
    case "${2:-}" in
        php81-php-pecl-redis) exit 0 ;;
        *) exit 1 ;;
    esac
fi
if [ "${1:-}" = "-qa" ]; then
    printf '%s\n' "php74" "php74-php-cli" "php74-runtime" "php81-php-cli"
    exit 0
fi
exit 1
EOF

    cat > "$bindir/apt-get" << 'EOF'
#!/bin/bash
printf 'apt-get %s\n' "$*" >> "${APT_LOG:?}"
exit 99
EOF

    cat > "$bindir/add-apt-repository" << 'EOF'
#!/bin/bash
printf 'add-apt-repository %s\n' "$*" >> "${APT_LOG:?}"
exit 99
EOF

    chmod +x "$bindir/dnf" "$bindir/sudo" "$bindir/rpm" "$bindir/apt-get" "$bindir/add-apt-repository"
}

fedora_test_env() {
    local bindir="$TEST_TMPDIR/fedora-bin"
    local root="$TEST_TMPDIR/fedora-root"
    FEDORA_SAVED_PATH="$PATH"
    mkdir -p "$root/etc/yum.repos.d" "$root/usr/bin"
    printf '%s\n' 'remi-safe enabled' > "$root/etc/yum.repos.d/remi-safe.repo"
    cat > "$TEST_TMPDIR/fedora-os-release" << 'EOF'
NAME="Fedora Linux"
ID=fedora
VERSION_ID=43
EOF
    export PHPSWITCHER_OS_RELEASE="$TEST_TMPDIR/fedora-os-release"
    export PHPSWITCHER_FEDORA_ROOT="$root"
    export DNF_LOG="$TEST_TMPDIR/dnf.log"
    export SUDO_LOG="$TEST_TMPDIR/sudo.log"
    export RPM_LOG="$TEST_TMPDIR/rpm.log"
    export APT_LOG="$TEST_TMPDIR/apt.log"
    export ALT_LOG="$TEST_TMPDIR/alt.log"
    : > "$DNF_LOG"
    : > "$SUDO_LOG"
    : > "$RPM_LOG"
    : > "$APT_LOG"
    : > "$ALT_LOG"
    fedora_write_stubs "$bindir"
    PATH="$bindir:$FEDORA_SAVED_PATH"
    export PATH
}

fedora_php_fixture() {
    local version="$1"
    local scl="php${version//./}"
    local root="$PHPSWITCHER_FEDORA_ROOT"
    write_executable "$root/usr/bin/${scl}" '#!/bin/sh' 'printf "%s\n" "[PHP Modules]" "xdebug" "mbstring"'
    mkdir -p "$root/opt/remi/${scl}/root/usr/bin" "$root/opt/remi/${scl}/root/usr/sbin"
    write_executable "$root/opt/remi/${scl}/root/usr/bin/phpize" '#!/bin/sh' 'printf "%s\n" phpize'
    write_executable "$root/opt/remi/${scl}/root/usr/bin/phar.phar" '#!/bin/sh' 'printf "%s\n" phar.phar'
    write_executable "$root/opt/remi/${scl}/root/usr/sbin/php-fpm" '#!/bin/sh' 'printf "%s\n" php-fpm'
    write_executable "$root/usr/bin/${scl}-phar" '#!/bin/sh' 'printf "%s\n" phar'
    write_executable "$root/usr/bin/${scl}-phpdbg" '#!/bin/sh' 'printf "%s\n" phpdbg'
}

test_fedora_family_chooses_remi_paths() {
    setup
    fedora_test_env
    test_case "fedora: use looks up Remi binaries, not /usr/bin/phpX.Y"
    local output
    output=$("$PHPSWITCHER" use 9.9 2>&1 || true)
    assert_contains "$output" "/usr/bin/php99" "Names the Remi wrapper"
    assert_contains "$output" "/opt/remi/php99/root/usr/bin/php" "Names the SCL binary"
    assert_not_contains "$output" "/usr/bin/php9.9" "Does not use the Debian binary path"
    if [ -s "$SUDO_LOG" ]; then
        report_failure "sudo log should stay empty when the binary is missing"
        echo "  sudo log: $(cat "$SUDO_LOG")"
    else
        report_success "sudo log stays empty when the binary is missing"
    fi
    teardown
}

test_ubuntu_family_keeps_apt_paths() {
    setup
    fedora_test_env
    cat > "$TEST_TMPDIR/ubuntu-os-release" << 'EOF'
ID=ubuntu
ID_LIKE=debian
VERSION_ID="24.04"
EOF
    export PHPSWITCHER_OS_RELEASE="$TEST_TMPDIR/ubuntu-os-release"
    test_case "ubuntu: use keeps /usr/bin/phpX.Y even when dnf is on PATH"
    local output
    output=$("$PHPSWITCHER" use 9.9 2>&1 || true)
    assert_contains "$output" "/usr/bin/php9.9" "Uses the Debian binary path"
    assert_not_contains "$output" "php99" "Does not use a Remi SCL name"
    if [ -s "$DNF_LOG" ]; then
        report_failure "dnf should not run for an Ubuntu os-release"
        echo "  dnf log: $(cat "$DNF_LOG")"
    else
        report_success "dnf is not invoked"
    fi
    teardown
}

test_fedora_install_uses_dnf_and_symlinks() {
    setup
    fedora_test_env
    fedora_php_fixture "8.2"
    mkdir -p "$PHPSWITCHER_DIR/bin"
    # The installer puts this directory on PATH. Include it so the warning stays quiet.
    PATH="${PHPSWITCHER_DIR}/bin:${PATH}"
    test_case "fedora install: dnf installs php82 and use symlinks the Remi tools"
    local output status
    status=0
    output=$("$PHPSWITCHER" install 8.2 2>&1) || status=$?
    assert_success "$status" "install 8.2 exits successfully"
    # assert_success consumed the previous status. Re-check the log instead of the lost status.
    assert_contains "$output" "php82" "Mentions the Remi package"
    assert_contains "$(cat "$DNF_LOG")" "install -y php82 php82-php-cli" "dnf installs the SCL and CLI packages"
    assert_not_contains "$(cat "$DNF_LOG")" "remi-release" "Existing remi-safe repo skips the release RPM"
    assert_not_contains "$(cat "$APT_LOG")" "apt-get" "apt-get is not used"
    assert_file_contents "$PHPSWITCHER_DIR/active_version" "8.2" "active_version is 8.2"
    local php_target
    php_target=$(readlink "$PHPSWITCHER_DIR/bin/php")
    assert_contains "$php_target" "/usr/bin/php82" "php symlink targets the Remi wrapper"
    assert_contains "$(readlink "$PHPSWITCHER_DIR/bin/phar.phar")" "phar.phar" "phar.phar symlink is created"
    assert_contains "$(readlink "$PHPSWITCHER_DIR/bin/php-fpm")" "/usr/sbin/php-fpm" "php-fpm symlink targets the SCL sbin binary"
    if grep -q 'plain sudo blocked' "$SUDO_LOG" 2>/dev/null; then
        report_failure "install/use should not block on a sudo password"
    else
        report_success "package install sudo ran through the stub"
    fi
    teardown
}

test_fedora_install_missing_repo() {
    setup
    fedora_test_env
    rm -f "$PHPSWITCHER_FEDORA_ROOT/etc/yum.repos.d/remi-safe.repo"
    export DNF_FAIL_REMI=1
    test_case "fedora install: missing Remi repo fails before a PHP package install"
    local output
    output=$("$PHPSWITCHER" install 8.1 2>&1 || true)
    assert_contains "$output" "Failed to install the Remi repository" "Reports the repository failure"
    assert_contains "$output" "remi-release-43.rpm" "Uses VERSION_ID from os-release"
    assert_contains "$(cat "$DNF_LOG")" "https://rpms.remirepo.net/fedora/remi-release-43.rpm" "Attempts the Remi release package"
    assert_not_contains "$(cat "$DNF_LOG")" "install -y php81 php81-php-cli" "Does not install PHP after the repo failure"
    teardown
}

test_fedora_install_rejects_bad_version() {
    setup
    fedora_test_env
    test_case "fedora install: rejects an unsafe version before dnf"
    local output
    output=$("$PHPSWITCHER" install "8.1;rm" 2>&1 || true)
    assert_contains "$output" "Invalid version format" "Rejects a version with a shell metacharacter"
    output=$("$PHPSWITCHER" install "8" 2>&1 || true)
    assert_contains "$output" "Invalid version format" "Rejects a major-only version"
    if [ -s "$DNF_LOG" ]; then
        report_failure "dnf should not run for an invalid version"
        echo "  dnf log: $(cat "$DNF_LOG")"
    else
        report_success "dnf is not invoked"
    fi
    teardown
}

test_fedora_missing_dnf() {
    setup
    local dir="$TEST_TMPDIR/no-dnf"
    local tool src
    mkdir -p "$dir"
    for tool in bash sh cat mkdir ln readlink rm grep sed chmod; do
        src=$(command -v "$tool" 2>/dev/null || true)
        if [ -n "$src" ]; then
            ln -s "$src" "$dir/$tool"
        fi
    done
    FEDORA_SAVED_PATH="$PATH"
    PATH="$dir"
    cat > "$TEST_TMPDIR/fedora-os-release" << 'EOF'
ID=fedora
VERSION_ID=43
EOF
    export PHPSWITCHER_OS_RELEASE="$TEST_TMPDIR/fedora-os-release"
    test_case "fedora install: missing dnf fails without sudo"
    local output
    output=$("$PHPSWITCHER" install 8.1 2>&1 || true)
    assert_contains "$output" "dnf" "Names dnf in the error"
    assert_contains "$output" "not available" "Says dnf is not available"
    teardown
}

test_fedora_quiet_use_does_not_block_on_sudo() {
    setup
    fedora_test_env
    fedora_php_fixture "8.1"
    export SUDO_DENY_N=1
    export SUDO_REQUIRE_N=1
    export ALT_TARGET="${PHPSWITCHER_FEDORA_ROOT}/usr/bin/php81"
    cat > "$TEST_TMPDIR/fedora-bin/update-alternatives" << 'EOF'
#!/bin/bash
printf '%s\n' "$*" >> "${ALT_LOG:?}"
if [ "${1:-}" = "--list" ]; then
    printf '%s\n' "${ALT_TARGET:-}"
    exit 0
fi
exit 0
EOF
    chmod +x "$TEST_TMPDIR/fedora-bin/update-alternatives"
    test_case "fedora quiet use: sudo -n failure still switches with a symlink"
    local output status
    status=0
    output=$("$PHPSWITCHER" use 8.1 --quiet 2>&1) || status=$?
    assert_success "$status" "quiet use exits successfully"
    assert_not_contains "$output" "Successfully switched" "Quiet mode suppresses the success message"
    assert_file_contents "$PHPSWITCHER_DIR/active_version" "8.1" "active_version is 8.1"
    local php_target
    php_target=$(readlink "$PHPSWITCHER_DIR/bin/php")
    assert_contains "$php_target" "/usr/bin/php81" "Symlink is written when sudo -n cannot set alternatives"
    assert_contains "$(cat "$SUDO_LOG")" "sudo -n" "Quiet mode asks sudo for a non-interactive check"
    assert_not_contains "$(cat "$SUDO_LOG")" "plain sudo blocked" "Quiet mode does not call sudo without -n"
    teardown
}

test_fedora_list_marks_active_version() {
    setup
    fedora_test_env
    fedora_php_fixture "8.1"
    fedora_php_fixture "8.2"
    "$PHPSWITCHER" use 8.2 --quiet >/dev/null 2>&1 || true
    test_case "fedora list: shows Remi versions and the active symlink"
    local output
    output=$("$PHPSWITCHER" list 2>&1 || true)
    assert_contains "$output" "via Remi" "List header names Remi"
    assert_contains "$output" "* 8.2 (active)" "Marks 8.2 active"
    assert_contains "$output" "8.1" "Lists 8.1"
    teardown
}

test_fedora_uninstall_refuses_active_and_removes_other() {
    setup
    fedora_test_env
    fedora_php_fixture "8.1"
    fedora_php_fixture "7.4"
    "$PHPSWITCHER" use 8.1 --quiet >/dev/null 2>&1 || true
    : > "$DNF_LOG"
    : > "$SUDO_LOG"
    test_case "fedora uninstall: active version is kept, another version uses dnf remove"
    local output
    output=$("$PHPSWITCHER" uninstall 8.1 2>&1 || true)
    assert_contains "$output" "currently active version" "Refuses to remove the active version"
    assert_not_contains "$DNF_LOG" "remove" "Active version does not call dnf remove"
    output=$("$PHPSWITCHER" uninstall 7.4 2>&1 || true)
    assert_contains "$output" "uninstalled successfully" "Removes an inactive version"
    assert_contains "$(cat "$DNF_LOG")" "remove -y php74 php74-php-cli php74-runtime" "dnf remove gets the php74 packages from rpm"
    assert_not_contains "$(cat "$APT_LOG")" "apt-get" "apt-get is not used"
    teardown
}

test_fedora_extension_names() {
    setup
    fedora_test_env
    fedora_php_fixture "8.2"
    test_case "fedora extensions: version and package name checks"
    local output
    output=$("$PHPSWITCHER" extensions install '../xdebug' 8.2 2>&1 || true)
    assert_contains "$output" "Invalid extension name" "Rejects a path-like extension name"
    output=$("$PHPSWITCHER" extensions install xdebug "8" 2>&1 || true)
    assert_contains "$output" "Invalid version format" "Rejects a bad extension version"
    if [ -s "$DNF_LOG" ]; then
        report_failure "dnf should not run for an invalid extension or version"
        echo "  dnf log: $(cat "$DNF_LOG")"
    else
        report_success "dnf is not invoked for invalid extension input"
    fi
    : > "$DNF_LOG"
    output=$("$PHPSWITCHER" extensions install xdebug 8.2 2>&1 || true)
    assert_contains "$output" "php82-php-pecl-xdebug" "PECL extension uses the php82-php-pecl- name"
    assert_contains "$(cat "$DNF_LOG")" "install -y php82-php-pecl-xdebug" "dnf installs the PECL package"
    assert_not_contains "$(cat "$DNF_LOG")" "install -y php82-php-xdebug" "The missing core package is not installed"
    output=$("$PHPSWITCHER" extensions install mbstring 8.2 2>&1 || true)
    assert_contains "$(cat "$DNF_LOG")" "install -y php82-php-mbstring" "Core extension uses php82-php-mbstring"
    output=$("$PHPSWITCHER" extensions 8.2 2>&1 || true)
    assert_contains "$output" "xdebug" "Lists modules from the Remi binary"
    output=$("$PHPSWITCHER" extensions uninstall redis 8.1 2>&1 || true)
    assert_contains "$output" "php81-php-pecl-redis" "Uninstall removes the installed PECL package"
    assert_contains "$(cat "$DNF_LOG")" "remove -y php81-php-pecl-redis" "dnf remove is used for the extension"
    teardown
}

test_fedora_detection_is_single() {
    test_case "fedora detection: one function, shell hooks do not reimplement it"
    local defs fish_init bash_init
    defs=$(grep -c '^detect_linux_family()' "$PHPSWITCHER" || true)
    if [ "$defs" = "1" ]; then
        report_success "detect_linux_family is defined once"
    else
        report_failure "detect_linux_family should be defined once (found $defs)"
    fi
    fish_init=$(cat "$SCRIPT_DIR/bin/phpswitcher-init.fish")
    bash_init=$(cat "$SCRIPT_DIR/bin/phpswitcher-init.sh")
    assert_not_contains "$fish_init" "os-release" "Fish hook does not read os-release"
    assert_not_contains "$bash_init" "os-release" "Bash hook does not read os-release"
    assert_contains "$fish_init" "phpswitcher use" "Fish still switches through the CLI"
    assert_contains "$bash_init" "phpswitcher use" "Bash still switches through the CLI"
}

test_help_mentions_fedora() {
    setup
    test_case "help: mentions Fedora, dnf, and Remi"
    local output
    output=$("$PHPSWITCHER" help 2>&1)
    assert_contains "$output" "Fedora" "Help mentions Fedora"
    assert_contains "$output" "dnf" "Help mentions dnf"
    assert_contains "$output" "Remi" "Help mentions Remi"
    assert_contains "$output" "php81" "Help mentions the SCL package name"
    assert_contains "$output" "Debian/Ubuntu" "Help still documents Debian/Ubuntu"
    teardown
}

# =============================================
# SHELL INTEGRATION
# =============================================

test_status_shell_integration_missing() {
    setup
    local home="$TEST_TMPDIR/home"
    mkdir -p "$home"
    printf 'export PHPSWITCHER_DIR="%s"\n' "$PHPSWITCHER_DIR" > "$home/.bashrc"

    test_case "status: reports a profile that does not source the hook"
    local output
    output=$(HOME="$home" SHELL=/bin/bash "$PHPSWITCHER" status 2>&1)
    assert_contains "$output" "Shell integration:" "Status has a shell integration section"
    assert_contains "$output" "not installed" "Hook is reported missing"
    assert_contains "$output" "$home/.bashrc" "Profile path is shown"
    teardown
}

test_status_shell_integration_enabled() {
    setup
    local home="$TEST_TMPDIR/home"
    mkdir -p "$home"
    printf 'source "$PHPSWITCHER_DIR/phpswitcher-init.sh"\n' > "$home/.bashrc"

    test_case "status: reports an enabled shell hook"
    local output
    output=$(HOME="$home" SHELL=/bin/bash "$PHPSWITCHER" status 2>&1)
    assert_contains "$output" "enabled" "Hook is reported enabled"
    teardown
}

test_installer_repairs_missing_hook() {
    setup
    local home="$TEST_TMPDIR/home"
    local install_dir="$TEST_TMPDIR/install-root"
    mkdir -p "$home" "$install_dir"
    printf 'export PHPSWITCHER_DIR="%s"\n' "$install_dir" > "$home/.bashrc"

    test_case "installer: adds hook lines when PHPSWITCHER_DIR is already set"
    (
        export HOME="$home"
        export SHELL=/bin/bash
        export PHPSWITCHER_DIR="$install_dir"
        # shellcheck disable=SC1091
        source "$SCRIPT_DIR/install.sh"
        configure_shell_profile
    )
    assert_success $? "configure_shell_profile exits successfully"
    local profile
    profile=$(cat "$home/.bashrc")
    assert_contains "$profile" "phpswitcher-init.sh" "Init hook was added"
    assert_contains "$profile" "phpswitcher-completion.sh" "Completion hook was added"

    test_case "installer: does not duplicate hook lines"
    (
        export HOME="$home"
        export SHELL=/bin/bash
        export PHPSWITCHER_DIR="$install_dir"
        # shellcheck disable=SC1091
        source "$SCRIPT_DIR/install.sh"
        configure_shell_profile
    )
    local count
    count=$(grep -c "phpswitcher-init.sh" "$home/.bashrc")
    if [ "$count" -eq 1 ]; then
        report_success "Init hook appears once"
    else
        report_failure "Init hook appears $count times"
    fi
    teardown
}

test_installer_repairs_fish_hook() {
    setup
    local home="$TEST_TMPDIR/home"
    local install_dir="$TEST_TMPDIR/install-root"
    mkdir -p "$home/.config/fish/conf.d" "$install_dir"
    printf 'set -gx PHPSWITCHER_DIR "%s"\n' "$install_dir" > "$home/.config/fish/conf.d/phpswitcher.fish"

    test_case "installer: adds Fish hook lines to an existing config"
    (
        export HOME="$home"
        export SHELL=/usr/bin/fish
        export PHPSWITCHER_DIR="$install_dir"
        # shellcheck disable=SC1091
        source "$SCRIPT_DIR/install.sh"
        configure_shell_profile
    )
    assert_success $? "configure_shell_profile exits successfully for fish"
    local profile
    profile=$(cat "$home/.config/fish/conf.d/phpswitcher.fish")
    assert_contains "$profile" "phpswitcher-init.fish" "Fish init hook was added"
    assert_contains "$profile" "phpswitcher-completion.fish" "Fish completion hook was added"
    teardown
}

test_bash_init_delegates() {
    test_case "bash init: delegates detection to phpswitcher"
    local content
    content=$(cat "$SCRIPT_DIR/bin/phpswitcher-init.sh")
    assert_contains "$content" "phpswitcher status" "Asks phpswitcher for the detected version"
    assert_contains "$content" "phpswitcher use" "Switches through phpswitcher use"
    assert_contains "$content" "--quiet" "Auto-switch is quiet"
    assert_contains "$content" "PHPSWITCHER_NO_UPDATE_CHECK" "Skips the update check on cd"
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
    test_extensions_install_invalid_name
    test_extensions_list_subcommand
    test_extensions_uninstall_no_extension
    test_extensions_uninstall_no_version
    test_extensions_uninstall_invalid_version
    test_extensions_uninstall_invalid_name
    test_extensions_uninstall_uses_active

    # Version detection
    test_detect_version_php_version_file
    test_detect_version_composer_json
    test_detect_version_default_fallback
    test_detect_version_no_detection
    test_detect_version_priority_order
    test_detect_version_composer_over_default
    test_detect_platform_over_require
    test_detect_parent_composer_json
    test_detect_nearest_composer_json

    # Help
    test_help_includes_new_commands
    test_help_mentions_default_in_detection

    # Version
    test_version_command
    test_version_fallback
    test_version_beside_script
    test_version_parent_of_script

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
    test_linux_switch_includes_fpm
    test_fedora_family_chooses_remi_paths
    test_ubuntu_family_keeps_apt_paths
    test_fedora_install_uses_dnf_and_symlinks
    test_fedora_install_missing_repo
    test_fedora_install_rejects_bad_version
    test_fedora_missing_dnf
    test_fedora_quiet_use_does_not_block_on_sudo
    test_fedora_list_marks_active_version
    test_fedora_uninstall_refuses_active_and_removes_other
    test_fedora_extension_names
    test_fedora_detection_is_single
    test_help_mentions_fedora
    test_checksum_scripts_refuse_without_match
    test_checksum_accepts_matching_archive
    test_checksum_rejects_tampered_archive
    test_release_workflow_updates_versions

    # Shell integration
    test_status_shell_integration_missing
    test_status_shell_integration_enabled
    test_installer_repairs_missing_hook
    test_installer_repairs_fish_hook
    test_bash_init_delegates

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
