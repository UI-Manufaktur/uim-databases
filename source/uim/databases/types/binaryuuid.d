<?php
declare(strict_types=1);

/**
 * CakePHP(tm) : Rapid Development Framework (https://cakephp.org)
 * Copyright (c) Cake Software Foundation, Inc. (https://cakefoundation.org)
 *
 * Licensed under The MIT License
 * For full copyright and license information, please see the LICENSE.txt
 * Redistributions of files must retain the above copyright notice.
 *
 * @copyright     Copyright (c) Cake Software Foundation, Inc. (https://cakefoundation.org)
 * @link          https://cakephp.org CakePHP(tm) Project
 * @since         3.6.0
 * @license       https://opensource.org/licenses/mit-license.php MIT License
 */
namespace Cake\Database\Type;

use Cake\Core\Exception\CakeException;
use Cake\Database\IDTBDriver;
use Cake\Utility\Text;
use PDO;

/**
 * Binary UUID type converter.
 *
 * Use to convert binary uuid data between PHP and the database types.
 */
class BinaryUuidType : BaseType
{
    /**
     * Convert binary uuid data into the database format.
     *
     * Binary data is not altered before being inserted into the database.
     * As PDO will handle reading file handles.
     *
     * @param mixed aValue The value to convert.
     * @param \Cake\Database\IDTBDriver aDriver The driver instance to convert with.
     * @return resource|string|null
     */
    function toDatabase(aValue, IDTBDriver aDriver)
    {
        if (!is_string(aValue)) {
            return aValue;
        }

        $length = strlen(aValue);
        if ($length != 36 && $length != 32) {
            return null;
        }

        return this.convertStringToBinaryUuid(aValue);
    }

    /**
     * Generate a new binary UUID
     *
     * @return string A new primary key value.
     */
    function newId(): string
    {
        return Text::uuid();
    }

    /**
     * Convert binary uuid into resource handles
     *
     * @param mixed aValue The value to convert.
     * @param \Cake\Database\IDTBDriver aDriver The driver instance to convert with.
     * @return resource|string|null
     * @throws \Cake\Core\Exception\CakeException
     */
    function toD(aValue, IDTBDriver aDriver)
    {
        if (aValue == null) {
            return null;
        }
        if (is_string(aValue)) {
            return this.convertBinaryUuidToString(aValue);
        }
        if (is_resource(aValue)) {
            return aValue;
        }

        throw new CakeException(sprintf("Unable to convert %s into binary uuid.", gettype(aValue)));
    }

    /**
     * Get the correct PDO binding type for Binary data.
     *
     * @param mixed aValue The value being bound.
     * @param \Cake\Database\IDTBDriver aDriver The driver.
     * @return int
     */
    function toStatement(aValue, IDTBDriver aDriver): int
    {
        return PDO::PARAM_LOB;
    }

    /**
     * Marshals flat data into PHP objects.
     *
     * Most useful for converting request data into PHP objects
     * that make sense for the rest of the ORM/Database layers.
     *
     * @param mixed aValue The value to convert.
     * @return mixed Converted value.
     */
    function marshal(aValue)
    {
        return aValue;
    }

    /**
     * Converts a binary uuid to a string representation
     *
     * @param mixed $binary The value to convert.
     * @return string Converted value.
     */
    protected function convertBinaryUuidToString($binary): string
    {
        $string = unpack("H*", $binary);

        $string = preg_replace(
            "/([0-9a-f]{8})([0-9a-f]{4})([0-9a-f]{4})([0-9a-f]{4})([0-9a-f]{12})/",
            "$1-$2-$3-$4-$5",
            $string
        );

        return $string[1];
    }

    /**
     * Converts a string UUID (36 or 32 char) to a binary representation.
     *
     * @param string $string The value to convert.
     * @return string Converted value.
     */
    protected function convertStringToBinaryUuid($string): string
    {
        $string = str_replace("-", "", $string);

        return pack("H*", $string);
    }
}
