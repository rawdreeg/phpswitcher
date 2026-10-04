[![CI](https://github.com/rawdreeg/phpswitcher/actions/workflows/ci.yml/badge.svg)](https://github.com/rawdreeg/phpswitcher/actions/workflows/ci.yml)

# PHP Switcher

A simple CLI tool to manage multiple PHP versions on macOS and Linux.

## Features

*   Install specific PHP versions (via Homebrew on macOS, APT on Debian/Ubuntu, dnf on Fedora, or the AUR on Arch).
*   Uninstall PHP versions you no longer need.
*   Switch the active PHP version.
*   List all installed PHP versions.
*   Auto-detect required version from `.php-version`, `composer.json`, or global default.
*   **Global default version** — set a fallback PHP version used when no project-level config is found.
*   **Automatic version switching** when you change directories (supports `.php-version`, `composer.json`, and global default).
*   **Status command** — see active PHP version, detection source, and path info at a glance.
*   **Extensions management** — list, install, or remove PHP extensions for any version.
*   **Tab completion** for Bash, Zsh, and Fish.

## Prerequisites

*   **macOS:** Requires **Homebrew** for installing and managing PHP versions.
*   **Linux (Debian/Ubuntu):** Requires `apt` and the `software-properties-common` package. `sudo` is required for installing and switching versions.
*   **Linux (Fedora):** Requires `dnf`. Side-by-side versions come from [Remi's RPM repository](https://rpms.remirepo.net/) (`remi-safe` Software Collections such as `php81` and `php82`). `sudo` is required to install and remove packages.
*   **Linux (Arch):** Side-by-side versions are AUR packages (`php81`, `php82`, and the same pattern through current versions such as `php85`). The official repositories ship one unversioned `php` package. `pacman` cannot build AUR packages; install **paru** or **yay** (paru is used when both are installed). `sudo` is required to install and remove packages. Switching itself does not need a password.

## Installation

### Homebrew (macOS)

```bash
brew install rawdreeg/phpswitcher/phpswitcher
```

### Composer

```bash
composer global require rawdreeg/phpswitcher
```

### Install script (macOS & Linux)

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/rawdreeg/phpswitcher/main/install.sh)"
```

After installing, restart your terminal and verify with:

```bash
phpswitcher help
```

## Usage

**List installed PHP versions:**

Shows all available PHP versions and highlights the one that is currently active.

```bash
phpswitcher list
# Example Output:
#
# Installed PHP Versions (via Homebrew):
#    7.4
#  * 8.1 (active)
```

**Install a PHP version:**

If a `composer.json` in this directory or a parent has a PHP requirement (`config.platform.php`, then `require.php`), you can omit the `<version>` argument to automatically detect and install the required `X.Y` version.

```bash
phpswitcher install [<version>]
# Examples:
phpswitcher install 8.1
phpswitcher install 7.4

# Auto-detect from composer.json in this directory or a parent:
cd my-project-using-php8.0/
phpswitcher install
```

**Uninstall a PHP version:**

Remove a PHP version that is no longer needed. The currently active version cannot be uninstalled — switch to a different version first.

```bash
phpswitcher uninstall <version>
# Example:
phpswitcher uninstall 7.4
```

**Switch active PHP version:**

If you are in a directory containing a `composer.json` file with a PHP requirement (`config.platform.php`, then `require.php`), you can omit the `<version>` argument, and `phpswitcher` will attempt to detect and use the appropriate `X.Y` version. The search walks parent directories, the same way `.php-version` does.

```bash
phpswitcher use [<version>]
# Examples:
phpswitcher use 8.1

# Auto-detect from composer.json in this directory or a parent:
cd my-project-using-php7.4/
phpswitcher use
```

On Debian and Ubuntu, `use` also switches `phpize`, `php-config`, `phar`, `phar.phar`, `phpdbg`, and `php-fpm` with `update-alternatives` when those binaries are installed. Versioned FPM services such as `php8.1-fpm` are left running; the `php-fpm` alternative only moves the unversioned binary.

### Fedora

`phpswitcher install 8.2` installs the Remi Software Collection `php82` and `php82-php-cli` from `remi-safe`. When that repository is missing, phpswitcher installs `https://rpms.remirepo.net/fedora/remi-release-<fedora version>.rpm` (the release number comes from `/etc/os-release`).

Those packages sit beside the system PHP. `/usr/bin/php82` runs `/opt/remi/php82/root/usr/bin/php`. `phpswitcher use 8.2` points `php` at that binary with a symlink in `$PHPSWITCHER_DIR/bin`, which the installer already puts on `PATH`. The same directory receives `phpize`, `php-config`, `phar`, `phar.phar`, `phpdbg`, and `php-fpm` when the matching Remi binaries are present (`/usr/bin/php82-phar`, `/usr/bin/php82-phpdbg`, `/opt/remi/php82/root/usr/sbin/php-fpm`, and the devel binaries for `phpize` and `php-config`). The versioned service `php82-php-fpm` is left running.

If that PHP binary is already registered with `alternatives` or `update-alternatives`, `use` selects it there. Quiet mode (`--quiet` or `PHPSWITCHER_QUIET`) runs that step with `sudo -n`. When the binary is not registered, `use` writes the symlink in `$PHPSWITCHER_DIR/bin`. A missing Remi repository or binary stops with an error that names the package and the paths it looked for.

A dnf module stream such as `php:remi-8.2` is a single system PHP. Side-by-side installs use the Remi Software Collections above.

### Arch

On Arch, those tools are versioned without a dot. For PHP 8.1 the AUR packages install `/usr/bin/php81` (`php81-cli`), `/usr/bin/phpize81` and `/usr/bin/php-config81` (`php81`), `/usr/bin/phar81` and `/usr/bin/phar.phar81` (`php81-cli`), `/usr/bin/phpdbg81` (`php81-phpdbg`), and `/usr/bin/php-fpm81` (`php81-fpm`). `use` links `php` and those tool names in `~/.phpswitcher/bin` (the directory the installer puts first on `PATH`) to whichever of those binaries exist. The systemd unit `php81-fpm` is left running. `--quiet` does not wait for a sudo password.

**Set a global default PHP version:**

Set a fallback version that's used when no `.php-version` file or `composer.json` is found in the directory tree:

```bash
phpswitcher default 8.2

# Show the current default:
phpswitcher default

# Remove the default:
phpswitcher default --unset
```

**Show status:**

Display the current active PHP version, how it was detected, and path information:

```bash
phpswitcher status
# Example Output:
#
# PHP Switcher Status
# ===================
#
# Active PHP version: 8.1
# PHP reports version: 8.1
# PHP binary path:    /usr/bin/php8.1
# Loaded php.ini:     /etc/php/8.1/cli/php.ini
#
# Version detection for current directory:
#   Detected version: 8.1
#   Source:           .php-version (/home/user/project/.php-version)
#
# Global default:     8.2
#
# Shell integration:  /home/user/.bashrc
#   enabled
```

**Manage PHP extensions:**

List installed extensions for a PHP version, or install and remove them:

```bash
# List extensions for the active PHP version:
phpswitcher extensions

# List extensions for a specific version:
phpswitcher extensions 8.1

# Install an extension (uses active version):
phpswitcher extensions install xdebug

# Install an extension for a specific version:
phpswitcher extensions install redis 8.1

# Remove an extension (uses active version):
phpswitcher extensions uninstall xdebug

# Remove an extension for a specific version:
phpswitcher extensions uninstall redis 8.1
```

On Debian and Ubuntu, extensions are installed and removed via `apt` (e.g., `php8.1-xdebug`). On Fedora, `dnf` installs `php81-php-mbstring` or, for PECL extensions, `php81-php-pecl-xdebug`. On Arch, the package name drops the dot (`php81-xdebug`) and is installed with paru or yay; removal uses `pacman`. On macOS, PECL is used.

**Show Version:**

```bash
phpswitcher version
```

**Self-Update:**

```bash
phpswitcher self-update
```
This will fetch and install the latest version of `phpswitcher` from GitHub. The tarball is checked against the published checksum before it is extracted.

**Check active PHP version (after switching):**

```bash
php --version
```

## Automatic Version Switching

`phpswitcher` supports automatic version switching when you change directories. This is achieved by hooking into your shell's prompt.

### How it Works

1.  When you `cd` into a new directory, `phpswitcher` looks for a `.php-version` file in the current directory or any parent directory.
2.  If no `.php-version` file is found, it walks parent directories for a `composer.json` and reads `config.platform.php`, then `require.php`.
3.  If neither is found, it falls back to the global default version (if set via `phpswitcher default`).
4.  If a required version is detected and it differs from the currently active version, `phpswitcher` automatically switches to it.

The shell hook asks `phpswitcher status` for that decision, so Bash, Zsh, and Fish stay on the same detection rules as `phpswitcher use`.

Re-running the installer adds the hook if an older install only put `phpswitcher` on your `PATH`. `phpswitcher status` reports whether the hook is present.

### Usage

To use this feature, simply create a file named `.php-version` in the root of your project and put the desired PHP version number in it.

```bash
# In your project's root directory
echo "8.1" > .php-version
```

Now, whenever you `cd` into this directory (or any subdirectory), `phpswitcher` will ensure that PHP 8.1 is activated automatically.

This feature is enabled by default during the installation process, which adds a sourcing line to your shell's profile file (`.bashrc`, `.zshrc`, or Fish config).

### Fish Shell Support

Fish shell is fully supported. The installer automatically detects Fish and creates a config file at `~/.config/fish/conf.d/phpswitcher.fish`. Auto-switching works via Fish's `--on-variable PWD` event.

## Tab Completion

Tab completion for commands and PHP versions is enabled automatically during installation for Bash, Zsh, and Fish. Type `phpswitcher` followed by Tab to see available commands, or `phpswitcher use` followed by Tab to see installed PHP versions.

## Development

1.  Clone the repository: `git clone https://github.com/rawdreeg/phpswitcher.git`
2.  Navigate into the project directory: `cd phpswitcher`.
3.  The main script is `bin/phpswitcher`. You can run it directly for testing:
    ```bash
    ./bin/phpswitcher install 8.2
    ```
4.  To create a release artifact, run the build script:
    ```bash
    ./build.sh
    ```
    This will create a `phpswitcher.tar.gz` in the root directory.

## Contributing

Contributions are welcome! Please feel free to open issues or submit pull requests.

## License

MIT License 
