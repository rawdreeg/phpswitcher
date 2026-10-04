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

# Append a line to a profile when the marker is missing.
# Existing installs that only exported PHPSWITCHER_DIR still need the hook.
append_profile_line() {
  local file="$1"
  local marker="$2"
  local line="$3"

  if [ -f "$file" ] && grep -q "$marker" "$file"; then
    return 1
  fi

  printf '%s\n' "$line" >> "$file"
  return 0
}

# Ensure init and completion are sourced, even when PHPSWITCHER_DIR is already set.
configure_shell_profile() {
  local profile_file=""
  local detected_shell
  local updated=0
  detected_shell=$(basename "${SHELL}")

  if [ "$detected_shell" = "bash" ]; then
    if [ -f "$HOME/.bashrc" ]; then
      profile_file="$HOME/.bashrc"
    else
      profile_file="$HOME/.bash_profile"
    fi
  elif [ "$detected_shell" = "zsh" ]; then
    profile_file="$HOME/.zshrc"
  elif [ "$detected_shell" = "fish" ]; then
    profile_file="fish"
  fi

  if [ -z "$profile_file" ]; then
    echo_error "Could not detect profile file (.bashrc, .bash_profile, .zshrc, or fish config)."
    echo "Please add the following lines manually to your shell profile file:"
    printf '\n  export PHPSWITCHER_DIR="%s/.phpswitcher"\n' "$HOME"
    printf '  export PATH="%s/bin:%s"\n' "$INSTALL_DIR" "\$PATH"
    printf "  source \"\$PHPSWITCHER_DIR/phpswitcher-init.sh\"\n"
    printf "  source \"\$PHPSWITCHER_DIR/phpswitcher-completion.sh\"\n\n"
    return 1
  fi

  if [ "$profile_file" = "fish" ]; then
    local fish_conf_dir="$HOME/.config/fish/conf.d"
    local fish_config_file="$fish_conf_dir/phpswitcher.fish"
    mkdir -p "$fish_conf_dir"
    echo "Detected Fish shell. Configuring: $fish_config_file"

    if [ ! -f "$fish_config_file" ]; then
      cat > "$fish_config_file" << FISH_EOF
# PHP Switcher Configuration
set -gx PHPSWITCHER_DIR "$INSTALL_DIR"
fish_add_path "$INSTALL_DIR/bin"
source "\$PHPSWITCHER_DIR/phpswitcher-init.fish"
source "\$PHPSWITCHER_DIR/phpswitcher-completion.fish"
FISH_EOF
      echo "Fish configuration written."
      updated=1
    else
      if append_profile_line "$fish_config_file" "set -gx PHPSWITCHER_DIR" "set -gx PHPSWITCHER_DIR \"$INSTALL_DIR\""; then
        updated=1
      fi
      if append_profile_line "$fish_config_file" "fish_add_path" "fish_add_path \"$INSTALL_DIR/bin\""; then
        updated=1
      fi
      if append_profile_line "$fish_config_file" "phpswitcher-init.fish" "source \"\$PHPSWITCHER_DIR/phpswitcher-init.fish\""; then
        updated=1
      fi
      if append_profile_line "$fish_config_file" "phpswitcher-completion.fish" "source \"\$PHPSWITCHER_DIR/phpswitcher-completion.fish\""; then
        updated=1
      fi
      if [ "$updated" -eq 1 ]; then
        echo "Added missing phpswitcher shell integration to $fish_config_file."
      else
        echo "phpswitcher already configured in $fish_config_file."
      fi
    fi
    PROFILE_FILE="$fish_config_file"
    return 0
  fi

  echo "Detected profile file: $profile_file"
  touch "$profile_file"

  if ! grep -q "PHPSWITCHER_DIR=" "$profile_file"; then
    {
      printf "\n# PHP Switcher Configuration\n"
      printf "export PHPSWITCHER_DIR=\"%s\"\n" "$INSTALL_DIR"
      printf "export PATH=\"%s/bin:\$PATH\"\n" "$INSTALL_DIR"
    } >> "$profile_file"
    updated=1
  fi

  if append_profile_line "$profile_file" "phpswitcher-init.sh" "source \"\$PHPSWITCHER_DIR/phpswitcher-init.sh\""; then
    updated=1
  fi
  if append_profile_line "$profile_file" "phpswitcher-completion.sh" "source \"\$PHPSWITCHER_DIR/phpswitcher-completion.sh\""; then
    updated=1
  fi

  if [ "$updated" -eq 1 ]; then
    echo "Added missing phpswitcher shell integration to $profile_file."
  else
    echo "phpswitcher already configured in $profile_file."
  fi

  PROFILE_FILE="$profile_file"
}

# Verify phpswitcher.tar.gz against phpswitcher.tar.gz.sha256 in the same directory.
# The checksum file is a sha256sum line: "<hash>  phpswitcher.tar.gz".
# Keep this in sync with verify_archive_checksum in bin/phpswitcher.
verify_archive_checksum() {
  local dir="$1"

  if [ ! -f "$dir/phpswitcher.tar.gz" ] || [ ! -f "$dir/phpswitcher.tar.gz.sha256" ]; then
    echo_error "Checksum file not found. Refusing to extract."
    return 1
  fi

  if command -v sha256sum >/dev/null 2>&1; then
    (cd "$dir" && sha256sum -c phpswitcher.tar.gz.sha256)
    return $?
  fi
  if command -v shasum >/dev/null 2>&1; then
    (cd "$dir" && shasum -a 256 -c phpswitcher.tar.gz.sha256)
    return $?
  fi

  echo_error "sha256sum or shasum is required to verify the download."
  return 1
}

install_artifact() {
  local artifact_url="${PHPSWITCHER_ARTIFACT_URL:-https://github.com/rawdreeg/phpswitcher/releases/latest/download/phpswitcher.tar.gz}"
  local checksum_url="${PHPSWITCHER_CHECKSUM_URL:-${artifact_url}.sha256}"
  local tmp_dir
  local tmp_file

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

  echo_message "Downloading phpswitcher artifact..."

  mkdir -p "$INSTALL_DIR"
  tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/phpswitcher.XXXXXXXXXX")
  tmp_file="$tmp_dir/phpswitcher.tar.gz"

  echo "Downloading from: $artifact_url"
  if curl -L --fail --max-time 120 --progress-bar -o "$tmp_file" "$artifact_url"; then
    echo "Download successful."
  else
    echo_error "Failed to download artifact from $artifact_url"
    rm -rf "$tmp_dir"
    exit 1
  fi

  echo_message "Downloading checksum..."
  if ! curl -fsSL --max-time 60 -o "$tmp_dir/phpswitcher.tar.gz.sha256" "$checksum_url"; then
    echo_error "Failed to download checksum from $checksum_url. Refusing to extract."
    rm -rf "$tmp_dir"
    exit 1
  fi

  echo_message "Verifying checksum..."
  if ! verify_archive_checksum "$tmp_dir"; then
    echo_error "Checksum verification failed. Refusing to extract."
    rm -rf "$tmp_dir"
    exit 1
  fi

  echo_message "Extracting phpswitcher..."
  # Use --strip-components=1 as the archive contains a top-level directory like phpswitcher-X.Y.Z/
  if tar -xzf "$tmp_file" -C "$INSTALL_DIR" --strip-components=1; then
    echo "Extraction successful."
    rm -rf "$tmp_dir"
  else
    echo_error "Failed to extract artifact $tmp_file"
    rm -rf "$tmp_dir"
    exit 1
  fi
}

main() {
  PROFILE_FILE=""

  install_artifact

  echo_message "Setting up environment..."
  configure_shell_profile

  echo_message "phpswitcher installation complete!"
  echo "Please restart your terminal session or run the following command to load the environment:"
  echo "  source $PROFILE_FILE"
  echo "After that, you can use the 'phpswitcher' command."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
