module uim.databases.types;

import uim.databases;

@safe:

/**
 * Denotes type objects capable of converting many values from their original
 * database representation to D values.
 */
interface IBatchCasting {
    /**
     * Returns an array of the values converted to the D representation of
     * this type.
     * Params:
     * array  someValues The original array of values containing the fields to be casted
     * @param string[] fields The field keys to cast
     * @param \UIM\Database\Driver driver Object from which database preferences and configuration will be extracted.
     */
    IData[string] manyToD(array  someValues, array fields, Driver driver);
}
