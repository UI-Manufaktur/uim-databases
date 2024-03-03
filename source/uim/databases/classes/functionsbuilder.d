module uim.databases;

import uim.databases;

@safe:

/**
 * Contains methods related to generating FunctionExpression objects
 * with most commonly used SQL functions.
 * This acts as a factory for FunctionExpression objects.
 */
class FunctionsBuilder {
    // Returns a FunctionExpression representing a call to SQL RAND function.
    FunctionExpression rand() {
        return new FunctionExpression("RAND", [], [], "float");
    }
    
    /**
     * Returns a AggregateExpression representing a call to SQL SUM function.
     * Params:
     * \UIM\Database\IExpression|string aexpression the auto argument
     * @param array types list of types to bind to the arguments
     */
    AggregateExpression sum(IExpression|string aexpression, array types = []) {
        resultType = "float";
        if (current($types) == "integer") {
            resultType = "integer";
        }
        return this.aggregate("SUM", this.toLiteralParam(expression), types, resultType);
    }
    
    /**
     * Returns a AggregateExpression representing a call to SQL AVG function.
     * Params:
     * \UIM\Database\IExpression|string aexpression the auto argument
     * @param array types list of types to bind to the arguments
     */
    AggregateExpression avg(IExpression|string aexpression, array types = []) {
        return this.aggregate("AVG", this.toLiteralParam(expression), types, "float");
    }
    
    /**
     * Returns a AggregateExpression representing a call to SQL MAX function.
     * Params:
     * \UIM\Database\IExpression|string aexpression the auto argument
     * @param array types list of types to bind to the arguments
     */
    AggregateExpression max(IExpression|string aexpression, array types = []) {
        return this.aggregate("MAX", this.toLiteralParam(expression), types, current($types) ?: "float");
    }
    
    /**
     * Returns a AggregateExpression representing a call to SQL MIN function.
     * Params:
     * \UIM\Database\IExpression|string aexpression the auto argument
     * @param array types list of types to bind to the arguments
     */
    AggregateExpression min(IExpression|string aexpression, array types = []) {
        return this.aggregate("MIN", this.toLiteralParam(expression), types, current($types) ?: "float");
    }
    
    /**
     * Returns a AggregateExpression representing a call to SQL COUNT function.
     * Params:
     * \UIM\Database\IExpression|string aexpression the auto argument
     * @param array types list of types to bind to the arguments
     */
    AggregateExpression count(IExpression|string aexpression, array types = []) {
        return this.aggregate("COUNT", this.toLiteralParam(expression), types, "integer");
    }
    
    /**
     * Returns a FunctionExpression representing a string concatenation
     * Params:
     * array someArguments List of strings or expressions to concatenate
     * @param array types list of types to bind to the arguments
     */
    FunctionExpression concat(array someArguments, array types = []) {
        return new FunctionExpression("CONCAT", someArguments, types, "string");
    }
    
    /**
     * Returns a FunctionExpression representing a call to SQL COALESCE function.
     * Params:
     * array someArguments List of expressions to evaluate as auto parameters
     * @param array types list of types to bind to the arguments
     */
    FunctionExpression coalesce(array someArguments, array types = []) {
        return new FunctionExpression("COALESCE", someArguments, types, current($types) ?: "string");
    }
    
    /**
     * Returns a FunctionExpression representing a SQL CAST.
     *
     * The `$type` parameter is a SQL type. The return type for the returned expression
     * is the default type name. Use `setReturnType()` to update it.
     * Params:
     * \UIM\Database\IExpression|string afield Field or expression to cast.
     * @param string sqlDatatype The SQL data type
     */
    FunctionExpression cast(IExpression|string afield, string sqlDatatype) {
        expression = new FunctionExpression("CAST", this.toLiteralParam(field));
        expression.setConjunction(" AS").add([sqlDatatype: "literal"]);

        return expression;
    }
    
    /**
     * Returns a FunctionExpression representing the difference in days between
     * two dates.
     * Params:
     * array someArguments List of expressions to obtain the difference in days.
     * @param array types list of types to bind to the arguments
     */
    FunctionExpression dateDiff(array someArguments, array types = []) {
        return new FunctionExpression("DATEDIFF", someArguments, types, "integer");
    }
    
    /**
     * Returns the specified date part from the SQL expression.
     * Params:
     * string apart Part of the date to return.
     * @param \UIM\Database\IExpression|string aexpression Expression to obtain the date part from.
     * @param array types list of types to bind to the arguments
     */
    FunctionExpression datePart(
        string apart,
        IExpression|string aexpression,
        array types = []
    ) {
        return this.extract($part, expression, types);
    }
    
    /**
     * Returns the specified date part from the SQL expression.
     * Params:
     * string apart Part of the date to return.
     * @param \UIM\Database\IExpression|string aexpression Expression to obtain the date part from.
     * @param array types list of types to bind to the arguments
     */
    FunctionExpression extract(string apart, IExpression|string aexpression, array types = []) {
        auto functionExpression = new FunctionExpression("EXTRACT", this.toLiteralParam(aexpression), types, "integer");
        functionExpression.setConjunction(" FROM").add([$part: "literal"], [], true);

        return functionExpression;
    }
    
    /**
     * Add the time unit to the date expression
     * Params:
     * \UIM\Database\IExpression|string aexpression Expression to obtain the date part from.
     * @param string|int aValue Value to be added. Use negative to subtract.
     * @param string aunit Unit of the value e.g. hour or day.
     * @param array types list of types to bind to the arguments
     */
    FunctionExpression dateAdd(
        IExpression|string aexpression,
        string|int aValue,
        string aunit,
        array types = []
    ) {
        if (!isNumeric(aValue)) {
            aValue = 0;
        }
         anInterval = aValue ~ " " ~ $unit;
        expression = new FunctionExpression("DATE_ADD", this.toLiteralParam(expression), types, "datetime");
        expression.setConjunction(", INTERVAL").add([anInterval: "literal"]);

        return expression;
    }
    
    /**
     * Returns a FunctionExpression representing a call to SQL WEEKDAY function.
     * 1 - Sunday, 2 - Monday, 3 - Tuesday...
     * Params:
     * \UIM\Database\IExpression|string aexpression the auto argument
     * @param array types list of types to bind to the arguments
     */
    FunctionExpression dayOfWeek(IExpression|string aexpression, array types = []) {
        return new FunctionExpression("DAYOFWEEK", this.toLiteralParam(expression), types, "integer");
    }
    
    /**
     * Returns a FunctionExpression representing a call to SQL WEEKDAY function.
     * 1 - Sunday, 2 - Monday, 3 - Tuesday...
     * Params:
     * \UIM\Database\IExpression|string aexpression the auto argument
     * @param array types list of types to bind to the arguments
     */
    FunctionExpression weekday(IExpression|string aexpression, array types = []) {
        return this.dayOfWeek(expression, types);
    }
    
    /**
     * Returns a FunctionExpression representing a call that will return the current
     * date and time. By default it returns both date and time, but you can also
     * make it generate only the date or only the time.
     * Params:
     * string atype (datetime|date|time)
     */
    FunctionExpression now(string atype = "datetime") {
        if ($type == "datetime") {
            return new FunctionExpression("NOW", [], [], "datetime");
        }
        if ($type == "date") {
            return new FunctionExpression("CURRENT_DATE", [], [], "date");
        }
        if ($type == "time") {
            return new FunctionExpression("CURRENT_TIME", [], [], "time");
        }
        throw new InvalidArgumentException("Invalid argument for FunctionsBuilder.now(): " ~ type);
    }
    
    /**
     * Returns an AggregateExpression representing call to SQL ROW_NUMBER().
     */
    AggregateExpression rowNumber() {
        return (new AggregateExpression("ROW_NUMBER", [], [], "integer")).over();
    }
    
    /**
     * Returns an AggregateExpression representing call to SQL LAG().
     * Params:
     * \UIM\Database\IExpression|string aexpression The value evaluated at offset
     * @param int anOffset The row offset
     * @param Json defaultValue The default value if offset doesn`t exist
     * @param string|null type The output type of the lag expression. Defaults to float.
     */
    AggregateExpression lag(
        IExpression|string aexpression,
        int anOffset,
        Json defaultValue = Json(null),
        string outputType = null
    ) {
        $params = this.toLiteralParam(expression) ~ [anOffset: "literal"];
        if ($default !isNull) {
            $params ~= $default;
        }
        types = [];
        if (!outputType.isNull) {
            types = [outputType, "integer", outputType];
        }
        return (new AggregateExpression("LAG", $params, types, outputType ?? "float")).over();
    }
    
    /**
     * Returns an AggregateExpression representing call to SQL LEAD().
     * Params:
     * \UIM\Database\IExpression|string aexpression The value evaluated at offset
     * @param int anOffset The row offset
     * @param Json defaultValue The default value if offset doesn`t exist
     * @param string|null outputType The output type of the lead expression. Defaults to float.
     */
    AggregateExpression lead(
        IExpression|string aexpression,
        int anOffset,
        Json defaultValue = Json(null),
        string atype = null
    ) {
        $params = this.toLiteralParam(expression) ~ [anOffset: "literal"];
        if ($default !isNull) {
            $params ~= $default;
        }
        types = [];
        if (outputType !isNull) {
            types = [outputType, "integer", outputType];
        }
        return (new AggregateExpression("LEAD", $params, types, outputType ?? "float")).over();
    }
    
    /**
     * Helper method to create arbitrary SQL aggregate auto calls.
     * Params:
     * @param array $params Array of arguments to be passed to the function.
     *    Can be an associative array with the literal value or identifier:
     *    `["value": "literal"]` or `["value": 'identifier"]
     * @param array types Array of types that match the names used in `$params`:
     *    `["name": 'type"]`
     * @param string result Return type of the entire expression. Defaults to float.
     */
    AggregateExpression aggregate(
        string sqlName,
        array $params = [],
        array types = [],
        string result = "float"
    ) {
        return new AggregateExpression(sqlName, $params, types, result);
    }
    
    /**
     * Magic method dispatcher to create custom SQL auto calls
     * Params:
     * string aName the SQL auto name to construct
     * @param array someArguments list with up to 3 arguments, first one being an array with
     * parameters for the SQL function, the second one a list of types to bind to those
     * params, and the third one the return type of the function
     */
    FunctionExpression __call(string aName, array someArguments) {
        return new FunctionExpression(name, ...someArguments);
    }
    
    /**
     * Creates auto parameter array from expression or string literal.
     * Params:
     * \UIM\Database\IExpression|string aexpression auto argument
     */
    protected array<\UIM\Database\IExpression|string> toLiteralParam(IExpression|string aexpression) {
        if (isString(expression)) {
            return [expression: 'literal"];
        }
        return [expression];
    }
}
