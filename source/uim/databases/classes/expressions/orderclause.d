module uim.databases.Expression;

import uim.databases;

@safe:

/*


/**
 * An expression object for complex ORDER BY clauses
 */
class OrderClauseExpression : IExpression, IField {
  use FieldTrait;

  /**
     * The direction of sorting.
     */
  protected string _direction;

  /**
     * Constructor
     * Params:
     * \UIM\Database\IExpression|string afield The field to order on.
     * @param string adirection The direction to sort on.
     */
  this(IExpression | string afield, string adirection) {
    _field = $field;
    _direction = $direction.toLower == "asc" ? "ASC" : "DESC";
  }

  string sql(ValueBinder aBinder) {
    $field = _field;
    if (cast(Query)$field) {
      $field = "(%s)".format($field.sql(aBinder));
    }
    elseif(cast(IExpression)$field) {
      $field = $field.sql(aBinder);
    }
    assert(isString($field));

    return "%s %s".format($field, _direction);
  }

  void traverse(Closure aCallback) {
    if (cast(IExpression) _field) {
      aCallback(_field);
      _field.traverse(aCallback);
    }
  }

  /**
     * Create a deep clone of the order clause.
     */
  void __clone() {
    if (cast(IExpression) _field) {
      _field = clone _field;
    }
  }
}
