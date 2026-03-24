#!/usr/bin/env bash

# phpswitcher shell completion.
# This script is intended to be sourced by a shell startup file (e.g., .bashrc, .zshrc).

# List of phpswitcher commands for completion.
_phpswitcher_commands="install uninstall use list self-update version help"

# Get installed PHP versions for completing version arguments.
_phpswitcher_installed_versions() {
    if command -v brew >/dev/null 2>&1; then
        brew list --formula 2>/dev/null | grep '^php@' | sed 's/php@//'
    elif command -v update-alternatives >/dev/null 2>&1; then
        update-alternatives --list php 2>/dev/null | grep -oE '[0-9]+\.[0-9]+$'
    fi
}

# --- Bash Completion ---
if [ -n "$BASH_VERSION" ]; then
    _phpswitcher_bash_complete() {
        local cur prev
        COMPREPLY=()
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"

        # Complete commands at position 1
        if [ "$COMP_CWORD" -eq 1 ]; then
            COMPREPLY=( $(compgen -W "$_phpswitcher_commands" -- "$cur") )
            return
        fi

        # Complete versions for commands that accept a version argument
        case "$prev" in
            install|uninstall|use)
                local versions
                versions=$(_phpswitcher_installed_versions)
                COMPREPLY=( $(compgen -W "$versions" -- "$cur") )
                return
                ;;
        esac
    }

    complete -F _phpswitcher_bash_complete phpswitcher
fi

# --- Zsh Completion ---
if [ -n "$ZSH_VERSION" ]; then
    _phpswitcher_zsh_complete() {
        local -a commands
        commands=(
            'install:Install a specific PHP version'
            'uninstall:Uninstall a specific PHP version'
            'use:Switch the active PHP version'
            'list:List all installed PHP versions'
            'self-update:Update phpswitcher to the latest version'
            'version:Show the phpswitcher version'
            'help:Show help message'
        )

        _arguments -C \
            '1: :->command' \
            '2: :->argument' \
            && return

        case "$state" in
            command)
                _describe 'command' commands
                ;;
            argument)
                case "${words[2]}" in
                    install|uninstall|use)
                        local -a versions
                        versions=( ${(f)"$(_phpswitcher_installed_versions)"} )
                        if [ ${#versions[@]} -gt 0 ]; then
                            _describe 'PHP version' versions
                        fi
                        ;;
                esac
                ;;
        esac
    }

    compdef _phpswitcher_zsh_complete phpswitcher
fi
