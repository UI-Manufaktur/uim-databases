module uim.databases.Query;

import uim.databases;

@safe:

/*

 */

//Factory class for generating instances of Select, Insert, Update, Delete queries.
class QueryFactory {
    
    this(
        protected Connection aConnection,
    ) {
    }
    
    /**
     * Create a new SelectQuery instance.
     * Params:
     * \UIM\Database\IExpression|\Closure|string[]|float|int $fields Fields/columns list for the query.
     * @param string[] atable List of tables to query.
     * typesForCasting Associative array containing the types to be used for casting.
     */
    SelectQuery select(
        IExpression|Closure|string[]|float|int $fields = [],
        string[] atable = [],
        STRINGAA typesForCasting = []
    ) {
        aQuery = new SelectQuery(this.connection);

        aQuery
            .select($fields)
            .from(aTable)
            .setDefaultTypes(typesForCasting);

        return aQuery;
    }
    
    /**
     * Create a new InsertQuery instance.
     * Params:
     * string|null aTable The table to insert rows into.
     * @param array  someValues Associative array of column: value to be inserted.
     * typesForCasting Associative array containing the types to be used for casting.
     */
    InsertQuery insert(string atable = null, array  someValues = [], STRINGAA typesForCasting = []) {
        aQuery = new InsertQuery(this.connection);

        if (aTable) {
            aQuery.into(aTable);
        }
        if (someValues) {
            someColumns = array_keys(someValues);
            aQuery
                .insert(someColumns, typesForCasting)
                .values(someValues);
        }
        return aQuery;
    }
    
    /**
     * Create a new UpdateQuery instance.
     * Params:
     * \UIM\Database\IExpression|string|null aTable The table to update rows of.
     * @param array  someValues Values to be updated.
     * @param array $conditions Conditions to be set for the update statement.
     * typesForCasting Associative array containing the types to be used for casting.
     */
    UpdateQuery update(
        IExpression|string|null aTable = null,
        array  someValues = [],
        array $conditions = [],
        typesForCasting = []
    ) {
        aQuery = new UpdateQuery(this.connection);

        if (aTable) {
            aQuery.update(aTable);
        }
        if (someValues) {
            aQuery.set(someValues, typesForCasting);
        }
        if ($conditions) {
            aQuery.where($conditions, typesForCasting);
        }
        return aQuery;
    }
    
    /**
     * Create a new DeleteQuery instance.
     * Params:
     * string|null aTable The table to delete rows from.
     * @param array $conditions Conditions to be set for the delete statement.
     * typesForCasting Associative array containing the types to be used for casting.
     */
    DeleteQuery delete(string atable = null, array $conditions = [], STRINGAA typesForCasting = []) {
        aQuery = (new DeleteQuery(this.connection))
            .delete(aTable);

        if ($conditions) {
            aQuery.where($conditions, typesForCasting);
        }
        return aQuery;
    }
}
