module uim.databases;

import uim.databases;

@safe:

/**
 * Responsible for compiling a Query object into its SQL representation
 * for Postgres
 */
class PostgresCompiler : QueryCompiler {
    /**
     * Always quote aliases in SELECT clause.
     *
     * Postgres auto converts unquoted identifiers to lower case.
     */
    protected bool _quotedSelectAliases = true;

    protected STRINGAA _templates = [
        "delete": "DELETE",
        "where": " WHERE %s",
        "group": " GROUP BY %s",
        "order": " %s",
        "limit": " LIMIT %s",
        "offset": " OFFSET %s",
        "epilog": " %s",
        "comment": "/* %s */ ",
    ];

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
        auto $selectParts = aQuery.clause("select");

        foreach ($selectKey: $selectPart; $selectParts) {
            if (!cast(FunctionExpression)$selectPart ) {
                continue;
            }
            foreach ($p; someParts; myKey) {
                if (!isString($p)) {
                    continue;
                }
                preg_match_all(
                    "/\b" ~ trim($selectKey, "\"") ~ "\b/i",
                    $p,
                    $matches
                );

                if ($matches[0].isEmpty) {
                    continue;
                }
                someParts[myKey] = preg_replace(
                    ["/"/"", "/\b" ~ trim($selectKey, "\"") ~ "\b/i"],
                    ["", $selectPart.sql(aBinder)],
                    $p
                );
            }
        }
        return " HAVING %s".format(join(", ", someParts));
    }
}
