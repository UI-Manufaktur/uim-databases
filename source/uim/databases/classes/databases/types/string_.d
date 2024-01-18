module uim.cake.databases.types.string_;

import uim.cake;

@safe:

/**
 * String type converter.
 *
 * Use to convert string data between PHP and the database types.
 */
class StringType : BaseType, IOptionalConvert {
    /**
     * Convert string data into the database format.
     * Params:
     * Json valueToConvert The value to convert.
     * @param \UIM\Database\Driver driver The driver instance to convert with.
     */
    string toDatabase(Json valueToConvert, Driver driver) {
        if (valueToConvert.isNull || isString(valueToConvert)) {
            return valueToConvert;
        }
        if (cast(Stringable)valueToConvert) {
            return (string)valueToConvert;
        }
        if (isScalar(valueToConvert)) {
            return (string)valueToConvert;
        }
        throw new InvalidArgumentException(
            "Cannot convert value `%s` of type `%s` to string"
            .format(print_r(valueToConvert, true),
            get_debug_type(valueToConvert)
        ));
    }
    
    /**
     * Convert string values to PHP strings.
     * Params:
     * Json valueToConvert The value to convert.
     * @param \UIM\Database\Driver driver The driver instance to convert with.
     */
    string ToD(Json valueToConvert, Driver driver) {
        if (valueToConvert.isNull) {
            return null;
        }
        return (string)valueToConvert;
    }
 
    int toStatement(Json valueToConvert, Driver driver) {
        return PDO.PARAM_STR;
    }
    
    // Marshals request data into PHP strings.
    string marshal(Json valueToConvert) {
        if (valueToConvert.isNull || isArray(valueToConvert)) {
            return null;
        }
        return valueToConvert.get!string;
    }

    bool requiresToDCast() {
        return false;
    }
}
