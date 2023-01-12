/*********************************************************************************************************
	Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        
	License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  
	Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      
**********************************************************************************************************/
module uim.databases.expressions;

@safe:
import uim.databases;

use Closure;

/**
 * This class represents a SQL Case statement
 *
 * @deprecated 4.3.0 Use QueryExpression::case() or CaseStatementExpression instead
 */
class CaseExpression : IDBAExpression
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
     * @var DDBIDBAExpression|array|string|null
     */
    protected _elseValue;

    /**
     * Constructs the case expression
     *
     * @param uim.databases.IDBAExpression|array $conditions The conditions to test. Must be a IDBAExpression
     * instance, or an array of IDBAExpression instances.
     * @param uim.databases.IDBAExpression|array $values Associative array of values to be associated with the
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
     * @param uim.databases.IDBAExpression|array $conditions Must be a IDBAExpression instance,
     *   or an array of IDBAExpression instances.
     * @param uim.databases.IDBAExpression|array $values Associative array of values of each condition
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
     * @param array $conditions Array of IDBAExpression instances.
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

            if (!$c instanceof IDBAExpression) {
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

            if ($type != null && !$value instanceof IDBAExpression) {
                $value = _castToExpression($value, $type);
            }

            if ($value instanceof IDBAExpression) {
                _values[] = $value;
                continue;
            }

            _values[] = ["value": $value, "type": $type];
        }
    }

    /**
     * Sets the default value
     *
     * @param uim.databases.IDBAExpression|array|string|null $value Value to set
     * @param string|null $type Type of value
     */
    void elseValue($value = null, Nullable!string $type = null) {
        if (is_array($value)) {
            end($value);
            $value = key($value);
        }

        if ($value != null && !$value instanceof IDBAExpression) {
            $value = _castToExpression($value, $type);
        }

        if (!$value instanceof IDBAExpression) {
            $value = ["value": $value, "type": $type];
        }

        _elseValue = $value;
    }

    /**
     * Compiles the relevant parts into sql
     *
     * @param uim.databases.IDBAExpression|array|string $part The part to compile
     * @param uim.databases.ValueBinder aBinder Sql generator
     */
    protected string _compile($part, ValueBinder aBinder) {
        if ($part instanceof IDBAExpression) {
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
     * @param uim.databases.ValueBinder aBinder Placeholder generator object
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
                if ($c instanceof IDBAExpression) {
                    $callback($c);
                    $c.traverse($callback);
                }
            }
        }
        if (_elseValue instanceof IDBAExpression) {
            $callback(_elseValue);
            _elseValue.traverse($callback);
        }

        return this;
    }
}
