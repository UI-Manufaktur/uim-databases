module uim.cake.databases.types;

import uim.cake.I18n\Date;
import uim.cake.I18n\FrozenDate;
import uim.cake.I18n\I18nDateTimeInterface;
use DateTime;
use DateTimeImmutable;
use DateTimeInterface;

/**
 * Class DateType
 */
class DateType : DateTimeType {

    protected _format = "Y-m-d";


    protected _marshalFormats = [
        "Y-m-d",
    ];

    /**
     * In this class we want Date objects to  have their time
     * set to the beginning of the day.
     */
    protected bool $setToDateStart = true;


    this(Nullable!string aName = null) {
        super(($name);

        _setClassName(FrozenDate::class, DateTimeImmutable::class);
    }

    /**
     * Change the preferred class name to the FrozenDate implementation.
     *
     * @return this
     * @deprecated 4.3.0 This method is no longer needed as using immutable datetime class is the default behavior.
     */
    function useImmutable() {
        deprecationWarning(
            "Configuring immutable or mutable classes is deprecated and immutable"
            ~ " classes will be the permanent configuration in 5.0. Calling `useImmutable()` is unnecessary."
        );

        _setClassName(FrozenDate::class, DateTimeImmutable::class);

        return this;
    }

    /**
     * Change the preferred class name to the mutable Date implementation.
     *
     * @return this
     * @deprecated 4.3.0 Using mutable datetime objects is deprecated.
     */
    function useMutable() {
        deprecationWarning(
            "Configuring immutable or mutable classes is deprecated and immutable"
            ~ " classes will be the permanent configuration in 5.0. Calling `useImmutable()` is unnecessary."
        );

        _setClassName(Date::class, DateTime::class);

        return this;
    }

    /**
     * Convert request data into a datetime object.
     *
     * @param mixed $value Request data
     * @return \DateTimeInterface|null
     */
    function marshal($value): ?DateTimeInterface
    {
        $date = super.marshal($value);
        /** @psalm-var \DateTime|\DateTimeImmutable|null $date */
        if ($date && !$date instanceof I18nDateTimeInterface) {
            // Clear time manually when I18n types aren"t available and raw DateTime used
            $date = $date.setTime(0, 0, 0);
        }

        return $date;
    }


    protected function _parseLocaleValue(string aValue): ?I18nDateTimeInterface
    {
        /** @psalm-var class-string<uim.cake.I18n\I18nDateTimeInterface> $class */
        $class = _className;

        return $class::parseDate($value, _localeMarshalFormat);
    }
}
