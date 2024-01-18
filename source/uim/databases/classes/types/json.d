module uim.databases.types.json;

import uim.databases;

@safe:

/*
use InvalidArgumentException;

/**
 * JSON type converter.
 * Use to convert JSON data between PHP and the database types.
 */
class JsonType : BaseType, IBatchCasting {
    protected int _encodingOptions = 0;

    /**
     * Convert a value data into a JSON string
     * Params:
     * Json aValue The value to convert.
     * @param \UIM\Database\Driver $driver The driver instance to convert with.
     */
    string toDatabase(Json valueToConvert, Driver $driver) {
        if (isResource(valueToConvert)) {
            throw new InvalidArgumentException("Cannot convert a resource value to JSON");
        }
        if (valueToConvert.isNull) {
            return null;
        }
        return json_encode(valueToConvert, JSON_THROW_ON_ERROR | _encodingOptions);
    }
    
    /**
 Params:
     * Json aValue The value to convert.
     * @param \UIM\Database\Driver $driver The driver instance to convert with.
    */
    Json ToD(Json valueToConvert, Driver $driver) {
        if (!isString(valueToConvert)) {
            return null;
        }
        return json_decode(valueToConvert, true);
    }
 
    array manyToD(array  someValues, array $fields, Driver $driver) {
        foreach ($fields as $field) {
            if (!isSet(someValues[$field])) {
                continue;
            }
             someValues[$field] = json_decode(someValues[$field], true);
        }
        return someValues;
    }
 
    int toStatement(Json aValue, Driver $driver) {
        return PDO.PARAM_STR;
    }
    
    /**
     * Marshals request data into a JSON compatible structure.
     */
    Json marshal(Json valueToConvert) {
        return valueToConvert;
    }
    
    /**
     * Set json_encode options.
     * Params:
     * int $options Encoding flags. Use JSON_* flags. Set `0` to reset.
     * @see https://www.d.net/manual/en/function.json-encode.d
     */
    void setEncodingOptions(int $options) {
       _encodingOptions = $options;
    }
}
