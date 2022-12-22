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
 * @since         3.1.2
 * @license       https://opensource.org/licenses/mit-license.php MIT License
 */
namespace Cake\Database\Type;

use Cake\Database\IDTBDriver;
use InvalidArgumentException;
use PDO;

/**
 * String type converter.
 *
 * Use to convert string data between PHP and the database types.
 */
class StringType : BaseType : OptionalConvertInterface
{
    /**
     * Convert string data into the database format.
     *
     * @param mixed aValue The value to convert.
     * @param \Cake\Database\IDTBDriver aDriver The driver instance to convert with.
     * @return string|null
     */
    function toDatabase(DValue aValue, IDTBDriver aDriver): ?string
    {
        if (DValue aValue == null || is_string(DValue aValue)) {
            return aValue;
        }

        if (is_object(DValue aValue) && method_exists(DValue aValue, "__toString")) {
            return aValue.__toString();
        }

        if (is_scalar(DValue aValue)) {
            return (string)aValue;
        }

        throw new InvalidArgumentException(sprintf(
            "Cannot convert value of type `%s` to string",
            getTypeName(DValue aValue)
        ));
    }

    /**
     * Convert string values to PHP strings.
     *
     * @param mixed aValue The value to convert.
     * @param \Cake\Database\IDTBDriver aDriver The driver instance to convert with.
     * @return string|null
     */
    function toD(DValue aValue, IDTBDriver aDriver): ?string
    {
        if (DValue aValue == null) {
            return null;
        }

        return (string)aValue;
    }

    /**
     * Get the correct PDO binding type for string data.
     *
     * @param mixed aValue The value being bound.
     * @param \Cake\Database\IDTBDriver aDriver The driver.
     * @return int
     */
    function toStatement(DValue aValue, IDTBDriver aDriver): int
    {
        return PDO::PARAM_STR;
    }

    /**
     * Marshals request data into PHP strings.
     *
     * @param mixed aValue The value to convert.
     * @return string|null Converted value.
     */
    function marshal(DValue aValue): ?string
    {
        if (DValue aValue == null || is_array(DValue aValue)) {
            return null;
        }

        return (string)aValue;
    }

    /**
     * {@inheritDoc}
     *
     * @return bool False as database results are returned already as strings
     */
    function requirestoDCast(): bool
    {
        return false;
    }
}
