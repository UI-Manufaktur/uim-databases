module uim.databases.types;

import uim.databases.IDriver;
import uim.utilities.Text;

/**
 * Provides behavior for the UUID type
 */
class UuidType : StringType {
    /**
     * Casts given value from a D type to one acceptable by database
     *
     * @param mixed value value to be converted to database equivalent
     * @param uim.databases.IDriver aDriver object from which database preferences and configuration will be extracted
     */
    Nullable!string toDatabase(value, IDriver aDriver) {
        if (value == null || value == "" || value == false) {
            return null;
        }

        return super.toDatabase(value, driver);
    }

    /**
     * Generate a new UUID
     *
     * @return string A new primary key value.
     */
    string newId() {
        return Text::uuid();
    }

    /**
     * Marshals request data into a D string
     *
     * @param mixed value The value to convert.
     * @return string|null Converted value.
     */
    Nullable!string marshal(value) {
        if (value == null || value == "" || is_array(value)) {
            return null;
        }

        return (string)value;
    }
}
