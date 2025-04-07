# PHP Switcher

A simple CLI tool to manage multiple PHP versions on macOS using Homebrew.
(Linux and Windows support planned).

## Features

*   Install specific PHP versions (via Homebrew).
*   Switch the active linked PHP version (via Homebrew).

## Installation

1.  **Ensure Composer is installed:** [Install Composer](https://getcomposer.org/download/)
2.  **Require the package globally:**
    ```bash
    composer global require rawdreeg/phpswitcher
    ```
3.  **Ensure Composer's global bin directory is in your PATH:**
    Add the following line to your shell profile (`~/.zshrc`, `~/.bash_profile`, etc.) if it's not already there:
    ```bash
    export PATH="$HOME/.composer/vendor/bin:$PATH"
    ```
    Then reload your profile (`source ~/.zshrc` or restart your terminal).

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

```bash
phpswitcher use <version>
# Example:
phpswitcher use 8.1 
```

**Check current PHP version:**

```bash
php --version
```

## Development

1.  Clone the repository.
2.  Navigate into the project directory: `cd phpswitcher`
3.  Install dependencies: `composer install`
4.  Run commands directly: `./bin/phpswitcher install 8.2`

## Contributing

Contributions are welcome! Please feel free to open issues or submit pull requests.

## License

MIT License 