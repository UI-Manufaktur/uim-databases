module uim.databases.types.datetimefractional;

import uim.databases;

@safe:

// DateTimeType with support for fractional seconds up to microseconds.
class DateTimeFractionalType : DateTimeType {
    mixin(TypeThis!("DateTimeFractionalType"));

    override bool initialize(IConfigData[string] configData = null) {
        if (!super.initialize(configData)) {
            return false;
        }

        return true;
    }
 
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
