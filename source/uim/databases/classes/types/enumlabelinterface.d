module uim.databases.types;

import uim.databases;

@safe:

// An interface used to clarify that an enum has a label() method instead of having to use `name` property.
interface IEnumLabel {
    // Label to return as string.
    string label();
}
