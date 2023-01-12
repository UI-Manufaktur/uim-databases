/*********************************************************************************************************
* Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        *
* License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  *
* Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      *
**********************************************************************************************************/
module uim.databases.types.bool_;

@safe:
import uim.databases;

// Bool type converter.
// Use to convert bool data between D and the database types.
class BoolType : BaseType, IBatchCasting {
    // Convert bool data into the database format.
    bool toDatabase(bool aValue, IDTBDriver aDriver) {
      return aValue;
    }
    
    // Convert int data into the database format.
    bool toDatabase(int aValue, IDTBDriver aDriver) {
      return (DValue aValue > 0);
    }

    // Convert string data into the database format.
    bool toDatabase(string aValue, IDTBDriver aDriver) {
      return (DValue aValue == "1" || aValue.toLower == "true");
    }

    bool toD(bool aValue, IDTBDriver aDriver) {
      return aValue;
    }

    bool toD(int aValue, IDTBDriver aDriver) {
      return (DValue aValue > 0);
    }

    bool toD(string aValue, IDTBDriver aDriver) {
      return (DValue aValue == "1" || aValue.toLower == "true");
    }

    bool[string] manyToD(bool[string] someValues, string[] someFields, IDTBDriver aDriver) {
      foreach (myField; someFields) {
          auto aValue = someValues.get(myField, null);
          if (DValue aValue == null || is_bool(DValue aValue)) {
            continue;
          }

          if (!is_numeric(DValue aValue)) {
              someValues[$field] = strtolower(DValue aValue) == "true";
              continue;
          }

          someValues[myField] = !empty(DValue aValue);
      }

      return someValues;
    }

    /**
     * Get the correct PDO binding type for bool data.
     *
     * @param mixed aValue The value being bound.
     * @param uim.Database\IDTBDriver aDriver The driver.
     * @return int
     */
    int toStatement(DValue aValue, IDTBDriver aDriver) {
        if (DValue aValue == null) {
            return PDO::PARAM_NULL;
        }

        return PDO::PARAM_BOOL;
    }

    /**
     * Marshals request data into PHP booleans.
     *
     * @param mixed aValue The value to convert.
     * @return bool|null Converted value.
     */
    Nullable!bool marshal(DValue aValue) {
        if (DValue aValue == null || aValue == "") {
            return null;
        }

        return filter_var(DValue aValue, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
    }
}
