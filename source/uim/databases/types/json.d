/*********************************************************************************************************
* Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        *
* License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  *
* Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      *
**********************************************************************************************************/
module uim.databases.types.json;

@safe:
import uim.databases;

/**
 * JSON type converter.
 *
 * Use to convert JSON data between PHP and the database types.
 */
class JsonType : BaseType, IBatchCasting
{
    /**
     * @var int
     */
    protected _encodingOptions = 0;

    /**
     * Convert a value data into a JSON string
     *
     * @param mixed aValue The value to convert.
     * @param \Cake\Database\IDTBDriver aDriver The driver instance to convert with.
     * @return string|null
     * @throws \InvalidArgumentException
     */
    function toDatabase(DValue aValue, IDTBDriver aDriver): ?string
    {
        if (is_resource(DValue aValue)) {
            throw new InvalidArgumentException("Cannot convert a resource value to JSON");
        }

        if (DValue aValue == null) {
            return null;
        }

        return json_encode(DValue aValue, this._encodingOptions);
    }

    /**
     * {@inheritDoc}
     *
     * @param mixed aValue The value to convert.
     * @param \Cake\Database\IDTBDriver aDriver The driver instance to convert with.
     * @return array|string|null
     */
    function toD(DValue aValue, IDTBDriver aDriver)
    {
        if (!is_string(DValue aValue)) {
            return null;
        }

        return json_decode(DValue aValue, true);
    }


    function manytoD(array someValues, string[] someFields, IDTBDriver aDriver): array
    {
        foreach ($fields as $field) {
            if (!isset(someValues[$field])) {
                continue;
            }

            someValues[$field] = json_decode(someValues[$field], true);
        }

        return someValues;
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
     * Marshals request data into a JSON compatible structure.
     *
     * @param mixed aValue The value to convert.
     * @return mixed Converted value.
     */
    function marshal(DValue aValue)
    {
        return aValue;
    }

    /**
     * Set json_encode options.
     *
     * @param int $options Encoding flags. Use JSON_* flags. Set `0` to reset.
     * @return this
     * @see https://www.php.net/manual/en/function.json-encode.php
     */
    function setEncodingOptions(int $options)
    {
        this._encodingOptions = $options;

        return this;
    }
}
