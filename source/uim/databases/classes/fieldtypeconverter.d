module uim.databases;

import uim.cake;

@safe:

/**
 * An invokable class to be used for processing each of the rows in a statement
 * result, so that the values are converted to the right PHP types.
 *
 * @internal
 */
class FieldTypeConverter {
    protected Driver $driver;

    // Maps type names to conversion settings.
    protected array $conversions = [];

    /**
     * Builds the type map
     * Params:
     * \UIM\Database\TypeMap $typeMap Contains the types to use for converting results
     * @param \UIM\Database\Driver $driver The driver to use for the type conversion
     */
    this(TypeMap $typeMap, Driver $driver) {
        this.driver = $driver;

        $types = TypeFactory.buildAll();
        foreach ($field: $typeName; $typeMap.toArray()) {
            $type = $types.get($typeName, null);
            if (!$type || (cast(IOptionalConvert)$type && !$type.requiresToDCast())) {
                continue;
            }
            this.conversions[$typeName] ??= [
                "type": $type,
                "hasBatch": cas(IBatchCasting)$type ,
                "fields": [],
            ];
            this.conversions[$typeName]["fields"] ~= $field;
        }
    }
    
    /**
     * Converts each of the fields in the array that are present in the type map
     * using the corresponding Type class.
     * Params:
     * Json $row The array with the fields to be casted
    */
    Json __invoke(Json $row) {
        if (!isArray($row)) {
            return $row;
        }
        foreach (myConversion; this.conversions) {
            if (myConversion["hasBatch"]) {
                $row = myConversion["type"].manyToD($row, myConversion["fields"], this.driver);
                continue;
            }
            myConversion["fields"].each!(field => $row[field] = myConversion["type"].ToD($row[field], this.driver));
        }
        return $row;
    }
}
