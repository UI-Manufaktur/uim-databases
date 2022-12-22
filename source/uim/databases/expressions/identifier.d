/*********************************************************************************************************
*	Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        *
*	License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  *
*	Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      *
**********************************************************************************************************/
module uim.cake;

@safe:
import uim.cake;

/**
 * Represents a single identifier name in the database.
 *
 * Identifier values are unsafe with user supplied data.
 * Values will be quoted when identifier quoting is enabled.
 */
class DDTBIdentifierExpression : IDTBExpression {
  // anIdentifier - The identifier this expression represents
  // aCollation   - The identifier collation
  this(string anIdentifier, string aCollation = null) {
    identifier(anIdentifier);
    collation(aCollation);
  }

  mixin(OProperty!("string", "identifier"));
  mixin(OProperty!("string", "collation"));

  string sql(DDTBValueBinder aValueBinder) {
    auto result = this.identifier;
    result ~= this.collation ? " COLLATE "~this.collation : "";

    return result;
  }

  O traverse(this O)(Closure aCallback) {
    return cast(O)this;
  }
}
auto DTBIdentifierExpression(string anIdentifier, string aCollation = null) { return DDTBIdentifierExpression(anIdentifier, aCollation); }

version(test_uim_databases) { unittest {
  auto expression = DTBIdentifierExpression("test");
  assert(DTBIdentifierExpression("test").sql(DTBValueBinder) == "test")
}}