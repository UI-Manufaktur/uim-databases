module uim.databases;

@safe:
import uim.databases;

use InvalidArgumentException;

/**
 * Factory for building database type classes.
 */
class TypeFactory
{
    /**
     * List of supported database types. A human readable
     * identifier is used as key and a complete namespaced class name as value
     * representing the class that will do actual type conversions.
     *
     * @var array<string, string>
     * @psalm-var array<string, class-string<uim.databases.TypeInterface>>
     */
    protected static _types = [
        "tinyinteger": types.IntegerType::class,
        "smallinteger": types.IntegerType::class,
        "integer": types.IntegerType::class,
        "biginteger": types.IntegerType::class,
        "binary": types.BinaryType::class,
        "binaryuuid": types.BinaryUuidType::class,
        "boolean": types.BoolType::class,
        "date": types.DateType::class,
        "datetime": types.DateTimeType::class,
        "datetimefractional": types.DateTimeFractionalType::class,
        "decimal": types.DecimalType::class,
        "float": types.FloatType::class,
        "json": types.JsonType::class,
        "string": types.StringType::class,
        "char": types.StringType::class,
        "text": types.StringType::class,
        "time": types.TimeType::class,
        "timestamp": types.DateTimeType::class,
        "timestampfractional": types.DateTimeFractionalType::class,
        "timestamptimezone": types.DateTimeTimezoneType::class,
        "uuid": types.UuidType::class,
    ];

    /**
     * Contains a map of type object instances to be reused if needed.
     *
     * @var array<uim.databases.TypeInterface>
     */
    protected static _builtTypes = null;

    /**
     * Returns a Type object capable of converting a type identified by name.
     *
     * @param string aName type identifier
     * @throws \InvalidArgumentException If type identifier is unknown
     * @return uim.databases.TypeInterface
     */
    static function build(string aName): TypeInterface
    {
        if (isset(_builtTypes[name])) {
            return _builtTypes[name];
        }
        if (!isset(_types[name])) {
            throw new InvalidArgumentException(sprintf("Unknown type '%s'", name));
        }

        return _builtTypes[name] = new _types[name](name);
    }

    /**
     * Returns an arrays with all the mapped type objects, indexed by name.
     *
     * @return array<uim.databases.TypeInterface>
     */
    static array buildAll() {
        result = null;
        foreach (_types as name: type) {
            result[name] = _builtTypes[name] ?? build(name);
        }

        return result;
    }

    /**
     * Set TypeInterface instance capable of converting a type identified by name
     *
     * @param string aName The type identifier you want to set.
     * @param uim.databases.TypeInterface instance The type instance you want to set.
     */
    static void set(string aName, TypeInterface instance) {
        _builtTypes[name] = instance;
        _types[name] = get_class(instance);
    }

    /**
     * Registers a new type identifier and maps it to a fully namespaced classname.
     *
     * @param string type Name of type to map.
     * @param string className The classname to register.
     * @return void
     * @psalm-param class-string<uim.databases.TypeInterface> className
     */
    static void map(string type, string className) {
        _types[type] = className;
        unset(_builtTypes[type]);
    }

    /**
     * Set type to classname mapping.
     *
     * @param array<string> map List of types to be mapped.
     * @return void
     * @psalm-param array<string, class-string<uim.databases.TypeInterface>> map
     */
    static void setMap(array map) {
        _types = map;
        _builtTypes = null;
    }

    /**
     * Get mapped class name for given type or map array.
     *
     * @param string|null type Type name to get mapped class for or null to get map array.
     * @return array<string>|string|null Configured class name for given type or map array.
     */
    static function getMap(Nullable!string type = null) {
        if (type == null) {
            return _types;
        }

        return _types.get(type, null);
    }

    /**
     * Clears out all created instances and mapped types classes, useful for testing
     */
    static void clear() {
        _types = null;
        _builtTypes = null;
    }
}
