module uim.databases;

@safe:
import uim.databases;

// Factory for building database type classes.
class DDBSTypeFactory {
    // List of supported database types. A human readable identifier is used as key and a complete moduled class name as value
    // representing the class that will do actual type conversions.
    protected static STRINGAA _types = [
        "tinyinteger": Type\IntegerType.class,
        "smallinteger": Type\IntegerType.class,
        "integer": Type\IntegerType.class,
        "biginteger": Type\IntegerType.class,
        "binary": Type\BinaryType.class,
        "binaryuuid": Type\BinaryUuidType.class,
        "boolean": Type\BoolType.class,
        "date": Type\DateType.class,
        "datetime": Type\DateTimeType.class,
        "datetimefractional": Type\DateTimeFractionalType.class,
        "decimal": Type\DecimalType.class,
        "float": Type\FloatType.class,
        "json": Type\JsonType.class,
        "string": Type\StringType.class,
        "char": Type\StringType.class,
        "text": Type\StringType.class,
        "time": Type\TimeType.class,
        "timestamp": Type\DateTimeType.class,
        "timestampfractional": Type\DateTimeFractionalType.class,
        "timestamptimezone": Type\DateTimeTimezoneType.class,
        "uuid": Type\UuidType.class,
    ];

    // Contains a map of type object instances to be reused if needed.
    protected static IDBSType _builtTypes = [];

    // Returns a Type object capable of converting a type identified by name.
    // myName type identifier
    // @throws \InvalidArgumentException If type identifier is unknown
    static IType build(string myName) {
        if (isset(static._builtTypes[myName])) {
            return static._builtTypes[myName];
        }
        if (!isset(static._types[myName])) {
            throw new InvalidArgumentException(sprintf("Unknown type "%s"", myName));
        }

        return static._builtTypes[myName] = new static._types[myName](myName);
    }

    // Returns an arrays with all the mapped type objects, indexed by name.
    static IType[] buildAll() {
        myResult = [];
        foreach (static._types as myName: myType) {
          myResult[myName] = static._builtTypes[myName] ?? static.build(myName);
        }

        return myResult;
    }

    // Set IType instance capable of converting a type identified by myName
    // myName The type identifier you want to set.
    // \Cake\Database\IType $instance The type instance you want to set.
    static void set(string myName, IType typeInstance) {
        static._builtTypes[myName] = typeInstance;
        static._types[myName] = get_class(typeInstance);
    }

    /**
     * Registers a new type identifier and maps it to a fully moduled classname.
     *
     * @param string myType Name of type to map.
     * @param string myClassName The classname to register.
     * @psalm-param class-string<\Cake\Database\IType> myClassName
     */
    static void map(string myType, string myClassName) {
        static._types[myType] = myClassName;
        unset(static._builtTypes[myType]);
    }

    /**
     * Set type to classname mapping.
     *
     * @param $map List of types to be mapped.
     * @psalm-param array<string, class-string<\Cake\Database\IType>> $map
     */
    static void setMap(string[] $map) {
        static._types = $map;
        static._builtTypes = [];
    }

    /**
     * Get mapped class name for given type or map array.
     *
     * @param string|null myType Type name to get mapped class for or null to get map array.
     * @return Configured class name for given myType or map array.
     */
    static string[] getMap(Nullable!string myType = null) {
        if (myType is null) {
            return static._types;
        }

        return static._types[myType] ?? null;
    }

    /**
     * Clears out all created instances and mapped types classes, useful for testing
     */
    static void clear() {
        static._types = [];
        static._builtTypes = [];
    }
}
