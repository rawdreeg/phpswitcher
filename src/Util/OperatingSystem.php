<?php

declare(strict_types=1);
/**
 * Operating System Utilities
 *
 * Php version ^8.1
 *
 * @category Utility
 *
 * @author Rodrigue T <rawdreeg@gmail.com>
 *
 * @license MIT https://opensource.org/licenses/MIT
 *
 * @link https://github.com/rawdreeg/phpswitcher
 */

namespace Rawdreeg\PhpSwitcher\Util;

/**
 * Provides utility methods related to the operating system.
 *
 * @category Utility
 *
 * @author Rodrigue T <rawdreeg@gmail.com>
 *
 * @license MIT https://opensource.org/licenses/MIT
 *
 * @link https://github.com/rawdreeg/phpswitcher
 */
class OperatingSystem
{
    public const FAMILY_DARWIN = 'Darwin';
    public const FAMILY_LINUX  = 'Linux';
    public const FAMILY_WINDOWS = 'Windows';
    // TODO: Add other families like BSD if needed later

    /**
     * Gets the current operating system family.
     *
     * @return string The OS family (e.g., 'Darwin', 'Linux').
     */
    public static function getFamily(): string
    {
        return PHP_OS_FAMILY;
    }

    /**
     * Checks if the current OS is macOS.
     *
     * @return bool True if macOS, false otherwise.
     */
    public static function isMac(): bool
    {
        return self::getFamily() === self::FAMILY_DARWIN;
    }

    /**
     * Checks if the current OS is Linux.
     *
     * @return bool True if Linux, false otherwise.
     */
    public static function isLinux(): bool
    {
        return self::getFamily() === self::FAMILY_LINUX;
    }

    /**
     * Checks if the current OS is Windows.
     *
     * @return bool True if Windows, false otherwise.
     */
    public static function isWindows(): bool
    {
        return self::getFamily() === self::FAMILY_WINDOWS;
    }
}
