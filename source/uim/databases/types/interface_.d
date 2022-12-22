/*********************************************************************************************************
*	Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        *
*	License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  *
*	Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      *
**********************************************************************************************************/
module uim.databases.types.interface_;

// Encapsulates all conversion functions for values coming from a database into PHP and going from PHP into a database.
interface IType {
  // Casts given value from a PHP type to one acceptable by a database.
  // mixed myValue Value to be converted to a database equivalent.
  // \Cake\Database\IDTBDriver myDriver Object from which database preferences and configuration will be extracted.
  // @return mixed Given PHP type casted to one acceptable by a database.
  function toDatabase(myValue, IDTBDriver myDriver);

  // Casts given value from a database type to a PHP equivalent.
  // mixed myValue Value to be converted to PHP equivalent
  // \Cake\Database\IDTBDriver myDriver Object from which database preferences and configuration will be extracted
  // @return mixed Given value casted from a database to a PHP equivalent.
  function toPHP(myValue, IDTBDriver myDriver);

  // Casts given value to its Statement equivalent.
  // mixed myValue Value to be converted to PDO statement.
  // \Cake\Database\IDTBDriver myDriver Object from which database preferences and configuration will be extracted.
  // @return mixed Given value casted to its Statement equivalent.
  function toStatement(myValue, IDTBDriver myDriver);

  // Marshals flat data into PHP objects.
  // Most useful for converting request data into PHP objects, that make sense for the rest of the ORM/Database layers.
  // mixed myValue The value to convert.
  // @return mixed Converted value.
  function marshal(myValue);

  // Returns the base type name that this class is inheriting.
  // This is useful when extending base type for adding extra functionality,
  // but still want the rest of the framework to use the same assumptions it would do about the base type it inherits from.
  // @return string|null The base type name that this class is inheriting.
  Nullable!string getBaseType();

  // Returns type identifier name for this object.
  // @return string|null The type identifier name for this object.
  Nullable!string getName();

  // Generate a new primary key value for a given type.
  // This method can be used by types to create new primary key values when entities are inserted.
  // @return mixed A new primary key value.
  function newId();
}
