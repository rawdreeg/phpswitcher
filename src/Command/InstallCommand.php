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
use Symfony\Component\Console\Question\Question;
use Symfony\Component\Console\Input\ArrayInput;

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
                InputArgument::OPTIONAL,
                'Target PHP version (e.g., 7.4, 8.1). Detects from composer.json if omitted.'
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
        $detectedVersionSource = null;

        // --- Version Auto-Detection ---
        if (null === $requestedVersion) {
            $output->writeln('<info>Version argument missing, attempting detection from composer.json...</info>');
            $composerJsonPath = getcwd().'/composer.json';

            if (file_exists($composerJsonPath)) {
                $output->writeln(sprintf('Found %s', $composerJsonPath));
                $composerJsonContent = @file_get_contents($composerJsonPath);
                if (false === $composerJsonContent) {
                    $output->writeln('<warning>Could not read composer.json.</warning>');
                } else {
                    $composerData = @json_decode($composerJsonContent, true);
                    if (JSON_ERROR_NONE !== json_last_error()) {
                        $output->writeln('<warning>Could not parse composer.json: '.json_last_error_msg().'</warning>');
                    } else {
                        $constraint = $composerData['require']['php'] ?? $composerData['config']['platform']['php'] ?? null;

                        if ($constraint) {
                            $output->writeln(sprintf('Found PHP constraint: "%s"', $constraint));
                            // Improved extraction: Find the first X.Y or X.Y.Z pattern
                            if (preg_match('/(\d+\.\d+)/ ', $constraint, $matches)) {
                                $requestedVersion = $matches[1]; // Extract only X.Y
                                $detectedVersionSource = 'composer.json';
                                $output->writeln(sprintf('<info>Detected target version %s from %s constraint \'%s\'.</info>', $requestedVersion, $detectedVersionSource, $constraint));
                            } else {
                                $output->writeln(sprintf('<warning>Could not extract an X.Y version from constraint \'%s\'. Please specify version manually.</warning>', $constraint));
                            }
                        } else {
                            $output->writeln('<info>No PHP version constraint (require.php or config.platform.php) found in composer.json.</info>');
                        }
                    }
                }
            } else {
                $output->writeln('<info>No composer.json found in current directory.</info>');
            }

            // If after detection, version is still null, fail.
            if (null === $requestedVersion) {
                $output->writeln('<error>PHP version not specified and could not be detected automatically.</error>');
                $output->writeln(sprintf('Usage: phpswitcher %s [<version>]', $this->getName()));

                return Command::FAILURE;
            }
        }
        // --- End Detection ---

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
            // Ask user if they want to switch to this version now
            $helper = $this->getHelper('question');
            $question = new Question(
                sprintf('Would you like to switch to PHP %s now? (y/N) ', $fullVersion),
                false
            );
            $question->setValidator(function ($answer) {
                return strtolower($answer) === 'y';
            });

            if ($helper->ask($input, $output, $question)) {
                $useCommand = $this->getApplication()->find('use');
                $arguments = [
                    'command' => 'use',
                    'version' => $fullVersion,
                ];
                $useInput = new ArrayInput($arguments);

                return $useCommand->run($useInput, $output);
            }
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
            // Check if the formula exists in Homebrew
            $process = new Process(['brew', 'search', 'php@'.$requestedVersion]);
            $process->run();
            
            if (!$process->isSuccessful() || !str_contains($process->getOutput(), 'php@'.$requestedVersion)) {
                $output->writeln(sprintf('<error>PHP version %s not found in Homebrew. Available versions can be found with `brew search php`.</error>', $requestedVersion));

                return null;
            }

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
}
