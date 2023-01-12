/*********************************************************************************************************
	Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        
	License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  
	Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      
**********************************************************************************************************/
module uim.expressions.string_;

@safe:
import uim.databases;

// String expression with collation.
class StringExpression : IDBAExpression {
  protected string _string;

  /**
    * @param string $string String value
    * @param string _collation String collation
    */
  this(string aString, string aCollation) {
    _string = aString;
    collation(aCollation);
  }

  mixin(OProperty!("string", "collation"));

  string sql(ValueBinder aValueBinder) {
    $placeholder = aValueBinder.placeholder("c");
    aValueBinder.bind($placeholder, $this.string,"string");

    return $placeholder ~ " COLLATE " ~ this.collation;
  }

  O traverse(this O)(Closure $callback)
  {
      return $this;
  }
}
