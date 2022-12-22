/*********************************************************************************************************
* Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        *
* License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  *
* Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      *
**********************************************************************************************************/
module uim.databases.types.integer;

@safe:
import uim.databases;

/**
 * Integer type converter.
 *
 * Use to convert integer data between PHP and the database types.
 */
class IntegerType extends BaseType : IBatchCasting
{
    /**
     * Checks if the value is not a numeric value
     *
     * @throws \InvalidArgumentException
     * @param mixed $value Value to check
     * @return void
     */
    protected function checkNumeric($value): void
    {
        if (!is_numeric($value)) {
            throw new InvalidArgumentException(sprintf(
                'Cannot convert value of type `%s` to integer',
                getTypeName($value)
            ));
        }
    }

    /**
     * Convert integer data into the database format.
     *
     * @param mixed $value The value to convert.
     * @param \Cake\Database\DriverInterface $driver The driver instance to convert with.
     * @return int|null
     */
    function toDatabase($value, DriverInterface $driver): ?int
    {
        if ($value === null || $value === '') {
            return null;
        }

        this->checkNumeric($value);

        return (int)$value;
    }

    /**
     * {@inheritDoc}
     *
     * @param mixed $value The value to convert.
     * @param \Cake\Database\DriverInterface $driver The driver instance to convert with.
     * @return int|null
     */
    function toPHP($value, DriverInterface $driver): ?int
    {
        if ($value === null) {
            return null;
        }

        return (int)$value;
    }

    /**
     * @inheritDoc
     */
    function manyToPHP(array $values, array $fields, DriverInterface $driver): array
    {
        foreach ($fields as $field) {
            if (!isset($values[$field])) {
                continue;
            }

            this->checkNumeric($values[$field]);

            $values[$field] = (int)$values[$field];
        }

        return $values;
    }

    /**
     * Get the correct PDO binding type for integer data.
     *
     * @param mixed $value The value being bound.
     * @param \Cake\Database\DriverInterface $driver The driver.
     * @return int
     */
    function toStatement($value, DriverInterface $driver): int
    {
        return PDO::PARAM_INT;
    }

    /**
     * Marshals request data into PHP integers.
     *
     * @param mixed $value The value to convert.
     * @return int|null Converted value.
     */
    function marshal($value): ?int
    {
        if ($value === null || $value === '') {
            return null;
        }
        if (is_numeric($value)) {
            return (int)$value;
        }

        return null;
    }
}
