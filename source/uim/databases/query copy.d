/*********************************************************************************************************
	Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        
	License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  
	Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      
**********************************************************************************************************/
module uim.cake.databases;

@safe:
import uim.cake;

use Closure;
use InvalidArgumentException;
use IteratorAggregate;
use RuntimeException;

/**
 * This class represents a Relational database SQL Query. A query can be of
 * different types like select, update, insert and delete. Exposes the methods
 * for dynamically constructing each query part, execute it and transform it
 * to a specific SQL dialect.
 */
class Query : IExpression, IteratorAggregate
{
    use TypeMapTrait;

    /**
     */
    const string JOIN_TYPE_INNER = "INNER";

    /**
     */
    const string JOIN_TYPE_LEFT = "LEFT";

    /**
     */
    const string JOIN_TYPE_RIGHT = "RIGHT";

    /**
     * Connection instance to be used to execute this query.
     *
     * @var DDBConnection
     */
    protected _connection;

    /**
     * Type of this query (select, insert, update, delete).
     */
    protected string _type = "select";

    /**
     * List of SQL parts that will be used to build this query.
     *
     * @var array<string, mixed>
     */
    protected _parts = [
        "delete": true,
        "update": [],
        "set": [],
        "insert": [],
        "values": [],
        "with": [],
        "select": [],
        "distinct": false,
        "modifier": [],
        "from": [],
        "join": [],
        "where": null,
        "group": [],
        "having": null,
        "window": [],
        "order": null,
        "limit": null,
        "offset": null,
        "union": [],
        "epilog": null,
    ];

    /**
     * The list of query clauses to traverse for generating a SELECT statement
     *
     * @var array<string>
     * @deprecated 4.4.3 This property is unused.
     */
    protected _selectParts = [
        "with", "select", "from", "join", "where", "group", "having", "order", "limit",
        "offset", "union", "epilog",
    ];

    /**
     * The list of query clauses to traverse for generating an UPDATE statement
     *
     * @var array<string>
     * @deprecated 4.4.3 This property is unused.
     */
    protected _updateParts = ["with", "update", "set", "where", "epilog"];

    /**
     * The list of query clauses to traverse for generating a DELETE statement
     *
     * @var array<string>
     * @deprecated 4.4.3 This property is unused.
     */
    protected _deleteParts = ["with", "delete", "modifier", "from", "where", "epilog"];

    /**
     * The list of query clauses to traverse for generating an INSERT statement
     *
     * @var array<string>
     * @deprecated 4.4.3 This property is unused.
     */
    protected _insertParts = ["with", "insert", "values", "epilog"];

    /**
     * Indicates whether internal state of this query was changed, this is used to
     * discard internal cached objects such as the transformed query or the reference
     * to the executed statement.
     */
    protected bool _dirty = false;

    /**
     * A list of callback functions to be called to alter each row from resulting
     * statement upon retrieval. Each one of the callback function will receive
     * the row array as first argument.
     *
     * @var array<callable>
     */
    protected _resultDecorators = null;

    /**
     * Statement object resulting from executing this query.
     *
     * @var DDBIStatement|null
     */
    protected _iterator;

    /**
     * The object responsible for generating query placeholders and temporarily store values
     * associated to each of those.
     *
     * @var DDBValueBinder|null
     */
    protected _valueBinder;

    /**
     * Instance of functions builder object used for generating arbitrary SQL functions.
     *
     * @var DDBFunctionsBuilder|null
     */
    protected _functionsBuilder;

    /**
     * Boolean for tracking whether buffered results
     * are enabled.
     */
    protected bool _useBufferedResults = true;

    /**
     * The Type map for fields in the select clause
     *
     * @var DDBTypeMap|null
     */
    protected _selectTypeMap;

    /**
     * Tracking flag to disable casting
     */
    protected bool $typeCastEnabled = true;

    /**
     * Constructor.
     *
     * @param uim.cake.databases.Connection $connection The connection
     * object to be used for transforming and executing this query
     */
    this(Connection $connection) {
        this.setConnection($connection);
    }

    /**
     * Sets the connection instance to be used for executing and transforming this query.
     *
     * @param uim.cake.databases.Connection $connection Connection instance
     * @return this
     */
    function setConnection(Connection $connection) {
        _dirty();
        _connection = $connection;

        return this;
    }

    /**
     * Gets the connection instance to be used for executing and transforming this query.
     *
     * @return uim.cake.databases.Connection
     */
    function getConnection(): Connection
    {
        return _connection;
    }

    /**
     * Compiles the SQL representation of this query and executes it using the
     * configured connection object. Returns the resulting statement object.
     *
     * Executing a query internally executes several steps, the first one is
     * letting the connection transform this object to fit its particular dialect,
     * this might result in generating a different Query object that will be the one
     * to actually be executed. Immediately after, literal values are passed to the
     * connection so they are bound to the query in a safe way. Finally, the resulting
     * statement is decorated with custom objects to execute callbacks for each row
     * retrieved if necessary.
     *
     * Resulting statement is traversable, so it can be used in any loop as you would
     * with an array.
     *
     * This method can be overridden in query subclasses to decorate behavior
     * around query execution.
     *
     * @return uim.cake.databases.IStatement
     */
    function execute(): IStatement
    {
        $statement = _connection.run(this);
        _iterator = _decorateStatement($statement);
        _dirty = false;

        return _iterator;
    }

    /**
     * Executes the SQL of this query and immediately closes the statement before returning the row count of records
     * changed.
     *
     * This method can be used with UPDATE and DELETE queries, but is not recommended for SELECT queries and is not
     * used to count records.
     *
     * ## Example
     *
     * ```
     * $rowCount = $query.update("articles")
     *                 .set(["published"=>true])
     *                 .where(["published"=>false])
     *                 .rowCountAndClose();
     * ```
     *
     * The above example will change the published column to true for all false records, and return the number of
     * records that were updated.
     */
    int rowCountAndClose() {
        $statement = this.execute();
        try {
            return $statement.rowCount();
        } finally {
            $statement.closeCursor();
        }
    }

    /**
     * Returns the SQL representation of this object.
     *
     * This function will compile this query to make it compatible
     * with the SQL dialect that is used by the connection, This process might
     * add, remove or alter any query part or internal expression to make it
     * executable in the target platform.
     *
     * The resulting query may have placeholders that will be replaced with the actual
     * values when the query is executed, hence it is most suitable to use with
     * prepared statements.
     *
     * @param uim.cake.databases.ValueBinder|null $binder Value binder that generates parameter placeholders
     */
    string sql(?ValueBinder aBinder = null) {
        if (!$binder) {
            $binder = this.getValueBinder();
            $binder.resetCount();
        }

        return this.getConnection().compileQuery(this, $binder);
    }

    /**
     * Will iterate over every specified part. Traversing functions can aggregate
     * results using variables in the closure or instance variables. This function
     * is commonly used as a way for traversing all query parts that
     * are going to be used for constructing a query.
     *
     * The callback will receive 2 parameters, the first one is the value of the query
     * part that is being iterated and the second the name of such part.
     *
     * ### Example
     * ```
     * $query.select(["title"]).from("articles").traverse(function ($value, $clause) {
     *     if ($clause == "select") {
     *         var_dump($value);
     *     }
     * });
     * ```
     *
     * @param callable $callback A function or callable to be executed for each part
     * @return this
     */
    O traverse(this O)($callback) {
        foreach (_parts as $name: $part) {
            $callback($part, $name);
        }

        return this;
    }

    /**
     * Will iterate over the provided parts.
     *
     * Traversing functions can aggregate results using variables in the closure
     * or instance variables. This method can be used to traverse a subset of
     * query parts in order to render a SQL query.
     *
     * The callback will receive 2 parameters, the first one is the value of the query
     * part that is being iterated and the second the name of such part.
     *
     * ### Example
     *
     * ```
     * $query.select(["title"]).from("articles").traverse(function ($value, $clause) {
     *     if ($clause == "select") {
     *         var_dump($value);
     *     }
     * }, ["select", "from"]);
     * ```
     *
     * @param callable $visitor A function or callable to be executed for each part
     * @param array<string> $parts The list of query parts to traverse
     * @return this
     */
    function traverseParts(callable $visitor, array $parts) {
        foreach ($parts as $name) {
            $visitor(_parts[$name], $name);
        }

        return this;
    }

    /**
     * Adds a new common table expression (CTE) to the query.
     *
     * ### Examples:
     *
     * Common table expressions can either be passed as preconstructed expression
     * objects:
     *
     * ```
     * $cte = new uim.cake.databases.Expression\CommonTableExpression(
     *     "cte",
     *     $connection
     *         .newQuery()
     *         .select("*")
     *         .from("articles")
     * );
     *
     * $query.with($cte);
     * ```
     *
     * or returned from a closure, which will receive a new common table expression
     * object as the first argument, and a new blank query object as
     * the second argument:
     *
     * ```
     * $query.with(function (
     *     uim.cake.databases.Expression\CommonTableExpression $cte,
     *     uim.cake.databases.Query $query
     *  ) {
     *     $cteQuery = $query
     *         .select("*")
     *         .from("articles");
     *
     *     return $cte
     *         .name("cte")
     *         .query($cteQuery);
     * });
     * ```
     *
     * @param uim.cake.databases.Expression\CommonTableExpression|\Closure $cte The CTE to add.
     * @param bool canOverwrite Whether to reset the list of CTEs.
     * @return this
     */
    function with($cte, bool canOverwrite = false) {
        if (canOverwrite) {
            _parts["with"] = null;
        }

        if ($cte instanceof Closure) {
            $query = this.getConnection().newQuery();
            $cte = $cte(new CommonTableExpression(), $query);
            if (!($cte instanceof CommonTableExpression)) {
                throw new RuntimeException(
                    "You must return a `CommonTableExpression` from a Closure passed to `with()`."
                );
            }
        }

        _parts["with"][] = $cte;
        _dirty();

        return this;
    }

    /**
     * Adds new fields to be returned by a `SELECT` statement when this query is
     * executed. Fields can be passed as an array of strings, array of expression
     * objects, a single expression or a single string.
     *
     * If an array is passed, keys will be used to alias fields using the value as the
     * real field to be aliased. It is possible to alias strings, Expression objects or
     * even other Query objects.
     *
     * If a callable bool is passed, the returning array of the function will
     * be used as the list of fields.
     *
     * By default this function will append any passed argument to the list of fields
     * to be selected, unless the second argument is set to true.
     *
     * ### Examples:
     *
     * ```
     * $query.select(["id", "title"]); // Produces SELECT id, title
     * $query.select(["author": "author_id"]); // Appends author: SELECT id, title, author_id as author
     * $query.select("id", true); // Resets the list: SELECT id
     * $query.select(["total": $countQuery]); // SELECT id, (SELECT ...) AS total
     * $query.select(function ($query) {
     *     return ["article_id", "total": $query.count("*")];
     * })
     * ```
     *
     * By default no fields are selected, if you have an instance of `Cake\orm.Query` and try to append
     * fields you should also call `Cake\orm.Query::enableAutoFields()` to select the default fields
     * from the table.
     *
     * @param uim.cake.databases.IExpression|callable|array|string $fields fields to be added to the list.
     * @param bool canOverwrite whether to reset fields with passed list or not
     * @return this
     */
    function select($fields = null, bool canOverwrite = false) {
        if (!is_string($fields) && is_callable($fields)) {
            $fields = $fields(this);
        }

        if (!is_array($fields)) {
            $fields = [$fields];
        }

        if (canOverwrite) {
            _parts["select"] = $fields;
        } else {
            _parts["select"] = array_merge(_parts["select"], $fields);
        }

        _dirty();
        _type = "select";

        return this;
    }

    /**
     * Adds a `DISTINCT` clause to the query to remove duplicates from the result set.
     * This clause can only be used for select statements.
     *
     * If you wish to filter duplicates based of those rows sharing a particular field
     * or set of fields, you may pass an array of fields to filter on. Beware that
     * this option might not be fully supported in all database systems.
     *
     * ### Examples:
     *
     * ```
     * // Filters products with the same name and city
     * $query.select(["name", "city"]).from("products").distinct();
     *
     * // Filters products in the same city
     * $query.distinct(["city"]);
     * $query.distinct("city");
     *
     * // Filter products with the same name
     * $query.distinct(["name"], true);
     * $query.distinct("name", true);
     * ```
     *
     * @param uim.cake.databases.IExpression|array|string|bool $on Enable/disable distinct class
     * or list of fields to be filtered on
     * @param bool canOverwrite whether to reset fields with passed list or not
     * @return this
     */
    function distinct($on = null, canOverwrite = false) {
        if ($on == null) {
            $on = true;
        } elseif (is_string($on)) {
            $on = [$on];
        }

        if (is_array($on)) {
            $merge = null;
            if (is_array(_parts["distinct"])) {
                $merge = _parts["distinct"];
            }
            $on = canOverwrite ? array_values($on) : array_merge($merge, array_values($on));
        }

        _parts["distinct"] = $on;
        _dirty();

        return this;
    }

    /**
     * Adds a single or multiple `SELECT` modifiers to be used in the `SELECT`.
     *
     * By default this function will append any passed argument to the list of modifiers
     * to be applied, unless the second argument is set to true.
     *
     * ### Example:
     *
     * ```
     * // Ignore cache query in MySQL
     * $query.select(["name", "city"]).from("products").modifier("SQL_NO_CACHE");
     * // It will produce the SQL: SELECT SQL_NO_CACHE name, city FROM products
     *
     * // Or with multiple modifiers
     * $query.select(["name", "city"]).from("products").modifier(["HIGH_PRIORITY", "SQL_NO_CACHE"]);
     * // It will produce the SQL: SELECT HIGH_PRIORITY SQL_NO_CACHE name, city FROM products
     * ```
     *
     * @param uim.cake.databases.IExpression|array|string $modifiers modifiers to be applied to the query
     * @param bool canOverwrite whether to reset order with field list or not
     * @return this
     */
    function modifier($modifiers, canOverwrite = false) {
        _dirty();
        if (canOverwrite) {
            _parts["modifier"] = null;
        }
        if (!is_array($modifiers)) {
            $modifiers = [$modifiers];
        }
        _parts["modifier"] = array_merge(_parts["modifier"], $modifiers);

        return this;
    }

    /**
     * Adds a single or multiple tables to be used in the FROM clause for this query.
     * Tables can be passed as an array of strings, array of expression
     * objects, a single expression or a single string.
     *
     * If an array is passed, keys will be used to alias tables using the value as the
     * real field to be aliased. It is possible to alias strings, IExpression objects or
     * even other Query objects.
     *
     * By default this function will append any passed argument to the list of tables
     * to be selected from, unless the second argument is set to true.
     *
     * This method can be used for select, update and delete statements.
     *
     * ### Examples:
     *
     * ```
     * $query.from(["p": "posts"]); // Produces FROM posts p
     * $query.from("authors"); // Appends authors: FROM posts p, authors
     * $query.from(["products"], true); // Resets the list: FROM products
     * $query.from(["sub": $countQuery]); // FROM (SELECT ...) sub
     * ```
     *
     * @param array|string $tables tables to be added to the list. This argument, can be
     *  passed as an array of strings, array of expression objects, or a single string. See
     *  the examples above for the valid call types.
     * @param bool canOverwrite whether to reset tables with passed list or not
     * @return this
     */
    function from($tables = null, canOverwrite = false) {
        $tables = (array)$tables;

        if (canOverwrite) {
            _parts["from"] = $tables;
        } else {
            _parts["from"] = array_merge(_parts["from"], $tables);
        }

        _dirty();

        return this;
    }

    /**
     * Adds a single or multiple tables to be used as JOIN clauses to this query.
     * Tables can be passed as an array of strings, an array describing the
     * join parts, an array with multiple join descriptions, or a single string.
     *
     * By default this function will append any passed argument to the list of tables
     * to be joined, unless the third argument is set to true.
     *
     * When no join type is specified an `INNER JOIN` is used by default:
     * `$query.join(["authors"])` will produce `INNER JOIN authors ON 1 = 1`
     *
     * It is also possible to alias joins using the array key:
     * `$query.join(["a": "authors"])` will produce `INNER JOIN authors a ON 1 = 1`
     *
     * A join can be fully described and aliased using the array notation:
     *
     * ```
     * $query.join([
     *     "a": [
     *         "table": "authors",
     *         "type": "LEFT",
     *         "conditions": "a.id = b.author_id"
     *     ]
     * ]);
     * // Produces LEFT JOIN authors a ON a.id = b.author_id
     * ```
     *
     * You can even specify multiple joins in an array, including the full description:
     *
     * ```
     * $query.join([
     *     "a": [
     *         "table": "authors",
     *         "type": "LEFT",
     *         "conditions": "a.id = b.author_id"
     *     ],
     *     "p": [
     *         "table": "publishers",
     *         "type": "INNER",
     *         "conditions": "p.id = b.publisher_id AND p.name = "Cake Software Foundation""
     *     ]
     * ]);
     * // LEFT JOIN authors a ON a.id = b.author_id
     * // INNER JOIN publishers p ON p.id = b.publisher_id AND p.name = "Cake Software Foundation"
     * ```
     *
     * ### Using conditions and types
     *
     * Conditions can be expressed, as in the examples above, using a string for comparing
     * columns, or string with already quoted literal values. Additionally it is
     * possible to use conditions expressed in arrays or expression objects.
     *
     * When using arrays for expressing conditions, it is often desirable to convert
     * the literal values to the correct database representation. This is achieved
     * using the second parameter of this function.
     *
     * ```
     * $query.join(["a": [
     *     "table": "articles",
     *     "conditions": [
     *         "a.posted >=": new DateTime("-3 days"),
     *         "a.published": true,
     *         "a.author_id = authors.id"
     *     ]
     * ]], ["a.posted": "datetime", "a.published": "boolean"])
     * ```
     *
     * ### Overwriting joins
     *
     * When creating aliased joins using the array notation, you can override
     * previous join definitions by using the same alias in consequent
     * calls to this function or you can replace all previously defined joins
     * with another list if the third parameter for this bool is set to true.
     *
     * ```
     * $query.join(["alias": "table"]); // joins table with as alias
     * $query.join(["alias": "another_table"]); // joins another_table with as alias
     * $query.join(["something": "different_table"], [], true); // resets joins list
     * ```
     *
     * @param array<string, mixed>|string $tables list of tables to be joined in the query
     * @param array<string, string> $types Associative array of type names used to bind values to query
     * @param bool canOverwrite whether to reset joins with passed list or not
     * @see uim.cake.databases.TypeFactory
     * @return this
     */
    function join($tables, $types = null, canOverwrite = false) {
        if (is_string($tables) || isset($tables["table"])) {
            $tables = [$tables];
        }

        $joins = null;
        $i = count(_parts["join"]);
        foreach ($tables as $alias: $t) {
            if (!is_array($t)) {
                $t = ["table": $t, "conditions": this.newExpr()];
            }

            if (!is_string($t["conditions"]) && is_callable($t["conditions"])) {
                $t["conditions"] = $t["conditions"](this.newExpr(), this);
            }

            if (!($t["conditions"] instanceof IExpression)) {
                $t["conditions"] = this.newExpr().add($t["conditions"], $types);
            }
            $alias = is_string($alias) ? $alias : null;
            $joins[$alias ?: $i++] = $t + ["type": static::JOIN_TYPE_INNER, "alias": $alias];
        }

        if (canOverwrite) {
            _parts["join"] = $joins;
        } else {
            _parts["join"] = array_merge(_parts["join"], $joins);
        }

        _dirty();

        return this;
    }

    /**
     * Remove a join if it has been defined.
     *
     * Useful when you are redefining joins or want to re-order
     * the join clauses.
     *
     * @param string aName The alias/name of the join to remove.
     * @return this
     */
    function removeJoin(string aName) {
        unset(_parts["join"][$name]);
        _dirty();

        return this;
    }

    /**
     * Adds a single `LEFT JOIN` clause to the query.
     *
     * This is a shorthand method for building joins via `join()`.
     *
     * The table name can be passed as a string, or as an array in case it needs to
     * be aliased:
     *
     * ```
     * // LEFT JOIN authors ON authors.id = posts.author_id
     * $query.leftJoin("authors", "authors.id = posts.author_id");
     *
     * // LEFT JOIN authors a ON a.id = posts.author_id
     * $query.leftJoin(["a": "authors"], "a.id = posts.author_id");
     * ```
     *
     * Conditions can be passed as strings, arrays, or expression objects. When
     * using arrays it is possible to combine them with the `$types` parameter
     * in order to define how to convert the values:
     *
     * ```
     * $query.leftJoin(["a": "articles"], [
     *      "a.posted >=": new DateTime("-3 days"),
     *      "a.published": true,
     *      "a.author_id = authors.id"
     * ], ["a.posted": "datetime", "a.published": "boolean"]);
     * ```
     *
     * See `join()` for further details on conditions and types.
     *
     * @param array<string, mixed>|string $table The table to join with
     * @param uim.cake.databases.IExpression|array|string $conditions The conditions
     * to use for joining.
     * @param array $types a list of types associated to the conditions used for converting
     * values to the corresponding database representation.
     * @return this
     */
    function leftJoin($table, $conditions = null, $types = null) {
        this.join(_makeJoin($table, $conditions, static::JOIN_TYPE_LEFT), $types);

        return this;
    }

    /**
     * Adds a single `RIGHT JOIN` clause to the query.
     *
     * This is a shorthand method for building joins via `join()`.
     *
     * The arguments of this method are identical to the `leftJoin()` shorthand, please refer
     * to that methods description for further details.
     *
     * @param array<string, mixed>|string $table The table to join with
     * @param uim.cake.databases.IExpression|array|string $conditions The conditions
     * to use for joining.
     * @param array $types a list of types associated to the conditions used for converting
     * values to the corresponding database representation.
     * @return this
     */
    function rightJoin($table, $conditions = null, $types = null) {
        this.join(_makeJoin($table, $conditions, static::JOIN_TYPE_RIGHT), $types);

        return this;
    }

    /**
     * Adds a single `INNER JOIN` clause to the query.
     *
     * This is a shorthand method for building joins via `join()`.
     *
     * The arguments of this method are identical to the `leftJoin()` shorthand, please refer
     * to that method"s description for further details.
     *
     * @param array<string, mixed>|string $table The table to join with
     * @param uim.cake.databases.IExpression|array|string $conditions The conditions
     * to use for joining.
     * @param array<string, string> $types a list of types associated to the conditions used for converting
     * values to the corresponding database representation.
     * @return this
     */
    function innerJoin($table, $conditions = null, $types = null) {
        this.join(_makeJoin($table, $conditions, static::JOIN_TYPE_INNER), $types);

        return this;
    }

    /**
     * Returns an array that can be passed to the join method describing a single join clause
     *
     * @param array<string, mixed>|string $table The table to join with
     * @param uim.cake.databases.IExpression|array|string $conditions The conditions
     * to use for joining.
     * @param string $type the join type to use
     * @return array
     * @psalm-suppress InvalidReturnType
     */
    protected array _makeJoin($table, $conditions, $type) {
        $alias = $table;

        if (is_array($table)) {
            $alias = key($table);
            $table = current($table);
        }

        /**
         * @psalm-suppress InvalidArrayOffset
         * @psalm-suppress InvalidReturnStatement
         */
        return [
            $alias: [
                "table": $table,
                "conditions": $conditions,
                "type": $type,
            ],
        ];
    }

    /**
     * Adds a condition or set of conditions to be used in the WHERE clause for this
     * query. Conditions can be expressed as an array of fields as keys with
     * comparison operators in it, the values for the array will be used for comparing
     * the field to such literal. Finally, conditions can be expressed as a single
     * string or an array of strings.
     *
     * When using arrays, each entry will be joined to the rest of the conditions using
     * an `AND` operator. Consecutive calls to this function will also join the new
     * conditions specified using the AND operator. Additionally, values can be
     * expressed using expression objects which can include other query objects.
     *
     * Any conditions created with this methods can be used with any `SELECT`, `UPDATE`
     * and `DELETE` type of queries.
     *
     * ### Conditions using operators:
     *
     * ```
     * $query.where([
     *     "posted >=": new DateTime("3 days ago"),
     *     "title LIKE": "Hello W%",
     *     "author_id": 1,
     * ], ["posted": "datetime"]);
     * ```
     *
     * The previous example produces:
     *
     * `WHERE posted >= 2012-01-27 AND title LIKE "Hello W%" AND author_id = 1`
     *
     * Second parameter is used to specify what type is expected for each passed
     * key. Valid types can be used from the mapped with databases.Type class.
     *
     * ### Nesting conditions with conjunctions:
     *
     * ```
     * $query.where([
     *     "author_id !=": 1,
     *     "OR": ["published": true, "posted <": new DateTime("now")],
     *     "NOT": ["title": "Hello"]
     * ], ["published": boolean, "posted": "datetime"]
     * ```
     *
     * The previous example produces:
     *
     * `WHERE author_id = 1 AND (published = 1 OR posted < "2012-02-01") AND NOT (title = "Hello")`
     *
     * You can nest conditions using conjunctions as much as you like. Sometimes, you
     * may want to define 2 different options for the same key, in that case, you can
     * wrap each condition inside a new array:
     *
     * `$query.where(["OR": [["published": false], ["published": true]])`
     *
     * Would result in:
     *
     * `WHERE (published = false) OR (published = true)`
     *
     * Keep in mind that every time you call where() with the third param set to false
     * (default), it will join the passed conditions to the previous stored list using
     * the `AND` operator. Also, using the same array key twice in consecutive calls to
     * this method will not override the previous value.
     *
     * ### Using expressions objects:
     *
     * ```
     * $exp = $query.newExpr().add(["id !=": 100, "author_id" != 1]).tieWith("OR");
     * $query.where(["published": true], ["published": "boolean"]).where($exp);
     * ```
     *
     * The previous example produces:
     *
     * `WHERE (id != 100 OR author_id != 1) AND published = 1`
     *
     * Other Query objects that be used as conditions for any field.
     *
     * ### Adding conditions in multiple steps:
     *
     * You can use callable functions to construct complex expressions, functions
     * receive as first argument a new QueryExpression object and this query instance
     * as second argument. Functions must return an expression object, that will be
     * added the list of conditions for the query using the `AND` operator.
     *
     * ```
     * $query
     *   .where(["title !=": "Hello World"])
     *   .where(function ($exp, $query) {
     *     $or = $exp.or(["id": 1]);
     *     $and = $exp.and(["id >": 2, "id <": 10]);
     *    return $or.add($and);
     *   });
     * ```
     *
     * * The previous example produces:
     *
     * `WHERE title != "Hello World" AND (id = 1 OR (id > 2 AND id < 10))`
     *
     * ### Conditions as strings:
     *
     * ```
     * $query.where(["articles.author_id = authors.id", "modified IS NULL"]);
     * ```
     *
     * The previous example produces:
     *
     * `WHERE articles.author_id = authors.id AND modified IS NULL`
     *
     * Please note that when using the array notation or the expression objects, all
     * *values* will be correctly quoted and transformed to the correspondent database
     * data type automatically for you, thus securing your application from SQL injections.
     * The keys however, are not treated as unsafe input, and should be validated/sanitized.
     *
     * If you use string conditions make sure that your values are correctly quoted.
     * The safest thing you can do is to never use string conditions.
     *
     * @param uim.cake.databases.IExpression|\Closure|array|string|null $conditions The conditions to filter on.
     * @param array<string, string> $types Associative array of type names used to bind values to query
     * @param bool canOverwrite whether to reset conditions with passed list or not
     * @see uim.cake.databases.TypeFactory
     * @see uim.cake.databases.Expression\QueryExpression
     * @return this
     */
    function where($conditions = null, array $types = null, bool canOverwrite = false) {
        if (canOverwrite) {
            _parts["where"] = this.newExpr();
        }
        _conjugate("where", $conditions, "AND", $types);

        return this;
    }

    /**
     * Convenience method that adds a NOT NULL condition to the query
     *
     * @param uim.cake.databases.IExpression|array|string $fields A single field or expressions or a list of them
     *  that should be not null.
     * @return this
     */
    function whereNotNull($fields) {
        if (!is_array($fields)) {
            $fields = [$fields];
        }

        $exp = this.newExpr();

        foreach ($fields as $field) {
            $exp.isNotNull($field);
        }

        return this.where($exp);
    }

    /**
     * Convenience method that adds a IS NULL condition to the query
     *
     * @param uim.cake.databases.IExpression|array|string $fields A single field or expressions or a list of them
     *   that should be null.
     * @return this
     */
    function whereNull($fields) {
        if (!is_array($fields)) {
            $fields = [$fields];
        }

        $exp = this.newExpr();

        foreach ($fields as $field) {
            $exp.isNull($field);
        }

        return this.where($exp);
    }

    /**
     * Adds an IN condition or set of conditions to be used in the WHERE clause for this
     * query.
     *
     * This method does allow empty inputs in contrast to where() if you set
     * "allowEmpty" to true.
     * Be careful about using it without proper sanity checks.
     *
     * Options:
     *
     * - `types` - Associative array of type names used to bind values to query
     * - `allowEmpty` - Allow empty array.
     *
     * @param string $field Field
     * @param array $values Array of values
     * @param array<string, mixed> $options Options
     * @return this
     */
    function whereInList(string $field, array $values, STRINGAA someOptions = null) {
        $options += [
            "types": [],
            "allowEmpty": false,
        ];

        if ($options["allowEmpty"] && !$values) {
            return this.where("1=0");
        }

        return this.where([$field ~ " IN": $values], $options["types"]);
    }

    /**
     * Adds a NOT IN condition or set of conditions to be used in the WHERE clause for this
     * query.
     *
     * This method does allow empty inputs in contrast to where() if you set
     * "allowEmpty" to true.
     * Be careful about using it without proper sanity checks.
     *
     * @param string $field Field
     * @param array $values Array of values
     * @param array<string, mixed> $options Options
     * @return this
     */
    function whereNotInList(string $field, array $values, STRINGAA someOptions = null) {
        $options += [
            "types": [],
            "allowEmpty": false,
        ];

        if ($options["allowEmpty"] && !$values) {
            return this.where([$field ~ " IS NOT": null]);
        }

        return this.where([$field ~ " NOT IN": $values], $options["types"]);
    }

    /**
     * Adds a NOT IN condition or set of conditions to be used in the WHERE clause for this
     * query. This also allows the field to be null with a IS NULL condition since the null
     * value would cause the NOT IN condition to always fail.
     *
     * This method does allow empty inputs in contrast to where() if you set
     * "allowEmpty" to true.
     * Be careful about using it without proper sanity checks.
     *
     * @param string $field Field
     * @param array $values Array of values
     * @param array<string, mixed> $options Options
     * @return this
     */
    function whereNotInListOrNull(string $field, array $values, STRINGAA someOptions = null) {
        $options += [
            "types": [],
            "allowEmpty": false,
        ];

        if ($options["allowEmpty"] && !$values) {
            return this.where([$field ~ " IS NOT": null]);
        }

        return this.where(
            [
                "OR": [$field ~ " NOT IN": $values, $field ~ " IS": null],
            ],
            $options["types"]
        );
    }

    /**
     * Connects any previously defined set of conditions to the provided list
     * using the AND operator. This function accepts the conditions list in the same
     * format as the method `where` does, hence you can use arrays, expression objects
     * callback functions or strings.
     *
     * It is important to notice that when calling this function, any previous set
     * of conditions defined for this query will be treated as a single argument for
     * the AND operator. This function will not only operate the most recently defined
     * condition, but all the conditions as a whole.
     *
     * When using an array for defining conditions, creating constraints form each
     * array entry will use the same logic as with the `where()` function. This means
     * that each array entry will be joined to the other using the AND operator, unless
     * you nest the conditions in the array using other operator.
     *
     * ### Examples:
     *
     * ```
     * $query.where(["title": "Hello World").andWhere(["author_id": 1]);
     * ```
     *
     * Will produce:
     *
     * `WHERE title = "Hello World" AND author_id = 1`
     *
     * ```
     * $query
     *   .where(["OR": ["published": false, "published is NULL"]])
     *   .andWhere(["author_id": 1, "comments_count >": 10])
     * ```
     *
     * Produces:
     *
     * `WHERE (published = 0 OR published IS NULL) AND author_id = 1 AND comments_count > 10`
     *
     * ```
     * $query
     *   .where(["title": "Foo"])
     *   .andWhere(function ($exp, $query) {
     *     return $exp
     *       .or(["author_id": 1])
     *       .add(["author_id": 2]);
     *   });
     * ```
     *
     * Generates the following conditions:
     *
     * `WHERE (title = "Foo") AND (author_id = 1 OR author_id = 2)`
     *
     * @param uim.cake.databases.IExpression|\Closure|array|string $conditions The conditions to add with AND.
     * @param array<string, string> $types Associative array of type names used to bind values to query
     * @see uim.cake.databases.Query::where()
     * @see uim.cake.databases.TypeFactory
     * @return this
     */
    function andWhere($conditions, array $types = null) {
        _conjugate("where", $conditions, "AND", $types);

        return this;
    }

    /**
     * Adds a single or multiple fields to be used in the ORDER clause for this query.
     * Fields can be passed as an array of strings, array of expression
     * objects, a single expression or a single string.
     *
     * If an array is passed, keys will be used as the field itself and the value will
     * represent the order in which such field should be ordered. When called multiple
     * times with the same fields as key, the last order definition will prevail over
     * the others.
     *
     * By default this function will append any passed argument to the list of fields
     * to be selected, unless the second argument is set to true.
     *
     * ### Examples:
     *
     * ```
     * $query.order(["title": "DESC", "author_id": "ASC"]);
     * ```
     *
     * Produces:
     *
     * `ORDER BY title DESC, author_id ASC`
     *
     * ```
     * $query
     *     .order(["title": $query.newExpr("DESC NULLS FIRST")])
     *     .order("author_id");
     * ```
     *
     * Will generate:
     *
     * `ORDER BY title DESC NULLS FIRST, author_id`
     *
     * ```
     * $expression = $query.newExpr().add(["id % 2 = 0"]);
     * $query.order($expression).order(["title": "ASC"]);
     * ```
     *
     * and
     *
     * ```
     * $query.order(function ($exp, $query) {
     *     return [$exp.add(["id % 2 = 0"]), "title": "ASC"];
     * });
     * ```
     *
     * Will both become:
     *
     * `ORDER BY (id %2 = 0), title ASC`
     *
     * Order fields/directions are not sanitized by the query builder.
     * You should use an allowed list of fields/directions when passing
     * in user-supplied data to `order()`.
     *
     * If you need to set complex expressions as order conditions, you
     * should use `orderAsc()` or `orderDesc()`.
     *
     * @param uim.cake.databases.IExpression|\Closure|array|string $fields fields to be added to the list
     * @param bool canOverwrite whether to reset order with field list or not
     * @return this
     */
    function order($fields, canOverwrite = false) {
        if (canOverwrite) {
            _parts["order"] = null;
        }

        if (!$fields) {
            return this;
        }

        if (!_parts["order"]) {
            _parts["order"] = new OrderByExpression();
        }
        _conjugate("order", $fields, "", []);

        return this;
    }

    /**
     * Add an ORDER BY clause with an ASC direction.
     *
     * This method allows you to set complex expressions
     * as order conditions unlike order()
     *
     * Order fields are not suitable for use with user supplied data as they are
     * not sanitized by the query builder.
     *
     * @param uim.cake.databases.IExpression|\Closure|string $field The field to order on.
     * @param bool canOverwrite Whether to reset the order clauses.
     * @return this
     */
    function orderAsc($field, canOverwrite = false) {
        if (canOverwrite) {
            _parts["order"] = null;
        }
        if (!$field) {
            return this;
        }

        if ($field instanceof Closure) {
            $field = $field(this.newExpr(), this);
        }

        if (!_parts["order"]) {
            _parts["order"] = new OrderByExpression();
        }
        _parts["order"].add(new OrderClauseExpression($field, "ASC"));

        return this;
    }

    /**
     * Add an ORDER BY clause with a DESC direction.
     *
     * This method allows you to set complex expressions
     * as order conditions unlike order()
     *
     * Order fields are not suitable for use with user supplied data as they are
     * not sanitized by the query builder.
     *
     * @param uim.cake.databases.IExpression|\Closure|string $field The field to order on.
     * @param bool canOverwrite Whether to reset the order clauses.
     * @return this
     */
    function orderDesc($field, canOverwrite = false) {
        if (canOverwrite) {
            _parts["order"] = null;
        }
        if (!$field) {
            return this;
        }

        if ($field instanceof Closure) {
            $field = $field(this.newExpr(), this);
        }

        if (!_parts["order"]) {
            _parts["order"] = new OrderByExpression();
        }
        _parts["order"].add(new OrderClauseExpression($field, "DESC"));

        return this;
    }

    /**
     * Adds a single or multiple fields to be used in the GROUP BY clause for this query.
     * Fields can be passed as an array of strings, array of expression
     * objects, a single expression or a single string.
     *
     * By default this function will append any passed argument to the list of fields
     * to be grouped, unless the second argument is set to true.
     *
     * ### Examples:
     *
     * ```
     * // Produces GROUP BY id, title
     * $query.group(["id", "title"]);
     *
     * // Produces GROUP BY title
     * $query.group("title");
     * ```
     *
     * Group fields are not suitable for use with user supplied data as they are
     * not sanitized by the query builder.
     *
     * @param uim.cake.databases.IExpression|array|string $fields fields to be added to the list
     * @param bool canOverwrite whether to reset fields with passed list or not
     * @return this
     */
    function group($fields, canOverwrite = false) {
        if (canOverwrite) {
            _parts["group"] = null;
        }

        if (!is_array($fields)) {
            $fields = [$fields];
        }

        _parts["group"] = array_merge(_parts["group"], array_values($fields));
        _dirty();

        return this;
    }

    /**
     * Adds a condition or set of conditions to be used in the `HAVING` clause for this
     * query. This method operates in exactly the same way as the method `where()`
     * does. Please refer to its documentation for an insight on how to using each
     * parameter.
     *
     * Having fields are not suitable for use with user supplied data as they are
     * not sanitized by the query builder.
     *
     * @param uim.cake.databases.IExpression|\Closure|array|string|null $conditions The having conditions.
     * @param array<string, string> $types Associative array of type names used to bind values to query
     * @param bool canOverwrite whether to reset conditions with passed list or not
     * @see uim.cake.databases.Query::where()
     * @return this
     */
    function having($conditions = null, $types = null, canOverwrite = false) {
        if (canOverwrite) {
            _parts["having"] = this.newExpr();
        }
        _conjugate("having", $conditions, "AND", $types);

        return this;
    }

    /**
     * Connects any previously defined set of conditions to the provided list
     * using the AND operator in the HAVING clause. This method operates in exactly
     * the same way as the method `andWhere()` does. Please refer to its
     * documentation for an insight on how to using each parameter.
     *
     * Having fields are not suitable for use with user supplied data as they are
     * not sanitized by the query builder.
     *
     * @param uim.cake.databases.IExpression|\Closure|array|string $conditions The AND conditions for HAVING.
     * @param array<string, string> $types Associative array of type names used to bind values to query
     * @see uim.cake.databases.Query::andWhere()
     * @return this
     */
    function andHaving($conditions, $types = null) {
        _conjugate("having", $conditions, "AND", $types);

        return this;
    }

    /**
     * Adds a named window expression.
     *
     * You are responsible for adding windows in the order your database requires.
     *
     * @param string aName Window name
     * @param uim.cake.databases.Expression\WindowExpression|\Closure $window Window expression
     * @param bool canOverwrite Clear all previous query window expressions
     * @return this
     */
    function window(string aName, $window, bool canOverwrite = false) {
        if (canOverwrite) {
            _parts["window"] = null;
        }

        if ($window instanceof Closure) {
            $window = $window(new WindowExpression(), this);
            if (!($window instanceof WindowExpression)) {
                throw new RuntimeException("You must return a `WindowExpression` from a Closure passed to `window()`.");
            }
        }

        _parts["window"][] = ["name": new IdentifierExpression($name), "window": $window];
        _dirty();

        return this;
    }

    /**
     * Set the page of results you want.
     *
     * This method provides an easier to use interface to set the limit + offset
     * in the record set you want as results. If empty the limit will default to
     * the existing limit clause, and if that too is empty, then `25` will be used.
     *
     * Pages must start at 1.
     *
     * @param int $num The page number you want.
     * @param int|null $limit The number of rows you want in the page. If null
     *  the current limit clause will be used.
     * @return this
     * @throws \InvalidArgumentException If page number < 1.
     */
    function page(int $num, Nullable!int $limit = null) {
        if ($num < 1) {
            throw new InvalidArgumentException("Pages must start at 1.");
        }
        if ($limit != null) {
            this.limit($limit);
        }
        $limit = this.clause("limit");
        if ($limit == null) {
            $limit = 25;
            this.limit($limit);
        }
        $offset = ($num - 1) * $limit;
        if (PHP_INT_MAX <= $offset) {
            $offset = PHP_INT_MAX;
        }
        this.offset((int)$offset);

        return this;
    }

    /**
     * Sets the number of records that should be retrieved from database,
     * accepts an integer or an expression object that evaluates to an integer.
     * In some databases, this operation might not be supported or will require
     * the query to be transformed in order to limit the result set size.
     *
     * ### Examples
     *
     * ```
     * $query.limit(10) // generates LIMIT 10
     * $query.limit($query.newExpr().add(["1 + 1"])); // LIMIT (1 + 1)
     * ```
     *
     * @param uim.cake.databases.IExpression|int|null $limit number of records to be returned
     * @return this
     */
    function limit($limit) {
        _dirty();
        _parts["limit"] = $limit;

        return this;
    }

    /**
     * Sets the number of records that should be skipped from the original result set
     * This is commonly used for paginating large results. Accepts an integer or an
     * expression object that evaluates to an integer.
     *
     * In some databases, this operation might not be supported or will require
     * the query to be transformed in order to limit the result set size.
     *
     * ### Examples
     *
     * ```
     * $query.offset(10) // generates OFFSET 10
     * $query.offset($query.newExpr().add(["1 + 1"])); // OFFSET (1 + 1)
     * ```
     *
     * @param uim.cake.databases.IExpression|int|null $offset number of records to be skipped
     * @return this
     */
    function offset($offset) {
        _dirty();
        _parts["offset"] = $offset;

        return this;
    }

    /**
     * Adds a complete query to be used in conjunction with an UNION operator with
     * this query. This is used to combine the result set of this query with the one
     * that will be returned by the passed query. You can add as many queries as you
     * required by calling multiple times this method with different queries.
     *
     * By default, the UNION operator will remove duplicate rows, if you wish to include
     * every row for all queries, use unionAll().
     *
     * ### Examples
     *
     * ```
     * $union = (new Query($conn)).select(["id", "title"]).from(["a": "articles"]);
     * $query.select(["id", "name"]).from(["d": "things"]).union($union);
     * ```
     *
     * Will produce:
     *
     * `SELECT id, name FROM things d UNION SELECT id, title FROM articles a`
     *
     * @param uim.cake.databases.Query|string $query full SQL query to be used in UNION operator
     * @param bool canOverwrite whether to reset the list of queries to be operated or not
     * @return this
     */
    function union($query, canOverwrite = false) {
        if (canOverwrite) {
            _parts["union"] = null;
        }
        _parts["union"][] = [
            "all": false,
            "query": $query,
        ];
        _dirty();

        return this;
    }

    /**
     * Adds a complete query to be used in conjunction with the UNION ALL operator with
     * this query. This is used to combine the result set of this query with the one
     * that will be returned by the passed query. You can add as many queries as you
     * required by calling multiple times this method with different queries.
     *
     * Unlike UNION, UNION ALL will not remove duplicate rows.
     *
     * ```
     * $union = (new Query($conn)).select(["id", "title"]).from(["a": "articles"]);
     * $query.select(["id", "name"]).from(["d": "things"]).unionAll($union);
     * ```
     *
     * Will produce:
     *
     * `SELECT id, name FROM things d UNION ALL SELECT id, title FROM articles a`
     *
     * @param uim.cake.databases.Query|string $query full SQL query to be used in UNION operator
     * @param bool canOverwrite whether to reset the list of queries to be operated or not
     * @return this
     */
    function unionAll($query, canOverwrite = false) {
        if (canOverwrite) {
            _parts["union"] = null;
        }
        _parts["union"][] = [
            "all": true,
            "query": $query,
        ];
        _dirty();

        return this;
    }

    /**
     * Create an insert query.
     *
     * Note calling this method will reset any data previously set
     * with Query::values().
     *
     * @param array $columns The columns to insert into.
     * @param array<int|string, string> $types A map between columns & their datatypes.
     * @return this
     * @throws \RuntimeException When there are 0 columns.
     */
    function insert(array $columns, array $types = null) {
        if (empty($columns)) {
            throw new RuntimeException("At least 1 column is required to perform an insert.");
        }
        _dirty();
        _type = "insert";
        _parts["insert"][1] = $columns;
        if (!_parts["values"]) {
            _parts["values"] = new ValuesExpression($columns, this.getTypeMap().setTypes($types));
        } else {
            _parts["values"].setColumns($columns);
        }

        return this;
    }

    /**
     * Set the table name for insert queries.
     *
     * @param string $table The table name to insert into.
     * @return this
     */
    function into(string $table) {
        _dirty();
        _type = "insert";
        _parts["insert"][0] = $table;

        return this;
    }

    /**
     * Creates an expression that refers to an identifier. Identifiers are used to refer to field names and allow
     * the SQL compiler to apply quotes or escape the identifier.
     *
     * The value is used as is, and you might be required to use aliases or include the table reference in
     * the identifier. Do not use this method to inject SQL methods or logical statements.
     *
     * ### Example
     *
     * ```
     * $query.newExpr().lte("count", $query.identifier("total"));
     * ```
     *
     * @param string $identifier The identifier for an expression
     * @return uim.cake.databases.IExpression
     */
    function identifier(string $identifier): IExpression
    {
        return new IdentifierExpression($identifier);
    }

    /**
     * Set the values for an insert query.
     *
     * Multi inserts can be performed by calling values() more than one time,
     * or by providing an array of value sets. Additionally $data can be a Query
     * instance to insert data from another SELECT statement.
     *
     * @param uim.cake.databases.Expression\ValuesExpression|uim.cake.databases.Query|array $data The data to insert.
     * @return this
     * @throws uim.cake.databases.exceptions.DatabaseException if you try to set values before declaring columns.
     *   Or if you try to set values on non-insert queries.
     */
    function values($data) {
        if (_type != "insert") {
            throw new DatabaseException(
                "You cannot add values before defining columns to use."
            );
        }
        if (empty(_parts["insert"])) {
            throw new DatabaseException(
                "You cannot add values before defining columns to use."
            );
        }

        _dirty();
        if ($data instanceof ValuesExpression) {
            _parts["values"] = $data;

            return this;
        }

        _parts["values"].add($data);

        return this;
    }

    /**
     * Create an update query.
     *
     * Can be combined with set() and where() methods to create update queries.
     *
     * @param uim.cake.databases.IExpression|string $table The table you want to update.
     * @return this
     */
    function update($table) {
        if (!is_string($table) && !($table instanceof IExpression)) {
            $text = "Table must be of type string or '%s', got '%s'";
            $message = sprintf($text, IExpression::class, gettype($table));
            throw new InvalidArgumentException($message);
        }

        _dirty();
        _type = "update";
        _parts["update"][0] = $table;

        return this;
    }

    /**
     * Set one or many fields to update.
     *
     * ### Examples
     *
     * Passing a string:
     *
     * ```
     * $query.update("articles").set("title", "The Title");
     * ```
     *
     * Passing an array:
     *
     * ```
     * $query.update("articles").set(["title": "The Title"], ["title": "string"]);
     * ```
     *
     * Passing a callable:
     *
     * ```
     * $query.update("articles").set(function ($exp) {
     *   return $exp.eq("title", "The title", "string");
     * });
     * ```
     *
     * @param uim.cake.databases.Expression\QueryExpression|\Closure|array|string aKey The column name or array of keys
     *    + values to set. This can also be a QueryExpression containing a SQL fragment.
     *    It can also be a Closure, that is required to return an expression object.
     * @param mixed $value The value to update $key to. Can be null if $key is an
     *    array or QueryExpression. When $key is an array, this parameter will be
     *    used as $types instead.
     * @param array<string, string>|string $types The column types to treat data as.
     * @return this
     */
    function set(string aKey, $value = null, $types = null) {
        if (empty(_parts["set"])) {
            _parts["set"] = this.newExpr().setConjunction(",");
        }

        if ($key instanceof Closure) {
            $exp = this.newExpr().setConjunction(",");
            _parts["set"].add($key($exp));

            return this;
        }

        if (is_array($key) || $key instanceof IExpression) {
            $types = (array)$value;
            _parts["set"].add($key, $types);

            return this;
        }

        if (!is_string($types)) {
            $types = null;
        }
        _parts["set"].eq($key, $value, $types);

        return this;
    }

    /**
     * Create a delete query.
     *
     * Can be combined with from(), where() and other methods to
     * create delete queries with specific conditions.
     *
     * @param string|null $table The table to use when deleting.
     * @return this
     */
    function delete(Nullable!string $table = null) {
        _dirty();
        _type = "delete";
        if ($table != null) {
            this.from($table);
        }

        return this;
    }

    /**
     * A string or expression that will be appended to the generated query
     *
     * ### Examples:
     * ```
     * $query.select("id").where(["author_id": 1]).epilog("FOR UPDATE");
     * $query
     *  .insert("articles", ["title"])
     *  .values(["author_id": 1])
     *  .epilog("RETURNING id");
     * ```
     *
     * Epliog content is raw SQL and not suitable for use with user supplied data.
     *
     * @param uim.cake.databases.IExpression|string|null $expression The expression to be appended
     * @return this
     */
    function epilog($expression = null) {
        _dirty();
        _parts["epilog"] = $expression;

        return this;
    }

    /**
     * Returns the type of this query (select, insert, update, delete)
     */
    string type() {
        return _type;
    }

    /**
     * Returns a new QueryExpression object. This is a handy function when
     * building complex queries using a fluent interface. You can also override
     * this function in subclasses to use a more specialized QueryExpression class
     * if required.
     *
     * You can optionally pass a single raw SQL string or an array or expressions in
     * any format accepted by uim.cake.databases.Expression\QueryExpression:
     *
     * ```
     * $expression = $query.expr(); // Returns an empty expression object
     * $expression = $query.expr("Table.column = Table2.column"); // Return a raw SQL expression
     * ```
     *
     * @param uim.cake.databases.IExpression|array|string|null $rawExpression A string, array or anything you want wrapped in an expression object
     * @return uim.cake.databases.Expression\QueryExpression
     */
    function newExpr($rawExpression = null): QueryExpression
    {
        return this.expr($rawExpression);
    }

    /**
     * Returns a new QueryExpression object. This is a handy function when
     * building complex queries using a fluent interface. You can also override
     * this function in subclasses to use a more specialized QueryExpression class
     * if required.
     *
     * You can optionally pass a single raw SQL string or an array or expressions in
     * any format accepted by uim.cake.databases.Expression\QueryExpression:
     *
     * ```
     * $expression = $query.expr(); // Returns an empty expression object
     * $expression = $query.expr("Table.column = Table2.column"); // Return a raw SQL expression
     * ```
     *
     * @param uim.cake.databases.IExpression|array|string|null $rawExpression A string, array or anything you want wrapped in an expression object
     * @return uim.cake.databases.Expression\QueryExpression
     */
    function expr($rawExpression = null): QueryExpression
    {
        $expression = new QueryExpression([], this.getTypeMap());

        if ($rawExpression != null) {
            $expression.add($rawExpression);
        }

        return $expression;
    }

    /**
     * Returns an instance of a functions builder object that can be used for
     * generating arbitrary SQL functions.
     *
     * ### Example:
     *
     * ```
     * $query.func().count("*");
     * $query.func().dateDiff(["2012-01-05", "2012-01-02"])
     * ```
     *
     * @return uim.cake.databases.FunctionsBuilder
     */
    function func(): FunctionsBuilder
    {
        if (_functionsBuilder == null) {
            _functionsBuilder = new FunctionsBuilder();
        }

        return _functionsBuilder;
    }

    /**
     * Executes this query and returns a results iterator. This bool is required
     * for implementing the IteratorAggregate interface and allows the query to be
     * iterated without having to call execute() manually, thus making it look like
     * a result set instead of the query itself.
     *
     * @return uim.cake.databases.IStatement
     * @psalm-suppress ImplementedReturnTypeMismatch
     */
    #[\ReturnTypeWillChange]
    function getIterator() {
        if (_iterator == null || _dirty) {
            _iterator = this.execute();
        }

        return _iterator;
    }

    /**
     * Returns any data that was stored in the specified clause. This is useful for
     * modifying any internal part of the query and it is used by the SQL dialects
     * to transform the query accordingly before it is executed. The valid clauses that
     * can be retrieved are: delete, update, set, insert, values, select, distinct,
     * from, join, set, where, group, having, order, limit, offset and union.
     *
     * The return value for each of those parts may vary. Some clauses use QueryExpression
     * to internally store their state, some use arrays and others may use booleans or
     * integers. This is summary of the return types for each clause.
     *
     * - update: string The name of the table to update
     * - set: QueryExpression
     * - insert: array, will return an array containing the table + columns.
     * - values: ValuesExpression
     * - select: array, will return empty array when no fields are set
     * - distinct: boolean
     * - from: array of tables
     * - join: array
     * - set: array
     * - where: QueryExpression, returns null when not set
     * - group: array
     * - having: QueryExpression, returns null when not set
     * - order: OrderByExpression, returns null when not set
     * - limit: integer or QueryExpression, null when not set
     * - offset: integer or QueryExpression, null when not set
     * - union: array
     *
     * @param string aName name of the clause to be returned
     * @return mixed
     * @throws \InvalidArgumentException When the named clause does not exist.
     */
    function clause(string aName) {
        if (!array_key_exists($name, _parts)) {
            $clauses = implode(", ", array_keys(_parts));
            throw new InvalidArgumentException("The "$name" clause is not defined. Valid clauses are: $clauses");
        }

        return _parts[$name];
    }

    /**
     * Registers a callback to be executed for each result that is fetched from the
     * result set, the callback function will receive as first parameter an array with
     * the raw data from the database for every row that is fetched and must return the
     * row with any possible modifications.
     *
     * Callbacks will be executed lazily, if only 3 rows are fetched for database it will
     * called 3 times, event though there might be more rows to be fetched in the cursor.
     *
     * Callbacks are stacked in the order they are registered, if you wish to reset the stack
     * the call this function with the second parameter set to true.
     *
     * If you wish to remove all decorators from the stack, set the first parameter
     * to null and the second to true.
     *
     * ### Example
     *
     * ```
     * $query.decorateResults(function ($row) {
     *   $row["order_total"] = $row["subtotal"] + ($row["subtotal"] * $row["tax"]);
     *    return $row;
     * });
     * ```
     *
     * @param callable|null $callback The callback to invoke when results are fetched.
     * @param bool canOverwrite Whether this should append or replace all existing decorators.
     * @return this
     */
    function decorateResults(?callable $callback, bool canOverwrite = false) {
        if (canOverwrite) {
            _resultDecorators = null;
        }

        if ($callback != null) {
            _resultDecorators[] = $callback;
        }

        return this;
    }

    /**
     * This function works similar to the traverse() function, with the difference
     * that it does a full depth traversal of the entire expression tree. This will execute
     * the provided callback function for each IExpression object that is
     * stored inside this query at any nesting depth in any part of the query.
     *
     * Callback will receive as first parameter the currently visited expression.
     *
     * @param callable $callback the function to be executed for each IExpression
     *   found inside this query.
     * @return this
     */
    function traverseExpressions(callable $callback) {
        if (!$callback instanceof Closure) {
            $callback = Closure::fromCallable($callback);
        }

        foreach (_parts as $part) {
            _expressionsVisitor($part, $callback);
        }

        return this;
    }

    /**
     * Query parts traversal method used by traverseExpressions()
     *
     * @param uim.cake.databases.IExpression|array<uim.cake.databases.IExpression> $expression Query expression or
     *   array of expressions.
     * @param \Closure $callback The callback to be executed for each IExpression
     *   found inside this query.
     */
    protected void _expressionsVisitor($expression, Closure $callback) {
        if (is_array($expression)) {
            foreach ($expression as $e) {
                _expressionsVisitor($e, $callback);
            }

            return;
        }

        if ($expression instanceof IExpression) {
            $expression.traverse(function ($exp) use ($callback) {
                _expressionsVisitor($exp, $callback);
            });

            if (!$expression instanceof self) {
                $callback($expression);
            }
        }
    }

    /**
     * Associates a query placeholder to a value and a type.
     *
     * ```
     * $query.bind(":id", 1, "integer");
     * ```
     *
     * @param string|int $param placeholder to be replaced with quoted version
     *   of $value
     * @param mixed $value The value to be bound
     * @param string|int|null $type the mapped type name, used for casting when sending
     *   to database
     * @return this
     */
    function bind($param, $value, $type = null) {
        this.getValueBinder().bind($param, $value, $type);

        return this;
    }

    /**
     * Returns the currently used ValueBinder instance.
     *
     * A ValueBinder is responsible for generating query placeholders and temporarily
     * associate values to those placeholders so that they can be passed correctly
     * to the statement object.
     *
     * @return uim.cake.databases.ValueBinder
     */
    function getValueBinder(): ValueBinder
    {
        if (_valueBinder == null) {
            _valueBinder = new ValueBinder();
        }

        return _valueBinder;
    }

    /**
     * Overwrite the current value binder
     *
     * A ValueBinder is responsible for generating query placeholders and temporarily
     * associate values to those placeholders so that they can be passed correctly
     * to the statement object.
     *
     * @param uim.cake.databases.ValueBinder|null $binder The binder or null to disable binding.
     * @return this
     */
    function setValueBinder(?ValueBinder aBinder) {
        _valueBinder = $binder;

        return this;
    }

    /**
     * Enables/Disables buffered results.
     *
     * When enabled the results returned by this Query will be
     * buffered. This enables you to iterate a result set multiple times, or
     * both cache and iterate it.
     *
     * When disabled it will consume less memory as fetched results are not
     * remembered for future iterations.
     *
     * @param bool $enable Whether to enable buffering
     * @return this
     */
    function enableBufferedResults(bool $enable = true) {
        _dirty();
        _useBufferedResults = $enable;

        return this;
    }

    /**
     * Disables buffered results.
     *
     * Disabling buffering will consume less memory as fetched results are not
     * remembered for future iterations.
     *
     * @return this
     */
    function disableBufferedResults() {
        _dirty();
        _useBufferedResults = false;

        return this;
    }

    /**
     * Returns whether buffered results are enabled/disabled.
     *
     * When enabled the results returned by this Query will be
     * buffered. This enables you to iterate a result set multiple times, or
     * both cache and iterate it.
     *
     * When disabled it will consume less memory as fetched results are not
     * remembered for future iterations.
     */
    bool isBufferedResultsEnabled() {
        return _useBufferedResults;
    }

    /**
     * Sets the TypeMap class where the types for each of the fields in the
     * select clause are stored.
     *
     * @param uim.cake.databases.TypeMap $typeMap The map object to use
     * @return this
     */
    function setSelectTypeMap(TypeMap $typeMap) {
        _selectTypeMap = $typeMap;
        _dirty();

        return this;
    }

    /**
     * Gets the TypeMap class where the types for each of the fields in the
     * select clause are stored.
     *
     * @return uim.cake.databases.TypeMap
     */
    function getSelectTypeMap(): TypeMap
    {
        if (_selectTypeMap == null) {
            _selectTypeMap = new TypeMap();
        }

        return _selectTypeMap;
    }

    /**
     * Disables result casting.
     *
     * When disabled, the fields will be returned as received from the database
     * driver (which in most environments means they are being returned as
     * strings), which can improve performance with larger datasets.
     *
     * @return this
     */
    function disableResultsCasting() {
        this.typeCastEnabled = false;

        return this;
    }

    /**
     * Enables result casting.
     *
     * When enabled, the fields in the results returned by this Query will be
     * cast to their corresponding PHP data type.
     *
     * @return this
     */
    function enableResultsCasting() {
        this.typeCastEnabled = true;

        return this;
    }

    /**
     * Returns whether result casting is enabled/disabled.
     *
     * When enabled, the fields in the results returned by this Query will be
     * casted to their corresponding PHP data type.
     *
     * When disabled, the fields will be returned as received from the database
     * driver (which in most environments means they are being returned as
     * strings), which can improve performance with larger datasets.
     */
    bool isResultsCastingEnabled() {
        return this.typeCastEnabled;
    }

    /**
     * Auxiliary function used to wrap the original statement from the driver with
     * any registered callbacks.
     *
     * @param uim.cake.databases.IStatement $statement to be decorated
     * @return uim.cake.databases.Statement\CallbackStatement|uim.cake.databases.IStatement
     */
    protected function _decorateStatement(IStatement $statement) {
        $typeMap = this.getSelectTypeMap();
        $driver = this.getConnection().getDriver();

        if (this.typeCastEnabled && $typeMap.toArray()) {
            $statement = new CallbackStatement($statement, $driver, new FieldTypeConverter($typeMap, $driver));
        }

        foreach (_resultDecorators as $f) {
            $statement = new CallbackStatement($statement, $driver, $f);
        }

        return $statement;
    }

    /**
     * Helper function used to build conditions by composing QueryExpression objects.
     *
     * @param string $part Name of the query part to append the new part to
     * @param uim.cake.databases.IExpression|\Closure|array|string|null $append Expression or builder function to append.
     *   to append.
     * @param string $conjunction type of conjunction to be used to operate part
     * @param array<string, string> $types Associative array of type names used to bind values to query
     */
    protected void _conjugate(string $part, $append, $conjunction, array $types) {
        $expression = _parts[$part] ?: this.newExpr();
        if (empty($append)) {
            _parts[$part] = $expression;

            return;
        }

        if ($append instanceof Closure) {
            $append = $append(this.newExpr(), this);
        }

        if ($expression.getConjunction() == $conjunction) {
            $expression.add($append, $types);
        } else {
            $expression = this.newExpr()
                .setConjunction($conjunction)
                .add([$expression, $append], $types);
        }

        _parts[$part] = $expression;
        _dirty();
    }

    /**
     * Marks a query as dirty, removing any preprocessed information
     * from in memory caching.
     */
    protected void _dirty() {
        _dirty = true;

        if (_iterator && _valueBinder) {
            this.getValueBinder().reset();
        }
    }

    /**
     * Handles clearing iterator and cloning all expressions and value binders.
     */
    void __clone() {
        _iterator = null;
        if (_valueBinder != null) {
            _valueBinder = clone _valueBinder;
        }
        if (_selectTypeMap != null) {
            _selectTypeMap = clone _selectTypeMap;
        }
        foreach (_parts as $name: $part) {
            if (empty($part)) {
                continue;
            }
            if (is_array($part)) {
                foreach ($part as $i: $piece) {
                    if (is_array($piece)) {
                        foreach ($piece as $j: $value) {
                            if ($value instanceof IExpression) {
                                /** @psalm-suppress PossiblyUndefinedMethod */
                                _parts[$name][$i][$j] = clone $value;
                            }
                        }
                    } elseif ($piece instanceof IExpression) {
                        /** @psalm-suppress PossiblyUndefinedMethod */
                        _parts[$name][$i] = clone $piece;
                    }
                }
            }
            if ($part instanceof IExpression) {
                _parts[$name] = clone $part;
            }
        }
    }

    /**
     * Returns string representation of this query (complete SQL statement).
     */
    string toString() {
        return this.sql();
    }

    /**
     * Returns an array that can be used to describe the internal state of this
     * object.
     *
     * @return array<string, mixed>
     */
    array __debugInfo() {
        try {
            set_error_handler(
                /** @return no-return */
                function ($errno, $errstr) {
                    throw new RuntimeException($errstr, $errno);
                },
                E_ALL
            );
            $sql = this.sql();
            $params = this.getValueBinder().bindings();
        } catch (RuntimeException $e) {
            $sql = "SQL could not be generated for this query as it is incomplete.";
            $params = null;
        } finally {
            restore_error_handler();
        }

        return [
            "(help)": "This is a Query object, to get the results execute or iterate it.",
            "sql": $sql,
            "params": $params,
            "defaultTypes": this.getDefaultTypes(),
            "decorators": count(_resultDecorators),
            "executed": _iterator ? true : false,
        ];
    }
}
