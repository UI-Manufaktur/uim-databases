module uim.databases.Query;

import uim.databases;

@safe:

/**
 * This class is used to generate SELECT queries for the relational database.
 *
 * @template T of mixed
 * @implements \IteratorAggregate<T>
 */
class SelectQuery : Query, IteratorAggregate {
    mixin(QueryThis!("SelectQuery"));

    override bool initialize(IData[string] initData = null) {
        if (!super.initialize(initData)) {
            return false;
        }

    _parts = [
        "comment": null,
        "modifier": [],
        "with": [],
        "select": [],
        "distinct": false,
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

        return true;
    }
    // Type of this query.
    protected string _type = self.TYPE_SELECT;

    // List of SQL parts that will be used to build this query.

    /**
     * A list of callbacks to be called to alter each row from resulting
     * statement upon retrieval. Each one of the callback auto will receive
     * the row array as first argument.
     *
     * @var array<\Closure>
     */
    protected array _resultDecorators = [];

    // Result set from exeuted SELCT query.
    protected iterable _results = null;

    // The Type map for fields in the select clause
    protected TypeMap _selectTypeMap = null;

    // Tracking flag to disable casting
    protected bool typeCastEnabled = true;

    /**
     * Executes query and returns set of decorated results.
     *
     * The results are cached until the query is modified and marked dirty.
     */
    iterable all() {
        if (_results.isNull || _isDirty) {
           _results = this.execute().fetchAll(IStatement.FETCH_TYPE_ASSOC);
            if (_resultDecorators) {
                foreach (& row; _results) {
                    foreach ( decorator; _resultDecorators) {
                         row =  decorator( row);
                    }
                }
            }
        }
        return _results;
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
     * If a callback is passed, the returning array of the auto will
     * be used as the list of fields.
     *
     * By default this auto will append any passed argument to the list of fields
     * to be selected, unless the second argument is set to true.
     *
     * ### Examples:
     *
     * ```
     * aQuery.select(["id", "title"]); // Produces SELECT id, title
     * aQuery.select(["author": 'author_id"]); // Appends author: SELECT id, title, author_id as author
     * aQuery.select("id", true); // Resets the list: SELECT id
     * aQuery.select(["total": countQuery]); // SELECT id, (SELECT ...) AS total
     * aQuery.select(function (aQuery) {
     *    return ["article_id", "total": aQuery.count("*")];
     * })
     * ```
     *
     * By default no fields are selected, if you have an instance of `UIM\ORM\Query` and try to append
     * fields you should also call `UIM\ORM\Query.enableAutoFields()` to select the default fields
     * from the table.
     * Params:
     * \UIM\Database\IExpression|\Closure|string[]|float|int fields fields to be added to the list.
     * @param bool overwrite whether to reset fields with passed list or not
     */
    void select(IExpression|Closure|string[]|float|int fields = [], bool overwrite = false) {
        if (!isString(fields) && cast(Closure)fieldsClosure) {
            fields = fields(this);
        }
        if (!isArray(fields)) {
            fields = [fields];
        }

        _parts["select"] = overwrite ? fields : array_merge(_parts["select"], fields);

       _isDirty();
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
     * aQuery.select(["name", "city"]).from("products").distinct();
     *
     * // Filters products in the same city
     * aQuery.distinct(["city"]);
     * aQuery.distinct("city");
     *
     * // Filter products with the same name
     * aQuery.distinct(["name"], true);
     * aQuery.distinct("name", true);
     * ```
     * Params:
     * \UIM\Database\IExpression|string[]|bool  on Enable/disable distinct class
     * or list of fields to be filtered on
     * @param bool overwrite whether to reset fields with passed list or not
     */
    void distinct(IExpression|string[]|bool  on = [], bool overwrite = false) {
        if ( on == []) {
             on = true;
        } elseif (isString( on)) {
             on = [ on];
        }
        if (isArray( on)) {
            $merge = [];
            if (isArray(_parts["distinct"])) {
                $merge = _parts["distinct"];
            }
             on = overwrite ? array_values( on): array_merge($merge,  on.values);
        }
       _parts["distinct"] =  on;
       _isDirty();
    }
    
    /**
     * Adds a single or multiple tables to be used as JOIN clauses to this query.
     * Tables can be passed as an array of strings, an array describing the
     * join parts, an array with multiple join descriptions, or a single string.
     *
     * By default this auto will append any passed argument to the list of tables
     * to be joined, unless the third argument is set to true.
     *
     * When no join type is specified an `INNER JOIN` is used by default:
     * `aQuery.join(["authors"])` will produce `INNER JOIN authors ON 1 = 1`
     *
     * It is also possible to alias joins using the array key:
     * `aQuery.join(["a": 'authors"])` will produce `INNER JOIN authors a ON 1 = 1`
     *
     * A join can be fully described and aliased using the array notation:
     *
     * ```
     * aQuery.join([
     *    "a": [
     *        "table": "authors",
     *        "type": "LEFT",
     *        "conditions": "a.id = b.author_id'
     *    ]
     * ]);
     * // Produces LEFT JOIN authors a ON a.id = b.author_id
     * ```
     *
     * You can even specify multiple joins in an array, including the full description:
     *
     * ```
     * aQuery.join([
     *    "a": [
     *        "table": 'authors",
     *        "type": 'LEFT",
     *        "conditions": 'a.id = b.author_id'
     *    ],
     *    "p": [
     *        'table": 'publishers",
     *        'type": 'INNER",
     *        'conditions": 'p.id = b.publisher_id AND p.name = "Cake Software Foundation"'
     *    ]
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
     * aQuery.join(["a": [
     *    "table": 'articles",
     *    "conditions": [
     *        "a.posted >=": new DateTime("-3 days"),
     *        "a.published": true,
     *        "a.author_id = authors.id'
     *    ]
     * ]], ["a.posted": 'datetime", "a.published": 'boolean"])
     * ```
     *
     * ### Overwriting joins
     *
     * When creating aliased joins using the array notation, you can override
     * previous join definitions by using the same alias in consequent
     * calls to this auto or you can replace all previously defined joins
     * with another list if the third parameter for this bool is set to true.
     *
     * ```
     * aQuery.join(["alias": 'table"]); // joins table with as alias
     * aQuery.join(["alias": 'another_table"]); // joins another_table with as alias
     * aQuery.join(["something": 'different_table"], [], true); // resets joins list
     * ```
     * Params:
     * IData[string]|string atables list of tables to be joined in the query
     * typeNames Associative array of type names used to bind values to query
     * @param bool overwrite whether to reset joins with passed list or not
     * @see \UIM\Database\TypeFactory
     */
    void join(string[] atables, STRINGAA typeNames = [], bool overwrite = false) {
        if (isString(aTables) || isSet(aTables["table"])) {
            aTables = [aTables];
        }
        $joins = [];
        anI = count(_parts["join"]);
        foreach (alias: t; aTables) {
            if (!isArray(t)) {
                t = ["table": t, "conditions": this.newExpr()];
            }
            if (!isString(t["conditions"]) && cast(Closure)t["conditions"]) {
                t["conditions"] = t["conditions"](this.newExpr(), this);
            }
            if (!(cast(IExpression)t["conditions"] )) {
                t["conditions"] = this.newExpr().add(t["conditions"], typeNames);
            }
            alias = isString(alias) ? alias : null;
            $joins[alias ?:  anI++] = t ~ ["type": JOIN_TYPE_INNER, "alias": alias];
        }

        _parts["join"] = overwrite 
            ? $joins
            : array_merge(_parts["join"], $joins);

       _isDirty();
    }
    
    /**
     * Remove a join if it has been defined.
     *
     * Useful when you are redefining joins or want to re-order
     * the join clauses.
     * Params:
     * string aName The alias/name of the join to remove.
     */
    void removeJoin(string aName) {
        unset(_parts["join"][name]);
       _isDirty();
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
     * aQuery.leftJoin("authors", "authors.id = posts.author_id");
     *
     * // LEFT JOIN authors a ON a.id = posts.author_id
     * aQuery.leftJoin(["a": 'authors"], "a.id = posts.author_id");
     * ```
     *
     * Conditions can be passed as strings, arrays, or expression objects. When
     * using arrays it is possible to combine them with the `types` parameter
     * in order to define how to convert the values:
     *
     * ```
     * aQuery.leftJoin(["a": 'articles"], [
     *     'a.posted >=": new DateTime("-3 days"),
     *     'a.published": true,
     *     'a.author_id = authors.id'
     * ], ["a.posted": 'datetime", "a.published": 'boolean"]);
     * ```
     *
     * See `join()` for further details on conditions and types.
     * Params:
     * IData[string]|string atable The table to join with
     * @param \UIM\Database\IExpression|\Closure|string[] aconditions The conditions
     * to use for joining.
     * @param array types a list of types associated to the conditions used for converting
     * values to the corresponding database representation.
     */
    void leftJoin(
        string[] atable,
        IExpression|Closure|string[] aconditions = [],
        array types = []
    ) {
        this.join(_makeJoin(aTable, conditions, JOIN_TYPE_LEFT), types);
    }

    /**
     * Adds a single `RIGHT JOIN` clause to the query.
     *
     * This is a shorthand method for building joins via `join()`.
     *
     * The arguments of this method are identical to the `leftJoin()` shorthand, please refer
     * to that methods description for further details.
     * Params:
     * IData[string]|string atable The table to join with
     * @param \UIM\Database\IExpression|\Closure|string[] aconditions The conditions
     * to use for joining.
     * @param array types a list of types associated to the conditions used for converting
     * values to the corresponding database representation.
     */
    auto rightJoin(
        string[] atable,
        IExpression|Closure|string[] aconditions = [],
        array types = []
    ) {
        this.join(_makeJoin(aTable, conditions, JOIN_TYPE_RIGHT), types);

        return this;
    }

    /**
     * Adds a single `INNER JOIN` clause to the query.
     *
     * This is a shorthand method for building joins via `join()`.
     *
     * The arguments of this method are identical to the `leftJoin()` shorthand, please refer
     * to that method`s description for further details.
     * Params:
     * IData[string]|string atable The table to join with
     * @param \UIM\Database\IExpression|\Closure|string[] aconditions The conditions
     * to use for joining.
     * @param STRINGAA types a list of types associated to the conditions used for converting
     * values to the corresponding database representation.
     */
    void innerJoin(
        string[] atable,
        IExpression|Closure|string[] aconditions = [],
        array types = []
    ) {
        this.join(_makeJoin(aTable, conditions, JOIN_TYPE_INNER), types);
    }

    /**
     * Returns an array that can be passed to the join method describing a single join clause
     * Params:
     * IData[string]|string atable The table to join with
     * @param \UIM\Database\IExpression|\Closure|string[] aconditions The conditions
     * to use for joining.
     * @param string atype the join type to use
     */
    protected array _makeJoin(
        string[] atable,
        IExpression|Closure|string[] aconditions,
        string atype
    ) {
        alias = aTable;

        if (isArray(aTable)) {
            alias = key(aTable);
            aTable = current(aTable);
        }
        /** @var string aalias */
        return [
            alias: [
                'table": aTable,
                'conditions": conditions,
                'type": type,
            ],
        ];
    }
    
    /**
     * Adds a single or multiple fields to be used in the GROUP BY clause for this query.
     * Fields can be passed as an array of strings, array of expression
     * objects, a single expression or a single string.
     *
     * By default this auto will append any passed argument to the list of fields
     * to be grouped, unless the second argument is set to true.
     *
     * ### Examples:
     *
     * ```
     * // Produces GROUP BY id, title
     * aQuery.groupBy(["id", "title"]);
     *
     * // Produces GROUP BY title
     * aQuery.groupBy("title");
     * ```
     *
     * Group fields are not suitable for use with user supplied data as they are
     * not sanitized by the query builder.
     * Params:
     * \UIM\Database\IExpression|string[] afields fields to be added to the list
     * @param bool overwrite whether to reset fields with passed list or not
     */
    auto groupBy(IExpression|string[] afields, bool overwrite = false) {
        if (overwrite) {
           _parts["group"] = [];
        }
        if (!isArray(fields)) {
            fields = [fields];
        }
       _parts["group"] = array_merge(_parts["group"], fields.values);
       _isDirty();

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
     * Params:
     * \UIM\Database\IExpression|\Closure|string[]|null conditions The having conditions.
     * types Associative array of type names used to bind values to query
     * @param bool overwrite whether to reset conditions with passed list or not
     * @see \UIM\Database\Query.where()
     */
    auto having(
        IExpression|Closure|string[]|null conditions = null,
        STRINGAA types = [],
        bool overwrite = false
    ) {
        if (overwrite) {
           _parts["having"] = this.newExpr();
        }
       _conjugate("having", conditions, "AND", types);

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
     * Params:
     * \UIM\Database\IExpression|\Closure|string[] aconditions The AND conditions for HAVING.
     * @param STRINGAA types Associative array of type names used to bind values to query
     * @see \UIM\Database\Query.andWhere()
     */
    auto andHaving(IExpression|Closure|string[] aconditions, array types = []) {
       _conjugate("having", conditions, "AND", types);

        return this;
    }
    
    /**
     * Adds a named window expression.
     *
     * You are responsible for adding windows in the order your database requires.
     * Params:
     * string aName Window name
     * @param \UIM\Database\Expression\WindowExpression|\Closure  window Window expression
     * @param bool overwrite Clear all previous query window expressions
     */
    void window(string aName, WindowExpression|Closure  window, bool overwrite = false) {
        if (overwrite) {
           _parts["window"] = [];
        }
        if (cast(Closure) window) {
             window =  window(new WindowExpression(), this);
            if (!(cast(WindowExpression) window)) {
                throw new UimException("You must return a `WindowExpression` from a Closure passed to `window()`.");
            }
        }
       _parts["window"] ~= ["name": new IdentifierExpression(name), "window":  window];
       _isDirty();
    }
    
    /**
     * Set the page of results you want.
     *
     * This method provides an easier to use interface to set the limit + offset
     * in the record set you want as results. If empty the limit will default to
     * the existing limit clause, and if that too is empty, then `25` will be used.
     *
     * Pages must start at 1.
     * Params:
     * int num The page number you want.
     * @param int aLimit The number of rows you want in the page. If null
     * the current limit clause will be used.
     */
    void page(int num, int aLimit = null) {
        if (num < 1) {
            throw new InvalidArgumentException("Pages must start at 1.");
        }
        if (aLimit !isNull) {
            this.limit(aLimit);
        }
        aLimit = this.clause("limit");
        if (aLimit.isNull) {
            aLimit = 25;
            this.limit(aLimit);
        }
         anOffset = (num - 1) * aLimit;
        if (PHP_INT_MAX <=  anOffset) {
             anOffset = PHP_INT_MAX;
        }
        this.offset((int) anOffset);
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
     * union = (new SelectQuery(conn)).select(["id", "title"]).from(["a": 'articles"]);
     * aQuery.select(["id", "name"]).from(["d": 'things"]).union(union);
     * ```
     *
     * Will produce:
     *
     * `SELECT id, name FROM things d UNION SELECT id, title FROM articles a`
     * Params:
     * \UIM\Database\Query|string aquery full SQL query to be used in UNION operator
     * @param bool overwrite whether to reset the list of queries to be operated or not
     */
    auto union(Query|string aquery, bool overwrite = false) {
        if (overwrite) {
           _parts["union"] = [];
        }
       _parts["union"] ~= [
            'all": false,
            'query": aQuery,
        ];
       _isDirty();

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
     * union = (new SelectQuery(conn)).select(["id", "title"]).from(["a": 'articles"]);
     * aQuery.select(["id", "name"]).from(["d": 'things"]).unionAll(union);
     * ```
     *
     * Will produce:
     *
     * `SELECT id, name FROM things d UNION ALL SELECT id, title FROM articles a`
     * Params:
     * \UIM\Database\Query|string aquery full SQL query to be used in UNION operator
     * @param bool overwrite whether to reset the list of queries to be operated or not
     */
    auto unionAll(Query|string aquery, bool overwrite = false) {
        if (overwrite) {
           _parts["union"] = [];
        }
       _parts["union"] ~= [
            'all": true,
            'query": aQuery,
        ];
       _isDirty();

        return this;
    }
    
    /**
     * Executes this query and returns a results iterator. This bool is required
     * for implementing the IteratorAggregate interface and allows the query to be
     * iterated without having to call all() manually, thus making it look like
     * a result set instead of the query itself.
     */
    Traversable getIterator() {
        /** @var \Traversable|array results */
        results = this.all();
        if (isArray(results)) {
            return new ArrayIterator(results);
        }
        return results;
    }
    
    /**
     * Registers a callback to be executed for each result that is fetched from the
     * result set, the callback auto will receive as first parameter an array with
     * the raw data from the database for every row that is fetched and must return the
     * row with any possible modifications.
     *
     * Callbacks will be executed lazily, if only 3 rows are fetched for database it will
     * be called 3 times, event though there might be more rows to be fetched in the cursor.
     *
     * Callbacks are stacked in the order they are registered, if you wish to reset the stack
     * the call this auto with the second parameter set to true.
     *
     * If you wish to remove all decorators from the stack, set the first parameter
     * to null and the second to true.
     *
     * ### Example
     *
     * ```
     * aQuery.decorateResults(function ( row) {
     *   row["order_total"] =  row["subtotal"] + ( row["subtotal"] *  row["tax"]);
     *   return  row;
     * });
     * ```
     * Params:
     * \Closure|null aCallback The callback to invoke when results are fetched.
     * @param bool overwrite Whether this should append or replace all existing decorators.
     */
    auto decorateResults(?Closure aCallback, bool overwrite = false) {
       _isDirty();
        if (overwrite) {
           _resultDecorators = [];
        }
        if (aCallback !isNull) {
           _resultDecorators ~= aCallback;
        }
        return this;
    }
    
    /**
     * Sets the TypeMap class where the types for each of the fields in the
     * select clause are stored.
     * Params:
     * \UIM\Database\TypeMap|array typeMap Creates a TypeMap if array, otherwise sets the given TypeMap.
     */
    auto setSelectTypeMap(TypeMap|array typeMap) {
       _selectTypeMap = isArray(typeMap) ? new TypeMap(typeMap): typeMap;
       _isDirty();

        return this;
    }
    
    /**
     * Gets the TypeMap class where the types for each of the fields in the
     * select clause are stored.
     */
    TypeMap getSelectTypeMap() {
        return _selectTypeMap ??= new TypeMap();
    }
    
    /**
     * Disables result casting.
     *
     * When disabled, the fields will be returned as received from the database
     * driver (which in most environments means they are being returned as
     * strings), which can improve performance with larger datasets.
     */
    auto disableResultsCasting() {
        this.typeCastEnabled = false;

        return this;
    }
    
    /**
     * Enables result casting.
     *
     * When enabled, the fields in the results returned by this Query will be
     * cast to their corresponding D data type.
     */
    void enableResultsCasting() {
        this.typeCastEnabled = true;
    }
    
    /**
     * Returns whether result casting is enabled/disabled.
     *
     * When enabled, the fields in the results returned by this Query will be
     * casted to their corresponding D data type.
     *
     * When disabled, the fields will be returned as received from the database
     * driver (which in most environments means they are being returned as
     * strings), which can improve performance with larger datasets.
     */
    bool isResultsCastingEnabled() {
        return this.typeCastEnabled;
    }
    
    // Handles clearing iterator and cloning all expressions and value binders.
    void __clone() {
        super.__clone();

       _results = null;
        if (_selectTypeMap !isNull) {
           _selectTypeMap = clone _selectTypeMap;
        }
    }
    
    /**
     * Returns an array that can be used to describe the internal state of this
     * object.
     */
    IData[string] debugInfo() {
        result = super.__debugInfo();
        result["decorators"] = count(_resultDecorators);

        return result;
    }
    
    /**
     * Sets the connection role.
     * Params:
     * string arole Connection role ("read' or 'write")
     */
    auto setConnectionRole(string arole) {
        assert( role == Connection.ROLE_READ ||  role == Connection.ROLE_WRITE);
        this.connectionRole =  role;

        return this;
    }
    
    // Sets the connection role to read.
    auto useReadRole() {
        return this.setConnectionRole(Connection.ROLE_READ);
    }

    // Sets the connection role to write
    auto useWriteRole() {
        return this.setConnectionRole(Connection.ROLE_WRITE);
    }
}
