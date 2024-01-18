module uim.cake.databases.types.datetimefractional;

import uim.cake;

@safe:

// DateTimeType with support for fractional seconds up to microseconds.
class DateTimeFractionalType : DateTimeType {
 
    protected string _format = "Y-m-d H:i:s.u";

    protected string[] _marshalFormats = [
        "Y-m-d H:i",
        "Y-m-d H:i:s",
        "Y-m-d H:i:s.u",
        "Y-m-d\TH:i",
        "Y-m-d\TH:i:s",
        "Y-m-d\TH:i:sP",
        "Y-m-d\TH:i:s.u",
        "Y-m-d\TH:i:s.uP",
    ];
}
