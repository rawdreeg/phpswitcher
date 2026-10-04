# phpswitcher shell integration for Fish.
# This script is intended to be sourced by Fish (e.g., in ~/.config/fish/conf.d/).

function _phpswitcher_auto_switch --on-variable PWD --description "Auto-switch PHP version on directory change"
    # Detection lives in `phpswitcher status` so this hook stays aligned with the CLI.
    set -l output (env PHPSWITCHER_NO_UPDATE_CHECK=1 phpswitcher status 2>/dev/null | string collect)
    set -l required_version (printf '%s\n' "$output" | string replace -r -f '^  Detected version: ' '')
    set -l current_version (printf '%s\n' "$output" | string replace -r -f '^Active PHP version: ' '')

    if test -n "$required_version" -a "$required_version" != "$current_version"
        env PHPSWITCHER_NO_UPDATE_CHECK=1 phpswitcher use "$required_version" --quiet
    end
end
