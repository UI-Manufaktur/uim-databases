/*********************************************************************************************************
  Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        
  License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  
  Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      
**********************************************************************************************************/
module uim.cake.databases;

@safe:
import uim.cake;

module uim.cake.databases;

import uim.cake.databases.types.BatchCastingInterface;
import uim.cake.databases.types.OptionalConvertInterface;

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
     * @var array<uim.cake.databases.TypeInterface>
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
     * @var array<uim.cake.databases.TypeInterface|uim.cake.databases.types.BatchCastingInterface>
     */
    protected $types;

    /**
     * The driver object to be used in the type conversion
     *
     * @var DDBIDriver
     */
    protected _driver;

    /**
     * Builds the type map
     *
     * @param uim.cake.databases.TypeMap $typeMap Contains the types to use for converting results
     * @param uim.cake.databases.IDriver aDriver The driver to use for the type conversion
     */
    this(TypeMap $typeMap, IDriver aDriver) {
        _driver = $driver;
        $map = $typeMap.toArray();
        $types = TypeFactory::buildAll();

        $simpleMap = $batchingMap = null;
        $simpleResult = $batchingResult = null;

        foreach ($types as $k: $type) {
            if ($type instanceof OptionalConvertInterface && !$type.requiresToPhpCast()) {
                continue;
            }

            if ($type instanceof BatchCastingInterface) {
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
     * @param array $row The array with the fields to be casted
     * @return array<string, mixed>
     */
    array __invoke(array $row) {
        if (!empty(_typeMap)) {
            foreach (_typeMap as $field: $type) {
                $row[$field] = $type.toPHP($row[$field], _driver);
            }
        }

        if (!empty(this.batchingTypeMap)) {
            foreach (this.batchingTypeMap as $t: $fields) {
                /** @psalm-suppress PossiblyUndefinedMethod */
                $row = this.types[$t].manyToPHP($row, $fields, _driver);
            }
        }

        return $row;
    }
}
