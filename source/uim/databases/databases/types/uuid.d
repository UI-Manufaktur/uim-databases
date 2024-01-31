module uim.cake.databases.types.uuid;

import uim.cake;

@safe:

/*
 * Provides behavior for the UUID type
 */
class UuidType : StringType {
    /**
     * Casts given value from a D type to one acceptable by database
     * Params:
     * Json valueToConvert value to be converted to database equivalent
     * @param \UIM\Database\Driver driver object from which database preferences and configuration will be extracted
     */
    string toDatabase(Json valueToConvert, Driver driver) {
        if (valueToConvert.isNull || valueToConvert.isEmpty || valueToConvert == false) {
            return null;
        }
        return super.toDatabase(valueToConvert, driver);
    }
    
    /**
     * Generate a new UUID
     */
    string newId() {
        return Text.uuid();
    }
    
    /**
     * Marshals request data into a D string
     * Params:
     * Json valueToConvert The value to convert.
     */
    string marshal(Json valueToConvert) {
        if (valueToConvert.isNull || valueToConvert.isEmpty || isArray(valueToConvert)) {
            return null;
        }
        return (string)valueToConvert;
    }
}
