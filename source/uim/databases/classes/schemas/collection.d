module uim.databases.schemas;

import uim.databases;

@safe:

/*

/**
 * Represents a database schema collection
 *
 * Used to access information about the tables,
 * and other data in a database.
 */
class Collection : ICollection {
    // Connection object
    protected Connection _connection;

    // Schema dialect instance.
    protected SchemaDialect _dialect;

    this(Connection newConnection) {
       _connection = newConnection;
       _dialect = newConnection.getDriver().schemaDialect();
    }
    
    /**
     * Get the list of tables, excluding any views, available in the current connection.
     * The list of tables in the connected database/schema.
     */
    string[] listTablesWithoutViews() {
        [sql, params] = _dialect.listTablesWithoutViewsSql(_connection.getDriver().config());
        auto statement = _connection.execute(sql, params);

        string[] result;
        while ( row = statement.fetch()) {
            result ~=  row[0];
        }
        return result;
    }
    
    // Get the list of tables and views available in the current connection.
    string[] listTables() {
        [sql, params] = _dialect.listTablesSql(_connection.getDriver().config());
        statement = _connection.execute(sql, params);
        
        string[] result;
        while ( row = statement.fetch()) {
            result ~=  row[0];
        }
        return result;
    }
    
    /**
     * Get the column metadata for a table.
     *
     * The name can include a database schema name in the form `schema.table'.
     *
     * Caching will be applied if `cacheMetadata` key is present in the Connection
     * configuration options. Defaults to _cake_model_when true.
     *
     * ### Options
     *
     * - `forceRefresh` - Set to true to force rebuilding the cached metadata.
     *  Defaults to false.
     * Params:
     * string aName The name of the table to describe.
     * @param IData[string] options The options to use, see above.
     */
    TableISchema describe(string aName, IData[string] options = null) {
        configData = _connection.config();
        if (name.has(".")) {
            [configData["schema"], name] = split(".", name);
        }
        aTable = _connection.getDriver().newTableSchema(name);

       _reflect("Column", name, configData, aTable);
        if (count(aTable.columns()) == 0) {
            throw new DatabaseException("Cannot describe %s. It has 0 columns.".format(name));
        }
       _reflect("Index", name, configData, aTable);
       _reflect("ForeignKey", name, configData, aTable);
       _reflect("Options", name, configData, aTable);

        return aTable;
    }
    
    /**
     * Helper method for running each step of the reflection process.
     * Params:
     * string astage The stage name.
     * @param string aName The table name.
     * configData - The config data.
     * @param \UIM\Database\Schema\TableISchema tableSchema The table schema instance.
     * @throws \UIM\Database\Exception\DatabaseException on query failure.
     * @uses \UIM\Database\Schema\SchemaDialect.describeColumnSql
     * @uses \UIM\Database\Schema\SchemaDialect.describeIndexSql
     * @uses \UIM\Database\Schema\SchemaDialect.describeForeignKeySql
     * @uses \UIM\Database\Schema\SchemaDialect.describeOptionsSql
     * @uses \UIM\Database\Schema\SchemaDialect.convertColumnDescription
     * @uses \UIM\Database\Schema\SchemaDialect.convertIndexDescription
     * @uses \UIM\Database\Schema\SchemaDialect.convertForeignKeyDescription
     * @uses \UIM\Database\Schema\SchemaDialect.convertOptionsDescription
     */
    protected void _reflect(string astage, string tableName, IData[string] configData, TableISchema tableSchema) {
        string describeMethod = "describe{stage}Sql";
        string convertMethod = "convert{stage}Description";

        [sql, params] = _dialect.{describeMethod}(tableName, configData);
        if (isEmpty(sql)) {
            return;
        }
        try {
            statement = _connection.execute(sql, params);
        } catch (PDOException  anException) {
            throw new DatabaseException(anException.getMessage(), 500,  anException);
        }
        statement.fetchAll("assoc")
            .each!(row => _dialect.{convertMethod}(tableSchema, row));
    }
}
