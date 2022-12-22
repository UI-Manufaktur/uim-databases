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
 * @since         3.0.0
 * @license       https://opensource.org/licenses/mit-license.php MIT License
 */
namespace Cake\Database\Type;

use Cake\Core\Exception\CakeException;
use Cake\Database\IDTBDriver;
use PDO;

/**
 * Binary type converter.
 *
 * Use to convert binary data between PHP and the database types.
 */
class BinaryType : BaseType
{
    /**
     * Convert binary data into the database format.
     *
     * Binary data is not altered before being inserted into the database.
     * As PDO will handle reading file handles.
     *
     * @param mixed aValue The value to convert.
     * @param \Cake\Database\IDTBDriver aDriver The driver instance to convert with.
     * @return resource|string
     */
    function toDatabase(DValue aValue, IDTBDriver aDriver)
    {
        return aValue;
    }

    /**
     * Convert binary into resource handles
     *
     * @param mixed aValue The value to convert.
     * @param \Cake\Database\IDTBDriver aDriver The driver instance to convert with.
     * @return resource|null
     * @throws \Cake\Core\Exception\CakeException
     */
    function toD(DValue aValue, IDTBDriver aDriver)
    {
        if (DValue aValue == null) {
            return null;
        }
        if (is_string(DValue aValue)) {
            return fopen("data:text/plain;base64," . base64_encode(DValue aValue), "rb");
        }
        if (is_resource(DValue aValue)) {
            return aValue;
        }
        throw new CakeException(sprintf("Unable to convert %s into binary.", gettype(DValue aValue)));
    }

    /**
     * Get the correct PDO binding type for Binary data.
     *
     * @param mixed aValue The value being bound.
     * @param \Cake\Database\IDTBDriver aDriver The driver.
     * @return int
     */
    function toStatement(DValue aValue, IDTBDriver aDriver): int
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
    function marshal(DValue aValue)
    {
        return aValue;
    }
}
