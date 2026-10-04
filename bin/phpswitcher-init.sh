#!/usr/bin/env bash

# phpswitcher shell integration.
# This script is intended to be sourced by a shell startup file (e.g., .bashrc, .zshrc).

# Run on directory change. Detection lives in `phpswitcher status` so Bash and Fish
# cannot drift from the CLI (parent composer.json, config.platform.php, default).
_phpswitcher_auto_switch() {
    local output required_version current_version

    output=$(PHPSWITCHER_NO_UPDATE_CHECK=1 phpswitcher status 2>/dev/null || true)
    required_version=$(printf '%s\n' "$output" | sed -n 's/^  Detected version: //p' | head -n 1)
    current_version=$(printf '%s\n' "$output" | sed -n 's/^Active PHP version: //p' | head -n 1)

    if [ -n "$required_version" ] && [ "$required_version" != "$current_version" ]; then
        PHPSWITCHER_NO_UPDATE_CHECK=1 phpswitcher use "$required_version" --quiet || true
    fi
}

# This section hooks the auto-switch function into the shell.
# It supports bash and zsh.

if [ -n "$ZSH_VERSION" ]; then
    # For zsh, add the function to the chpwd_functions array.
    # This ensures it's executed whenever the directory changes.
    if [[ ! " ${chpwd_functions[*]-} " =~ " _phpswitcher_auto_switch " ]]; then
        chpwd_functions+=(_phpswitcher_auto_switch)
    fi
elif [ -n "$BASH_VERSION" ]; then
    # For bash, prepend the function to the PROMPT_COMMAND.
    # This is executed just before the prompt is displayed.
    # We check if it's already there to avoid adding it multiple times.
    if [[ ! "${PROMPT_COMMAND:-}" =~ "_phpswitcher_auto_switch" ]]; then
        PROMPT_COMMAND="_phpswitcher_auto_switch;${PROMPT_COMMAND:-}"
    fi
fi
