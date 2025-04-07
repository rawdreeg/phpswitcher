# PHP Switcher

A simple CLI tool to manage multiple PHP versions on macOS using Homebrew.
(Currently only supports macOS with Homebrew. Linux/Windows support is planned).

## Features

*   Install specific PHP versions (via Homebrew).
*   Switch the active linked PHP version (via Homebrew).

## Prerequisites

*   **macOS:** The current version only supports macOS.
*   **Homebrew:** Required for installing and managing PHP versions. Ensure it's installed: [https://brew.sh/](https://brew.sh/)

## Installation (Recommended)

Run the following command in your terminal to download and execute the installation script:

```bash
# Ensure you have curl installed
# Download and run the installer script
bash -c "$(curl -fsSL https://raw.githubusercontent.com/rawdreeg/phpswitcher/v0.1.0/install.sh)" 
```

Follow any prompts from the script. You may need to enter your password for `sudo` commands if installing to a system-wide directory like `/usr/local/bin`.

After installation, open a **new terminal session** or run `source ~/.zshrc` (or the equivalent for your shell, like `source ~/.bash_profile`) and verify with:

```bash
phpswitcher --version
```

## Installation from Source (for Development)

1.  Clone the repository: `git clone https://github.com/rawdreeg/phpswitcher.git`
2.  Navigate into the project directory: `cd phpswitcher`.
3.  Run the *local* setup script: `bash install.sh`.
    *Note: Running the script locally like this is intended for development. It checks dependencies and builds the PHAR in the `bin/` directory.*
4.  Test commands using the locally built executable: `./bin/phpswitcher install 8.2`.

## Usage

*(Currently supports macOS/Homebrew only)*

**Install a PHP version:**

```bash
phpswitcher install <version>
# Example:
phpswitcher install 8.1
phpswitcher install 7.4
```

**Switch active PHP version:**

If you are in a directory containing a `composer.json` file with a PHP requirement ('php' key under 'require' or 'config.platform.php'), you can omit the `<version>` argument, and `phpswitcher` will attempt to detect and use the appropriate `X.Y` version.

```bash
phpswitcher use [<version>]
# Examples:
phpswitcher use 8.1 

# Auto-detect from composer.json in current directory:
cd my-project-using-php7.4/
phpswitcher use
```

**Check active PHP version (after switching):**

```bash
php --version
```

## Development

1.  Clone the repository.
2.  Navigate into the project directory: `cd phpswitcher`.
3.  Install dependencies: `composer install`.
4.  Run the setup script (this installs dependencies including Homebrew if missing): `bash install.sh`.
5.  Run commands directly using the local executable: `./bin/phpswitcher install 8.2`.

## Contributing

Contributions are welcome! Please feel free to open issues or submit pull requests.

## License

MIT License 
