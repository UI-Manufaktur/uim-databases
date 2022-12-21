module uim.databases;

@safe:
import uim.cake;

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
     * @param array $parts List of CTEs to be transformed to string
     * @param \Cake\Database\Query myQuery The query that is being compiled
     * @param \Cake\Database\ValueBinder $binder Value binder used to generate parameter placeholder
     * @return string
     */
    protected string _buildWithPart(array $parts, Query myQuery, ValueBinder $binder) {
        $expressions = [];
        foreach ($parts as $cte) {
            $expressions[] = $cte.sql($binder);
        }

        return sprintf("WITH %s ", implode(", ", $expressions));
    }

    /**
     * Generates the INSERT part of a SQL query
     *
     * To better handle concurrency and low transaction isolation levels,
     * we also include an OUTPUT clause so we can ensure we get the inserted
     * row"s data back.
     *
     * @param array $parts The parts to build
     * @param \Cake\Database\Query myQuery The query that is being compiled
     * @param \Cake\Database\ValueBinder $binder Value binder used to generate parameter placeholder
     * @return string
     */
    protected string _buildInsertPart(array $parts, Query myQuery, ValueBinder $binder) {
        if (!isset($parts[0])) {
            throw new DatabaseException(
                "Could not compile insert query. No table was specified. " .
                "Use `into()` to define a table."
            );
        }
        myTable = $parts[0];
        $columns = _stringifyExpressions($parts[1], $binder);
        $modifiers = _buildModifierPart(myQuery.clause("modifier"), myQuery, $binder);

        return sprintf(
            "INSERT%s INTO %s (%s) OUTPUT INSERTED.*",
            $modifiers,
            myTable,
            implode(", ", $columns)
        );
    }

    /**
     * Generates the LIMIT part of a SQL query
     *
     * @param int $limit the limit clause
     * @param \Cake\Database\Query myQuery The query that is being compiled
     * @return string
     */
    protected string _buildLimitPart(int $limit, Query myQuery) {
        if (myQuery.clause("offset") is null) {
            return "";
        }

        return sprintf(" FETCH FIRST %d ROWS ONLY", $limit);
    }

    /**
     * Helper function used to build the string representation of a HAVING clause,
     * it constructs the field list taking care of aliasing and
     * converting expression objects to string.
     *
     * @param array $parts list of fields to be transformed to string
     * @param \Cake\Database\Query myQuery The query that is being compiled
     * @param \Cake\Database\ValueBinder $binder Value binder used to generate parameter placeholder
     * @return string
     */
    protected auto _buildHavingPart($parts, myQuery, $binder) {
        $selectParts = myQuery.clause("select");

        foreach ($selectParts as $selectKey: $selectPart) {
            if (!$selectPart instanceof FunctionExpression) {
                continue;
            }
            foreach ($parts as $k: $p) {
                if (!is_string($p)) {
                    continue;
                }
                preg_match_all(
                    "/\b" . trim($selectKey, "[]") . "\b/i",
                    $p,
                    $matches
                );

                if (empty($matches[0])) {
                    continue;
                }

                $parts[$k] = preg_replace(
                    ["/\[|\]/", "/\b" . trim($selectKey, "[]") . "\b/i"],
                    ["", $selectPart.sql($binder)],
                    $p
                );
            }
        }

        return sprintf(" HAVING %s", implode(", ", $parts));
    }
}
