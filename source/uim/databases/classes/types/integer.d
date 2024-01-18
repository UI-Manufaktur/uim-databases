module uim.databases.types.integer;

import uim.databases;

@safe:

/**
 * Integer type converter.
 *
 * Use to convert integer data between PHP and the database types.
 */
class IntegerType : BaseType, IBatchCasting {
    // Checks if the value is not a numeric value
    protected void checkNumeric(Json valueToCheck) {
        if (!isNumeric(valueToCheck) && !isBool(valueToCheck)) {
            throw new InvalidArgumentException(
                "Cannot convert value `%s` of type `%s` to int"
                .format(print_r(valueToCheck, true),
                get_debug_type(valueToCheck)
            ));
        }
    }
    
    // Convert integer data into the database format.
    int toDatabase(Json valueToConvert, Driver driverForConvert) {
        if (valueToConvert.isNull || valueToConvert.isEmpty) {
            return null;
        }
        this.checkNumeric(valueToConvert);

        return (int)valueToConvert;
    }
    
    /**
 Params:
     * Json valueToConvert The value to convert.
     * @param \UIM\Database\Driver $driver The driver instance to convert with.
     */
    int ToD(Json valueToConvert, Driver $driver) {
        if (valueToConvert.isNull) {
            return null;
        }
        return (int)valueToConvert;
    }
 
    array manyToD(array  someValues, array $fields, Driver $driver) {
        foreach ($fields as $field) {
            if (!isSet(someValues[$field])) {
                continue;
            }
            this.checkNumeric(someValues[$field]);

             someValues[$field] = (int) someValues[$field];
        }
        return someValues;
    }
 
    int toStatement(Json aValue, Driver $driver) {
        return PDO.PARAM_INT;
    }
    
    /**
     * Marshals request data into PHP integers.
     * Params:
     * Json valueToConvert The value to convert.
     */
    int marshal(Json valueToConvert) {
        if (valueToConvert.isNull || valueToConvert.isEmpty || !isNumeric(valueToConvert)) {
            return null;
        }
        return (int)valueToConvert;
    }
}
