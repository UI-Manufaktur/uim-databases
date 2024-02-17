module source.uim.databases.classes.queries.factory;

import uim.databases;

@safe:

//Factory class for generating instances of Select, Insert, Update, Delete queries.
class QueryFactory {
    
    this(Connection aConnection) {
    }
    
    /**
     * Create a new SelectQuery instance.
     * Params:
     * \UIM\Database\IExpression|\Closure|string[]|float|int fields Fields/columns list for the query.
     * typesForCasting Associative array containing the types to be used for casting.
     */
    SelectQuery select(
        IExpression|Closure|string[]|float|int fields = [],
        string[] tableNames = null,
        STRINGAA typesForCasting = null
    ) {
        auto selectQuery = new SelectQuery(this.connection);
        with (selectQuery) {
            select(fields);
            from(tableNames);
            setDefaultTypes(typesForCasting);
        }
        return selectQuery;
    }
    
    /**
     * Create a new InsertQuery instance.
     * Params:
     * string|null tableName The table to insert rows into.
     * @param array  someValues Associative array of column: value to be inserted.
     * typesForCasting Associative array containing the types to be used for casting.
     */
    InsertQuery insert(string tableName = null, array  someValues = [], STRINGAA typesForCasting = []) {
        aQuery = new InsertQuery(this.connection);

        if (tableName) {
            aQuery.into(tableName);
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
    DeleteQuery delete(string tableName = null, array $conditions = [], STRINGAA typesForCasting = []) {
        aQuery = (new DeleteQuery(this.connection))
            .delete(tableName);

        if ($conditions) {
            aQuery.where($conditions, typesForCasting);
        }
        return aQuery;
    }
}
