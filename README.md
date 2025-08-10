# PHP Switcher

A simple CLI tool to manage multiple PHP versions on macOS and Linux.

## Features

*   Install specific PHP versions (via Homebrew for macOS, or APT for Linux).
*   Switch the active PHP version.
*   List all installed PHP versions.
*   Auto-detect required version from `.php-version` or `composer.json`.
*   **Automatic version switching** when you change directories.

## Prerequisites

*   **macOS:** Requires **Homebrew** for installing and managing PHP versions.
*   **Linux (Debian/Ubuntu):** Requires `apt` and the `software-properties-common` package. `sudo` is required for installing and switching versions.

## Installation

Run the following command in your terminal to download and execute the installation script:

```bash
# Ensure you have curl installed
bash -c "$(curl -fsSL https://raw.githubusercontent.com/rawdreeg/phpswitcher/main/install.sh)"
```

This will install `phpswitcher` to `$HOME/.phpswitcher` and add it to your shell's profile file (e.g., `.zshrc`, `.bashrc`).

After installation, open a **new terminal session** or run `source ~/.zshrc` (or the equivalent for your shell) and verify with:

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

If you are in a directory containing a `composer.json` file with a PHP requirement, you can omit the `<version>` argument to automatically detect and install the required `X.Y` version.

```bash
phpswitcher install [<version>]
# Examples:
phpswitcher install 8.1
phpswitcher install 7.4

# Auto-detect from composer.json in current directory:
cd my-project-using-php8.0/
phpswitcher install
```

**Switch active PHP version:**

If you are in a directory containing a `composer.json` file with a PHP requirement (`require.php` or `config.platform.php`), you can omit the `<version>` argument, and `phpswitcher` will attempt to detect and use the appropriate `X.Y` version.

```bash
phpswitcher use [<version>]
# Examples:
phpswitcher use 8.1

# Auto-detect from composer.json in current directory:
cd my-project-using-php7.4/
phpswitcher use
```

**Show Version:**

```bash
phpswitcher version
```

**Self-Update:**

```bash
phpswitcher self-update
```
This will fetch and install the latest version of `phpswitcher` from GitHub.

**Check active PHP version (after switching):**

```bash
php --version
```

## Automatic Version Switching

`phpswitcher` supports automatic version switching when you change directories. This is achieved by hooking into your shell's prompt.

### How it Works

1.  When you `cd` into a new directory, `phpswitcher` looks for a `.php-version` file in the current directory or any parent directory.
2.  If a `.php-version` file is found, it reads the required version from it.
3.  If the required version is not the currently active version, `phpswitcher` automatically runs `phpswitcher use` to switch to the correct version.

### Usage

To use this feature, simply create a file named `.php-version` in the root of your project and put the desired PHP version number in it.

```bash
# In your project's root directory
echo "8.1" > .php-version
```

Now, whenever you `cd` into this directory (or any subdirectory), `phpswitcher` will ensure that PHP 8.1 is activated automatically.

This feature is enabled by default during the installation process, which adds a sourcing line to your shell's profile file (`.bashrc` or `.zshrc`).

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
