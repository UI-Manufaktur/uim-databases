


 *


 * @since         3.3.0
  */module uim.databases.types;

import uim.databases.IDBAExpression;

/**
 * An interface used by Type objects to signal whether the value should
 * be converted to an IDBAExpression instead of a string when sent
 * to the database.
 */
interface ExpressionTypeInterface
{
    /**
     * Returns an IDBAExpression object for the given value that can
     * be used in queries.
     *
     * @param mixed $value The value to be converted to an expression
     * @return uim.databases.IDBAExpression
     */
    function toExpression($value): IDBAExpression;
}
