#!/usr/bin/env bash

set -e # Exit immediately if a command exits with a non-zero status.

# Define installation directory
export PHPSWITCHER_DIR="${PHPSWITCHER_DIR:-$HOME/.phpswitcher}"
INSTALL_DIR="$PHPSWITCHER_DIR"
# TODO: Replace hardcoded URL with logic to get latest release artifact URL from GitHub API
# Example: LATEST_RELEASE_URL=$(curl -s https://api.github.com/repos/rawdreeg/phpswitcher/releases/latest | grep 'browser_download_url.*phpswitcher\.tar\.gz' | cut -d '"' -f 4)
ARTIFACT_URL="https://github.com/rawdreeg/phpswitcher/releases/download/v0.1.0/phpswitcher.tar.gz" # <<< REPLACE THIS
ARTIFACT_NAME="phpswitcher.tar.gz"

# Helper function for printing messages
echo_message() {
  printf "\n%s\n" "$1"
}

echo_error() {
  printf "\n\033[0;31m%s\033[0m\n" "$1" >&2
}

# Function to compare semantic versions (a >= b)
version_ge() {
  printf '%s\n%s\n' "$2" "$1" | sort -V -C
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# --- Dependency Checks ---
echo_message "Checking dependencies..."

if ! command_exists tar; then
  echo_error "Error: tar is not installed. Please install tar and try again."
  exit 1
fi

if ! command_exists curl && ! command_exists wget; then
  echo_error "Error: curl or wget is required but not installed. Please install one and try again."
  exit 1
fi

echo "Dependencies found."

# --- OS Detection ---
OS=""
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  OS="Linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
  OS="macOS"
else
  echo_error "Unsupported operating system: $OSTYPE. Currently only macOS and Linux are planned."
  exit 1
fi
echo "Detected OS: $OS"

# --- PHP Prerequisite Check ---
REQUIRED_PHP_VERSION="8.1"

ensure_php_prerequisite() {
  echo_message "Checking for prerequisite PHP (>= $REQUIRED_PHP_VERSION)..."

  local current_php_version
  if command_exists php; then
    current_php_version=$(php -r 'echo PHP_MAJOR_VERSION."".PHP_MINOR_VERSION;')
    echo "Found existing PHP version: $current_php_version"

    if version_ge "$current_php_version" "$REQUIRED_PHP_VERSION"; then
      echo "Existing PHP version meets requirement (>= $REQUIRED_PHP_VERSION)."
      return 0
    else
      echo "Existing PHP version $current_php_version is older than required $REQUIRED_PHP_VERSION."
      if [[ "$OS" == "macOS" ]] && command_exists brew; then
        # Offer upgrade via Homebrew on macOS
        read -p "Do you want to attempt upgrading PHP using 'brew install php'? [y/N] " -n 1 -r REPLY
        echo # Move to a new line
        if [[ "$REPLY" =~ ^[Yy]$ ]]; then
          echo "Attempting to install/upgrade PHP via Homebrew..."
          if brew install php; then
            echo "PHP installation/upgrade via Homebrew successful."
            # Re-check version and update PATH if necessary
            if command_exists php; then
               current_php_version=$(php -r 'echo PHP_MAJOR_VERSION."".PHP_MINOR_VERSION;')
               echo "Current PHP version after brew install: $current_php_version"
               if version_ge "$current_php_version" "$REQUIRED_PHP_VERSION"; then
                    # Ensure brew path is in PATH for the rest of the script
                    local brew_prefix
                    if [[ $(uname -m) == "arm64" ]]; then
                        brew_prefix=$(brew --prefix php || echo "/opt/homebrew/opt/php")
                    else
                        brew_prefix=$(brew --prefix php || echo "/usr/local/opt/php")
                    fi
                    if [ -d "$brew_prefix/bin" ] && [[ ":$PATH:" != *":$brew_prefix/bin:"* ]]; then
                         export PATH="$brew_prefix/bin:$PATH"
                         echo "Temporarily added $(php --version | head -n 1) to PATH for installation."
                    fi
                   return 0 # Success!
               else
                   echo_error "PHP version after brew install ($current_php_version) still does not meet requirement ($REQUIRED_PHP_VERSION)."
                   return 1
               fi
            else
               echo_error "PHP command not found after brew install attempt."
               return 1
            fi
          else
            echo_error "Failed to install/upgrade PHP via Homebrew."
            return 1
          fi
        else
          echo "Skipping PHP upgrade."
          echo "Please manually install PHP >= $REQUIRED_PHP_VERSION and try again."
          return 1
        fi
      # TODO: Add logic here to attempt upgrade using apt/dnf/yum on Linux
      # elif [[ "$OS" == "Linux" ]]; then ...
      else
        echo "Automatic PHP upgrade not available for this setup."
        echo "Please manually install PHP >= $REQUIRED_PHP_VERSION and try again."
        return 1
      fi
    fi
  fi

  # PHP command doesn't exist, try installing from scratch
  echo "PHP not found."
  if [[ "$OS" == "macOS" ]]; then
    if command_exists brew; then
      echo "Attempting to install PHP via Homebrew (needed to run phpswitcher itself)..."
      if brew install php; then
        echo "Successfully installed prerequisite PHP via Homebrew."
        # Add brew's php bin to PATH temporarily for the rest of the script
        local brew_prefix
        if [[ $(uname -m) == "arm64" ]]; then
            brew_prefix=$(brew --prefix php || echo "/opt/homebrew/opt/php")
        else
            brew_prefix=$(brew --prefix php || echo "/usr/local/opt/php")
        fi
        if [ -d "$brew_prefix/bin" ]; then
            export PATH="$brew_prefix/bin:$PATH"
            echo "Temporarily added $(php --version | head -n 1) to PATH for installation."
            # Final check after initial install
            current_php_version=$(php -r 'echo PHP_MAJOR_VERSION."".PHP_MINOR_VERSION;')
            if version_ge "$current_php_version" "$REQUIRED_PHP_VERSION"; then
                return 0
            else
                echo_error "Installed PHP version ($current_php_version) does not meet requirement ($REQUIRED_PHP_VERSION)."
                return 1
            fi
        else
             echo_error "Failed to find Homebrew PHP bin directory after installation."
             return 1
        fi
      else
        echo_error "Failed to install prerequisite PHP via Homebrew."
        return 1
      fi
    else
      echo_error "Error: brew command not found. Please install Homebrew (https://brew.sh/) or install PHP manually (>= $REQUIRED_PHP_VERSION) and try again."
      return 1
    fi
  # TODO: Add logic here to attempt initial install using apt/dnf/yum on Linux
  # elif [[ "$OS" == "Linux" ]]; then ...
  else
     echo_error "PHP not found, and automatic installation is not yet supported for $OS."
     echo "Please install PHP manually (>= $REQUIRED_PHP_VERSION) and try again."
     return 1
  fi
}

if ! ensure_php_prerequisite; then
  exit 1
fi

# --- Download and Extract Build Artifact ---
echo_message "Downloading phpswitcher artifact..."

mkdir -p "$INSTALL_DIR"
TMP_FILE="$INSTALL_DIR/$ARTIFACT_NAME"

DOWNLOAD_CMD=""
if command_exists curl; then
    DOWNLOAD_CMD="curl -L --fail --progress-bar -o '$TMP_FILE' '$ARTIFACT_URL'"
elif command_exists wget; then
    DOWNLOAD_CMD="wget --progress=bar:force -O '$TMP_FILE' '$ARTIFACT_URL'"
fi

echo "Downloading from: $ARTIFACT_URL"
if eval "$DOWNLOAD_CMD"; then
    echo "Download successful."
else
    echo_error "Failed to download artifact from $ARTIFACT_URL"
    rm -f "$TMP_FILE" # Clean up partial download
    exit 1
fi

echo_message "Extracting phpswitcher..."
# Use --strip-components=1 assuming tarball contains a top-level directory like phpswitcher-X.Y.Z/
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
  elif [ -f "$HOME/.bash_profile" ]; then
    # Check if .bashrc is sourced from .bash_profile for non-login shells
    if grep -q '.bashrc' "$HOME/.bash_profile"; then
        PROFILE_FILE="$HOME/.bashrc" # Prefer .bashrc if sourced
    else
        PROFILE_FILE="$HOME/.bash_profile"
    fi
  fi
elif [ "$DETECTED_SHELL" = "zsh" ]; then
  PROFILE_FILE="$HOME/.zshrc"
fi

if [ -z "$PROFILE_FILE" ]; then
  echo_error "Could not detect profile file (.bashrc, .bash_profile, or .zshrc)."
  echo "Please add the following lines manually to your shell profile file:"
  printf "\n  export PHPSWITCHER_DIR=\"$HOME/.phpswitcher\""
  printf "\n  export PATH=\"$PHPSWITCHER_DIR/bin:\$PATH\"\n\n"
  exit 1
fi

echo "Detected profile file: $PROFILE_FILE"

# Check if already configured
if ! grep -q "PHPSWITCHER_DIR=" "$PROFILE_FILE"; then
  echo "Adding phpswitcher configuration to $PROFILE_FILE..."
  printf "\n# PHP Switcher Configuration\n" >> "$PROFILE_FILE"
  printf "export PHPSWITCHER_DIR=\"$HOME/.phpswitcher\"\n" >> "$PROFILE_FILE"
  printf "export PATH=\"$PHPSWITCHER_DIR/bin:\$PATH\"\n" >> "$PROFILE_FILE"
else
  echo "phpswitcher already configured in $PROFILE_FILE."
fi

# --- Final Message ---
echo_message "phpswitcher installation complete!"
echo "Please restart your terminal session or run the following command to load the environment:"
echo "  source $PROFILE_FILE"
echo "After that, you can use the 'phpswitcher' command."

exit 0 