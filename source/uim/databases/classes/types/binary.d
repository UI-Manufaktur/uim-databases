module uim.databases.types;

import uim.databases;

@safe:

/**
 * Binary type converter.
 * Use to convert binary data between D and the database types.
 */
class BinaryType : BaseTyp {
    mixin(TypeThis!("BinaryType"));

    override bool initialize(IData[string] initData = null) {
        if (!super.initialize(initData)) {
            return false;
        }

        return true;
    }
    /**
     * Convert binary data into the database format.
     *
     * Binary data is not altered before being inserted into the database.
     * As PDO will handle reading file handles.
     * Params:
     * Json aValue The value to convert.
     * @param \UIM\Database\Driver driver The driver instance to convert with.
     */
    resource|string toDatabase(Json aValue, Driver driver) {
        return aValue;
    }
    
    /**
     * Convert binary into resource handles
     * Params:
     * Json aValue The value to convert.
     * @param \UIM\Database\Driver driver The driver instance to convert with.
     */
    Json ToD(Json aValue, Driver driver) {
        if (aValue.isNull) {
            return null;
        }
        if (isString(aValue)) {
            return fopen("data:text/plain;base64," ~ base64_encode(aValue), "rb") ?: null;
        }
        if (isResource(aValue)) {
            return aValue;
        }
        throw new UimException("Unable to convert `%s` into binary.".format(gettype(aValue)));
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
     * @rexturn Json Converted value.
     */
    Json marshal(Json aValue) {
        return aValue;
    }
}
