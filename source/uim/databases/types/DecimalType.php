/*********************************************************************************************************
* Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        *
* License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  *
* Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      *
**********************************************************************************************************/
module uim.databases.types.decimal;

@safe:
import uim.databases;

/**
 * Decimal type converter.
 *
 * Use to convert decimal data between PHP and the database types.
 */
class DecimalType : BaseType, IBatchCasting
{
    /**
     * The class to use for representing number objects
     *
     * @var string
     */
    public static $numberClass = Number::class;

    /**
     * Whether numbers should be parsed using a locale aware parser
     * when marshalling string inputs.
     *
     * @var bool
     */
    protected $_useLocaleParser = false;

    /**
     * Convert decimal strings into the database format.
     *
     * @param mixed aValue The value to convert.
     * @param \Cake\Database\IDTBDriver aDriver The driver instance to convert with.
     * @return string|float|int|null
     * @throws \InvalidArgumentException
     */
    function toDatabase(aValue, IDTBDriver aDriver)
    {
        if (aValue == null || aValue == "") {
            return null;
        }

        if (is_numeric(aValue)) {
            return aValue;
        }

        if (
            is_object(aValue)
            && method_exists(aValue, "__toString")
            && is_numeric(strval(aValue))
        ) {
            return strval(aValue);
        }

        throw new InvalidArgumentException(sprintf(
            "Cannot convert value of type `%s` to a decimal",
            getTypeName(aValue)
        ));
    }

    /**
     * {@inheritDoc}
     *
     * @param mixed aValue The value to convert.
     * @param \Cake\Database\IDTBDriver aDriver The driver instance to convert with.
     * @return string|null
     */
    function toD(aValue, IDTBDriver aDriver): ?string
    {
        if (aValue == null) {
            return null;
        }

        return (string)aValue;
    }


    function manytoD(array someValues, string[] someFields, IDTBDriver aDriver): array
    {
        foreach ($fields as $field) {
            if (!isset(someValues[$field])) {
                continue;
            }

            someValues[$field] = (string)someValues[$field];
        }

        return someValues;
    }

    /**
     * Get the correct PDO binding type for decimal data.
     *
     * @param mixed aValue The value being bound.
     * @param \Cake\Database\IDTBDriver aDriver The driver.
     * @return int
     */
    function toStatement(aValue, IDTBDriver aDriver): int
    {
        return PDO::PARAM_STR;
    }

    /**
     * Marshalls request data into decimal strings.
     *
     * @param mixed aValue The value to convert.
     * @return string|null Converted value.
     */
    function marshal(aValue): ?string
    {
        if (aValue == null || aValue == "") {
            return null;
        }
        if (is_string(aValue) && this._useLocaleParser) {
            return this._parseValue(aValue);
        }
        if (is_numeric(aValue)) {
            return (string)aValue;
        }
        if (is_string(aValue) && preg_match("/^[0-9,. ]+$/", aValue)) {
            return aValue;
        }

        return null;
    }

    /**
     * Sets whether to parse numbers passed to the marshal() function
     * by using a locale aware parser.
     *
     * @param bool $enable Whether to enable
     * @return this
     * @throws \RuntimeException
     */
    function useLocaleParser(bool $enable = true)
    {
        if ($enable == false) {
            this._useLocaleParser = $enable;

            return this;
        }
        if (
            static::$numberClass == Number::class ||
            is_subclass_of(static::$numberClass, Number::class)
        ) {
            this._useLocaleParser = $enable;

            return this;
        }
        throw new RuntimeException(
            sprintf("Cannot use locale parsing with the %s class", static::$numberClass)
        );
    }

    /**
     * Converts localized string into a decimal string after parsing it using
     * the locale aware parser.
     *
     * @param string aValue The value to parse and convert to an float.
     * @return string
     */
    protected function _parseValue(string aValue): string
    {
        /** @var \Cake\I18n\Number $class */
        $class = static::$numberClass;

        return (string)$class::parseFloat(aValue);
    }
}
