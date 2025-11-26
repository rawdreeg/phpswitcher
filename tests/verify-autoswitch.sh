#!/usr/bin/env bash

# This script verifies that the automatic version switching feature works as intended.
# It simulates a user's shell environment after installation.

set -e
set -o pipefail

# --- Test Helpers ---
echo_message() {
    printf "\n\033[0;32m%s\033[0m\n" "$1"
}

echo_error() {
    printf "\n\033[0;31m%s\033[0m\n" "$1" >&2
}

# --- Test Setup ---
# Create a temporary directory for our test
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT # Cleanup on exit

# Mock the phpswitcher installation directory
export PHPSWITCHER_DIR="$TEST_DIR/.phpswitcher"
mkdir -p "$PHPSWITCHER_DIR/bin"

# Create a log file to track command calls
LOG_FILE="$TEST_DIR/commands.log"
touch "$LOG_FILE"

# Create a mock 'phpswitcher' command that logs its arguments
# This allows us to see if it was called correctly by the auto-switcher.
cat > "$PHPSWITCHER_DIR/bin/phpswitcher" <<EOF
#!/usr/bin/env bash
# This is a mock phpswitcher script for testing.
echo "phpswitcher \$@" >> "$LOG_FILE"
# When 'use' is called, create the active_version file to simulate a switch.
if [ "\$1" = "use" ]; then
    echo "\$2" > "$PHPSWITCHER_DIR/active_version"
fi
EOF
chmod +x "$PHPSWITCHER_DIR/bin/phpswitcher"

# Add the mock phpswitcher to our PATH for this script's session
export PATH="$PHPSWITCHER_DIR/bin:$PATH"

# Source the auto-switching script to activate the shell hooks
# This is the core of what we are testing.
# shellcheck source=../bin/phpswitcher.sh
source "$(dirname "$0")/../bin/phpswitcher.sh"

echo_message "Test setup complete. Running verification..."

# --- Test Execution ---

# 1. Simulate changing into a directory WITHOUT a .php-version file
echo_message "1. Testing 'cd' into a directory with no .php-version file..."
cd "$TEST_DIR"
if [ -s "$LOG_FILE" ]; then
    echo_error "FAIL: phpswitcher was called unexpectedly."
    cat "$LOG_FILE"
    exit 1
fi
echo "✅ PASS: phpswitcher was not called."

# 2. Create a project directory with a .php-version file
mkdir -p "$TEST_DIR/my-project"
echo "8.1" > "$TEST_DIR/my-project/.php-version"

# 3. Simulate changing into the project directory. This should trigger the switch.
echo_message "2. Testing 'cd' into a directory WITH a .php-version file..."
cd "$TEST_DIR/my-project"

# 4. Verification
echo_message "3. Verifying the results..."
if ! grep -q "phpswitcher use 8.1 --quiet" "$LOG_FILE"; then
    echo_error "FAIL: Expected phpswitcher to be called with 'use 8.1 --quiet'."
    echo "Log file content:"
    cat "$LOG_FILE"
    exit 1
fi
echo "✅ PASS: phpswitcher was called automatically to switch to version 8.1."

# 5. Simulate changing back out of the directory. This should not trigger anything.
truncate -s 0 "$LOG_FILE" # Clear the log file
cd "$TEST_DIR"
if [ -s "$LOG_FILE" ]; then
    echo_error "FAIL: phpswitcher was called unexpectedly when leaving the directory."
    cat "$LOG_FILE"
    exit 1
fi
echo "✅ PASS: phpswitcher was not called when leaving the project directory."


# 6. Test that switching does not happen if the version is already active
echo_message "4. Testing that switching is skipped if version is already active..."
cd "$TEST_DIR/my-project" # This will set the active version to 8.1
truncate -s 0 "$LOG_FILE" # Clear the log file for the next check

# cd into a subdirectory. The .php-version file should be found, but the version is
# already active, so no command should be run.
mkdir -p "$TEST_DIR/my-project/subdir"
cd "$TEST_DIR/my-project/subdir"

if [ -s "$LOG_FILE" ]; then
    echo_error "FAIL: phpswitcher was called even though the version was already active."
    cat "$LOG_FILE"
    exit 1
fi
echo "✅ PASS: phpswitcher was not called when the version was already active."


echo_message "----------------------------------------"
echo "🎉 Verification successful! The auto-switching feature works correctly."
exit 0
