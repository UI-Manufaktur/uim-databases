/*********************************************************************************************************
	Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        
	License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  
	Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      
**********************************************************************************************************/
module uim.databases.schemas;

use uim.databases.Connection;
use uim.databases.Exception\DatabaseException;
use PDOException;

/**
 * Represents a database schema collection
 *
 * Used to access information about the tables,
 * and other data in a database.
 */
class Collection : CollectionInterface
{
    /**
     * Connection object
     *
     * @var DDBAConnection
     */
    protected _connection;

    /**
     * Schema dialect instance.
     *
     * @var uim.databases.Schema\SchemaDialect
     */
    protected _dialect;

    /**
     * Constructor.
     *
     * @param DDBAConnection $connection The connection instance.
     */
    public this(Connection $connection)
    {
        this._connection = $connection;
        this._dialect = $connection.getDriver().schemaDialect();
    }

    /**
     * Get the list of tables, excluding any views, available in the current connection.
     *
     * @return array<string> The list of tables in the connected database/schema.
     */
    function listTablesWithoutViews(): array
    {
        [mySql, $params] = this._dialect.listTablesWithoutViewsSql(this._connection.config());
        $result = [];
        $statement = this._connection.execute(mySql, $params);
        while (aRow = $statement.fetch()) {
            $result[] = aRow[0];
        }
        $statement.closeCursor();

        return $result;
    }

    /**
     * Get the list of tables and views available in the current connection.
     *
     * @return array<string> The list of tables and views in the connected database/schema.
     */
    function listTables(): array
    {
        [mySql, $params] = this._dialect.listTablesSql(this._connection.config());
        $result = [];
        $statement = this._connection.execute(mySql, $params);
        while (aRow = $statement.fetch()) {
            $result[] = aRow[0];
        }
        $statement.closeCursor();

        return $result;
    }

    /**
     * Get the column metadata for a table.
     *
     * The name can include a database schema name in the form "schema.table".
     *
     * Caching will be applied if `cacheMetadata` key is present in the Connection
     * configuration options. Defaults to _cake_model_ when true.
     *
     * ### Options
     *
     * - `forceRefresh` - Set to true to force rebuilding the cached metadata.
     *   Defaults to false.
     *
     * @param string $name The name of the table to describe.
     * @param array<string, mixed> $options The options to use, see above.
     * @return uim.databases.Schema\TableSchema Object with column metadata.
     * @throws uim.databases.Exception\DatabaseException when table cannot be described.
     */
    function describe(string $name, array $options = []): ITableSchema
    {
        $config = this._connection.config();
        if (strpos($name, ".")) {
            [$config["schema"], $name] = explode(".", $name);
        }
        $table = this._connection.getDriver().newTableSchema($name);

        this._reflect("Column", $name, $config, $table);
        if (count($table.columns()) == 0) {
            throw new DatabaseException(sprintf("Cannot describe %s. It has 0 columns.", $name));
        }

        this._reflect("Index", $name, $config, $table);
        this._reflect("ForeignKey", $name, $config, $table);
        this._reflect("Options", $name, $config, $table);

        return $table;
    }

    /**
     * Helper method for running each step of the reflection process.
     *
     * @param string $stage The stage name.
     * @param string $name The table name.
     * @param array<string, mixed> $config The config data.
     * @param uim.databases.Schema\TableSchema aSchema The table schema instance.
     * @return void
     * @throws uim.databases.Exception\DatabaseException on query failure.
     * @uses uim.databases.Schema\SchemaDialect::describeColumnSql
     * @uses uim.databases.Schema\SchemaDialect::describeIndexSql
     * @uses uim.databases.Schema\SchemaDialect::describeForeignKeySql
     * @uses uim.databases.Schema\SchemaDialect::describeOptionsSql
     * @uses uim.databases.Schema\SchemaDialect::convertColumnDescription
     * @uses uim.databases.Schema\SchemaDialect::convertIndexDescription
     * @uses uim.databases.Schema\SchemaDialect::convertForeignKeyDescription
     * @uses uim.databases.Schema\SchemaDialect::convertOptionsDescription
     */
    protected function _reflect(string $stage, string $name, array aConfig, TableSchema aSchema): void
    {
        $describeMethod = "describe{$stage}Sql";
        $convertMethod = "convert{$stage}Description";

        [mySql, $params] = this._dialect.{$describeMethod}($name, $config);
        if (empty(mySql)) {
            return;
        }
        try {
            $statement = this._connection.execute(mySql, $params);
        } catch (PDOException $e) {
            throw new DatabaseException($e.getMessage(), 500, $e);
        }
        /** @psalm-suppress PossiblyFalseIterator */
        foreach ($statement.fetchAll("assoc") as aRow) {
            this._dialect.{$convertMethod}($schema, aRow);
        }
        $statement.closeCursor();
    }
}
