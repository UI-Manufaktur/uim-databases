module uim.databases.classes.compilers.sqlserver;

import uim.databases;

@safe:

/**
 * Responsible for compiling a Query object into its SQL representation
 * for SQL Server
 *
 * @internal
 */
class SqlserverCompiler : QueryCompiler {
    // SQLserver does not support ORDER BY in UNION queries.
    protected bool _orderedUnion = false;

    protected STRINGAA _templates = [
        "delete": "DELETE",
        "where": " WHERE %s",
        "group": " GROUP BY %s",
        "order": " %s",
        "offset": " OFFSET %s ROWS",
        "epilog": " %s",
        "comment": "/* %s */ ",
    ];

    protected string[] _selectParts = [
        "comment", "with", "select", "from", "join", "where", "group", "having", "window", "order",
        "offset", "limit", "union", "epilog",
    ];

    /**
     * Helper auto used to build the string representation of a `WITH` clause,
     * it constructs the CTE definitions list without generating the `RECURSIVE`
     * keyword that is neither required nor valid.
     * Params:
     * someParts = List of CTEs to be transformed to string
     * @param \UIM\Database\Query aQuery The query that is being compiled
     * @param \UIM\Database\ValueBinder aBinder Value binder used to generate parameter placeholder
     */
    protected string _buildWithPart(CommonTableExpression[] cteParts, Query aQuery, ValueBinder aBinder) {
        string[] sqlExpressions = cteParts
            .map!(cte => cte.sql(aBinder)).array;

        return "WITH %s ".format(sqlExpressions.join(", "));
    }
    
    /**
     * Generates the INSERT part of a SQL query
     *
     * To better handle concurrency and low transaction isolation levels,
     * we also include an OUTPUT clause so we can ensure we get the inserted
     * row`s data back.
     * Params:
     * array someParts The parts to build
     * @param \UIM\Database\Query aQuery The query that is being compiled
     * @param \UIM\Database\ValueBinder aBinder Value binder used to generate parameter placeholder
     */
    protected string _buildInsertFromParts(array someParts, Query aQuery, ValueBinder aBinder) {
        if (!isSet(someParts[0])) {
            throw new DatabaseException(
                'Could not compile insert query. No table was specified. ' .
                'Use `into()` to define a table.'
            );
        }
        auto aTable = someParts[0];
        auto someColumns = _stringifyExpressions(someParts[1], aBinder);
        auto someModifiers = _buildModifierPart(aQuery.clause("modifier"), aQuery, aBinder);

        return "INSERT%s INTO %s (%s) OUTPUT INSERTED.*".format(
            someModifiers,
            aTable,
            join(", ", someColumns)
        );
    }
    
    /**
     * Generates the LIMIT part of a SQL query
     * Params:
     * aLimit = the limit clause
     * aQuery = The query that is being compiled
     */
    protected string _buildLimitPart(int aLimit, Query aQuery) {
        if (aQuery.clause("offset").isNull) {
            return "";
        }
        return " FETCH FIRST %d ROWS ONLY".format(aLimit);
    }
    
    /**
     * Helper auto used to build the string representation of a HAVING clause,
     * it constructs the field list taking care of aliasing and
     * converting expression objects to string.
     * Params:
     * array someParts list of fields to be transformed to string
     * @param \UIM\Database\Query aQuery The query that is being compiled
     * @param \UIM\Database\ValueBinder aBinder Value binder used to generate parameter placeholder
     */
    protected string _buildHavingParts(array someParts, Query aQuery, ValueBinder aBinder) {
        auto selectParts = aQuery.clause("select");

        foreach (selectKey: selectPart; selectParts) {
        selectParts.byKeyValue
            .filter!(keyPart => cast(FunctionExpression)keyPart.value)
            .each!((keyPart) {
                foreach (myKey, p; someParts) {
                    if (!isString(p)) {
                        continue;
                    }
                    preg_match_all(
                        "/\b" ~ trim(keyPart.key, "[]") ~ "\b/i",
                        p,
                        $matches
                    );

                    if ($matches[0].isEmpty) {
                        continue;
                    }
                    someParts[myKey] = preg_replace(
                        ["/\[|\]/", "/\b" ~ trim(keyPart.key, "[]") ~ "\b/i"],
                        ["", keyPart.value.sql(aBinder)],
                        p
                    );
                }
            });
        return " HAVING %s".format(join(", ", someParts));
    }
}
