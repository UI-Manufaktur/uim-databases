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

use Cake\Database\IDTBDriver;
use Cake\Utility\Text;

/**
 * Provides behavior for the UUID type
 */
class UuidType : StringType
{
    /**
     * Casts given value from a PHP type to one acceptable by database
     *
     * @param mixed aValue value to be converted to database equivalent
     * @param \Cake\Database\IDTBDriver aDriver object from which database preferences and configuration will be extracted
     * @return string|null
     */
    function toDatabase(DValue aValue, IDTBDriver aDriver): ?string
    {
        if (DValue aValue == null || aValue == "" || aValue == false) {
            return null;
        }

        return parent::toDatabase(DValue aValue, $driver);
    }

    /**
     * Generate a new UUID
     *
     * @return string A new primary key value.
     */
    function newId(): string
    {
        return Text::uuid();
    }

    /**
     * Marshals request data into a PHP string
     *
     * @param mixed aValue The value to convert.
     * @return string|null Converted value.
     */
    function marshal(DValue aValue): ?string
    {
        if (DValue aValue == null || aValue == "" || is_array(DValue aValue)) {
            return null;
        }

        return (string)aValue;
    }
}
