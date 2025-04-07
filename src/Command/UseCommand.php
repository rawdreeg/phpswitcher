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
    protected static $defaultDescription = 'Switches the active PHP version (macOS/Homebrew only).';

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
        // Ensure running on macOS
        if (!OperatingSystem::isMac()) {
            $output->writeln(
                '<error>The \'use\' command currently only supports macOS with Homebrew.</error>'
            );

            return Command::FAILURE;
        }

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

        $targetPackage = 'php@'.$requestedVersion;
        $output->writeln(sprintf('Attempting to switch to %s...', $targetPackage));

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
}
