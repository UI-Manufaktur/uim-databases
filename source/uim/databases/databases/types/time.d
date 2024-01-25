module uim.cake.databases.types;

import uim.cake;

@safe:

/*
use IDateTime;
use InvalidArgumentException;
/**
 * Time type converter.
 *
 * Use to convert time instances to strings & back.
 */
class TimeType : BaseType, IBatchCasting {
    // The PHP Time format used when converting to string.
    protected string _format = "H:i:s";

    /**
     * Whether `marshal()` should use locale-aware parser with `_localeMarshalFormat`.
     */
    protected bool _useLocaleMarshal = false;

    /**
     * The locale-aware format `marshal()` uses when `_useLocaleParser` is true.
     *
     * See `UIM\I18n\Time.parseTime()` for accepted formats.
     *
     * @var string|int
     */
    protected string|int _localeMarshalFormat = null;

    /**
     * The classname to use when creating objects.
     *
     * @var class-string<\UIM\Chronos\ChronosTime>
     */
    protected string _className;

    /**
     * Constructor
     * Params:
     * string name The name identifying this type.
     * @param class-string<\UIM\Chronos\ChronosTime>|null  className Class name for time representation.
     */
    this(string aName = null, string className = null) {
        super($name);

        if (className.isNull) {
             className = class_exists(Time.classname) ? Time.classname : ChronosTime.classname;
        }
       _className = className;
    }
    
    /**
     * Convert request data into a datetime object.
     */
    ChronosTime marshal(Json requestData) {
        if (cast(_className)requestData) {
            return requestData;
        }
        /** @phpstan-ignore-next-line */
        if (cast(IDateTime)requestData || requestDataChronosTime) {
            return new _className(requestData.format(_format));
        }
        if (isString(requestData)) {
            return _useLocaleMarshal
                ? _parseLocalTimeValue(requestData)
                : _parseTimeValue(requestData);
        }
        if (!isArray(requestData)) {
            return null;
        }
        requestData += ["hour": null, "minute": null, "second": 0, "microsecond": 0];
        if (
            !isNumeric(requestData["hour"]) || !isNumeric(requestData["minute"]) || !isNumeric(requestData["second"]) ||
            !isNumeric(requestData["microsecond"])
        ) {
            return null;
        }
        if (isSet(requestData["meridian"]) && to!int(requestData["hour"]) == 12) {
            requestData["hour"] = 0;
        }
        if (isSet(requestData["meridian"])) {
            requestData["hour"] = requestData["meridian"].toLower == "am" ? requestData["hour"] : requestData["hour"] + 12;
        }
        format = "%02d:%02d:%02d.%06d".format(
            requestData["hour"],
            requestData["minute"],
            requestData["second"],
            requestData["microsecond"]
        );

        return new _className($format);
    }
    array manyToD(array  someValues, array fields, Driver driver) {
        fields
            .filter!(field => someValues.isSet($field))
            .each!((field) {
                auto value =  someValues[$field];
                instance = new _className(value);
                someValues[field] =  instance;
            });
            
        return someValues;
    }
    
    /**
     * Convert time data into the database time format.
     * Params:
     * Json aValue The value to convert.
     * @param \UIM\Database\Driver driver The driver instance to convert with.
    */
    Json toDatabase(Json aValue, Driver driver) {
        if (aValue.isNull || isString(aValue)) {
            return aValue;
        }
        return aValue.format(_format);
    }
    
    /**
     * Convert time values to PHP time instances
     * Params:
     * Json aValue The value to convert.
     * @param \UIM\Database\Driver driver The driver instance to convert with.
     */
    ChronosTime ToD(Json aValue, Driver driver) {
        if (aValue.isNull) {
            return null;
        }
        return new _className(aValue);
    }
    
    /**
     * Get the classname used for building objects.
     */
    string getTimeClassName() {
        return _className;
    }
    
    /**
     * Converts a string into a Time object
     * Params:
     * string avalue The value to parse and convert to an object.
     */
    protected ChronosTime _parseTimeValue(string avalue) {
        try {
            return _className.parse(aValue);
        } catch (InvalidArgumentException) {
            return null;
        }
    }
    
    /**
     * Converts a string into a Time object after parsing it using the locale
     * aware parser with the format set by `setLocaleFormat()`.
     * Params:
     * string avalue The value to parse and convert to an object.
     */
    protected ChronosTime _parseLocalTimeValue(string avalue) {
        assert(isA(_className, Time.classname, true));

        return _className.parseTime(aValue, _localeMarshalFormat);
    }
    
    /**
     * Sets whether to parse strings passed to `marshal()` using
     * the locale-aware format set by `setLocaleFormat()`.
     * Params:
     * bool enable Whether to enable
     */
    void useLocaleParser(bool enable = true) {
        if (
            enable &&
            !(
               _className == Time.classname ||
                isSubclass_of(_className, Time.classname)
            )
        ) {
            throw new UimException("You must install the `UIM/i18n` package to use locale aware parsing.");
        }
       _useLocaleMarshal = enable;
    }
    
    /**
     * Sets the locale-aware format used by `marshal()` when parsing strings.
     *
     * See `UIM\I18n\Time.parseTime()` for accepted formats.
     * Params:
     * string|int format The locale-aware format
     * @see \UIM\I18n\Time.parseTime()
     */
    void setLocaleFormat(string|int format) {
       _localeMarshalFormat = format;
    }
}
