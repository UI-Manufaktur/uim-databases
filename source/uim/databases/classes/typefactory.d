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
        "tinyinteger": Type\IntegerType.classname,
        "smallinteger": Type\IntegerType.classname,
        "integer": Type\IntegerType.classname,
        "biginteger": Type\IntegerType.classname,
        "binary": Type\BinaryType.classname,
        "binaryuuid": Type\BinaryUuidType.classname,
        "boolean": Type\BoolType.classname,
        "date": Type\DateType.classname,
        "datetime": Type\DateTimeType.classname,
        "datetimefractional": Type\DateTimeFractionalType.classname,
        "decimal": Type\DecimalType.classname,
        "float": Type\FloatType.classname,
        "json": Type\JsonType.classname,
        "string": Type\StringType.classname,
        "char": Type\StringType.classname,
        "text": Type\StringType.classname,
        "time": Type\TimeType.classname,
        "timestamp": Type\DateTimeType.classname,
        "timestampfractional": Type\DateTimeFractionalType.classname,
        "timestamptimezone": Type\DateTimeTimezoneType.classname,
        "uuid": Type\UuidType.classname,
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
     * string aName type identifier
     * @throws \InvalidArgumentException If type identifier is unknown
     */
    static IType build(string aName) {
        if (isSet(_builtTypes[$name])) {
            return _builtTypes[$name];
        }
        if (!isSet(_supportedDbTypes[$name])) {
            throw new InvalidArgumentException("Unknown type `%s`".format($name));
        }
        return _builtTypes[$name] = new _supportedDbTypes[$name]($name);
    }

    // Returns an arrays with all the mapped type objects, indexed by name.
    static IType[] buildAll() {
        _supportedDbTypes.byKeyValue
            .each!(nameType => _builtTypes[nameType.key] = _builtTypes.get(nameType.key, build(nameType.key)));

        return _builtTypes;
    }
    
    /**
     * Set IType instance capable of converting a type identified by $name
     * Params:
     * string aName The type identifier you want to set.
     * @param \UIM\Database\IType  anInstance The type instance you want to set.
     */
    static void set(string aName, IType  anInstance) {
        _builtTypes[$name] =  anInstance;
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
     * string|null $type Type name to get mapped class for or null to get map array.
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
