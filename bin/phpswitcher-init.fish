# phpswitcher shell integration for Fish.
# This script is intended to be sourced by Fish (e.g., in ~/.config/fish/conf.d/).

function _phpswitcher_auto_switch --on-variable PWD --description "Auto-switch PHP version on directory change"
    set -l required_version ""

    # 1. Find the .php-version file by traversing up from the current directory.
    set -l dir (pwd)
    while test -n "$dir" -a "$dir" != "/"
        if test -f "$dir/.php-version"
            set required_version (head -n 1 "$dir/.php-version" | string trim)
            break
        end
        set dir (dirname "$dir")
    end

    # 2. Fallback to composer.json in the current directory.
    if test -z "$required_version" -a -f "$PWD/composer.json"
        set -l constraint (grep -o '"php": *"[^"]*"' "$PWD/composer.json" 2>/dev/null | head -n 1)
        if test -n "$constraint"
            set -l match (string match -r '([0-9]+\.[0-9]+)' "$constraint")
            if test (count $match) -ge 2
                set required_version $match[2]
            end
        end
    end

    # 3. Fallback to global default version.
    if test -z "$required_version"
        set -l default_file "$PHPSWITCHER_DIR/default_version"
        if test -z "$PHPSWITCHER_DIR"
            set default_file "$HOME/.phpswitcher/default_version"
        end
        if test -f "$default_file"
            set required_version (cat "$default_file" | string trim)
        end
    end

    # If a version was detected, process it.
    if test -n "$required_version"
        set -l active_version_file "$PHPSWITCHER_DIR/active_version"
        if test -z "$PHPSWITCHER_DIR"
            set active_version_file "$HOME/.phpswitcher/active_version"
        end
        set -l current_version ""
        if test -f "$active_version_file"
            set current_version (cat "$active_version_file" | string trim)
        end

        if test "$required_version" != "$current_version"
            phpswitcher use "$required_version" --quiet
        end
    end
end
