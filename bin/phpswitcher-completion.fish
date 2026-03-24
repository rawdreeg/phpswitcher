# phpswitcher tab completion for Fish shell.

# Helper: get installed PHP versions
function __phpswitcher_installed_versions
    if command -q brew
        brew list --formula 2>/dev/null | string match -r '^php@(.+)' | string replace -r '^php@' ''
    else if command -q update-alternatives
        update-alternatives --list php 2>/dev/null | string match -r '[0-9]+\.[0-9]+$'
    end
end

# Helper: check if a subcommand has already been given
function __phpswitcher_needs_command
    set -l cmd (commandline -opc)
    if test (count $cmd) -eq 1
        return 0
    end
    return 1
end

# Helper: check if current subcommand matches
function __phpswitcher_using_command
    set -l cmd (commandline -opc)
    if test (count $cmd) -ge 2
        if test "$cmd[2]" = "$argv[1]"
            return 0
        end
    end
    return 1
end

# Disable file completion by default
complete -c phpswitcher -f

# Subcommands
complete -c phpswitcher -n __phpswitcher_needs_command -a install -d "Install a specific PHP version"
complete -c phpswitcher -n __phpswitcher_needs_command -a uninstall -d "Uninstall a specific PHP version"
complete -c phpswitcher -n __phpswitcher_needs_command -a use -d "Switch the active PHP version"
complete -c phpswitcher -n __phpswitcher_needs_command -a list -d "List all installed PHP versions"
complete -c phpswitcher -n __phpswitcher_needs_command -a default -d "Set or show the global default PHP version"
complete -c phpswitcher -n __phpswitcher_needs_command -a status -d "Show current PHP version and detection info"
complete -c phpswitcher -n __phpswitcher_needs_command -a extensions -d "List or install PHP extensions"
complete -c phpswitcher -n __phpswitcher_needs_command -a self-update -d "Update phpswitcher to the latest version"
complete -c phpswitcher -n __phpswitcher_needs_command -a version -d "Show the phpswitcher version"
complete -c phpswitcher -n __phpswitcher_needs_command -a help -d "Show help message"

# Version completions for commands that accept a version
complete -c phpswitcher -n "__phpswitcher_using_command install" -a "(__phpswitcher_installed_versions)" -d "PHP version"
complete -c phpswitcher -n "__phpswitcher_using_command uninstall" -a "(__phpswitcher_installed_versions)" -d "PHP version"
complete -c phpswitcher -n "__phpswitcher_using_command use" -a "(__phpswitcher_installed_versions)" -d "PHP version"
complete -c phpswitcher -n "__phpswitcher_using_command default" -a "(__phpswitcher_installed_versions)" -d "PHP version"
complete -c phpswitcher -n "__phpswitcher_using_command default" -l unset -d "Remove the global default"
complete -c phpswitcher -n "__phpswitcher_using_command extensions" -a "(__phpswitcher_installed_versions)" -d "PHP version"
complete -c phpswitcher -n "__phpswitcher_using_command extensions" -a install -d "Install an extension"
complete -c phpswitcher -n "__phpswitcher_using_command extensions" -a list -d "List installed extensions"
