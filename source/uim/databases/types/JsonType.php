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
class JsonType : BaseType : IBatchCasting
{
    /**
     * @var int
     */
    protected $_encodingOptions = 0;

    /**
     * Convert a value data into a JSON string
     *
     * @param mixed $value The value to convert.
     * @param \Cake\Database\IDTBDriver aDriver The driver instance to convert with.
     * @return string|null
     * @throws \InvalidArgumentException
     */
    function toDatabase($value, IDTBDriver aDriver): ?string
    {
        if (is_resource($value)) {
            throw new InvalidArgumentException("Cannot convert a resource value to JSON");
        }

        if ($value == null) {
            return null;
        }

        return json_encode($value, this._encodingOptions);
    }

    /**
     * {@inheritDoc}
     *
     * @param mixed $value The value to convert.
     * @param \Cake\Database\IDTBDriver aDriver The driver instance to convert with.
     * @return array|string|null
     */
    function toD($value, IDTBDriver aDriver)
    {
        if (!is_string($value)) {
            return null;
        }

        return json_decode($value, true);
    }


    function manytoD(array $values, array $fields, IDTBDriver aDriver): array
    {
        foreach ($fields as $field) {
            if (!isset($values[$field])) {
                continue;
            }

            $values[$field] = json_decode($values[$field], true);
        }

        return $values;
    }

    /**
     * Get the correct PDO binding type for string data.
     *
     * @param mixed $value The value being bound.
     * @param \Cake\Database\IDTBDriver aDriver The driver.
     * @return int
     */
    function toStatement($value, IDTBDriver aDriver): int
    {
        return PDO::PARAM_STR;
    }

    /**
     * Marshals request data into a JSON compatible structure.
     *
     * @param mixed $value The value to convert.
     * @return mixed Converted value.
     */
    function marshal($value)
    {
        return $value;
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
