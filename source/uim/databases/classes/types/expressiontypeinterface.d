module uim.databases.types;

import uim.cake;

@safe:

/**
 * An interface used by Type objects to signal whether the value should
 * be converted to an IExpression instead of a string when sent
 * to the database.
 */
interface IExpressionType {
    // Returns an IExpression object for the given value that can be used in queries.
    IExpression toExpression(Json valueToConvert);
}
