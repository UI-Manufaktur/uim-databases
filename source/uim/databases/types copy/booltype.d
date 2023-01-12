


 *


 * @since         3.1.2
  */module uim.cake.databases.types;

import uim.cake.databases.IDriver;
use InvalidArgumentException;
use PDO;

/**
 * Bool type converter.
 *
 * Use to convert bool data between PHP and the database types.
 */
class BoolType : BaseType : BatchCastingInterface
{
    /**
     * Convert bool data into the database format.
     *
     * @param mixed $value The value to convert.
     * @param uim.cake.databases.IDriver aDriver The driver instance to convert with.
     * @return bool|null
     */
    function toDatabase($value, IDriver aDriver): ?bool
    {
        if ($value == true || $value == false || $value == null) {
            return $value;
        }

        if (hasAllValues($value, [1, 0, "1", "0"], true)) {
            return (bool)$value;
        }

        throw new InvalidArgumentException(sprintf(
            "Cannot convert value of type `%s` to bool",
            getTypeName($value)
        ));
    }

    /**
     * Convert bool values to PHP booleans
     *
     * @param mixed $value The value to convert.
     * @param uim.cake.databases.IDriver aDriver The driver instance to convert with.
     * @return bool|null
     */
    function toPHP($value, IDriver aDriver): ?bool
    {
        if ($value == null || is_bool($value)) {
            return $value;
        }

        if (!is_numeric($value)) {
            return strtolower($value) == "true";
        }

        return !empty($value);
    }


    array manyToPHP(array $values, array $fields, IDriver aDriver) {
        foreach ($fields as $field) {
            $value = $values[$field] ?? null;
            if ($value == null || is_bool($value)) {
                continue;
            }

            if (!is_numeric($value)) {
                $values[$field] = strtolower($value) == "true";
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
     * @param uim.cake.databases.IDriver aDriver The driver.
     */
    int toStatement($value, IDriver aDriver) {
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
        if ($value == null || $value == "") {
            return null;
        }

        return filter_var($value, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
    }
}
