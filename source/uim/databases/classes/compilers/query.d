module uim.databases.classes.compilers.query;

import uim.databases;

@safe:

/**
 * Responsible for compiling a Query object into its SQL representation
 *
 * @internal
 */
class QueryCompiler {
    /**
     * List of sprintf templates that will be used for compiling the SQL for
     * this query. There are some clauses that can be built as just as the
     * direct concatenation of the internal parts, those are listed here.
     */
    protected STRINGAA _templatesForSQLCompiling = [
        "delete": "DELETE",
        "where": " WHERE %s",
        "group": " GROUP BY %s ",
        "having": " HAVING %s ",
        "order": " %s",
        "limit": " LIMIT %s",
        "offset": " OFFSET %s",
        "epilog": " %s",
        "comment": "/* %s */ ",
    ];

    // The list of query clauses to traverse for generating a SELECT statement
    protected string[] _selectParts = [
        "comment", "with", "select", "from", "join", "where", "group", "having", "window", "order",
        "limit", "offset", "union", "epilog",
    ];

    // The list of query clauses to traverse for generating an UPDATE statement
    protected string[] _updateParts = ["comment", "with", "update", "set", "where", "epilog"];

    // The list of query clauses to traverse for generating a DELETE statement
    protected string[] _deleteParts = ["comment", "with", "delete", "modifier", "from", "where", "epilog"];

    // The list of query clauses to traverse for generating an INSERT statement
    protected string[] _insertParts = ["comment", "with", "insert", "values", "epilog"];

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
     * Params:
     * \UIM\Database\Query compiledQuery The query that is being compiled
     * @param \UIM\Database\ValueBinder aBinder Value binder used to generate parameter placeholders
     */
    string compile(Query compiledQuery, ValueBinder aBinder) {
        string result = "";
        auto queryType = compiledQuery.type();
        compiledQuery.traverseParts(
           _sqlCompiler(result, compiledQuery, aBinder),
            this.{"_{queryType}Parts"}
        );

        // Propagate bound parameters from sub-queries if the
        // placeholders can be found in the SQL statement.
        if (compiledQuery.getValueBinder() != aBinder) {
            compiledQuery.getValueBinder().bindings().each!((binding) {
                string placeholder = ":" ~ binding.get("placeholder", null);
                if (preg_match("/" ~ placeholder ~ "(?:\W|$)/", result) > 0) {
                    aBinder.bind(placeholder, binding.get("value", null), binding.get("type", null));
                }
            });
        }
        return result;
    }
    
    /**
     * Returns a closure that can be used to compile a SQL string representation
     * of this query.
     * Params:
     * string asql initial sql string to append to
     * @param \UIM\Database\Query compiledQuery The query that is being compiled
     * @param \UIM\Database\ValueBinder aBinder Value binder used to generate parameter placeholder
     */
    protected Closure _sqlCompiler(string &sql, Query compiledQuery, ValueBinder aBinder) {
        return void (part, partName) use (&sql, compiledQuery, aBinder) {
            if (
                part.isNull ||
                (isArray(part) && empty(part)) ||
                (cast(Countable)part && count(part) == 0)
            ) {
                return;
            }
            if (cast(IExpression)part) {
                part = [part.sql(aBinder)];
            }
            if (isSet(_templates[partName])) {
                part = _stringifyExpressions((array)part, aBinder);
                sql ~= _templates[partName].format(join(", ", part));

                return;
            }
            sql ~= this.{"_build" ~ partName ~ "Part"}(part, compiledQuery, aBinder);
        };
    }
    
    /**
     * Helper auto used to build the string representation of a `WITH` clause,
     * it constructs the CTE definitions list and generates the `RECURSIVE`
     * keyword when required.
     * Params:
     * array<\UIM\Database\Expression\CommonTableExpression> someParts List of CTEs to be transformed to string
     * @param \UIM\Database\Query compiledQuery The query that is being compiled
     * @param \UIM\Database\ValueBinder aBinder Value binder used to generate parameter placeholder
     */
    protected string _buildWithPart(array someParts, Query compiledQuery, ValueBinder aBinder) {
        bool isRecursive = false;
        someExpressions = [];
        someParts.each!((cte) {
            isRecursive = isRecursive || cte.isRecursive();
            someExpressions ~= cte.sql(aBinder);
        });
        string recursive = isRecursive ? "RECURSIVE " : "";

        return "WITH %s%s ".format(recursive, join(", ", someExpressions));
    }
    
    /**
     * Helper auto used to build the string representation of a SELECT clause,
     * it constructs the field list taking care of aliasing and
     * converting expression objects to string. This auto also constructs the
     * DISTINCT clause for the query.
     * Params:
     * array someParts list of fields to be transformed to string
     * @param \UIM\Database\Query compiledQuery The query that is being compiled
     * @param \UIM\Database\ValueBinder aBinder Value binder used to generate parameter placeholder
     */
    protected string _buildSelectPart(array someParts, Query compiledQuery, ValueBinder aBinder) {
        auto select = "SELECT%s %s%s";
        if (_orderedUnion && compiledQuery.clause("union")) {
            select = "(SELECT%s %s%s";
        }
        auto  distinct = compiledQuery.clause("distinct");
        someModifiers = _buildModifierPart(compiledQuery.clause("modifier"), compiledQuery, aBinder);

        auto driver = compiledQuery.getConnection().getDriver(compiledQuery.getConnectionRole());
        auto  quoteIdentifiers = driver.isAutoQuotingEnabled() || _quotedSelectAliases;
        auto normalized = [];
        auto someParts = _stringifyExpressions(someParts, aBinder);
        foreach (myKey: p; someParts ) {
            if (!isNumeric(myKey)) {
                p = p ~ " AS ";
                p ~=  quoteIdentifiers
                    ? driver.quoteIdentifier(myKey)
                    : myKey;
            }
            normalized ~= p;
        }

        if ( distinct == true) {
             distinct = "DISTINCT ";
        }
        if (isArray( distinct)) {
             distinct = _stringifyExpressions( distinct, aBinder);
             distinct = "DISTINCT ON (%s) ".format(join(", ",  distinct));
        }
        return select.format(someModifiers,  distinct, join(", ", normalized));
    }
    
    /**
     * Helper auto used to build the string representation of a FROM clause,
     * it constructs the tables list taking care of aliasing and
     * converting expression objects to string.
     * Params:
     * array someParts list of tables to be transformed to string
     * @param \UIM\Database\Query compiledQuery The query that is being compiled
     * @param \UIM\Database\ValueBinder aBinder Value binder used to generate parameter placeholder
     */
    protected string _buildFromPart(array someParts, Query compiledQuery, ValueBinder aBinder) {
        string sqlSelect = " FROM %s";
        string[] normalized = [];
        _stringifyExpressions(someParts, aBinder).byKeyValue
            .each!((kv) {
            if (!isNumeric(kv.key)) {
                kv.valuep = kv.value ~ " " ~ kv.key;
            }
            normalized ~= kv.value;
        });
        return sqlSelect.format(normalized.join(", "));
    }
    
    /**
     * Helper auto used to build the string representation of multiple JOIN clauses,
     * it constructs the joins list taking care of aliasing and converting
     * expression objects to string in both the table to be joined and the conditions
     * to be used.
     * Params:
     * array someParts list of joins to be transformed to string
     * @param \UIM\Database\Query compiledQuery The query that is being compiled
     * @param \UIM\Database\ValueBinder aBinder Value binder used to generate parameter placeholder
     */
    protected string _buildJoinPart(array someParts, Query compiledQuery, ValueBinder aBinder) {
        string joinPart = "";
        foreach ($join; someParts) {
            if (!isSet($join["table"])) {
                throw new DatabaseException(
                    "Could not compile join clause for alias `%s`. No table was specified. " ~
                    "Use the `table` key to define a table."
                    .format($join["alias"])
                );
            }
            if (cast(IExpression)$join["table"] ) {
                $join["table"] = "(" ~ $join["table"].sql(aBinder) ~ ")";
            }
            joinPart ~= " %s JOIN %s %s".format($join["type"], $join["table"], $join["alias"]);

            string condition = "";
            if (isSet($join["conditions"]) && cast(IExpression)$join["conditions"] ) {
                condition = $join["conditions"].sql(aBinder);
            }

            joinPart ~= condition.isEmpty ? " ON 1 = 1" : " ON {condition}";
        }
        return joinPart;
    }
    
    /**
     * Helper auto to build the string representation of a window clause.
     * Params:
     * array someParts List of windows to be transformed to string
     * @param \UIM\Database\Query compiledQuery The query that is being compiled
     * @param \UIM\Database\ValueBinder aBinder Value binder used to generate parameter placeholder
     */
    protected string _buildWindowPart(array someParts, Query compiledQuery, ValueBinder aBinder) {
        auto windows = someParts
            .map!(windows => window["name"].sql(aBinder) ~ " AS (" ~ window["window"].sql(aBinder) ~ ")")
            .array;

        return " WINDOW " ~ windows.join(", ");
    }
    
    /**
     * Helper auto to generate SQL for SET expressions.
     * Params:
     * array someParts List of keys & values to set.
     * @param \UIM\Database\Query compiledQuery The query that is being compiled
     * @param \UIM\Database\ValueBinder aBinder Value binder used to generate parameter placeholder
     */
    protected string _buildSetPart(array someParts, Query compiledQuery, ValueBinder valueBinder) {
        string[] set;
        someParts.each!((part) {
            if (cast(IExpression)part ) {
                part = part.sql(valueBinder);
            }
            if (part[0] == "(") {
                part = substr(part, 1, -1);
            }
            set ~= part;
        });
        return " SET " ~ set.join("");
    }
    
    /**
     * Builds the SQL string for all the UNION clauses in this query, when dealing
     * with query objects it will also transform them using their configured SQL
     * dialect.
     * Params:
     * array someParts list of queries to be operated with UNION
     * @param \UIM\Database\Query compiledQuery The query that is being compiled
     * @param \UIM\Database\ValueBinder aBinder Value binder used to generate parameter placeholder
     */
    protected string _buildUnionPart(array someParts, Query compiledQuery, ValueBinder valueBinder) {
        someParts = array_map(function (p) use (valueBinder) {
            p["query"] = p["query"].sql(valueBinder);
            p["query"] = p["query"][0] == "(" ? trim(p["query"], "()"): p["query"];
            prefix = p["all"] ? "ALL " : "";
            if (_orderedUnion) {
                return "{prefix}("~p["query"]~")";
            }
            return prefix ~ p["query"];
        }, someParts);

        return _orderedUnion 
            ? ")\nUNION %s", join("\nUNION ".format(omeParts))
            : "\nUNION %s".format(join("\nUNION ", someParts));
    }
    
    /**
     * Builds the SQL fragment for INSERT INTO.
     * Params:
     * array someParts The insert parts.
     * @param \UIM\Database\Query compiledQuery The query that is being compiled
     * @param \UIM\Database\ValueBinder aBinder Value binder used to generate parameter placeholder
     */
    protected string _buildInsertFromParts(array someParts, Query compiledQuery, ValueBinder valueBinder) {
        if (!isSet(someParts[0])) {
            throw new DatabaseException(
                "Could not compile insert query. No table was specified. " ~
                "Use `into()` to define a table."
            );
        }
        aTable = someParts[0];
        someColumns = _stringifyExpressions(someParts[1], valueBinder);
        someModifiers = _buildModifierPart(compiledQuery.clause("modifier"), compiledQuery, valueBinder);

        return "INSERT%s INTO %s (%s)".format(someModifiers, aTable, join(", ", someColumns));
    }
    
    /**
     * Builds the SQL fragment for INSERT INTO.
     * Params:
     * array someParts The values parts.
     * @param \UIM\Database\Query compiledQuery The query that is being compiled
     * @param \UIM\Database\ValueBinder aBinder Value binder used to generate parameter placeholder
     */
    protected string _buildValuesPart(array someParts, Query compiledQuery, ValueBinder valueBinder) {
        return _stringifyExpressions(someParts, valueBinder).join("");
    }
    
    /**
     * Builds the SQL fragment for UPDATE.
     * Params:
     * array someParts The update parts.
     * @param \UIM\Database\Query compiledQuery The query that is being compiled
     * @param \UIM\Database\ValueBinder aBinder Value binder used to generate parameter placeholder
     */
    protected string _buildUpdateFromParts(array someParts, Query compiledQuery, ValueBinder valueBinder) {
        auto aTable = _stringifyExpressions(someParts, valueBinder);
        auto someModifiers = _buildModifierPart(compiledQuery.clause("modifier"), compiledQuery, valueBinder);

        return sprintf("UPDATE%s %s", someModifiers, join(",", aTable));
    }
    
    /**
     * Builds the SQL modifier fragment
     * Params:
     * array someParts The query modifier parts
     * @param \UIM\Database\Query compiledQuery The query that is being compiled
     * @param \UIM\Database\ValueBinder aBinder Value binder used to generate parameter placeholder
     * returns SQL fragment.
     */
    protected string _buildModifierPart(array someParts, Query compiledQuery, ValueBinder valueBinder) {
        if (someParts == []) {
            return "";
        }
        return " " ~ _stringifyExpressions(someParts, valueBinder, false).join(" ");
    }
    
    /**
     * Helper auto used to covert IExpression objects inside an array
     * into their string representation.
     * Params:
     * array someExpressions list of strings and IExpression objects
     * @param \UIM\Database\ValueBinder aBinder Value binder used to generate parameter placeholder
     * @param bool  wrap Whether to wrap each expression object with parenthesis
     */
    protected array _stringifyExpressions(array someExpressions, ValueBinder valueBinder, bool shouldWrap = true) {
        STRINGAA results;

        foreach (myKey: expression; someExpressions) {
            string sqlExpression;
            if (cast(IExpression)expression ) {
                aValue = expression.sql(valueBinder);
                sqlExpression = shouldWrap ? "(" ~ aValue ~ ")" : aValue;
            }

            results[myKey] = sqlExpression;
        }
        return results;
    }
}
