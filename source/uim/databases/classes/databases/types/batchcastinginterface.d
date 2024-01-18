module uim.cake.databases.types;

import uim.cake;

@safe:

/**
 * Denotes type objects capable of converting many values from their original
 * database representation to php values.
 */
interface IBatchCasting {
    /**
     * Returns an array of the values converted to the PHP representation of
     * this type.
     * Params:
     * array  someValues The original array of values containing the fields to be casted
     * @param string[] $fields The field keys to cast
     * @param \UIM\Database\Driver $driver Object from which database preferences and configuration will be extracted.
     */
    Json[string] manyToD(array  someValues, array $fields, Driver $driver);
}
