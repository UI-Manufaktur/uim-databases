module uim.cake.databases;

import uim.cake;

@safe:

// Factory for building database type classes.
class TypeFactory {
    /**
     * List of supported database types. A human readable
     * identifier is used as key and a complete namespaced class name as value
     * representing the class that will do actual type conversions.
     * @psalm-var array<string, class-string<\UIM\Database\IType>>
     */
    protected static STRINGAA _supportedDbTypes = [
        "tinyinteger": IntegerType.classname,
        "smallinteger": IntegerType.classname,
        "integer": IntegerType.classname,
        "biginteger": IntegerType.classname,
        "binary": BinaryType.classname,
        "binaryuuid": BinaryUuidType.classname,
        "boolean": BoolType.classname,
        "date": DateType.classname,
        "datetime": DateTimeType.classname,
        "datetimefractional": DateTimeFractionalType.classname,
        "decimal": DecimalType.classname,
        "float": FloatType.classname,
        "json": JsonType.classname,
        "string": StringType.classname,
        "char": StringType.classname,
        "text": StringType.classname,
        "time": TimeType.classname,
        "timestamp": DateTimeType.classname,
        "timestampfractional": DateTimeFractionalType.classname,
        "timestamptimezone": DateTimeTimezoneType.classname,
        "uuid": UuidType.classname,
    ];

    /**
     * Contains a map of type object instances to be reused if needed.
     *
     * @var array<\UIM\Database\IType>
     */
    protected static array _builtTypes = [];

    /**
     * Returns a Type object capable of converting a type identified by name.
     * Params:
     * string typeId type identifier
     * @throws \InvalidArgumentException If type identifier is unknown
     */
    static IType build(string typeId) {
        if (isSet(_builtTypes[typeId])) {
            return _builtTypes[typeId];
        }
        if (!isSet(_supportedDbTypes[typeId])) {
            throw new InvalidArgumentException("Unknown type `%s`".format(typeId));
        }

        return _builtTypes[typeId] = new _supportedDbTypes[typeId](typeId);
    }

    // Returns an arrays with all the mapped type objects, indexed by name.
    static IType[] buildAll() {
        _supportedDbTypes.byKeyValue
            .each!(nameType => _builtTypes[nameType.key] = _builtTypes.get(nameType.key, build(nameType.key)));

        return _builtTypes;
    }
    
    /**
     * Set IType instance capable of converting a type identified by name
     * Params:
     * string typeId The type identifier you want to set.
     * @param \UIM\Database\IType  anInstance The type instance you want to set.
     */
    static void set(string typeId, IType  anInstance) {
        _builtTypes[name] =  anInstance;
    }
    
    /**
     * Registers a new type identifier and maps it to a fully namespaced classname.
     * Params:
     * string atype Name of type to map.
     * @psalm-param class-string<\UIM\Database\IType>  className
     */
    static void map(string atype, string className) {
        _supportedDbTypes[$type] = className;
        _builtTypes.remove($type);
    }
    
    // Set type to classname mapping.
    static void setMap(string[] typesToMap) {
        _supportedDbTypes = typesToMap;
        _builtTypes = [];
    }
    
    /**
     * Get mapped class name for given type or map array.
     * Params:
     * string type Type name to get mapped class for or null to get map array.
     */
    static  string[] getMap(string typeName = null) {
        if (typeName.isNull) {
            return _supportedDbTypes;
        }
        return _supportedDbTypes[typeName] ?? null;
    }
    
    // Clears out all created instances and mapped types classes, useful for testing
    static void clear() {
        _supportedDbTypes = [];
        _builtTypes = [];
    }
}
