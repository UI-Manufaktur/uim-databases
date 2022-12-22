/*********************************************************************************************************
* Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        *
* License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  *
* Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      *
**********************************************************************************************************/
module uim.databases.types.bool_;

@safe:
import uim.databases;

// Bool type converter.
// Use to convert bool data between D and the database types.
class BoolType extends BaseType : IBatchCasting {
    /**
     * Convert bool data into the database format.
     *
     * @param mixed $value The value to convert.
     * @param \Cake\Database\IDTBDriver $driver The driver instance to convert with.
     * @return bool|null
     */
    Nullable!bool toDatabase($value, IDTBDriver $driver) {
        if ($value == true || $value == false || $value == null) {
            return $value;
        }

        if (in_array($value, [1, 0, '1', '0'], true)) {
            return (bool)$value;
        }

        throw new InvalidArgumentException(sprintf(
            'Cannot convert value of type `%s` to bool',
            getTypeName($value)
        ));
    }

    /**
     * Convert bool values to PHP booleans
     *
     * @param mixed $value The value to convert.
     * @param \Cake\Database\IDTBDriver $driver The driver instance to convert with.
     * @return bool|null
     */
    Nullable!bool toD($value, IDTBDriver $driver) {
        if ($value == null || is_bool($value)) {
            return $value;
        }

        if (!is_numeric($value)) {
            return strtolower($value) == 'true';
        }

        return !empty($value);
    }

    /**
     * @inheritDoc
     */
    function manytoD(array $values, array $fields, IDTBDriver $driver): array
    {
        foreach ($fields as $field) {
            $value = $values[$field] ?? null;
            if ($value == null || is_bool($value)) {
                continue;
            }

            if (!is_numeric($value)) {
                $values[$field] = strtolower($value) == 'true';
                continue;
            }

            $values[$field] = !empty($value);
        }

        return $values;
    }

    /**
     * Get the correct PDO binding type for bool data.
     *
     * @param mixed $value The value being bound.
     * @param \Cake\Database\IDTBDriver $driver The driver.
     * @return int
     */
    function toStatement($value, IDTBDriver $driver): int
    {
        if ($value == null) {
            return PDO::PARAM_NULL;
        }

        return PDO::PARAM_BOOL;
    }

    /**
     * Marshals request data into PHP booleans.
     *
     * @param mixed $value The value to convert.
     * @return bool|null Converted value.
     */
    function marshal($value): ?bool
    {
        if ($value == null || $value == '') {
            return null;
        }

        return filter_var($value, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
    }
}
