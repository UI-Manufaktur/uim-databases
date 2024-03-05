module uim.cake.databases.types;

import uim.cake;

@safe:

/**
 * Datetime type converter.
 *
 * Use to convert datetime instances to strings & back.
 */
class DateTimeType : BaseType, IBatchCasting {
    // The DateTime format used when converting to string.
    protected string _format = "Y-m-d H:i:s";

    // The DateTime formats allowed by `marshal()`.
    protected string[] _marshalFormats = [
        "Y-m-d H:i",
        "Y-m-d H:i:s",
        "Y-m-d\TH:i",
        "Y-m-d\TH:i:s",
        "Y-m-d\TH:i:sP",
    ];

    /**
     * Whether `marshal()` should use locale-aware parser with `_localeMarshalFormat`.
     */
    protected bool _useLocaleMarshal = false;

    /**
     * The locale-aware format `marshal()` uses when `_useLocaleParser` is true.
     *
     * See `UIM\I18n\Time.parseDateTime()` for accepted formats.
     *
     * @var string[]|int
     */
    protected string[]|int _localeMarshalFormat = null;

    /**
     * The classname to use when creating objects.
     *
     * @var class-string<\UIM\I18n\DateTime>|class-string<\DateTimeImmutable>
     */
    protected string _className;

    /**
     * Database time zone.
     *
     * @var \DateTimeZone|null
     */
    protected DateTimeZone dbTimezone = null;

    /**
     * User time zone.
     *
     * @var \DateTimeZone|null
     */
    protected DateTimeZone userTimezone = null;

    /**
     * Default time zone.
     *
     * @var \DateTimeZone
     */
    protected DateTimeZone defaultTimezone;

    /**
     * Whether database time zone is kept when converting
     */
    protected bool keepDatabaseTimezone = false;

    /**
 Params:
     * string name The name identifying this type
     */
    this(string aName = null) {
        super(name);

        this.defaultTimezone = new DateTimeZone(date_default_timezone_get());
       _className = class_exists(DateTime.classname) ? DateTime.classname : DateTimeImmutable.classname;
    }
    
    /**
     * Convert DateTime instance into strings.
     * Params:
     * Json aValue The value to convert.
     * @param \UIM\Database\Driver driver The driver instance to convert with.
     */
    string toDatabase(Json aValue, Driver driver) {
        if (aValue.isNull || isString(aValue)) {
            return aValue;
        }
        if (isInt(aValue)) {
             className = _className;
            aValue = new className("@" ~ aValue);
        }
        if (
            this.dbTimezone !isNull
            && this.dbTimezone.name != aValue.getTimezone().name
        ) {
            if (!cast(DateTimeImmutable)aValue) {
                aValue = clone aValue;
            }
            aValue = aValue.setTimezone(this.dbTimezone);
        }
        return aValue.format(_format);
    }
    
    /**
     * Set database timezone.
     *
     * This is the time zone used when converting database strings to DateTime
     * instances and converting DateTime instances to database strings.
     *
     * @see DateTimeType.setKeepDatabaseTimezone
     * @param \DateTimeZone|string timezone Database timezone.
     */
    void setDatabaseTimezone(DateTimeZone|string timezone) {
        if (isString(timezone)) {
            timezone = new DateTimeZone(timezone);
        }
        this.dbTimezone = timezone;
    }
    
    /**
     * Set user timezone.
     *
     * This is the time zone used when marshalling strings to DateTime instances.
     * Params:
     * \DateTimeZone|string timezone User timezone.
     */
    void setUserTimezone(DateTimeZone|string timezone) {
        if (isString(timezone)) {
            timezone = new DateTimeZone(timezone);
        }
        this.userTimezone = timezone;
    }
    
    /**
 Params:
     * Json aValue Value to be converted to D equivalent
     * @param \UIM\Database\Driver driver Object from which database preferences and configuration will be extracted
     */
    DateTime|DateTimeImmutable|null ToD(Json aValue, Driver driver) {
        if (aValue.isNull) {
            return null;
        }
         className = _className;
        if (isInt(aValue)) {
             anInstance = new className("@" ~ aValue);
        } else if (aValue.startsWith("0000-00-00")) {
            return null;
        } else {
             anInstance = new className(aValue, this.dbTimezone);
        }
        if (
            !this.keepDatabaseTimezone
            &&  anInstance.getTimezone()
            &&  anInstance.getTimezone().name != this.defaultTimezone.name
        ) {
             anInstance =  anInstance.setTimezone(this.defaultTimezone);
        }
        return anInstance;
    }
    
    /**
     * Set whether DateTime object created from database string is converted
     * to default time zone.
     *
     * If your database date times are in a specific time zone that you want
     * to keep in the DateTime instance then set this to true.
     *
     * When false, datetime timezones are converted to default time zone.
     * This is default behavior.
     * Params:
     * bool keep If true, database time zone is kept when converting
     *     to DateTime instances.
     */
    void setKeepDatabaseTimezone(bool keep) {
        this.keepDatabaseTimezone = keep;
    }
 
    array manyToD(array  someValues, array fields, Driver driver) {
        fields.each!((field) {
            if (!someValues.isSet(field)) {
                continue;
            }
            
            auto aValue =  someValues[field];
            auto className = _className;
            if (isInt(aValue)) {
                 anInstance = new className("@" ~ aValue);
            } else if (aValue.startsWith("0000-00-00")) {
                 someValues[field] = null;
                continue;
            } else {
                 anInstance = new className(aValue, this.dbTimezone);
            }
            if (
                !this.keepDatabaseTimezone
                &&  anInstance.getTimezone()
                &&  anInstance.getTimezone().name != this.defaultTimezone.name
            ) {
                 anInstance =  anInstance.setTimezone(this.defaultTimezone);
            }
             someValues[field] =  anInstance;
        });
        return someValues;
    }
    
    /**
     * Convert request data into a datetime object.
     * Params:
     * Json aValue Request data
     */
    IDateTime marshal(Json requestData) {
        if (cast(IDateTime)requestData) {
            if (cast(NativeDateTime)requestData) {
                myRequestData = clone requestData;
            }
            return myRequestData.setTimezone(this.defaultTimezone);
        }
         className = _className;
        try {
            if (isInt(myRequestData) || (isString(myRequestData) && ctype_digit(myRequestData))) {
                dateTime = new className("@" ~ myRequestData);

                return dateTime.setTimezone(this.defaultTimezone);
            }
            if (isString(myRequestData)) {
                if (_useLocaleMarshal) {
                    dateTime = _parseLocaleValue(myRequestData);
                } else {
                    dateTime = _parseValue(myRequestData);
                }
                if ( dateTime) {
                    dateTime = dateTime.setTimezone(this.defaultTimezone);
                }
                return dateTime;
            }
        } catch (Exception  anException) {
            return null;
        }
        if (!isArray(myRequestData)) {
            return null;
        }
        aValue ~= [
            "year": null, "month": null, "day": null,
            "hour": 0, "minute": 0, "second": 0, "microsecond": 0,
        ];
        if (
            !isNumeric(myRequestData["year"]) || !isNumeric(myRequestData["month"]) || !isNumeric(myRequestData["day"]) ||
            !isNumeric(myRequestData["hour"]) || !isNumeric(myRequestData["minute"]) || !isNumeric(myRequestData["second"]) ||
            !isNumeric(myRequestData["microsecond"])
        ) {
            return null;
        }
        if (isSet(myRequestData["meridian"]) && (int)myRequestData["hour"] == 12) {
            myRequestData["hour"] = 0;
        }
        if (isSet(myRequestData["meridian"])) {
            myRequestData["hour"] = myRequestData["meridian"].toLower == "am" ? myRequestData["hour"] : myRequestData["hour"] + 12;
        }
        format = 
            "%d-%02d-%02d %02d:%02d:%02d.%06d"
            .format(
                myRequestData["year"],
                myRequestData["month"],
                myRequestData["day"],
                myRequestData["hour"],
                myRequestData["minute"],
                myRequestData["second"],
                myRequestData["microsecond"]
            );

        dateTime = new className(format, myRequestData.get("timezone", this.userTimezone);

        return dateTime.setTimezone(this.defaultTimezone);
    }
    
    /**
     * Sets whether to parse strings passed to `marshal()` using
     * the locale-aware format set by `setLocaleFormat()`.
     * Params:
     * bool enable Whether to enable
     */
    void useLocaleParser(bool enable = true) {
        if (enable == false) {
           _useLocaleMarshal = enable;

            return;
        }
        if (isA(_className, DateTime.classname, true)) {
           _useLocaleMarshal = enable;

            return;
        }
        throw new DatabaseException(
            "Cannot use locale parsing with the %s class".format(_className)
        );
    }
    
    /**
     * Sets the locale-aware format used by `marshal()` when parsing strings.
     *
     * See `UIM\I18n\Time.parseDateTime()` for accepted formats.
     * Params:
     * string[] aformat The locale-aware format
     * @see \UIM\I18n\Time.parseDateTime()
     */
    void setLocaleFormat(string[] aformat) {
       _localeMarshalFormat = format;
    }
    
    /**
     * Get the classname used for building objects.
     */
    string getDateTimeClassName() {
        return _className;
    }
    
    /**
     * Converts a string into a DateTime object after parsing it using the locale
     * aware parser with the format set by `setLocaleFormat()`.
     */
    protected DateTime _parseLocaleValue(string valueToParse) {
        /** @var class-string<\UIM\I18n\DateTime>  className */
        string className = _className;

        return className.parseDateTime(valueToParse, _localeMarshalFormat, this.userTimezone);
    }
    
    /**
     * Converts a string into a DateTime object after parsing it using the
     * formats in `_marshalFormats`.
     * Params:
     * string valueToParse The value to parse and convert to an object.
     */
    protected DateTime|DateTimeImmutable|null _parseValue(string valueToParse) {
         className = _className;
        foreach (format; _marshalFormats) {
            try {
                if(auto dateTime = className.createFromFormat(format, valueToParse, this.userTimezone)) {
                    return dateTime;
                }
            } catch (InvalidArgumentException) {
                // Chronos wraps DateTimeImmutable.createFromFormat and throws
                // exception if parse fails.
                continue;
            }
        }
        return null;
    }

    int toStatement(Json aValue, Driver driver) {
        return PDO.PARAM_STR;
    }
}
