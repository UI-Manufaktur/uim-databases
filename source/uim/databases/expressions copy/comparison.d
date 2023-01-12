module uim.cake.databases.Expression;

import uim.cake.databases.exceptions.DatabaseException;
import uim.cake.databases.IExpression;
import uim.cake.databases.types.ExpressionTypeCasterTrait;
import uim.cake.databases.ValueBinder;
use Closure;

/**
 * A Comparison is a type of query expression that represents an operation
 * involving a field an operator and a value. In its most common form the
 * string representation of a comparison is `field = value`
 */
class ComparisonExpression : IExpression, FieldInterface
{
    use ExpressionTypeCasterTrait;
    use FieldTrait;

    /**
     * The value to be used in the right hand side of the operation
     *
     * @var mixed
     */
    protected _value;

    /**
     * The type to be used for casting the value to a database representation
     *
     */
    protected Nullable!string _type;

    /**
     * The operator used for comparing field and value
     */
    protected string _operator = "=";

    /**
     * Whether the value in this expression is a traversable
     */
    protected bool _isMultiple = false;

    /**
     * A cached list of IExpression objects that were
     * found in the value for this expression.
     *
     * @var array<uim.cake.databases.IExpression>
     */
    protected _valueExpressions = null;

    /**
     * Constructor
     *
     * @param uim.cake.databases.IExpression|string $field the field name to compare to a value
     * @param mixed $value The value to be used in comparison
     * @param string|null $type the type name used to cast the value
     * @param string $operator the operator used for comparing field and value
     */
    this($field, $value, Nullable!string $type = null, string $operator = "=") {
        _type = $type;
        this.setField($field);
        this.setValue($value);
        _operator = $operator;
    }

    /**
     * Sets the value
     *
     * @param mixed $value The value to compare
     */
    void setValue($value) {
        $value = _castToExpression($value, _type);

        $isMultiple = _type && strpos(_type, "[]") != false;
        if ($isMultiple) {
            [$value, _valueExpressions] = _collectExpressions($value);
        }

        _isMultiple = $isMultiple;
        _value = $value;
    }

    /**
     * Returns the value used for comparison
     *
     * @return mixed
     */
    function getValue() {
        return _value;
    }

    /**
     * Sets the operator to use for the comparison
     *
     * @param string $operator The operator to be used for the comparison.
     */
    void setOperator(string $operator) {
        _operator = $operator;
    }

    /**
     * Returns the operator used for comparison
     */
    string getOperator() {
        return _operator;
    }


    string sql(ValueBinder aBinder) {
        /** @var DDBIExpression|string $field */
        $field = _field;

        if ($field instanceof IExpression) {
            $field = $field.sql($binder);
        }

        if (_value instanceof IdentifierExpression) {
            $template = "%s %s %s";
            $value = _value.sql($binder);
        } elseif (_value instanceof IExpression) {
            $template = "%s %s (%s)";
            $value = _value.sql($binder);
        } else {
            [$template, $value] = _stringExpression($binder);
        }

        return sprintf($template, $field, _operator, $value);
    }


    O traverse(this O)(Closure $callback) {
        if (_field instanceof IExpression) {
            $callback(_field);
            _field.traverse($callback);
        }

        if (_value instanceof IExpression) {
            $callback(_value);
            _value.traverse($callback);
        }

        foreach (_valueExpressions as $v) {
            $callback($v);
            $v.traverse($callback);
        }

        return this;
    }

    /**
     * Create a deep clone.
     *
     * Clones the field and value if they are expression objects.
     */
    void __clone() {
        foreach (["_value", "_field"] as $prop) {
            if (this.{$prop} instanceof IExpression) {
                this.{$prop} = clone this.{$prop};
            }
        }
    }

    /**
     * Returns a template and a placeholder for the value after registering it
     * with the placeholder $binder
     *
     * @param uim.cake.databases.ValueBinder aBinder The value binder to use.
     * @return array First position containing the template and the second a placeholder
     */
    protected array _stringExpression(ValueBinder aBinder) {
        $template = "%s ";

        if (_field instanceof IExpression && !_field instanceof IdentifierExpression) {
            $template = "(%s) ";
        }

        if (_isMultiple) {
            $template ~= "%s (%s)";
            $type = _type;
            if ($type != null) {
                $type = replace("[]", "", $type);
            }
            $value = _flattenValue(_value, $binder, $type);

            // To avoid SQL errors when comparing a field to a list of empty values,
            // better just throw an exception here
            if ($value == "") {
                $field = _field instanceof IExpression ? _field.sql($binder) : _field;
                /** @psalm-suppress PossiblyInvalidCast */
                throw new DatabaseException(
                    "Impossible to generate condition with empty list of values for field ($field)"
                );
            }
        } else {
            $template ~= "%s %s";
            $value = _bindValue(_value, $binder, _type);
        }

        return [$template, $value];
    }

    /**
     * Registers a value in the placeholder generator and returns the generated placeholder
     *
     * @param mixed $value The value to bind
     * @param uim.cake.databases.ValueBinder aBinder The value binder to use
     * @param string|null $type The type of $value
     * @return string generated placeholder
     */
    protected string _bindValue($value, ValueBinder aBinder, Nullable!string $type = null) {
        $placeholder = $binder.placeholder("c");
        $binder.bind($placeholder, $value, $type);

        return $placeholder;
    }

    /**
     * Converts a traversable value into a set of placeholders generated by
     * $binder and separated by `,`
     *
     * @param iterable $value the value to flatten
     * @param uim.cake.databases.ValueBinder aBinder The value binder to use
     * @param string|null $type the type to cast values to
     */
    protected string _flattenValue(iterable $value, ValueBinder aBinder, Nullable!string $type = null) {
        $parts = null;
        if (is_array($value)) {
            foreach (_valueExpressions as $k: $v) {
                $parts[$k] = $v.sql($binder);
                unset($value[$k]);
            }
        }

        if (!empty($value)) {
            $parts += $binder.generateManyNamed($value, $type);
        }

        return implode(",", $parts);
    }

    /**
     * Returns an array with the original $values in the first position
     * and all IExpression objects that could be found in the second
     * position.
     *
     * @param uim.cake.databases.IExpression|iterable $values The rows to insert
     */
    protected array _collectExpressions($values) {
        if ($values instanceof IExpression) {
            return [$values, []];
        }

        $expressions = $result = null;
        $isArray = is_array($values);

        if ($isArray) {
            /** @var array $result */
            $result = $values;
        }

        foreach ($values as $k: $v) {
            if ($v instanceof IExpression) {
                $expressions[$k] = $v;
            }

            if ($isArray) {
                $result[$k] = $v;
            }
        }

        return [$result, $expressions];
    }
}

// phpcs:disable
// Comparison will not load during instanceof checks so ensure it"s loaded here
// @deprecated 4.1.0 Add backwards compatible alias.
class_alias("Cake\databases.Expression\ComparisonExpression", "Cake\databases.Expression\Comparison");
// phpcs:enable
