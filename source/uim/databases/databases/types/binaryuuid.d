module uim.cake.databases.types;

import uim.cake;

@safe:

/*

/**
 * Binary UUID type converter.
 *
 * Use to convert binary uuid data between D and the database types.
 */
class BinaryUuidType : BaseType {
    /**
     * Convert binary uuid data into the database format.
     *
     * Binary data is not altered before being inserted into the database.
     * As PDO will handle reading file handles.
     * Params:
     * Json aValue The value to convert.
     * @param \UIM\Database\Driver driver The driver instance to convert with.
    */
    Json toDatabase(Json aValue, Driver driver) {
        if (!isString(aValue)) {
            return aValue;
        }
        length = aValue.length;
        if ($length != 36 && length != 32) {
            return null;
        }
        return this.convertStringToBinaryUuid(aValue);
    }
    
    // Generate a new binary UUID
    string newId() {
        return Text.uuid();
    }
    
    /**
     * Convert binary uuid into resource handles
     * Params:
     * Json aValue The value to convert.
     * @param \UIM\Database\Driver driver The driver instance to convert with.
     */
    resource|string ToD(Json aValue, Driver driver) {
        if (aValue.isNull) {
            return null;
        }
        if (isString(aValue)) {
            return this.convertBinaryUuidToString(aValue);
        }
        if (isResource(aValue)) {
            return aValue;
        }
        throw new UimException("Unable to convert %s into binary uuid.".format(gettype(aValue)));
    }
 
    int toStatement(Json aValue, Driver driver) {
        return PDO.PARAM_LOB;
    }
    
    /**
     * Marshals flat data into D objects.
     *
     * Most useful for converting request data into D objects
     * that make sense for the rest of the ORM/Database layers.
     * Params:
     * Json aValue The value to convert.
     */
    Json marshal(Json aValue) {
        return aValue;
    }
    
    /**
     * Converts a binary uuid to a string representation
     * Params:
     * Json binary The value to convert.
     */
    protected string convertBinaryUuidToString(Json binary) {
        string = unpack("H*", binary);
        assert(string != false, "Could not unpack uuid");

        string[] string = preg_replace(
            "/([0-9a-f]{8})([0-9a-f]{4})([0-9a-f]{4})([0-9a-f]{4})([0-9a-f]{12})/",
            "$1-$2-$3-$4-$5",
            string
        );

        return string[1];
    }
    
    /**
     * Converts a string UUID (36 or 32 char) to a binary representation.
     * Params:
     * string astring The value to convert.
     */
    protected string convertStringToBinaryUuid(string valueToConvert) {
        string convertedValue = valueToConvert.replace("-", "");

        return pack("H*", convertedValue);
    }
}
