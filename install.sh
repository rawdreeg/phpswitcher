#!/usr/bin/env bash

set -e # Exit immediately if a command exits with a non-zero status.

# Define installation directory
export PHPSWITCHER_DIR="${PHPSWITCHER_DIR:-$HOME/.phpswitcher}"
INSTALL_DIR="$PHPSWITCHER_DIR"

# Helper function for printing messages
echo_message() {
  printf "\n%s\n" "$1"
}

echo_error() {
  printf "\n\033[0;31m%s\033[0m\n" "$1" >&2
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Fetch the latest release artifact URL
ARTIFACT_URL=$(curl -s https://api.github.com/repos/rawdreeg/phpswitcher/releases/latest | grep 'browser_download_url.*phpswitcher\.tar\.gz' | cut -d '"' -f 4)
if [ -z "$ARTIFACT_URL" ]; then
    echo_error "Could not find the latest release artifact URL. Please check the repository."
    exit 1
fi
ARTIFACT_NAME="phpswitcher.tar.gz"

# --- Dependency Checks ---
echo_message "Checking dependencies..."

if ! command_exists tar; then
  echo_error "Error: tar is not installed. Please install tar and try again."
  exit 1
fi

if ! command_exists curl; then
  echo_error "Error: curl is required but not installed. Please install it and try again."
  exit 1
fi

echo "Dependencies found."

# --- Download and Extract Build Artifact ---
echo_message "Downloading phpswitcher artifact..."

mkdir -p "$INSTALL_DIR"
TMP_FILE="/tmp/$ARTIFACT_NAME"

echo "Downloading from: $ARTIFACT_URL"
if curl -L --fail --progress-bar -o "$TMP_FILE" "$ARTIFACT_URL"; then
    echo "Download successful."
else
    echo_error "Failed to download artifact from $ARTIFACT_URL"
    rm -f "$TMP_FILE" # Clean up partial download
    exit 1
fi

echo_message "Extracting phpswitcher..."
# Use --strip-components=1 as the archive contains a top-level directory like phpswitcher-X.Y.Z/
if tar -xzf "$TMP_FILE" -C "$INSTALL_DIR" --strip-components=1; then
    echo "Extraction successful."
    rm -f "$TMP_FILE" # Clean up downloaded tarball
else
    echo_error "Failed to extract artifact $TMP_FILE"
    rm -f "$TMP_FILE"
    exit 1
fi

# --- Setup Environment / Profile ---
echo_message "Setting up environment..."

PROFILE_FILE=""
DETECTED_SHELL=$(basename "${SHELL}")

if [ "$DETECTED_SHELL" = "bash" ]; then
    if [ -f "$HOME/.bashrc" ]; then
        PROFILE_FILE="$HOME/.bashrc"
    else
        PROFILE_FILE="$HOME/.bash_profile"
    fi
elif [ "$DETECTED_SHELL" = "zsh" ]; then
    PROFILE_FILE="$HOME/.zshrc"
fi

if [ -z "$PROFILE_FILE" ]; then
  echo_error "Could not detect profile file (.bashrc, .bash_profile, or .zshrc)."
  echo "Please add the following lines manually to your shell profile file:"
  printf "\n  export PHPSWITCHER_DIR=\"$HOME/.phpswitcher\""
  printf "\n  export PATH=\"$INSTALL_DIR/bin:\$PATH\"\n\n"
  exit 1
fi

echo "Detected profile file: $PROFILE_FILE"

# Check if already configured
if ! grep -q "PHPSWITCHER_DIR=" "$PROFILE_FILE"; then
  echo "Adding phpswitcher configuration to $PROFILE_FILE..."
  printf "\n# PHP Switcher Configuration\n" >> "$PROFILE_FILE"
  printf "export PHPSWITCHER_DIR=\"%s\"\n" "$INSTALL_DIR" >> "$PROFILE_FILE"
  printf "export PATH=\"%s/bin:\$PATH\"\n" "$INSTALL_DIR" >> "$PROFILE_FILE"
else
  echo "phpswitcher already configured in $PROFILE_FILE."
fi

# --- Final Message ---
echo_message "phpswitcher installation complete!"
echo "Please restart your terminal session or run the following command to load the environment:"
echo "  source $PROFILE_FILE"
echo "After that, you can use the 'phpswitcher' command."

exit 0
