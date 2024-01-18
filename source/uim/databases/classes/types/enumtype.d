module uim.databases.types;

import uim.databases;

@safe:

/**
 * Enum type converter.
 *
 * Use to convert string data between PHP and the database types.
 */
class EnumType : BaseType {
    // The type of the enum which is either string or int
    protected string _backingType;

    /**
     * The enum classname which is associated to the type instance
     */
    protected string _enumClassName;

    /**
     * @param string aName The name identifying this type
     * @param class-string<\BackedEnum> enumClassName The associated enum class name
     */
    this(
        string aName,
        string enumClassName
    ) {
        super($name);
        this.enumClassName = enumClassName;

        try {
            $reflectionEnum = new ReflectionEnum(enumClassName);
        } catch (ReflectionException  anException) {
            throw new DatabaseException(
                "Unable to use `%s` for type `%s`. %s."
                .format(
                    enumClassName,
                    $name,
                    anException.getMessage()
            ));
        }
        $namedType = $reflectionEnum.getBackingType();
        if ($namedType.isNull) {
            throw new DatabaseException(
                "Unable to use enum `%s` for type `%s`, must be a backed enum."
                .format(enumClassName, $name)
            );
        }
        _.backingType = (string)$namedType;
    }
    
    /**
     * Convert enum instances into the database format.
     * Params:
     * Json aValue The value to convert.
     * @param \UIM\Database\Driver $driver The driver instance to convert with.
     */
    string|int toDatabase(Json aValue, Driver $driver) {
        if (aValue.isNull) {
            return null;
        }
        if (cast(BackedEnum)aValue ) {
            if (!cast(this.enumClassName)aValue) {
                throw new InvalidArgumentException(
                    "Given value type `%s` does not match associated `%s` backed enum"
                    .format(get_debug_type(aValue), this.backingType));
            }
            return aValue.value;
        }
        if (!isString(aValue) && !isInt(aValue)) {
            throw new InvalidArgumentException(
                "Cannot convert value '%s' of type `%s` to string or int"
                .format(print_r(aValue, true), get_debug_type(aValue)
            ));
        }
        if (this.enumClassName.tryFrom(aValue).isNull) {
            throw new InvalidArgumentException(
                "`%s` is not a valid value for `%s`"
                .format(aValue, this.enumClassName));
        }
        return aValue;
    }
    
    /**
     * Transform DB value to backed enum instance
     * Params:
     * Json aValue The value to convert.
     * @param \UIM\Database\Driver $driver The driver instance to convert with.
     */
    BackedEnum ToD(Json aValue, Driver $driver) {
        if (aValue.isNull) {
            return null;
        }
        if (this.backingType == "int' && isString(aValue)) {
             anIntVal = filter_var(aValue, FILTER_VALIDATE_INT);
            if (anIntVal != false) {
                aValue =  anIntVal;
            }
        }
        return this.enumClassName.from(aValue);
    }
 
    int toStatement(Json aValue, Driver $driver) {
        if (this.backingType == "int") {
            return PDO.PARAM_INT;
        }
        return PDO.PARAM_STR;
    }
    
    /**
     * Marshals request data
     * Params:
     * Json aValue The value to convert.
     */
    BackedEnum marshal(Json aValue) {
        if (aValue.isNull) {
            return null;
        }
        if (cast(this.enumClassName)aValue) {
            return aValue;
        }
        if (get_debug_type(aValue) != this.backingType) {
            throw new InvalidArgumentException(
                "Given value type `%s` does not match associated `%s` backed enum"
                .format(
                get_debug_type(aValue),
                this.backingType
            ));
        }
        $enumInstance = this.enumClassName.tryFrom(aValue);
        if ($enumInstance.isNull) {
            throw new InvalidArgumentException(
                "Unable to marshal value to %s, got %s"
                .format(this.enumClassName, get_debug_type(aValue),
            ));
        }
        return $enumInstance;
    }
    
    /**
     * Create an `EnumType` that is paired with the provided `enumClassName`.
     *
     * ### Usage
     *
     * ```
     * // In a table class
     * this.getSchema().setColumnType("status", EnumType.from(StatusEnum.classname));
     * ```
     * Params:
     * class-string<\BackedEnum> enumClassName The enum class name
     */
    static string from(string enumClassName) {
        $typeName = "enum-" ~ (Text.slug(enumClassName).toLower);
         anInstance = new EnumType($typeName, enumClassName);
        TypeFactory.set($typeName,  anInstance);

        return $typeName;
    }
    
    string getEnumClassName() {
        return this.enumClassName;
    }
}
