module uim.cake.databases.types.float_;

import uim.cake;

@safe:

/*

/**
 * Float type converter.
 *
 * Use to convert float/decimal data between D and the database types.
 */
class FloatType : BaseType, IBatchCasting {
    // The class to use for representing number objects
    static string anumberClass = Number.classname;

    /**
     * Whether numbers should be parsed using a locale aware parser
     * when marshalling string inputs.
     */
    protected bool _useLocaleParser = false;

    /**
     * Convert integer data into the database format.
     */
    float toDatabase(Json valueToConvert, Driver driver) {
        if (valueToConvert.isNull || valueToConvert.isEmpty) {
            return null;
        }
        return (float)valueToConvert;
    }
    
    /**
 Params:
     * Json valueToConvert The value to convert.
     * @param \UIM\Database\Driver driver The driver instance to convert with.
     */
    float ToD(Json valueToConvert, Driver driver) {
        if (valueToConvert.isNull) {
            return 0.0; // TODO not a real null
        }

        return valueToConvert.get!float;
    }
 
    array manyToD(array  someValues, array fields, Driver driver) {
        fields
            .filter!(field => isSet(someValues[field]))
            .each(field => someValues[field] = (float) someValues[field]);
        }
        return someValues;
    }
 
    int toStatement(Json valueToConvert, Driver driver) {
        return PDO.PARAM_STR;
    }
    
    /**
     * Marshals request data into D floats.
     * Params:
     * Json valueToConvert The value to convert.
     */
    string|float marshal(Json valueToConvert)
    {
        if (valueToConvert.isNull || valueToConvert.isEmpty) {
            return null;
        }
        if (isString(valueToConvert) && _useLocaleParser) {
            return _parseValue(valueToConvert);
        }
        if (isNumeric(valueToConvert)) {
            return (float)valueToConvert;
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
            isSubclass_of($numberClass, Number.classname)
        ) {
           _useLocaleParser = enable;

            return;
        }
        throw new DatabaseException(
            "Cannot use locale parsing with the %s class"
            .format($numberClass)
        );
    }
    
    /**
     * Converts a string into a float point after parsing it using the locale
     * aware parser.
     * Params:
     * string valueToConvert The value to parse and convert to an float.
     */
    protected float _parseValue(string valueToConvert) {
         className = numberClass;

        return className.parseFloat(valueToConvert);
    }
}
