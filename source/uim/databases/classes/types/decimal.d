module uim.databases.types.decimal;

import uim.databases;

@safe:

/**
 * Decimal type converter.
 *
 * Use to convert decimal data between D and the database types.
 */
class DecimalType : BaseType, IBatchCasting {
    mixin(TypeThis!("DecimalType"));

    override bool initialize(IData[string] initData = null) {
        if (!super.initialize(initData)) {
            return false;
        }

        return true;
    }

    // The class to use for representing number objects
    static string anumberClass = Number.classname;

    /**
     * Whether numbers should be parsed using a locale aware parser
     * when marshalling string inputs.
     */
    protected bool _useLocaleParser = false;

    /**
     * Convert decimal strings into the database format.
     *
     * valueToConvert - The value to convert.
     * @param \UIM\Database\Driver driver The driver instance to convert with.
     */
    string|float|int toDatabase(Json valueToConvert, Driver driver) {
        if (valueToConvert.isNull || valueToConvert == "") {
            return null;
        }
        if (isNumeric(valueToConvert)) {
            return valueToConvert;
        }
        if (cast(Stringable)valueToConvert) {
            str = (string)valueToConvert;

            if (isNumeric(str)) {
                return str;
            }
        }
        throw new InvalidArgumentException(
            "Cannot convert value `%s` of type `%s` to a decimal"
            .format(print_r(valueToConvert, true),
            get_debug_type(valueToConvert)
        ));
    }
    
    /**
 Params:
     * Json valueToConvert The value to convert.
     * @param \UIM\Database\Driver driver The driver instance to convert with.
     */
    string ToD(Json valueToConvert, Driver driver) {
        if (valueToConvert.isNull) {
            return null;
        }
        return (string)valueToConvert;
    }
 
    array manyToD(array  someValues, array fields, Driver driver) {
        foreach (fields as field) {
            if (!someValues.isSet(field)) {
                continue;
            }
             someValues[field] = (string) someValues[field];
        }
        return someValues;
    }
 
    int toStatement(Json valueToConvert, Driver driver) {
        return PDO.PARAM_STR;
    }
    
    /**
     * Marshalls request data into decimal strings.
     */
    string marshal(Json valueToConvert) {
        if (valueToConvert.isNull || valueToConvert == "") {
            return null;
        }
        if (isString(valueToConvert) && _useLocaleParser) {
            return _parseValue(valueToConvert);
        }
        if (isNumeric(valueToConvert)) {
            return (string)valueToConvert;
        }
        if (isString(valueToConvert) && preg_match("/^[0-9,. ]+$/", valueToConvert)) {
            return valueToConvert;
        }
        return null;
    }
    
    /**
     * Sets whether to parse numbers passed to the marshal() function
     * by using a locale aware parser.
     * Params:
     * bool enable Whether to enable
     */
    void useLocaleParser(bool enable = true) {
        if (enable == false) {
           _useLocaleParser = enable;

            return;
        }
        if (
            numberClass == Number.classname ||
            isSubclass_of(numberClass, Number.classname)
        ) {
           _useLocaleParser = enable;

            return;
        }
        throw new DatabaseException(
            "Cannot use locale parsing with the %s class".format(numberClass)
        );
    }
    
    /**
     * Converts localized string into a decimal string after parsing it using
     * the locale aware parser.
     * Params:
     * string valueToConvert The value to parse and convert to an float.
     */
    protected string _parseValue(string valueToParse) {
        className = numberClass;

        return (string) className.parseFloat(valueToParse);
    }
}
