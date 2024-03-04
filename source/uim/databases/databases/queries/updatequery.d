module uim.cake.databases.Query;

import uim.cake;

@safe:

/*
 */

// This class is used to generate UPDATE queries for the relational database.
class UpdateQuery : Query {
    // Type of this query.
    protected string _type = self.TYPE_UPDATE;

    /**
     * List of SQL parts that will be used to build this query.
     */
    protected IData[string] _parts = [
        "comment": null,
        "with": [],
        "update": [],
        "modifier": [],
        "join": [],
        "set": [],
        "where": null,
        "order": null,
        "limit": null,
        "epilog": null,
    ];

    /**
     * Create an update query.
     *
     * Can be combined with set() and where() methods to create update queries.
     * Params:
     * \UIM\Database\IExpression|string atable The table you want to update.
     */
    void update(IExpression|string atable) {
       _isDirty();
       _parts["update"][0] = aTable;
Y>    }
    
    /**
     * Set one or many fields to update.
     *
     * ### Examples
     *
     * Passing a string:
     *
     * ```
     * aQuery.update("articles").set("title", "The Title");
     * ```
     *
     * Passing an array:
     *
     * ```
     * aQuery.update("articles").set(["title": 'The Title"], ["title": `string"]);
     * ```
     *
     * Passing a callback:
     *
     * ```
     * aQuery.update("articles").set(function (exp) {
     *  return exp.eq("title", "The title", "string");
     * });
     * ```
     * Params:
     * \UIM\Database\Expression\QueryExpression|\Closure|string[] aKey The column name or array of keys
     *   + values to set. This can also be a QueryExpression containing a SQL fragment.
     *   It can also be a Closure, that is required to return an expression object.
     * @param Json aValue The value to update aKey to. Can be null if aKey is an
     *   array or QueryExpression. When aKey is an array, this parameter will be
     *   used as types instead.
     * @param STRINGAA|string atypes The column types to treat data as.
     */
    void set(QueryExpression|Closure|string[] aKey, Json aValue = null, string[] atypes = []) {
        if (isEmpty(_parts["set"])) {
           _parts["set"] = this.newExpr().setConjunction(",");
        }
        if (cast(Closure)aKey) {
            exp = this.newExpr().setConjunction(",");
           _parts["set"].add(aKey(exp));

            return ;
        }
        if (isArray(aKey) || cast(IExpression)aKey ) {
            types = (array)aValue;
           _parts["set"].add(aKey, types);

            return ;
        }
        if (!isString(types)) {
            types = null;
        }
       _parts["set"].eq(aKey, aValue, types);
    }
}
