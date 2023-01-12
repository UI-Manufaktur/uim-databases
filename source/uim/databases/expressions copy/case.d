module uim.cake.databases.Expression;

module uim.cake.databases.Expression;

import uim.cake.databases.IExpression;
import uim.cake.databases.types.ExpressionTypeCasterTrait;
import uim.cake.databases.ValueBinder;
use Closure;

/**
 * This class represents a SQL Case statement
 *
 * @deprecated 4.3.0 Use QueryExpression::case() or CaseStatementExpression instead
 */
class CaseExpression : IExpression
{
    use ExpressionTypeCasterTrait;

    /**
     * A list of strings or other expression objects that represent the conditions of
     * the case statement. For example one key of the array might look like "sum > :value"
     *
     * @var array
     */
    protected _conditions = null;

    /**
     * Values that are associated with the conditions in the _conditions array.
     * Each value represents the "true" value for the condition with the corresponding key.
     *
     * @var array
     */
    protected _values = null;

    /**
     * The `ELSE` value for the case statement. If null then no `ELSE` will be included.
     *
     * @var DDBIExpression|array|string|null
     */
    protected _elseValue;

    /**
     * Constructs the case expression
     *
     * @param uim.cake.databases.IExpression|array $conditions The conditions to test. Must be a IExpression
     * instance, or an array of IExpression instances.
     * @param uim.cake.databases.IExpression|array $values Associative array of values to be associated with the
     * conditions passed in $conditions. If there are more $values than $conditions,
     * the last $value is used as the `ELSE` value.
     * @param array<string> $types Associative array of types to be associated with the values
     * passed in $values
     */
    this($conditions = null, $values = null, $types = null) {
        $conditions = is_array($conditions) ? $conditions : [$conditions];
        $values = is_array($values) ? $values : [$values];
        $types = is_array($types) ? $types : [$types];

        if (!empty($conditions)) {
            this.add($conditions, $values, $types);
        }

        if (count($values) > count($conditions)) {
            end($values);
            $key = key($values);
            this.elseValue($values[$key], $types[$key] ?? null);
        }
    }

    /**
     * Adds one or more conditions and their respective true values to the case object.
     * Conditions must be a one dimensional array or a QueryExpression.
     * The trueValues must be a similar structure, but may contain a string value.
     *
     * @param uim.cake.databases.IExpression|array $conditions Must be a IExpression instance,
     *   or an array of IExpression instances.
     * @param uim.cake.databases.IExpression|array $values Associative array of values of each condition
     * @param array<string> $types Associative array of types to be associated with the values
     * @return this
     */
    function add($conditions = null, $values = null, $types = null) {
        $conditions = is_array($conditions) ? $conditions : [$conditions];
        $values = is_array($values) ? $values : [$values];
        $types = is_array($types) ? $types : [$types];

        _addExpressions($conditions, $values, $types);

        return this;
    }

    /**
     * Iterates over the passed in conditions and ensures that there is a matching true value for each.
     * If no matching true value, then it is defaulted to "1".
     *
     * @param array $conditions Array of IExpression instances.
     * @param array<mixed> $values Associative array of values of each condition
     * @param array<string> $types Associative array of types to be associated with the values
     */
    protected void _addExpressions(array $conditions, array $values, array $types) {
        $rawValues = array_values($values);
        $keyValues = array_keys($values);

        foreach ($conditions as $k: $c) {
            $numericKey = is_numeric($k);

            if ($numericKey && empty($c)) {
                continue;
            }

            if (!$c instanceof IExpression) {
                continue;
            }

            _conditions[] = $c;
            $value = $rawValues[$k] ?? 1;

            if ($value == "literal") {
                $value = $keyValues[$k];
                _values[] = $value;
                continue;
            }

            if ($value == "identifier") {
                /** @var string $identifier */
                $identifier = $keyValues[$k];
                $value = new IdentifierExpression($identifier);
                _values[] = $value;
                continue;
            }

            $type = $types[$k] ?? null;

            if ($type != null && !$value instanceof IExpression) {
                $value = _castToExpression($value, $type);
            }

            if ($value instanceof IExpression) {
                _values[] = $value;
                continue;
            }

            _values[] = ["value": $value, "type": $type];
        }
    }

    /**
     * Sets the default value
     *
     * @param uim.cake.databases.IExpression|array|string|null $value Value to set
     * @param string|null $type Type of value
     */
    void elseValue($value = null, Nullable!string $type = null) {
        if (is_array($value)) {
            end($value);
            $value = key($value);
        }

        if ($value != null && !$value instanceof IExpression) {
            $value = _castToExpression($value, $type);
        }

        if (!$value instanceof IExpression) {
            $value = ["value": $value, "type": $type];
        }

        _elseValue = $value;
    }

    /**
     * Compiles the relevant parts into sql
     *
     * @param uim.cake.databases.IExpression|array|string $part The part to compile
     * @param uim.cake.databases.ValueBinder aBinder Sql generator
     */
    protected string _compile($part, ValueBinder aBinder) {
        if ($part instanceof IExpression) {
            $part = $part.sql($binder);
        } elseif (is_array($part)) {
            $placeholder = $binder.placeholder("param");
            $binder.bind($placeholder, $part["value"], $part["type"]);
            $part = $placeholder;
        }

        return $part;
    }

    /**
     * Converts the Node into a SQL string fragment.
     *
     * @param uim.cake.databases.ValueBinder aBinder Placeholder generator object
     */
    string sql(ValueBinder aBinder) {
        $parts = null;
        $parts[] = "CASE";
        foreach (_conditions as $k: $part) {
            $value = _values[$k];
            $parts[] = "WHEN " ~ _compile($part, $binder) ~ " THEN " ~ _compile($value, $binder);
        }
        if (_elseValue != null) {
            $parts[] = "ELSE";
            $parts[] = _compile(_elseValue, $binder);
        }
        $parts[] = "END";

        return implode(" ", $parts);
    }


    O traverse(this O)(Closure $callback) {
        foreach (["_conditions", "_values"] as $part) {
            foreach (this.{$part} as $c) {
                if ($c instanceof IExpression) {
                    $callback($c);
                    $c.traverse($callback);
                }
            }
        }
        if (_elseValue instanceof IExpression) {
            $callback(_elseValue);
            _elseValue.traverse($callback);
        }

        return this;
    }
}
