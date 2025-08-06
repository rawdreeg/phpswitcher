#!/usr/bin/env bash

set -e # Exit on errors

# --- Configuration ---
VERSION="1.0.0" # New version for the bash rewrite
ARCHIVE_NAME="phpswitcher.tar.gz"
BUILD_DIR="_build"
STAGING_DIR="$BUILD_DIR/phpswitcher-$VERSION"

# --- Helper Functions ---
echo_message() {
  printf "\n\033[0;32m%s\033[0m\n" "$1"
}

echo_error() {
  printf "\n\033[0;31m%s\033[0m\n" "$1" >&2
}

# --- Build Steps ---
echo_message "Starting build process for phpswitcher v$VERSION..."

# 1. Clean and create staging directory
echo_message "[1/3] Preparing staging directory: $STAGING_DIR..."
rm -rf "$BUILD_DIR"
mkdir -p "$STAGING_DIR/bin"
echo "Staging directory created."

# 2. Copy necessary files to staging directory
echo_message "[2/3] Copying application files..."
cp "bin/phpswitcher" "$STAGING_DIR/bin/"
cp "README.md" "$STAGING_DIR/"
chmod +x "$STAGING_DIR/bin/phpswitcher"
echo "Files copied."

# 3. Create the archive
echo_message "[3/3] Creating archive: $ARCHIVE_NAME..."
(cd "$BUILD_DIR" && tar -czf "../$ARCHIVE_NAME" "phpswitcher-$VERSION") || {
    echo_error "Failed to create archive."
    exit 1
}
echo "Archive created: $(pwd)/$ARCHIVE_NAME"

# Clean up staging directory
echo_message "Cleaning up..."
rm -rf "$BUILD_DIR"
echo "Build complete!"

exit 0 