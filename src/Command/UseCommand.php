<?php

declare(strict_types=1);
/**
 * PHP Switcher Command: Use
 *
 * This command handles switching the active PHP version.
 *
 * @category Command
 *
 * @author Rodrigue T <rawdreeg@gmail.com>
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
 * Command to switch the active PHP version.
 *
 * @category Command
 *
 * @author Rodrigue T <rawdreeg@gmail.com>
 *
 * @license MIT https://opensource.org/licenses/MIT
 *
 * @link https://github.com/rawdreeg/phpswitcher
 */
class UseCommand extends Command
{
    /**
     * The default command name.
     *
     * @var string|null
     */
    protected static $defaultName = 'use';

    /**
     * The default command description.
     *
     * @var string|null
     */
    protected static $defaultDescription = 'Switches the active PHP version (macOS/Linux).';

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
                'The PHP version to switch to (e.g., 8.1)'
            );
    }

    /**
     * Executes the command.
     *
     * @param InputInterface  $input  The input interface.
     * @param OutputInterface $output The output interface
     *
     * @return int Command exit code (0 for success)
     */
    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        $requestedVersion = $input->getArgument('version');

        // Validate version format (X.Y)
        if (!preg_match('/^\d+\.\d+$/', $requestedVersion)) {
            $output->writeln(
                sprintf(
                    '<error>Invalid version format: "%s". Please use format X.Y (e.g., 7.4, 8.1).</error>',
                    $requestedVersion
                )
            );

            return Command::FAILURE;
        }

        if (OperatingSystem::isMac()) {
            return $this->switchMac($requestedVersion, $output);
        }

        // If not macOS, check Linux
        if (OperatingSystem::isLinux()) {
            // Basic Linux support (Debian/Ubuntu update-alternatives for now)
            if ($this->commandExists('update-alternatives')) {
                $output->writeln('<info>Detected Debian/Ubuntu Linux. Preparing to use update-alternatives...</info>');

                return $this->switchDebian($requestedVersion, $output);
            }

            // If command doesn't exist or other Linux
            $output->writeln('<error>Unsupported Linux distribution. Only Debian/Ubuntu (with update-alternatives) is currently supported for switching.</error>');

            return Command::FAILURE;
        }

        // If not macOS or Linux
        $output->writeln(
            sprintf(
                '<error>Unsupported OS: %s. Only macOS and Linux are supported.</error>',
                OperatingSystem::getFamily()
            )
        );

        return Command::FAILURE;
    }

    /**
     * Handles switching PHP versions on macOS using Homebrew link/unlink.
     *
     * @param string          $requestedVersion The target version (e.g., 8.1).
     * @param OutputInterface $output           For logging.
     *
     * @return int Command exit code.
     */
    private function switchMac(string $requestedVersion, OutputInterface $output): int
    {
        $targetPackage = 'php@'.$requestedVersion;
        $output->writeln(sprintf('Attempting to switch to %s via Homebrew...', $targetPackage));

        // 1. Check if target version is installed via Homebrew
        try {
            $checkProcess = new Process(['brew', 'list', $targetPackage]);
            $checkProcess->mustRun();
            $output->writeln(sprintf('<info>%s is installed.</info>', $targetPackage));
        } catch (ProcessFailedException $e) {
            $output->writeln(
                sprintf(
                    '<error>Target version %s does not appear to be installed via Homebrew.</error>',
                    $targetPackage
                )
            );
            $output->writeln(
                sprintf('Please run `phpswitcher install %s` first.', $requestedVersion)
            );

            return Command::FAILURE;
        }

        // 2. Get all installed PHP versions from Homebrew
        $listProcess = new Process(['brew', 'list', '--formula']);
        try {
            $listProcess->mustRun();
            $installedFormulas = explode("\n", trim($listProcess->getOutput()));
            $installedPhpVersions = array_filter(
                $installedFormulas,
                function ($formula) {
                    return strpos($formula, 'php@') === 0;
                }
            );
        } catch (ProcessFailedException $e) {
            $output->writeln('<error>Failed to list installed Homebrew formulas.</error>');

            return Command::FAILURE;
        }

        // 3. Unlink all other installed PHP versions
        $output->writeln('Unlinking other PHP versions...');
        foreach ($installedPhpVersions as $phpVersionFormula) {
            if ($phpVersionFormula === $targetPackage) {
                continue;
            }
            try {
                $output->writeln(sprintf(' - Unlinking %s', $phpVersionFormula));
                $unlinkProcess = new Process(['brew', 'unlink', $phpVersionFormula]);
                $unlinkProcess->mustRun();
            } catch (ProcessFailedException $e) {
                // Unlink might fail if it wasn't linked; often safe to ignore.
                $output->writeln(
                    sprintf(
                        '<comment>  - Could not unlink %s (maybe already unlinked).</comment>',
                        $phpVersionFormula
                    )
                );
            }
        }

        // 4. Link the target PHP version
        $output->writeln(sprintf('Linking %s...', $targetPackage));
        try {
            $linkProcess = new Process(['brew', 'link', '--force', '--overwrite', $targetPackage]);
            $linkProcess->mustRun(
                function ($type, $buffer) use ($output) {
                    $output->write($buffer);
                }
            );
            $output->writeln(sprintf('<info>Successfully switched to %s!</info>', $targetPackage));
            $output->writeln(
                '<comment>Changes should take effect immediately. '
                .'If you experience issues, try restarting your terminal session.</comment>'
            );
        } catch (ProcessFailedException $e) {
            $output->writeln(
                sprintf(
                    '<error>Failed to link %s: %s</error>',
                    $targetPackage,
                    $e->getMessage()
                )
            );

            return Command::FAILURE;
        }

        return Command::SUCCESS;
    }

    /**
     * Handles switching PHP versions on Debian/Ubuntu using update-alternatives.
     *
     * @param string          $requestedVersion The target version (e.g., 8.1).
     * @param OutputInterface $output           For logging.
     *
     * @return int Command exit code.
     */
    private function switchDebian(string $requestedVersion, OutputInterface $output): int
    {
        // Determine expected path (common location for APT installs)
        $phpExecutablePath = '/usr/bin/php'.$requestedVersion;
        $output->writeln(sprintf('Attempting to switch to %s via update-alternatives...', $phpExecutablePath));

        // 1. Check if the target PHP executable exists
        if (!file_exists($phpExecutablePath)) {
            $output->writeln(
                sprintf(
                    '<error>Target PHP executable %s not found. Is PHP %s installed correctly via APT?</error>',
                    $phpExecutablePath,
                    $requestedVersion
                )
            );
            $output->writeln(
                sprintf('Please run `phpswitcher install %s` first.', $requestedVersion)
            );

            return Command::FAILURE;
        }

        // 2. Execute update-alternatives --set
        $output->writeln('<comment>This may require sudo privileges.</comment>');
        $output->writeln(sprintf('Running: sudo update-alternatives --set php %s', $phpExecutablePath));
        $switchProcess = new Process(['sudo', 'update-alternatives', '--set', 'php', $phpExecutablePath]);

        try {
            $switchProcess->mustRun(
                function ($type, $buffer) use ($output) {
                    $output->write($buffer);
                }
            );
            $output->writeln(sprintf('<info>Successfully set default PHP to %s!</info>', $phpExecutablePath));
            $output->writeln('<comment>Changes should take effect immediately.</comment>');

            return Command::SUCCESS;
        } catch (ProcessFailedException $e) {
            $output->writeln(
                sprintf(
                    '<error>Failed to set update-alternatives for %s: %s</error>',
                    $phpExecutablePath,
                    $e->getMessage()
                )
            );
            // Provide hints
            if (str_contains($e->getMessage(), 'is not managed using update-alternatives')) {
                $output->writeln('<comment>Hint: PHP might not be managed by update-alternatives on this system.</comment>');
            } elseif (str_contains($e->getMessage(), 'no alternatives for php')) {
                $output->writeln('<comment>Hint: PHP alternatives might not be configured. You may need to run `sudo update-alternatives --install /usr/bin/php php /usr/bin/phpX.Y PRIORITY` for each installed version first.</comment>');
            } elseif (str_contains($e->getMessage(), 'permission denied') || str_contains($e->getMessage(), 'not in the sudoers file')) {
                $output->writeln('<comment>Hint: Switching requires sudo privileges.</comment>');
            }

            return Command::FAILURE;
        }
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
