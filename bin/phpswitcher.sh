#!/usr/bin/env bash

# This script is intended to be sourced by your shell's profile script
# (e.g., .bashrc, .zshrc) to enable automatic PHP version switching.

_phpswitcher_auto_switch() {
    # Check if we are in a directory where auto-switching should occur.
    # This function is called after the directory has been changed.
    local phpswitcher_path
    phpswitcher_path=$(command -v phpswitcher)

    if [ -z "$phpswitcher_path" ]; then
        # If phpswitcher is not on the PATH, do nothing.
        return
    fi

    # Find a .php-version file by traversing up from the current directory.
    local dir="$PWD"
    local version_file_path=""
    while [ -n "$dir" ] && [ "$dir" != "/" ]; do
        if [ -f "$dir/.php-version" ]; then
            version_file_path="$dir/.php-version"
            break
        fi
        dir=$(dirname "$dir")
    done

    if [ -z "$version_file_path" ]; then
        # No .php-version file found, so nothing to do.
        return
    fi

    # Read the required version from the file.
    local required_version
    required_version=$(head -n 1 "$version_file_path" | tr -d '[:space:]')

    if [ -z "$required_version" ]; then
        # The .php-version file is empty, do nothing.
        return
    fi

    # Get the currently active version stored by phpswitcher.
    local active_version_file="$PHPSWITCHER_DIR/active_version"
    local active_version=""
    if [ -f "$active_version_file" ]; then
        active_version=$(cat "$active_version_file")
    fi

    # If the required version is not the active one, switch it.
    if [ "$required_version" != "$active_version" ]; then
        # Use --quiet to avoid spamming the user's terminal on every cd.
        phpswitcher use "$required_version" --quiet
    fi
}

# --- Shell Integration ---

# Zsh integration using chpwd_functions array.
if [ -n "$ZSH_VERSION" ]; then
    # Function to add a function to a hook array if not already present.
    add-zsh-hook() {
        local hook_array_name="$1"
        local function_to_add="$2"
        # Check if the function is already in the array
        if ! [[ "${(P)hook_array_name[(Ie)$function_to_add]}" -le "${#(P)hook_array_name}" ]]; then
            # If not found, add it.
            eval "$hook_array_name+=(\"$function_to_add\")"
        fi
    }
    # Add our function to the chpwd_functions hook.
    add-zsh-hook "chpwd_functions" "_phpswitcher_auto_switch"

# Bash integration by overriding the 'cd' command.
elif [ -n "$BASH_VERSION" ]; then
    cd() {
        # Call the built-in 'cd' command with all arguments.
        builtin cd "$@" || return
        # After changing directory, run our auto-switcher function.
        _phpswitcher_auto_switch
    }
fi
