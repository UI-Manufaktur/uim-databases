/*********************************************************************************************************
* Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        *
* License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  *
* Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      *
**********************************************************************************************************/
module uim.databases.types.batchcastinginterface;

@safe:
import uim.databases;
/**
 * Denotes type objects capable of converting many values from their original
 * database representation to php values.
 */
interface IBatchCasting {
    /**
     * Returns an array of the values converted to the UIM representation of this type.
     *
     * @param array someValues The original array of values containing the fields to be casted
     * someFields - The field keys to cast
     * aDriver - Object from which database preferences and configuration will be extracted.
     */
    DValue[string] manytoD(DValue[] someValues, string[] someFields, IDTBDriver aDriver);
}
