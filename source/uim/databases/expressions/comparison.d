/*********************************************************************************************************
*	Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        *
*	License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  *
*	Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      *
**********************************************************************************************************/
module uim.cake;

@safe:
import uim.cake;

/**
 * A Comparison is a type of query expression that represents an operation
 * involving a field an operator and a value. In its most common form the
 * string representation of a comparison is `field = value`
 */
class ComparisonExpression : IDTBExpression, FieldInterface
{
    use ExpressionTypeCasterTrait;
    use FieldTrait;

    /**
     * The value to be used in the right hand side of the operation
     *
     * @var mixed
     */
    protected $_value;

    /**
     * The type to be used for casting the value to a database representation
     *
     * @var string|null
     */
    protected $_type;

    /**
     * The operator used for comparing field and value
     *
     * @var string
     */
    protected $_operator ="=";

    /**
     * Whether the value in this expression is a traversable
     *
     * @var bool
     */
    protected $_isMultiple = false;

    /**
     * A cached list of IDTBExpression objects that were
     * found in the value for this expression.
     *
     * @var array<\Cake\Database\IDTBExpression>
     */
    protected $_valueExpressions = [];

    /**
     * Constructor
     *
     * @param uim.databases\IDTBExpression|string $field the field name to compare to a value
     * aValue - The value to be used in comparison
     * @param string|null $type the type name used to cast the value
     * @param string $operator the operator used for comparing field and value
     */
    this($field, DValue aValue, ?string $type = null, string $operator ="=")
    {
        _type = $type;
        $this.setField($field);
        $this.setValue(aValue);
        _operator = $operator;
    }

    /**
     * Sets the value
     *
     * aValue - The value to compare
     * @return void
     */
    function setValue(DValue aValue): void
    {
        aValue = _castToExpression(aValue, _type);

        $isMultiple = _type && strpos(_type,"[]") != false;
        if ($isMultiple) {
            [aValue, _valueExpressions] = _collectExpressions(aValue);
        }

        _isMultiple = $isMultiple;
        _value = aValue;
    }

    /**
     * Returns the value used for comparison
     *
     * @return mixed
     */
    DValue getValue() {
        return _value;
    }

    /**
     * Sets the operator to use for the comparison
     *
     * @param string $operator The operator to be used for the comparison.
     * @return void
     */
    function setOperator(string $operator): void
    {
        _operator = $operator;
    }

    /**
     * Returns the operator used for comparison
     *
     * @return string
     */
    string getOperator()
    {
        return _operator;
    }


    string sql(ValueBinder aValueBinder)
    {
        /** @var \Cake\Database\IDTBExpression|string $field */
        $field = _field;

        if ($field instanceof IDTBExpression) {
            $field = $field.sql($binder);
        }

        if (_value instanceof IdentifierExpression) {
            $template ="%s %s %s";
            aValue = _value.sql($binder);
        } elseif (_value instanceof IDTBExpression) {
            $template ="%s %s (%s)";
            aValue = _value.sql($binder);
        } else {
            [$template, DValue aValue] = _stringExpression($binder);
        }

        return sprintf($template, $field, _operator, DValue aValue);
    }


    O traverse(this O)(Closure $callback)
    {
        if (_field instanceof IDTBExpression) {
            $callback(_field);
            _field.traverse($callback);
        }

        if (_value instanceof IDTBExpression) {
            $callback(_value);
            _value.traverse($callback);
        }

        foreach (_valueExpressions as $v) {
            $callback($v);
            $v.traverse($callback);
        }

        return $this;
    }

    /**
     * Create a deep clone.
     *
     * Clones the field and value if they are expression objects.
     *
     * @return void
     */
    function __clone()
    {
        foreach (["_value","_field"] as $prop) {
            if ($this.{$prop} instanceof IDTBExpression) {
                $this.{$prop} = clone $this.{$prop};
            }
        }
    }

    /**
     * Returns a template and a placeholder for the value after registering it
     * with the placeholder $binder
     *
     * @param uim.databases\ValueBinder aValueBinder The value binder to use.
     * @return array First position containing the template and the second a placeholder
     */
    protected function _stringExpression(ValueBinder aValueBinder): array
    {
        $template ="%s";

        if (_field instanceof IDTBExpression && !_field instanceof IdentifierExpression) {
            $template ="(%s)";
        }

        if (_isMultiple) {
            $template .="%s (%s)";
            $type = _type;
            if ($type !is null) {
                $type = str_replace("[]","", $type);
            }
            aValue = _flattenValue(_value, $binder, $type);

            // To avoid SQL errors when comparing a field to a list of empty values,
            // better just throw an exception here
            if (aValue =="") {
                $field = _field instanceof IDTBExpression ? _field.sql($binder) : _field;
                /** @psalm-suppress PossiblyInvalidCast */
                throw new DatabaseException(
                    "Impossible to generate condition with empty list of values for field ($field)"
                );
            }
        } else {
            $template .="%s %s";
            aValue = _bindValue(_value, $binder, _type);
        }

        return [$template, DValue aValue];
    }

    /**
     * Registers a value in the placeholder generator and returns the generated placeholder
     *
     * @param mixed aValue The value to bind
     * @param uim.databases\ValueBinder aValueBinder The value binder to use
     * @param string|null $type The type of aValue
     * @return string generated placeholder
     */
    protected string _bindValue(aValue, ValueBinder aValueBinder, ?string $type = null) {
        $placeholder = aValueBinder.placeholder("c");
        aValueBinder.bind($placeholder, DValue aValue, $type);

        return $placeholder;
    }

    /**
     * Converts a traversable value into a set of placeholders generated by
     * $binder and separated by `,`
     *
     * @param iterable aValue the value to flatten
     * @param uim.databases\ValueBinder aValueBinder The value binder to use
     * @param string|null $type the type to cast values to
     */
    protected string _flattenValue(iterable aValue, ValueBinder aValueBinder, ?string $type = null) {
        $parts = [];
        if (is_array(aValue)) {
            foreach (_valueExpressions as $k: $v) {
                $parts[$k] = $v.sql(aValueBinder);
                unset(aValue[$k]);
            }
        }

        if (!empty(aValue)) {
            $parts += $binder.generateManyNamed(aValue, $type);
        }

        return implode(",", $parts);
    }

    /**
     * Returns an array with the original someValues in the first position
     * and all IDTBExpression objects that could be found in the second
     * position.
     *
     * @param uim.databases\IDTBExpression|iterable someValues The rows to insert
     * @return array
     */
    protected array _collectExpressions(IDTBExpression[] someValues...) {
      return _collectExpressions(someValues);
    }
    protected array _collectExpressions(IDTBExpression[] someValues) {
      if (someValues instanceof IDTBExpression) {
          return [someValues, []];
      }

      $expressions = $result = [];
      $result = someValues;

      foreach (someValues as $k: $v) {
          if ($v instanceof IDTBExpression) {
              $expressions[$k] = $v;
          }

          if ($isArray) {
              $result[$k] = $v;
          }
      }

      return [$result, $expressions];
    }
}