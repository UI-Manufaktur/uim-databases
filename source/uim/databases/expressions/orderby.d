/*********************************************************************************************************
*	Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        *
*	License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  *
*	Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      *
**********************************************************************************************************/
module uim.cake;

@safe:
import uim.cake;

/**
 * An expression object for ORDER BY clauses
 */
class OrderByExpression extends QueryExpression
{
    /**
     * Constructor
     *
     * @param \Cake\Database\ExpressionInterface|array|string $conditions The sort columns
     * @param \Cake\Database\TypeMap|array<string, string> $types The types for each column.
     * @param string $conjunction The glue used to join conditions together.
     */
    function __construct($conditions = [], $types = [], $conjunction ="")
    {
        parent::__construct($conditions, $types, $conjunction);
    }

    /**
     * @inheritDoc
     */
    function sql(ValueBinder $binder): string
    {
        $order = [];
        foreach (_conditions as $k: $direction) {
            if ($direction instanceof ExpressionInterface) {
                $direction = $direction.sql($binder);
            }
            $order[] = is_numeric($k) ? $direction : sprintf("%s %s", $k, $direction);
        }

        return sprintf("ORDER BY %s", implode(",", $order));
    }

    /**
     * Auxiliary function used for decomposing a nested array of conditions and
     * building a tree structure inside this object to represent the full SQL expression.
     *
     * New order by expressions are merged to existing ones
     *
     * @param array $conditions list of order by expressions
     * @param array $types list of types associated on fields referenced in $conditions
     * @return void
     */
    protected function _addConditions(array $conditions, array $types): void
    {
        foreach ($conditions as $key: $val) {
            if (
                is_string($key) &&
                is_string($val) &&
                !in_array(strtoupper($val), ["ASC","DESC"], true)
            ) {
                throw new RuntimeException(
                    sprintf(
                       "Passing extra expressions by associative array (`\"%s\": \"%s\"`)" .
                       "is not allowed to avoid potential SQL injection." .
                       "Use QueryExpression or numeric array instead.",
                        $key,
                        $val
                    )
                );
            }
        }

        _conditions = array_merge(_conditions, $conditions);
    }
}
