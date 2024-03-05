/*********************************************************************************************************
	Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        
	License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  
	Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      
**********************************************************************************************************/
module uim.databases.compilers.postgres.compiler;

@safe:
import uim.databases;

// Responsible for compiling a Query object into its SQL representation for Postgres
class PostgresCompiler : QueryCompiler {
    // Always quote aliases in SELECT clause.
    // Postgres auto converts unquoted identifiers to lower case.
    protected bool _quotedSelectAliases = true;

    protected STRINGAA _templates = [
        "delete":"DELETE",
        "where":" WHERE %s",
        "group":" GROUP BY %s",
        "order":" %s",
        "limit":" LIMIT %s",
        "offset":" OFFSET %s",
        "epilog":" %s",
    ];

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
    protected auto _buildHavingPart(parts, myQuery,  binder) {
        selectParts = myQuery.clause("select");

        foreach (selectKey, selectPart; selectParts) {
            if (!selectPart instanceof FunctionExpression) {
                continue;
            }
            foreach (parts as $k: p) {
                if (!is_string(p)) {
                    continue;
                }
                preg_match_all(
                    "/\b"~ trim(selectKey, "\"") . "\b/i",
                    p,
                    $matches
                );

                if (empty($matches[0])) {
                    continue;
                }

                parts[$k] = preg_replace(
                    ["/"/", "/\b"~ trim(selectKey, "\"") . "\b/i"],
                    ["", selectPart.sql( binder)],
                    p
                );
            }
        }

        return sprintf(" HAVING %s", implode(", ", parts));
    }
}
