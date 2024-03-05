/*********************************************************************************************************
	Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        
	License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  
	Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      
**********************************************************************************************************/
module uim.databases.compilers.sqlserver.compiler;

@safe:
import uim.databases;

/**
 * Responsible for compiling a Query object into its SQL representation
 * for SQL Server
 *
 * @internal
 */
class SqlserverCompiler : QueryCompiler
{
    // SQLserver does not support ORDER BY in UNION queries.
    protected bool _orderedUnion = false;

    protected _templates = [
        "delete":"DELETE",
        "where":" WHERE %s",
        "group":" GROUP BY %s",
        "order":" %s",
        "offset":" OFFSET %s ROWS",
        "epilog":" %s",
    ];

    protected _selectParts = [
        "with", "select", "from", "join", "where", "group", "having", "window", "order",
        "offset", "limit", "union", "epilog",
    ];

    /**
     * Helper function used to build the string representation of a `WITH` clause,
     * it constructs the CTE definitions list without generating the `RECURSIVE`
     * keyword that is neither required nor valid.
     *
     * @param array someParts List of CTEs to be transformed to string
     * @param uim.databases\Query myQuery The query that is being compiled
     * @param uim.databases\ValueBinder aValueBinder Value binder used to generate parameter placeholder
     * @return string
     */
    protected string _buildWithPart(array someParts, Query myQuery, ValueBinder aValueBinder) {
        expressions = [];
        foreach (myPart; someParts) {
            expressions[] = myPart.sql(aValueBinder);
        }

        return sprintf("WITH %s ", implode(", ", expressions));
    }

    /**
     * Generates the INSERT part of a SQL query
     *
     * To better handle concurrency and low transaction isolation levels,
     * we also include an OUTPUT clause so we can ensure we get the inserted
     * row"s data back.
     *
     * @param array someParts The parts to build
     * @param uim.databases\Query myQuery The query that is being compiled
     * @param uim.databases\ValueBinder aValueBinder Value binder used to generate parameter placeholder
     * @return string
     */
    protected string _buildInsertPart(array someParts, Query myQuery, ValueBinder aValueBinder) {
        if (!isset([0])) {
            throw new DatabaseException(
                "Could not compile insert query. No table was specified. " .
                "Use `into()` to define a table."
            );
        }
        myTable = [0];
        columns = _stringifyExpressions([1], aValueBinder);
        auto myModifiers = _buildModifierPart(myQuery.clause("modifier"), myQuery, aValueBinder);

        return "INSERT%s INTO %s (%s) OUTPUT INSERTED.*".format(myModifiers, myTable, implode(", ", columns));
    }

    /**
     * Generates the LIMIT part of a SQL query
     *
     * @param int aLimit the limit clause
     * @param uim.databases\Query myQuery The query that is being compiled
     * @return string
     */
    protected string _buildLimitPart(int aLimit, Query myQuery) {
        if (myQuery.clause("offset") is null) {
            return "";
        }

        return sprintf(" FETCH FIRST %d ROWS ONLY", aLimit);
    }

    /**
     * Helper function used to build the string representation of a HAVING clause,
     * it constructs the field list taking care of aliasing and
     * converting expression objects to string.
     *
     * @param array someParts list of fields to be transformed to string
     * @param uim.databases\Query myQuery The query that is being compiled
     * @param uim.databases\ValueBinder aValueBinder Value binder used to generate parameter placeholder
     * @return string
     */
    protected auto _buildHavingPart(, myQuery, aValueBinder) {
        selectParts = myQuery.clause("select");

        foreach (selectParts as selectKey: selectPart) {
            if (!selectPart instanceof FunctionExpression) {
                continue;
            }
            foreach ( as  k: p) {
                if (!is_string(p)) {
                    continue;
                }
                preg_match_all(
                    "/\b" . trim(selectKey, "[]") . "\b/i",
                    p,
                    $matches
                );

                if (empty($matches[0])) {
                    continue;
                }

                [ k] = preg_replace(
                    ["/\[|\]/", "/\b" . trim(selectKey, "[]") . "\b/i"],
                    ["", selectPart.sql(aValueBinder)],
                    p
                );
            }
        }

        return " HAVING %s ".format(implode(", ", );
    }
}
