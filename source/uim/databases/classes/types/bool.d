module uim.databases.types;

import uim.databases;

@safe:

/**
 * Bool type converter.
 *
 * Use to convert bool data between D and the database types.
 */
class BoolType : BaseType, IBatchCasting {
    mixin(TypeThis!("BoolType"));

    override bool initialize(IConfigData[string] configData = null) {
        if (!super.initialize(configData)) {
            return false;
        }

        return true;
    }

    /**
     * Convert bool data into the database format.
     * Params:
     * Json aValue The value to convert.
     * @param \UIM\Database\Driver aDriver The driver instance to convert with.
     */
    bool toDatabase(Json aValue, Driver aDriver) {
        if (aValue == true || aValue == false || aValue.isNull) {
            return aValue;
        }
        if (in_array(aValue, [1, 0, "1", "0"], true)) {
            return (bool)aValue;
        }
        throw new InvalidArgumentException(
            "Cannot convert value `%s` of type `%s` to bool"
            .format(print_r(aValue, true),
            get_debug_type(aValue)
        ));
    }
    
    /**
     * Convert bool values to D booleans
     * Params:
     * Json aValue The value to convert.
     * @param \UIM\Database\Driver aDriver The driver instance to convert with.
     */
    bool ToD(Json aValue, Driver aDriver) {
        if (aValue.isNull || isBool(aValue)) {
            return aValue;
        }
        if (!isNumeric(aValue)) {
            return aValue.toLower == "true";
        }
        return !aValue.isEmpty;
    }
 
    array manyToD(array  someValues, array $fields, Driver aDriver) {
        foreach (field; $fields) {
            aValue = someValues[field] ?? null;
            if (aValue.isNull || isBool(aValue)) {
                continue;
            }
            if (!isNumeric(aValue)) {
                someValues[field] = aValue.toLower == "true";
                continue;
            }
            someValues[field] = !aValue.isEmpty;
        }
        return someValues;
    }
 
    int toStatement(Json aValue, Driver aDriver) {
        if (aValue.isNull) {
            return PDO.PARAM_NULL;
        }
        return PDO.PARAM_BOOL;
    }
    
    /**
     * Marshals request data into D booleans.
     * Params:
     * Json aValue The value to convert.
     */
    bool marshal(Json aValue) {
        if (aValue.isNull || aValue == "") {
            return null;
        }
        return filter_var(aValue, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
    }
}
