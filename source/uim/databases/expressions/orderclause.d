/*********************************************************************************************************
*	Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        *
*	License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  *
*	Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      *
**********************************************************************************************************/
module uim.cake;

@safe:
import uim.cake;

/**
 * An expression object for complex ORDER BY clauses
 */
class OrderClauseExpression : ExpressionInterface, FieldInterface
{
    use FieldTrait;

    /**
     * The direction of sorting.
     *
     * @var string
     */
    protected $_direction;

    /**
     * Constructor
     *
     * @param \Cake\Database\ExpressionInterface|string $field The field to order on.
     * @param string $direction The direction to sort on.
     */
    function __construct($field, $direction)
    {
        _field = $field;
        _direction = strtolower($direction) ==="asc" ?"ASC" :"DESC";
    }


    string sql(ValueBinder $binder)
    {
        /** @var \Cake\Database\ExpressionInterface|string $field */
        $field = _field;
        if ($field instanceof Query) {
            $field = sprintf("(%s)", $field.sql($binder));
        } elseif ($field instanceof ExpressionInterface) {
            $field = $field.sql($binder);
        }

        return sprintf("%s %s", $field, _direction);
    }


    function traverse(Closure $callback)
    {
        if (_field instanceof ExpressionInterface) {
            $callback(_field);
            _field.traverse($callback);
        }

        return $this;
    }

    /**
     * Create a deep clone of the order clause.
     *
     * @return void
     */
    function __clone()
    {
        if (_field instanceof ExpressionInterface) {
            _field = clone _field;
        }
    }
}
