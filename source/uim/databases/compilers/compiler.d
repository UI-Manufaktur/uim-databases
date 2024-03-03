/*********************************************************************************************************
	Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        
	License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  
	Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      
**********************************************************************************************************/
module uim.databases.compilers.compiler;

@safe:
import uim.databases;

// Responsible for compiling a Query object into its SQL representation
class QueryCompiler {
    /**
     * List of string templates that will be used for compiling the SQL for
     * this query. There are some clauses that can be built as just as the
     * direct concatenation of the internal parts, those are listed here.
     *
     * @var array<string, string>
     */
    protected STRINGAA _templates = [
        "delete":"DELETE",
        "where":" WHERE %s",
        "group":" GROUP BY %s ",
        "having":" HAVING %s ",
        "order":" %s",
        "limit":" LIMIT %s",
        "offset":" OFFSET %s",
        "epilog":" %s",
    ];

    // The list of query clauses to traverse for generating a SELECT statement
    protected string[] _selectParts = [
        "with", "select", "from", "join", "where", "group", "having", "window", "order",
        "limit", "offset", "union", "epilog",
    ];

    /**
     * The list of query clauses to traverse for generating an UPDATE statement
     *
     * @var array<string>
     * @deprecated Not used.
     */
    protected string[] _updateParts = ["with", "update", "set", "where", "epilog"];

    // The list of query clauses to traverse for generating a DELETE statement
    protected string[] _deleteParts = ["with", "delete", "modifier", "from", "where", "epilog"];

    // The list of query clauses to traverse for generating an INSERT statement
    protected string[] _insertParts = ["with", "insert", "values", "epilog"];

    // Indicate whether this query dialect supports ordered unions.
    protected bool _orderedUnion = true;

    /**
     * Indicate whether aliases in SELECT clause need to be always quoted.
     *
     * @var bool
     */
    protected _quotedSelectAliases = false;

    /**
     * Returns the SQL representation of the provided query after generating
     * the placeholders for the bound values using the provided generator
     *
     * @param uim.databases\Query myQuery The query that is being compiled
     * @param uim.databases\ValueBinder aValueBinder Value binder used to generate parameter placeholders
     */
    string compile(Query myQuery, ValueBinder aValueBinder) {
        mySql = "";
        myType = myQuery.type();
        myQuery.traverseParts(
            _sqlCompiler(mySql, myQuery, $binder),
            this.{"_{myType}Parts"}
        );

        // Propagate bound parameters from sub-queries if the
        // placeholders can be found in the SQL statement.
        if (myQuery.getValueBinder() != $binder) {
            foreach (myQuery.getValueBinder().bindings() as $binding) {
                $placeholder = ":"~ $binding["placeholder"];
                if (preg_match("/"~ $placeholder . "(?:\W|$)/", mySql) > 0) {
                    $binder.bind($placeholder, $binding["value"], $binding["type"]);
                }
            }
        }

        return mySql;
    }

    /**
     * Returns a callable object that can be used to compile a SQL string representation
     * of this query.
     *
     * @param string mySql initial sql string to append to
     * @param uim.databases\Query myQuery The query that is being compiled
     * @param uim.databases\ValueBinder aValueBinder Value binder used to generate parameter placeholder
     * @return \Closure
     */
    protected Closure _sqlCompiler(string &mySql, Query myQuery, ValueBinder aValueBinder) {
        return function ($part, $partName) use (&mySql, myQuery, $binder) {
            if (
                $part is null ||
                (is_array($part) && empty($part)) ||
                ($part instanceof Countable && count($part) == 0)
            ) {
                return;
            }

            if ($part instanceof IDBAExpression) {
                $part = [$part.sql($binder)];
            }
            if (isset(_templates[$partName])) {
                $part = _stringifyExpressions((array)$part, $binder);
                mySql ~= _templates[$partName].format(implode(", ", $part));

                return;
            }

            mySql ~= this.{"_build"~ $partName . "Part"}($part, myQuery, $binder);
        };
    }

    /**
     * Helper function used to build the string representation of a `WITH` clause,
     * it constructs the CTE definitions list and generates the `RECURSIVE`
     * keyword when required.
     *
     * @param array someParts List of CTEs to be transformed to string
     * @param uim.databases\Query myQuery The query that is being compiled
     * @param uim.databases\ValueBinder aValueBinder Value binder used to generate parameter placeholder
     * @return string
     */
    protected string _buildWithPart(array someParts, Query myQuery, ValueBinder aValueBinder) {
        $recursive = false;
        $expressions = [];
        foreach (someParts as cte) {
            $recursive = $recursive || cte.isRecursive();
            $expressions[] = cte.sql($binder);
        }

        $recursive = $recursive ? "RECURSIVE " : "";

        return "WITH %s%s ".format($recursive, implode(", ", $expressions));
    }

    /**
     * Helper function used to build the string representation of a SELECT clause,
     * it constructs the field list taking care of aliasing and
     * converting expression objects to string. This function also constructs the
     * DISTINCT clause for the query.
     *
     * @param array someParts list of fields to be transformed to string
     * @param uim.databases\Query myQuery The query that is being compiled
     * @param uim.databases\ValueBinder aValueBinder Value binder used to generate parameter placeholder
     * @return string
     */
    protected string _buildSelectPart(array someParts, Query myQuery, ValueBinder aValueBinder) {
        $select = "SELECT%s %s%s";
        if (_orderedUnion && myQuery.clause("union")) {
            $select = "(SELECT%s %s%s";
        }
        $distinct = myQuery.clause("distinct");
        myModifiers = _buildModifierPart(myQuery.clause("modifier"), myQuery, $binder);

        myDriver = myQuery.getConnection().getDriver();
        $quoteIdentifiers = myDriver.isAutoQuotingEnabled() || _quotedSelectAliases;
        $normalized = [];
        someParts = _stringifyExpressions(someParts, $binder);
        foreach (someParts as $k: $p) {
            if (!is_numeric($k)) {
                $p = $p . " AS ";
                if ($quoteIdentifiers) {
                    $p ~= myDriver.quoteIdentifier($k);
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
            $distinct = "DISTINCT ON (%s) ".format(implode(", ", $distinct));
        }

        return $select, myModifiers, $distinct.format(implode(", ", $normalized));
    }

    /**
     * Helper function used to build the string representation of a FROM clause,
     * it constructs the tables list taking care of aliasing and
     * converting expression objects to string.
     *
     * @param array someParts list of tables to be transformed to string
     * @param uim.databases\Query myQuery The query that is being compiled
     * @param uim.databases\ValueBinder aValueBinder Value binder used to generate parameter placeholder
     * @return string
     */
    protected string _buildFromPart(array someParts, Query myQuery, ValueBinder aValueBinder) {
        $select = " FROM %s";
        $normalized = [];
        someParts = _stringifyExpressions(someParts, $binder);
        foreach (someParts as $k: $p) {
            if (!is_numeric($k)) {
                $p = $p . " "~ $k;
            }
            $normalized[] = $p;
        }

        return $select.format(implode(", ", $normalized));
    }

    /**
     * Helper function used to build the string representation of multiple JOIN clauses,
     * it constructs the joins list taking care of aliasing and converting
     * expression objects to string in both the table to be joined and the conditions
     * to be used.
     *
     * @param array someParts list of joins to be transformed to string
     * @param uim.databases\Query myQuery The query that is being compiled
     * @param uim.databases\ValueBinder aValueBinder Value binder used to generate parameter placeholder
     * @return string
     */
    protected string _buildJoinPart(array someParts, Query myQuery, ValueBinder aValueBinder) {
        $joins = "";
        foreach (someParts as $join) {
            if (!$join.isSet("table")) {
                throw new DatabaseException(
                    "Could not compile join clause for alias `%s`. No table was specified. "~
                    "Use the `table` key to define a table.".format(
                    $join["alias"]
                ));
            }
            if ($join["table"] instanceof IDBAExpression) {
                $join["table"] = "("~ $join["table"].sql($binder) . ")";
            }

            $joins ~= " %s JOIN %s %s".format($join["type"], $join["table"], $join["alias"]);

            condition = "";
            if (isset($join["conditions"]) && $join["conditions"] instanceof IDBAExpression) {
                condition = $join["conditions"].sql($binder);
            }
            if (condition == "") {
                $joins ~= " ON 1 = 1";
            } else {
                $joins ~= " ON {condition}";
            }
        }

        return $joins;
    }

    /**
     * Helper function to build the string representation of a window clause.
     *
     * @param array someParts List of windows to be transformed to string
     * @param uim.databases\Query myQuery The query that is being compiled
     * @param uim.databases\ValueBinder aValueBinder Value binder used to generate parameter placeholder
     * @return string
     */
    protected string _buildWindowPart(array someParts, Query myQuery, ValueBinder aValueBinder) {
        $windows = [];
        foreach (someParts as $window) {
            $windows[] = $window["name"].sql($binder) . " AS ("~ $window["window"].sql($binder) . ")";
        }

        return " WINDOW "~ implode(", ", $windows);
    }

    /**
     * Helper function to generate SQL for SET expressions.
     *
     * @param array someParts List of keys & values to set.
     * @param uim.databases\Query myQuery The query that is being compiled
     * @param uim.databases\ValueBinder aValueBinder Value binder used to generate parameter placeholder
     * @return string
     */
    protected string _buildSetPart(array someParts, Query myQuery, ValueBinder aValueBinder) {
        $set = [];
        foreach (someParts as $part) {
            if ($part instanceof IDBAExpression) {
                $part = $part.sql($binder);
            }
            if ($part[0] == "(") {
                $part = subString($part, 1, -1);
            }
            $set[] = $part;
        }

        return " SET "~ implode("", $set);
    }

    /**
     * Builds the SQL string for all the UNION clauses in this query, when dealing
     * with query objects it will also transform them using their configured SQL
     * dialect.
     *
     * @param array someParts list of queries to be operated with UNION
     * @param uim.databases\Query myQuery The query that is being compiled
     * @param uim.databases\ValueBinder aValueBinder Value binder used to generate parameter placeholder
     * @return string
     */
    protected string _buildUnionPart(array someParts, Query myQuery, ValueBinder aValueBinder) {
        someParts = array_map(function ($p) use ($binder) {
            $p["query"] = $p["query"].sql($binder);
            $p["query"] = $p["query"][0] == "(" ? trim($p["query"], "()") : $p["query"];
            $prefix = $p["all"] ? "ALL " : "";
            if (_orderedUnion) {
                return "{$prefix}({$p["query"]})";
            }

            return $prefix . $p["query"];
        }, someParts);

        if (_orderedUnion) {
            return ")\nUNION %s".format(implode("\nUNION ", someParts));
        }

        return "\nUNION %s".format(implode("\nUNION ", someParts));
    }

    // Builds the SQL fragment for INSERT INTO.
    // array someParts The insert parts.
    //  uim.databases.Query myQuery The query that is being compiled
    // $binder Value binder used to generate parameter placeholder
    // SQL fragment.
    protected string _buildInsertPart(array someParts, DDBAQuery myQuery, DDBAValueBinder aValueBinder) {
        if (0 !in someParts[0]) {
            throw new DatabaseException(
                "Could not compile insert query. No table was specified. "~
                "Use `into()` to define a table."
            );
        }
        auto myTable = someParts[0];
        auto myColumns = _stringifyExpressions(someParts[1], $binder);
        auto mymodifiers = _buildModifierPart(myQuery.clause("modifier"), myQuery, $binder);

        return "INSERT%s INTO %s (%s)".format(myModifiers, myTable, implode(", ", myColumns));
    }

    /**
     * Builds the SQL fragment for INSERT INTO.
     *
     * @param array someParts The values parts.
     * @param uim.databases\Query myQuery The query that is being compiled
     * @param uim.databases\ValueBinder aValueBinder Value binder used to generate parameter placeholder
     * @return SQL fragment.
     */
    protected string _buildValuesPart(array someParts, Query myQuery, ValueBinder aValueBinder) {
        return implode("", _stringifyExpressions(someParts, $binder));
    }

    /**
     * Builds the SQL fragment for UPDATE.
     *
     * @param array someParts The update parts.
     * @param uim.databases\Query myQuery The query that is being compiled
     * @param uim.databases\ValueBinder aValueBinder Value binder used to generate parameter placeholder
     * @return SQL fragment.
     */
    protected string _buildUpdatePart(array someParts, Query aQuery, ValueBinder aBinder) {
        auto myTable = _stringifyExpressions(someParts, $binder);
        myModifiers = _buildModifierPart(myQuery.clause("modifier"), aQuery, aBinder);

        return "UPDATE%s %s".format(myModifiers, myTable.joined(","));
    }

    /**
     * Builds the SQL modifier fragment
     *
     * @param array someParts The query modifier parts
     * @param uim.databases\Query myQuery The query that is being compiled
     * @param uim.databases\ValueBinder aValueBinder Value binder used to generate parameter placeholder
     * @return SQL fragment.
     */
    protected string _buildModifierPart(array someParts, Query aQuery, ValueBinder aBinder) {
      if (someParts) {
        return " "~ implode(" ", _stringifyExpressions(someParts, aBinder, false));
      }
      return "";
    }

    /**
     * Helper function used to covert IDBAExpression objects inside an array
     * into their string representation.
     *
     * @param array $expressions list of strings and IDBAExpression objects
     * @param uim.databases\ValueBinder aValueBinder Value binder used to generate parameter placeholder
     * @param $wrap Whether to wrap each expression object with parenthesis
     * @return array
     */
    protected array _stringifyExpressions(IDBAExpression[] someExpressions, ValueBinder aBinder, bool shouldWrap = true) {
      auto myResult = [];
      foreach (key, anExpression; someExpressions) {
          if (cast(IDBAExpression)anExpression) {
            auto myValue = anExpression.sql(aBinder);
            anExpression = shouldWrap ? "("~ myValue . ")" : myValue;
          }
          myResult[key] = anExpression;
      }

      return myResult;
    }
}
