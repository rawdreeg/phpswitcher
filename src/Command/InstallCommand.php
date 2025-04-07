<?php

declare(strict_types=1);
/**
 * PHP Switcher Command: Install
 *
 * This command handles the installation of PHP versions.
 *
 * @author Rodrigue T <rawdreeg@gmail.com>
 *
 * @category Command
 *
 * @license MIT https://opensource.org/licenses/MIT
 *
 * @link https://github.com/rawdreeg/phpswitcher
 */

namespace Rawdreeg\PhpSwitcher\Command;

use Rawdreeg\PhpSwitcher\Util\OperatingSystem;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputArgument;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;
use Symfony\Component\Process\Process;
use Symfony\Component\Process\Exception\ProcessFailedException;

/**
 * Command to install a specific PHP version.
 *
 * @author Rodrigue T <rawdreeg@gmail.com>
 *
 * @category Command
 *
 * @license MIT https://opensource.org/licenses/MIT
 *
 * @link https://github.com/rawdreeg/phpswitcher
 */
class InstallCommand extends Command
{
    /**
     * The default command name.
     *
     * @var string|null
     */
    protected static $defaultName = 'install';

    /**
     * The default command description.
     *
     * @var string|null
     */
    protected static $defaultDescription = 'Installs a specific PHP version (macOS/Linux).';

    /**
     * Configures the command.
     *
     * @return void
     */
    protected function configure(): void
    {
        $this
            ->addArgument(
                'version',
                InputArgument::REQUIRED,
                'The PHP version to install (e.g., 7.4, 8.1)'
            );
    }

    /**
     * Executes the command.
     *
     * @param InputInterface  $input  The input interface.
     * @param OutputInterface $output The output interface.
     *
     * @return int Command exit code (0 for success)
     */
    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        $requestedVersion = $input->getArgument('version');

        // Validate version format (X.Y or X.Y.Z)
        if (!preg_match('/^\d+\.\d+(\.\d+)?$/', $requestedVersion)) {
            $output->writeln(
                sprintf(
                    '<error>Invalid version format: "%s". '
                    .' Please use format X.Y or X.Y.Z (e.g., 7.4, 8.1, 8.2.15).</error>',
                    $requestedVersion
                )
            );

            return Command::FAILURE;
        }

        $output->writeln(
            sprintf('Attempting to install PHP version: %s', $requestedVersion)
        );

        // TODO: Version resolution is simplified for macOS only currently.
        $resolved = $this->resolveVersion($requestedVersion, $output);
        if (null === $resolved) {
            $output->writeln('<error>Could not resolve requested PHP version.</error>');

            return Command::FAILURE;
        }
        $packageName = $resolved['packageName']; // e.g., php@8.2 or php8.1
        $fullVersion = $resolved['fullVersion']; // e.g., 8.2 or 8.1

        if (OperatingSystem::isMac()) {
            $this->installMac($packageName, $output);
        } elseif (OperatingSystem::isLinux()) {
            // Basic Linux support (Debian/Ubuntu APT for now)
            if ($this->commandExists('apt-get')) {
                $output->writeln('<info>Detected Debian/Ubuntu Linux. Preparing to use APT...</info>');
                $this->installDebian($packageName, $output);
            } else {
                $output->writeln('<error>Unsupported Linux distribution. Only Debian/Ubuntu (APT) is currently supported.</error>');

                return Command::FAILURE;
            }
        } else {
            $output->writeln(
                sprintf(
                    '<error>Unsupported OS: %s. Only macOS and Linux are supported.</error>',
                    OperatingSystem::getFamily()
                )
            );

            return Command::FAILURE;
        }

        return Command::SUCCESS;
    }

    /**
     * Handles PHP installation on macOS using Homebrew.
     *
     * @param string          $packageName The Homebrew package name (e.g., php@8.2).
     * @param OutputInterface $output      For logging.
     *
     * @return int Command exit code.
     */
    private function installMac(string $packageName, OutputInterface $output): int
    {
        $output->writeln('<info>Detected macOS. Preparing to use Homebrew...</info>');

        // Check if already installed
        $checkProcess = new Process(['brew', 'list', $packageName]);
        try {
            $checkProcess->mustRun();
            $output->writeln(
                sprintf('<comment>%s is already installed via Homebrew.</comment>', $packageName)
            );

            return Command::SUCCESS; // Already installed
        } catch (ProcessFailedException $e) {
            // Not installed, proceed with installation
            $output->writeln(sprintf('Attempting to install %s...', $packageName));
            $installProcess = new Process(['brew', 'install', $packageName]);
            $installProcess->setTimeout(3600);

            try {
                $installProcess->mustRun(
                    function ($type, $buffer) use ($output) {
                        $output->write($buffer);
                    }
                );
                $output->writeln(
                    sprintf('<info>%s installed successfully!</info>', $packageName)
                );
                // TODO: After successful install, offer to automatically run 'use' command?
                return Command::SUCCESS;
            } catch (ProcessFailedException $exception) {
                $output->writeln(
                    sprintf(
                        '<error>Failed to install %s: %s</error>',
                        $packageName,
                        $exception->getMessage()
                    )
                );

                return Command::FAILURE;
            }
        }
    }

    /**
     * Handles PHP installation on Debian/Ubuntu using APT.
     *
     * @param string          $packageName The APT package name (e.g., php8.1).
     * @param OutputInterface $output      For logging.
     *
     * @return int Command exit code.
     */
    private function installDebian(string $packageName, OutputInterface $output): int
    {
        // Check if already installed using dpkg
        $checkProcess = new Process(['dpkg', '-s', $packageName]);
        try {
            // We expect a non-zero exit code if not installed, suppress output
            $checkProcess->disableOutput()->mustRun();
            $output->writeln(
                sprintf('<comment>%s is already installed via APT.</comment>', $packageName)
            );

            return Command::SUCCESS; // Already installed
        } catch (ProcessFailedException $e) {
            // Not installed, proceed with installation
            $output->writeln(sprintf('Attempting to install %s...', $packageName));
            $output->writeln('<comment>This may require sudo privileges.</comment>');

            // Ensure APT cache is updated
            $output->writeln('Updating APT package list (sudo apt-get update)...');
            $updateProcess = new Process(['sudo', 'apt-get', 'update']);
            try {
                $updateProcess->setTimeout(300)->mustRun(
                    function ($type, $buffer) use ($output) {
                        $output->write($buffer);
                    }
                );
            } catch (ProcessFailedException $exception) {
                $output->writeln(
                    sprintf(
                        '<error>Failed to update APT cache: %s</error>',
                        $exception->getMessage()
                    )
                );

                return Command::FAILURE;
            }

            // Install the package
            // We likely need common extensions too, start with cli and common
            // TODO: Make installable extensions configurable?
            $fullPackageName = $packageName.'-cli'; // Assume we at least need the CLI
            $output->writeln(sprintf('Installing %s (sudo apt-get install -y %s)...', $fullPackageName, $fullPackageName));
            $installProcess = new Process(['sudo', 'apt-get', 'install', '-y', $fullPackageName]);
            $installProcess->setTimeout(3600);

            try {
                $installProcess->mustRun(
                    function ($type, $buffer) use ($output) {
                        $output->write($buffer);
                    }
                );
                $output->writeln(
                    sprintf('<info>%s installed successfully!</info>', $fullPackageName)
                );
                // TODO: After successful install, offer to automatically run 'use' command?
                return Command::SUCCESS;
            } catch (ProcessFailedException $exception) {
                $output->writeln(
                    sprintf(
                        '<error>Failed to install %s: %s</error>',
                        $fullPackageName,
                        $exception->getMessage()
                    )
                );
                // Provide hint about needing PPA for older/newer versions
                if (str_contains($exception->getMessage(), 'Unable to locate package')) {
                    $output->writeln('<comment>Hint: For PHP versions not in standard repositories, you might need the Ondřej Surý PPA: https://launchpad.net/~ondrej/+archive/ubuntu/php</comment>');
                }

                return Command::FAILURE;
            }
        }
    }

    /**
     * Resolves a partial PHP version (e.g., "8.2") to a full package version/name
     * based on the detected OS and package manager.
     *
     * @param string          $requestedVersion The partial version from user input.
     * @param OutputInterface $output           For logging.
     *
     * @return array{packageName: string, fullVersion: string}|null An array containing
     *                                                           package name and full version,
     *                                                           or null on failure.
     */
    private function resolveVersion(string $requestedVersion, OutputInterface $output): ?array
    {
        $output->writeln(
            sprintf(
                'Resolving version %s for %s...',
                $requestedVersion,
                OperatingSystem::getFamily()
            )
        );

        if (OperatingSystem::isMac()) {
            // Homebrew uses php@X.Y format for formulae.
            // TODO: Add `brew search php@X.Y` check to confirm formula existence before assuming.
            $packageName = 'php@'.$requestedVersion;
            $output->writeln(sprintf('Assuming Homebrew package: %s', $packageName));
            // For Homebrew, the 'fullVersion' isn't strictly separate, the formula name IS the identifier.
            return ['packageName' => $packageName, 'fullVersion' => $requestedVersion];
        }

        if (OperatingSystem::isLinux()) {
            // Basic support for Debian/Ubuntu APT naming (e.g., php8.1)
            // TODO: Add detection for other package managers (yum/dnf?)
            if ($this->commandExists('apt-get')) {
                // APT uses phpX.Y format (strip patch version if present)
                preg_match('/^(\d+\.\d+)/ ', $requestedVersion, $matches);
                if (empty($matches[1])) {
                    $output->writeln('<error>Could not extract X.Y version for APT package name.</error>');

                    return null;
                }
                $baseVersion = $matches[1]; // e.g., 8.1
                $packageName = 'php'.$baseVersion;
                $output->writeln(sprintf('Assuming APT package: %s', $packageName));

                return ['packageName' => $packageName, 'fullVersion' => $baseVersion];
            } else {
                $output->writeln('<error>Linux distribution detected, but only APT (Debian/Ubuntu) is supported for package name resolution.</error>');

                return null;
            }
        }

        $output->writeln(
            '<error>Currently only macOS (using Homebrew) and Linux (using APT) are supported for version resolution.</error>'
        );

        return null;
    }

    /**
     * Helper function to check if a command exists.
     *
     * @param string $command The command name to check.
     *
     * @return bool True if the command exists, false otherwise.
     */
    private function commandExists(string $command): bool
    {
        try {
            // Use 'command -v' which is more POSIX compliant than 'which'
            $checkCmd = "command -v {$command} > /dev/null 2>&1";

            $process = new Process(['sh', '-c', $checkCmd]);
            $process->mustRun();

            return true;
        } catch (ProcessFailedException $e) {
            return false;
        }
    }
}
