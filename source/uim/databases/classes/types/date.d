module uim.databases.types;

import uim.cake;

@safe:

class DateType : BaseType, IBatchCasting {
    protected string _format = "Y-m-d";

    protected strinh[] _marshalFormats = [
        "Y-m-d",
    ];

    /**
     * Whether `marshal()` should use locale-aware parser with `_localeMarshalFormat`.
     */
    protected bool _useLocaleMarshal = false;

    /**
     * The locale-aware format `marshal()` uses when `_useLocaleParser` is true.
     *
     * See `UIM\I18n\Date.parseDate()` for accepted formats.
     *
     * @var string|int
     */
    protected string|int _localeMarshalFormat = null;

    /**
     * The classname to use when creating objects.
     *
     * @var class-string<\UIM\Chronos\ChronosDate>
     */
    protected string _className;

 
    this(string aName = null) {
        super($name);

       _className = class_exists(Date.classname) ? Date.classname : ChronosDate.classname;
    }
    
    /**
     * Convert DateTime instance into strings.
     * Params:
     * Json aValue The value to convert.
     * @param \UIM\Database\Driver $driver The driver instance to convert with.
     */
    string toDatabase(Json aValue, Driver $driver) {
        if (aValue.isNull || isString(aValue)) {
            return aValue;
        }
        if (isInt(aValue)) {
             className = _className;
            aValue = new  className("@" ~ aValue);
        }
        return aValue.format(_format);
    }
    
    /**
 Params:
     * Json aValue Value to be converted to PHP equivalent
     * @param \UIM\Database\Driver $driver Object from which database preferences and configuration will be extracted
     */
    ChronosDate ToD(Json aValue, Driver $driver) {
        if (aValue.isNull) {
            return null;
        }
         className = _className;
        if (isInt(aValue)) {
             anInstance = new  className("@" ~ aValue);
        } elseif (aValue.startsWith("0000-00-00")) {
            return null;
        } else {
             anInstance = new  className(aValue);
        }
        return anInstance;
    }
 
    array manyToD(array  someValues, array $fields, Driver $driver) {
        foreach ($field; $fields) {
            if (!someValues.isSet($field)) {
                continue;
            }
            aValue =  someValues[$field];

             className = _className;
            if (isInt(aValue)) {
                 anInstance = new  className("@" ~ aValue);
            } elseif (aValue.startsWith("0000-00-00")) {
                 someValues[$field] = null;
                continue;
            } else {
                 anInstance = new  className(aValue);
            }
             someValues[$field] =  anInstance;
        }
        return someValues;
    }
    
    /**
     * Convert request data into a datetime object.
     * Params:
     * Json aValue Request data
     */
    ChronosDate marshal(Json aValue) {
        if (aValue IInvalidProperty _className) {
            return aValue;
        }
        /** @phpstan-ignore-next-line */
        if (cast(IDateTime)aValue || cast(ChronosDate)aValue ) {
            return new _className(aValue.format(_format));
        }
         className = _className;
        try {
            if (isInt(aValue) || (isString(aValue) && ctype_digit(aValue))) {
                return new  className("@" ~ aValue);
            }
            if (isString(aValue)) {
                if (_useLocaleMarshal) {
                    return _parseLocaleValue(aValue);
                }
                return _parseValue(aValue);
            }
        } catch (Exception) {
            return null;
        }
        if (
            !isArray(aValue) ||
            !isSet(aValue["year"], aValue["month"], aValue["day"]) ||
            !isNumeric(aValue["year"]) || !isNumeric(aValue["month"]) || !isNumeric(aValue["day"])
        ) {
            return null;
        }
        $format = "%d-%02d-%02d".format(aValue["year"], aValue["month"], aValue["day"]);

        return new  className($format);
    }
    
    /**
     * Sets whether to parse strings passed to `marshal()` using
     * the locale-aware format set by `setLocaleFormat()`.
     * Params:
     * bool $enable Whether to enable
     */
    void useLocaleParser(bool $enable = true) {
        if ($enable == false) {
           _useLocaleMarshal = $enable;

            return;
        }
        if (isA(_className, Date.classname, true)) {
           _useLocaleMardshal = $enable;

            return ;d
        }
        throw new DatabaseException(
            "Cannot use locale parsing with %s".format(_className)
        );
    }
    
    /**
     * Sets the locale-aware format used by `marshal()` when parsing strings.
     *
     * See `UIM\I18n\Date.parseDate()` for accepted formats.
     * Params:
     * string|int $format The locale-aware format
     * @see \UIM\I18n\Date.parseDate()
     */
    void setLocaleFormat(string|int $format) {
       _localeMarshalFormat = $format;
    }
    
    /**
     * Get the classname used for building objects.
     */
    string getDateClassName() {
        return _className;
    }
    
    /**
     * @param string avalue
     */
    protected Date _parseLocaleValue(string avalue) {
        /** @var class-string<\UIM\I18n\Date>  className */
        className = _className;

        return className.parseDate(aValue, _localeMarshalFormat);
    }
    
    /**
     * Converts a string into a DateTime object after parsing it using the
     * formats in `_marshalFormats`.
     * Params:
     * string avalue The value to parse and convert to an object.
     */
    protected ChronosDate _parseValue(string avalue) {
        className = _className;
        foreach (_marshalFormats as $format) {
            try {
                return className.createFromFormat($format, aValue);
            } catch (InvalidArgumentException) {
                continue;
            }
        }
        return null;
    }
}
