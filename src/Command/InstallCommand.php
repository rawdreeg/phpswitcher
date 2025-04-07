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
    protected static $defaultDescription = 'Installs a specific PHP version (macOS/Homebrew only).';

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
        $resolved = $this->_resolveVersion($requestedVersion, $output);
        if (null === $resolved) {
            $output->writeln('<error>Could not resolve requested PHP version.</error>');

            return Command::FAILURE;
        }
        $packageName = $resolved['packageName']; // e.g., php@8.2
        $fullVersion = $resolved['fullVersion']; // e.g., 8.2

        if (OperatingSystem::isMac()) {
            $output->writeln('<info>Detected macOS. Preparing to use Homebrew...</info>');

            // Check if already installed
            $checkProcess = new Process(['brew', 'list', $packageName]);
            try {
                $checkProcess->mustRun();
                $output->writeln(
                    sprintf('<comment>%s is already installed via Homebrew.</comment>', $packageName)
                );
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
            // TODO: After successful install, offer to automatically run 'use' command?
        } else {
            $output->writeln(
                sprintf(
                    '<error>Unsupported OS: %s. Only macOS is supported.</error>',
                    OperatingSystem::getFamily()
                )
            );

            return Command::FAILURE;
        }

        return Command::SUCCESS;
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
    private function _resolveVersion(string $requestedVersion, OutputInterface $output): ?array
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

        $output->writeln(
            '<error>Currently only macOS (using Homebrew) is supported for version resolution.</error>'
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
    private function _commandExists(string $command): bool
    {
        try {
            $checkCmd = OperatingSystem::isWindows()
                ? "where {$command} > NUL 2>&1"
                : "command -v {$command} > /dev/null 2>&1 || which {$command} > /dev/null 2>&1";

            // TODO: Test Windows command execution robustness
            $process = new Process(['sh', '-c', $checkCmd]);
            if (OperatingSystem::isWindows()) {
                $process = new Process(['cmd', '/c', $checkCmd]);
            }

            $process->mustRun();

            return true;
        } catch (ProcessFailedException $e) {
            return false;
        }
    }
}
