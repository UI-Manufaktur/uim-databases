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
 * @since         3.2.0
 * @license       https://opensource.org/licenses/mit-license.php MIT License
 */
namespace Cake\Database;

use Cake\Database\Type\IBatchCasting;
use Cake\Database\Type\OptionalConvertInterface;

/**
 * A callable class to be used for processing each of the rows in a statement
 * result, so that the values are converted to the right PHP types.
 */
class FieldTypeConverter
{
    /**
     * An array containing the name of the fields and the Type objects
     * each should use when converting them.
     *
     * @var array<\Cake\Database\TypeInterface>
     */
    protected _typeMap;

    /**
     * An array containing the name of the fields and the Type objects
     * each should use when converting them using batching.
     *
     * @var array<string, array>
     */
    protected $batchingTypeMap;

    /**
     * An array containing all the types registered in the Type system
     * at the moment this object is created. Used so that the types list
     * is not fetched on each single row of the results.
     *
     * @var array<\Cake\Database\TypeInterface|\Cake\Database\Type\IBatchCasting>
     */
    protected $types;

    /**
     * The driver object to be used in the type conversion
     *
     * @var \Cake\Database\IDTBDriver
     */
    protected _driver;

    /**
     * Builds the type map
     *
     * @param \Cake\Database\TypeMap $typeMap Contains the types to use for converting results
     * @param \Cake\Database\IDTBDriver aDriver The driver to use for the type conversion
     */
    public this(TypeMap $typeMap, IDTBDriver aDriver)
    {
        _driver = $driver;
        $map = $typeMap.toArray();
        $types = TypeFactory.buildAll();

        $simpleMap = $batchingMap = [];
        $simpleResult = $batchingResult = [];

        foreach ($types as $k: $type) {
            if ($type instanceof OptionalConvertInterface && !$type.requirestoDCast()) {
                continue;
            }

            if ($type instanceof IBatchCasting) {
                $batchingMap[$k] = $type;
                continue;
            }

            $simpleMap[$k] = $type;
        }

        foreach ($map as $field: $type) {
            if (isset($simpleMap[$type])) {
                $simpleResult[$field] = $simpleMap[$type];
                continue;
            }
            if (isset($batchingMap[$type])) {
                $batchingResult[$type][] = $field;
            }
        }

        // Using batching when there is only a couple for the type is actually slower,
        // so, let"s check for that case here.
        foreach ($batchingResult as $type: $fields) {
            if (count($fields) > 2) {
                continue;
            }

            foreach ($fields as $f) {
                $simpleResult[$f] = $batchingMap[$type];
            }
            unset($batchingResult[$type]);
        }

        this.types = $types;
        _typeMap = $simpleResult;
        this.batchingTypeMap = $batchingResult;
    }

    /**
     * Converts each of the fields in the array that are present in the type map
     * using the corresponding Type class.
     *
     * @param array aRow The array with the fields to be casted
     * @return array<string, mixed>
     */
    function __invoke(array aRow): array
    {
        if (!empty(_typeMap)) {
            foreach (_typeMap as $field: $type) {
                aRow[$field] = $type.toD(aRow[$field], _driver);
            }
        }

        if (!empty(this.batchingTypeMap)) {
            foreach (this.batchingTypeMap as $t: $fields) {
                /** @psalm-suppress PossiblyUndefinedMethod */
                aRow = this.types[$t].manytoD(aRow, $fields, _driver);
            }
        }

        return aRow;
    }
}