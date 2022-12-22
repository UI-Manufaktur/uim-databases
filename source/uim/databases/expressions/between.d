module uim.databases.expressions.expression;

@safe:
import uim.databases;

/**
 * An expression object that represents a SQL BETWEEN snippet
 */
class BetweenExpression : IExpression, IField {
    use ExpressionTypeCasterTrait;
    use FieldTrait;

    // The first value in the expression
    // @var mixed
    protected DValue _fromValue;

    // The second value in the expression
    // @var mixed
    protected DValue _toValueValue;

    // The data type for the from and to arguments
    // @var mixed
    protected string _valueDatatype;

    /**
     * Constructor
     *
     * @param uim.databases\IDTBExpression|string $field The field name to compare for values inbetween the range.
     * @param mixed $from The initial value of the range.
     * @param mixed $to The ending value in the comparison range.
     * @param string|null aBindDatatype The data type name to bind the values with.
     */

    // this(IIDTBExpression field, DValue aFromValue, DValue aToValue, string $aValueDatatype = null) {

    this(string aFieldName, DValue aFromValue, DValue aToValue, string aBindDatatype = null) {
        if (aValueDatatype !is null) {
            fromValue = _castToExpression($from, $type);
            toValue = _castToExpression($to, $type);
        }

        _fieldName = aFieldName;
        _fromValue = aFromValue;
        _toValue = aToValue;
        _valueDatatype = aBindDatatype;
    }

    string sql(ValueBinder aBinder) {
      $parts = [
       "from": _fromValue,
       "to": _toValue,
      ];

        /** @var \Cake\Database\IDTBExpression|string $field */
        myFieldName = _fieldName;
/*         if ($field instanceof IDTBExpression) {
            $field = $field.sql($binder);
        }
 */
        foreach ($name: $part; $parts) {
/*             if ($part instanceof IDTBExpression) {
                $parts[$name] = $part.sql($binder);
                continue;
            }
 */            
          $parts[$name] = _bindValue($part, $binder, _type);
        }

        return sprintf("%s BETWEEN %s AND %s", $field, $parts["from"], $parts["to"]);
    }

    O traverse(this O)(Closure $callback) {
        foreach ([_field, _from, _toValue] as $part) {
            if ($part instanceof IDTBExpression) {
                $callback($part);
            }
        }

        return $this;
    }

    /**
     * Registers a value in the placeholder generator and returns the generated placeholder
     *
     * @param mixed $value The value to bind
     * @param uim.databases\ValueBinder aValueBinder The value binder to use
     * @param string $type The type of $value
     * @return string generated placeholder
     */
    protected string _bindValue(aValue, DDTBValueBinder aBinder, $type) {
      auto myPlaceholder = aBinder.placeholder("c");
      aBinder.bind(myPlaceholder, $value, $type);

      return myPlaceholder;
    }

    // Do a deep clone of this expression.
    void __clone() {
        foreach (["_field","_from","_toValue"] as $part) {
            if ($this.{$part} instanceof IDTBExpression) {
                $this.{$part} = clone $this.{$part};
            }
        }
    }
}
