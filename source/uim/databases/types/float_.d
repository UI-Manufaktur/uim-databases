/*********************************************************************************************************
* Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        *
* License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  *
* Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      *
**********************************************************************************************************/
module uim.databases.types.float_;

@safe:
import uim.databases;

// Float type converter.
// Use to convert float/decimal data between D and the database types.
class FloatType : BaseType, IBatchCasting {
  // The class to use for representing number objects
  public static _numberClass = Number::class;

  // Whether numbers should be parsed using a locale aware parser when marshalling string inputs.
  protected bool _useLocaleParser = false;

  /**
    * Convert integer data into the database format.
    *
    * @param mixed aValue The value to convert.
    * @param uim.databases.IDBADriver aDriver The driver instance to convert with.
    * @return float|null
    */
  float toDatabase(string aValue, IDBADriver aDriver) {
    if (DValue aValue == null || aValue == "") {
        return null;
    }

    return (float)aValue;
  }

  /**
    * @param mixed aValue The value to convert.
    * @param uim.databases.IDBADriver aDriver The driver instance to convert with.
    * @return float|null
    * @throws uim.Core\Exception\CakeException
    */
  float toD(string aValue, IDBADriver aDriver) {
    if (!aValue.isNumeric) {
      return 0.0;
    }
    return to!float(DValue aValue);
  }


  function manytoD(array someValues, array someFields, IDBADriver aDriver): array
  {
      foreach (someFields as field) {
          if (!isset(someValues[field])) {
              continue;
          }

          someValues[field] = (float)someValues[field];
      }

      return someValues;
  }

  /**
    * Get the correct PDO binding type for float data.
    *
    * @param mixed aValue The value being bound.
    * @param uim.databases.IDBADriver aDriver The driver.
    * @return int
    */
  function toStatement(DValue aValue, IDBADriver aDriver): int
  {
      return PDO::PARAM_STR;
  }

  /**
    * Marshals request data into D floats.
    *
    * @param mixed aValue The value to convert.
    * @return string|float|null Converted value.
    */
  function marshal(DValue aValue)
  {
      if (DValue aValue == null || aValue == "") {
          return null;
      }
      if (is_string(DValue aValue) && this._useLocaleParser) {
          return this._parseValue(DValue aValue);
      }
      if (isNumeric(DValue aValue)) {
          return (float)aValue;
      }
      if (is_string(DValue aValue) && preg_match("/^[0-9,. ]+/", DValue aValue)) {
          return aValue;
      }

      return null;
  }

  /**
    * Sets whether to parse numbers passed to the marshal() function
    * by using a locale aware parser.
    *
    * @param bool isEnabled Whether to enable
    * @return this
    */
  O useLocaleParser(this O)(bool isEnabled = true) {
    if (isEnabled == false) {
      this._useLocaleParser = isEnabled;

      return this;
  }
    if (
        _numberClass == Number::class ||
        is_subclass_of(_numberClass, Number::class)
    ) {
        this._useLocaleParser = isEnabled;

        return this;
    }
    return cast(O)this;
/*     throw new RuntimeException(
        sprintf("Cannot use locale parsing with the %s class", _numberClass)
    );
 */  
  }

  /**
    * Converts a string into a float point after parsing it using the locale
    * aware parser.
    *
    * @param string aValue The value to parse and convert to an float.
    * @return float
    */
  protected float _parseValue(string aValue) {
      class = _numberClass;

      return class::parseFloat(DValue aValue);
  }
}
