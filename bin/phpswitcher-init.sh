#!/usr/bin/env bash

# phpswitcher shell integration.
# This script is intended to be sourced by a shell startup file (e.g., .bashrc, .zshrc).

# This function is executed when the directory changes. It checks for a
# .php-version file or composer.json and automatically switches to the specified version.
_phpswitcher_auto_switch() {
    local required_version=""

    # 1. Find the .php-version file by traversing up from the current directory.
    local dir="$PWD"
    while [ -n "$dir" ] && [ "$dir" != "/" ]; do
        if [ -f "$dir/.php-version" ]; then
            required_version=$(head -n 1 "$dir/.php-version" | tr -d '[:space:]')
            break
        fi
        dir=$(dirname "$dir")
    done

    # 2. Fallback to composer.json in the current directory.
    if [ -z "$required_version" ] && [ -f "$PWD/composer.json" ]; then
        local constraint
        constraint=$(grep -o '"php": *"[^"]*"' "$PWD/composer.json" 2>/dev/null | head -n 1)
        if [[ "$constraint" =~ ([0-9]+\.[0-9]+) ]]; then
            required_version="${BASH_REMATCH[1]}"
        fi
    fi

    # If a version was detected, process it.
    if [ -n "$required_version" ]; then
        # Get the version currently marked as active by phpswitcher.
        local active_version_file="${PHPSWITCHER_DIR:-$HOME/.phpswitcher}/active_version"
        local current_version=""
        if [ -f "$active_version_file" ]; then
            current_version=$(cat "$active_version_file")
        fi

        # If the required version is not the active one, switch to it.
        if [ "$required_version" != "$current_version" ]; then
            # The `phpswitcher` command must be in the PATH.
            phpswitcher use "$required_version" --quiet
        fi
    fi
}

# This section hooks the auto-switch function into the shell.
# It supports bash and zsh.

if [ -n "$ZSH_VERSION" ]; then
    # For zsh, add the function to the chpwd_functions array.
    # This ensures it's executed whenever the directory changes.
    if [[ ! " ${chpwd_functions[*]} " =~ " _phpswitcher_auto_switch " ]]; then
        chpwd_functions+=(_phpswitcher_auto_switch)
    fi
elif [ -n "$BASH_VERSION" ]; then
    # For bash, prepend the function to the PROMPT_COMMAND.
    # This is executed just before the prompt is displayed.
    # We check if it's already there to avoid adding it multiple times.
    if [[ ! "$PROMPT_COMMAND" =~ "_phpswitcher_auto_switch" ]]; then
        PROMPT_COMMAND="_phpswitcher_auto_switch;${PROMPT_COMMAND}"
    fi
fi
