module uim.cake.databases;

@safe:
import uim.cake;

/module uim.cake.databases;

import uim.cake.databases.exceptions.DatabaseException;
use Closure;
use Countable;

/**
 * Responsible for compiling a Query object into its SQL representation
 *
 * @internal
 */
class QueryCompiler
{
    /**
     * List of sprintf templates that will be used for compiling the SQL for
     * this query. There are some clauses that can be built as just as the
     * direct concatenation of the internal parts, those are listed here.
     *
     * @var array<string, string>
     */
    protected _templates = [
        "delete": "DELETE",
        "where": " WHERE %s",
        "group": " GROUP BY %s ",
        "having": " HAVING %s ",
        "order": " %s",
        "limit": " LIMIT %s",
        "offset": " OFFSET %s",
        "epilog": " %s",
    ];

    /**
     * The list of query clauses to traverse for generating a SELECT statement
     *
     * @var array<string>
     */
    protected _selectParts = [
        "with", "select", "from", "join", "where", "group", "having", "window", "order",
        "limit", "offset", "union", "epilog",
    ];

    /**
     * The list of query clauses to traverse for generating an UPDATE statement
     *
     * @var array<string>
     */
    protected _updateParts = ["with", "update", "set", "where", "epilog"];

    /**
     * The list of query clauses to traverse for generating a DELETE statement
     *
     * @var array<string>
     */
    protected _deleteParts = ["with", "delete", "modifier", "from", "where", "epilog"];

    /**
     * The list of query clauses to traverse for generating an INSERT statement
     *
     * @var array<string>
     */
    protected _insertParts = ["with", "insert", "values", "epilog"];

    /**
     * Indicate whether this query dialect supports ordered unions.
     *
     * Overridden in subclasses.
     */
    protected bool _orderedUnion = true;

    /**
     * Indicate whether aliases in SELECT clause need to be always quoted.
     */
    protected bool _quotedSelectAliases = false;

    /**
     * Returns the SQL representation of the provided query after generating
     * the placeholders for the bound values using the provided generator
     *
     * @param uim.cake.databases.Query $query The query that is being compiled
     * @param uim.cake.databases.ValueBinder aBinder Value binder used to generate parameter placeholders
     */
    string compile(Query $query, ValueBinder aBinder) {
        $sql = "";
        $type = $query.type();
        $query.traverseParts(
            _sqlCompiler($sql, $query, $binder),
            this.{"_{$type}Parts"}
        );

        // Propagate bound parameters from sub-queries if the
        // placeholders can be found in the SQL statement.
        if ($query.getValueBinder() != $binder) {
            foreach ($query.getValueBinder().bindings() as $binding) {
                $placeholder = ":" ~ $binding["placeholder"];
                if (preg_match("/" ~ $placeholder ~ "(?:\W|$)/", $sql) > 0) {
                    $binder.bind($placeholder, $binding["value"], $binding["type"]);
                }
            }
        }

        return $sql;
    }

    /**
     * Returns a callable object that can be used to compile a SQL string representation
     * of this query.
     *
     * @param string $sql initial sql string to append to
     * @param uim.cake.databases.Query $query The query that is being compiled
     * @param uim.cake.databases.ValueBinder aBinder Value binder used to generate parameter placeholder
     * @return \Closure
     */
    protected function _sqlCompiler(string &$sql, Query $query, ValueBinder aBinder): Closure
    {
        return function ($part, $partName) use (&$sql, $query, $binder) {
            if (
                $part == null ||
                (is_array($part) && empty($part)) ||
                ($part instanceof Countable && count($part) == 0)
            ) {
                return;
            }

            if ($part instanceof IExpression) {
                $part = [$part.sql($binder)];
            }
            if (isset(_templates[$partName])) {
                $part = _stringifyExpressions((array)$part, $binder);
                $sql ~= sprintf(_templates[$partName], implode(", ", $part));

                return;
            }

            $sql ~= this.{"_build" ~ $partName ~ "Part"}($part, $query, $binder);
        };
    }

    /**
     * Helper function used to build the string representation of a `WITH` clause,
     * it constructs the CTE definitions list and generates the `RECURSIVE`
     * keyword when required.
     *
     * @param array $parts List of CTEs to be transformed to string
     * @param uim.cake.databases.Query $query The query that is being compiled
     * @param uim.cake.databases.ValueBinder aBinder Value binder used to generate parameter placeholder
     */
    protected string _buildWithPart(array $parts, Query $query, ValueBinder aBinder) {
        $recursive = false;
        $expressions = null;
        foreach ($parts as $cte) {
            $recursive = $recursive || $cte.isRecursive();
            $expressions[] = $cte.sql($binder);
        }

        $recursive = $recursive ? "RECURSIVE " : "";

        return sprintf("WITH %s%s ", $recursive, implode(", ", $expressions));
    }

    /**
     * Helper function used to build the string representation of a SELECT clause,
     * it constructs the field list taking care of aliasing and
     * converting expression objects to string. This function also constructs the
     * DISTINCT clause for the query.
     *
     * @param array $parts list of fields to be transformed to string
     * @param uim.cake.databases.Query $query The query that is being compiled
     * @param uim.cake.databases.ValueBinder aBinder Value binder used to generate parameter placeholder
     */
    protected string _buildSelectPart(array $parts, Query $query, ValueBinder aBinder) {
        $select = "SELECT%s %s%s";
        if (_orderedUnion && $query.clause("union")) {
            $select = "(SELECT%s %s%s";
        }
        $distinct = $query.clause("distinct");
        $modifiers = _buildModifierPart($query.clause("modifier"), $query, $binder);

        $driver = $query.getConnection().getDriver();
        $quoteIdentifiers = $driver.isAutoQuotingEnabled() || _quotedSelectAliases;
        $normalized = null;
        $parts = _stringifyExpressions($parts, $binder);
        foreach ($parts as $k: $p) {
            if (!is_numeric($k)) {
                $p = $p ~ " AS ";
                if ($quoteIdentifiers) {
                    $p ~= $driver.quoteIdentifier($k);
                } else {
                    $p ~= $k;
                }
            }
            $normalized[] = $p;
        }

        if ($distinct == true) {
            $distinct = "DISTINCT ";
        }

        if (is_array($distinct)) {
            $distinct = _stringifyExpressions($distinct, $binder);
            $distinct = sprintf("DISTINCT ON (%s) ", implode(", ", $distinct));
        }

        return sprintf($select, $modifiers, $distinct, implode(", ", $normalized));
    }

    /**
     * Helper function used to build the string representation of a FROM clause,
     * it constructs the tables list taking care of aliasing and
     * converting expression objects to string.
     *
     * @param array $parts list of tables to be transformed to string
     * @param uim.cake.databases.Query $query The query that is being compiled
     * @param uim.cake.databases.ValueBinder aBinder Value binder used to generate parameter placeholder
     */
    protected string _buildFromPart(array $parts, Query $query, ValueBinder aBinder) {
        $select = " FROM %s";
        $normalized = null;
        $parts = _stringifyExpressions($parts, $binder);
        foreach ($parts as $k: $p) {
            if (!is_numeric($k)) {
                $p = $p ~ " " ~ $k;
            }
            $normalized[] = $p;
        }

        return sprintf($select, implode(", ", $normalized));
    }

    /**
     * Helper function used to build the string representation of multiple JOIN clauses,
     * it constructs the joins list taking care of aliasing and converting
     * expression objects to string in both the table to be joined and the conditions
     * to be used.
     *
     * @param array $parts list of joins to be transformed to string
     * @param uim.cake.databases.Query $query The query that is being compiled
     * @param uim.cake.databases.ValueBinder aBinder Value binder used to generate parameter placeholder
     */
    protected string _buildJoinPart(array $parts, Query $query, ValueBinder aBinder) {
        $joins = "";
        foreach ($parts as $join) {
            if (!isset($join["table"])) {
                throw new DatabaseException(sprintf(
                    "Could not compile join clause for alias `%s`. No table was specified~ " ~
                    "Use the `table` key to define a table.",
                    $join["alias"]
                ));
            }
            if ($join["table"] instanceof IExpression) {
                $join["table"] = "(" ~ $join["table"].sql($binder) ~ ")";
            }

            $joins ~= sprintf(" %s JOIN %s %s", $join["type"], $join["table"], $join["alias"]);

            $condition = "";
            if (isset($join["conditions"]) && $join["conditions"] instanceof IExpression) {
                $condition = $join["conditions"].sql($binder);
            }
            if ($condition == "") {
                $joins ~= " ON 1 = 1";
            } else {
                $joins ~= " ON {$condition}";
            }
        }

        return $joins;
    }

    /**
     * Helper function to build the string representation of a window clause.
     *
     * @param array $parts List of windows to be transformed to string
     * @param uim.cake.databases.Query $query The query that is being compiled
     * @param uim.cake.databases.ValueBinder aBinder Value binder used to generate parameter placeholder
     */
    protected string _buildWindowPart(array $parts, Query $query, ValueBinder aBinder) {
        $windows = null;
        foreach ($parts as $window) {
            $windows[] = $window["name"].sql($binder) ~ " AS (" ~ $window["window"].sql($binder) ~ ")";
        }

        return " WINDOW " ~ implode(", ", $windows);
    }

    /**
     * Helper function to generate SQL for SET expressions.
     *
     * @param array $parts List of keys & values to set.
     * @param uim.cake.databases.Query $query The query that is being compiled
     * @param uim.cake.databases.ValueBinder aBinder Value binder used to generate parameter placeholder
     */
    protected string _buildSetPart(array $parts, Query $query, ValueBinder aBinder) {
        $set = null;
        foreach ($parts as $part) {
            if ($part instanceof IExpression) {
                $part = $part.sql($binder);
            }
            if ($part[0] == "(") {
                $part = substr($part, 1, -1);
            }
            $set[] = $part;
        }

        return " SET " ~ implode("", $set);
    }

    /**
     * Builds the SQL string for all the UNION clauses in this query, when dealing
     * with query objects it will also transform them using their configured SQL
     * dialect.
     *
     * @param array $parts list of queries to be operated with UNION
     * @param uim.cake.databases.Query $query The query that is being compiled
     * @param uim.cake.databases.ValueBinder aBinder Value binder used to generate parameter placeholder
     */
    protected string _buildUnionPart(array $parts, Query $query, ValueBinder aBinder) {
        $parts = array_map(function ($p) use ($binder) {
            $p["query"] = $p["query"].sql($binder);
            $p["query"] = $p["query"][0] == "(" ? trim($p["query"], "()") : $p["query"];
            $prefix = $p["all"] ? "ALL " : "";
            if (_orderedUnion) {
                return "{$prefix}({$p["query"]})";
            }

            return $prefix . $p["query"];
        }, $parts);

        if (_orderedUnion) {
            return sprintf(")\nUNION %s", implode("\nUNION ", $parts));
        }

        return sprintf("\nUNION %s", implode("\nUNION ", $parts));
    }

    /**
     * Builds the SQL fragment for INSERT INTO.
     *
     * @param array $parts The insert parts.
     * @param uim.cake.databases.Query $query The query that is being compiled
     * @param uim.cake.databases.ValueBinder aBinder Value binder used to generate parameter placeholder
     * @return string SQL fragment.
     */
    protected string _buildInsertPart(array $parts, Query $query, ValueBinder aBinder) {
        if (!isset($parts[0])) {
            throw new DatabaseException(
                "Could not compile insert query. No table was specified~ " ~
                "Use `into()` to define a table."
            );
        }
        $table = $parts[0];
        $columns = _stringifyExpressions($parts[1], $binder);
        $modifiers = _buildModifierPart($query.clause("modifier"), $query, $binder);

        return sprintf("INSERT%s INTO %s (%s)", $modifiers, $table, implode(", ", $columns));
    }

    /**
     * Builds the SQL fragment for INSERT INTO.
     *
     * @param array $parts The values parts.
     * @param uim.cake.databases.Query $query The query that is being compiled
     * @param uim.cake.databases.ValueBinder aBinder Value binder used to generate parameter placeholder
     * @return string SQL fragment.
     */
    protected string _buildValuesPart(array $parts, Query $query, ValueBinder aBinder) {
        return implode("", _stringifyExpressions($parts, $binder));
    }

    /**
     * Builds the SQL fragment for UPDATE.
     *
     * @param array $parts The update parts.
     * @param uim.cake.databases.Query $query The query that is being compiled
     * @param uim.cake.databases.ValueBinder aBinder Value binder used to generate parameter placeholder
     * @return string SQL fragment.
     */
    protected string _buildUpdatePart(array $parts, Query $query, ValueBinder aBinder) {
        $table = _stringifyExpressions($parts, $binder);
        $modifiers = _buildModifierPart($query.clause("modifier"), $query, $binder);

        return sprintf("UPDATE%s %s", $modifiers, implode(",", $table));
    }

    /**
     * Builds the SQL modifier fragment
     *
     * @param array $parts The query modifier parts
     * @param uim.cake.databases.Query $query The query that is being compiled
     * @param uim.cake.databases.ValueBinder aBinder Value binder used to generate parameter placeholder
     * @return string SQL fragment.
     */
    protected string _buildModifierPart(array $parts, Query $query, ValueBinder aBinder) {
        if ($parts == null) {
            return "";
        }

        return " " ~ implode(" ", _stringifyExpressions($parts, $binder, false));
    }

    /**
     * Helper function used to covert IExpression objects inside an array
     * into their string representation.
     *
     * @param array $expressions list of strings and IExpression objects
     * @param uim.cake.databases.ValueBinder aBinder Value binder used to generate parameter placeholder
     * @param bool $wrap Whether to wrap each expression object with parenthesis
     */
    protected array _stringifyExpressions(array $expressions, ValueBinder aBinder, bool $wrap = true) {
        $result = null;
        foreach ($expressions as $k: $expression) {
            if ($expression instanceof IExpression) {
                $value = $expression.sql($binder);
                $expression = $wrap ? "(" ~ $value ~ ")" : $value;
            }
            $result[$k] = $expression;
        }

        return $result;
    }
}
