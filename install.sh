#!/usr/bin/env bash

set -e # Exit immediately if a command exits with a non-zero status.

# Define installation directory
export PHPSWITCHER_DIR="${PHPSWITCHER_DIR:-$HOME/.phpswitcher}"
INSTALL_DIR="$PHPSWITCHER_DIR"

# This is a local installer for development.
# It will install phpswitcher from the current repository clone.

# Helper function for printing messages
echo_message() {
  printf "\n%s\n" "$1"
}

echo_error() {
  printf "\n\033[0;31m%s\033[0m\n" "$1" >&2
}

# --- Installation ---
echo_message "Installing phpswitcher from local repository..."

mkdir -p "$INSTALL_DIR/bin"

# Copy the main script and the init script
cp "bin/phpswitcher" "$INSTALL_DIR/bin/"
cp "bin/phpswitcher-init.sh" "$INSTALL_DIR/" # Place init script in the root

# Ensure the main script is executable
chmod +x "$INSTALL_DIR/bin/phpswitcher"

echo "Installation of scripts successful."

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
  printf "\n  export PHPSWITCHER_DIR=\"%s\"" "$HOME/.phpswitcher"
  printf "\n  export PATH=\"%s/bin:\$PATH\"\n\n" "$INSTALL_DIR"
  exit 1
fi

echo "Detected profile file: $PROFILE_FILE"

# Add configuration to profile if it's not already there.
if ! grep -q "PHPSWITCHER_DIR=" "$PROFILE_FILE"; then
  echo "Adding phpswitcher configuration to $PROFILE_FILE..."
  {
    printf "\n# PHP Switcher Configuration\n"
    printf "export PHPSWITCHER_DIR=\"%s\"\n" "$INSTALL_DIR"
    printf "export PATH=\"%s/bin:\$PATH\"\n" "$INSTALL_DIR"
  } >> "$PROFILE_FILE"
else
  echo "phpswitcher PATH already configured in $PROFILE_FILE."
fi

# Add shell integration sourcing if it's not already there
if ! grep -q "phpswitcher-init.sh" "$PROFILE_FILE"; then
  echo "Adding shell integration to $PROFILE_FILE..."
  {
    printf "\n# PHP Switcher Shell Integration\n"
    printf "source \"%s/phpswitcher-init.sh\"\n" "$INSTALL_DIR"
  } >> "$PROFILE_FILE"
else
  echo "phpswitcher shell integration already configured in $PROFILE_FILE."
fi

# --- Final Message ---
echo_message "phpswitcher installation complete!"
echo "Please restart your terminal session or run the following command to load the environment:"
echo "  source $PROFILE_FILE"
echo "After that, you can use the 'phpswitcher' command."

exit 0 