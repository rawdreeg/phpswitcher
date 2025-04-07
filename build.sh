#!/usr/bin/env bash

set -e # Exit on errors

# --- Configuration ---
# TODO: Maybe we should be getting the version dynamically (e.g., from a VERSION file or git tag)
VERSION="0.1.0"
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

# 1. Install/Update Composer dependencies (optimized for production)
echo_message "[1/4] Installing/optimizing Composer dependencies..."
composer install --no-dev --optimize-autoloader --no-interaction --no-progress || {
    echo_error "Composer install failed."
    exit 1
}
echo "Dependencies installed."

# 2. Clean and create staging directory
echo_message "[2/4] Preparing staging directory: $STAGING_DIR..."
rm -rf "$BUILD_DIR"
mkdir -p "$STAGING_DIR"
echo "Staging directory created."

# 3. Copy necessary files to staging directory
echo_message "[3/4] Copying application files..."
rsync -av --progress \
    --exclude='.git' \
    --exclude='.gitignore' \
    --exclude='.idea' \
    --exclude='.vscode' \
    --exclude='_build' \
    --exclude='build.sh' \
    --exclude='install.sh' \
    --exclude='.DS_Store' \
    --exclude='composer.lock' \
    . "$STAGING_DIR/" || {
        echo_error "Failed to copy files to staging directory."
        exit 1
    }
# Ensure vendor is copied, as rsync might exclude it if listed in .gitignore
if [ -d "vendor" ]; then
  cp -R "vendor" "$STAGING_DIR/"
fi
chmod +x "$STAGING_DIR/bin/phpswitcher"
echo "Files copied."

# 4. Create the archive
echo_message "[4/4] Creating archive: $ARCHIVE_NAME..."
(cd "$BUILD_DIR" && tar -czf "../$ARCHIVE_NAME" "phpswitcher-$VERSION") || {
    echo_error "Failed to create archive."
    exit 1
}
echo "Archive created: $(pwd)/$ARCHIVE_NAME"

# 5. Clean up staging directory
echo_message "Cleaning up..."
rm -rf "$BUILD_DIR"
echo "Build complete!"

exit 0 