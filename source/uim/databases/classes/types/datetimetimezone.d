module uim.databases.types;

import uim.databases;

@safe:

// DateTimeType with support for time zones.
class DateTimeTimezoneType : DateTimeType {
     mixin(TypeThis!("DateTimeTimezoneType"));

    override bool initialize(IData[string] configData = null) {
        if (!super.initialize(configData)) {
            return false;
        }

        return true;
    }

    protected string _format = "Y-m-d H:i:s.uP";

    protected string[] _marshalFormats = [
        "Y-m-d H:i",
        "Y-m-d H:i:s",
        "Y-m-d H:i:sP",
        "Y-m-d H:i:s.u",
        "Y-m-d H:i:s.uP",
        "Y-m-d\TH:i",
        "Y-m-d\TH:i:s",
        "Y-m-d\TH:i:sP",
        "Y-m-d\TH:i:s.u",
        "Y-m-d\TH:i:s.uP",
    ];
}
