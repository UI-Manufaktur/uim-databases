/*********************************************************************************************************
	Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        
	License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  
	Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      
**********************************************************************************************************/
module uim.databases.expressions;

import uim.databases.IDBAExpression;
import uim.databases.Query;
import uim.databases.ValueBinder;
use Closure;

/**
 * An expression object for complex ORDER BY clauses
 */
class OrderClauseExpression : IDBAExpression, FieldInterface
{
    use FieldTrait;

    /**
     * The direction of sorting.
     */
    protected string _direction;

    /**
     * Constructor
     *
     * @param uim.databases.IDBAExpression|string $field The field to order on.
     * @param string $direction The direction to sort on.
     */
    this($field, $direction) {
        _field = $field;
        _direction = strtolower($direction) == "asc" ? "ASC" : "DESC";
    }


    string sql(ValueBinder aBinder) {
        /** @var DDBIDBAExpression|string $field */
        $field = _field;
        if ($field instanceof Query) {
            $field = sprintf("(%s)", $field.sql($binder));
        } elseif ($field instanceof IDBAExpression) {
            $field = $field.sql($binder);
        }

        return sprintf("%s %s", $field, _direction);
    }


    O traverse(this O)(Closure $callback) {
        if (_field instanceof IDBAExpression) {
            $callback(_field);
            _field.traverse($callback);
        }

        return this;
    }

    /**
     * Create a deep clone of the order clause.
     */
    void __clone() {
        if (_field instanceof IDBAExpression) {
            _field = clone _field;
        }
    }
}
