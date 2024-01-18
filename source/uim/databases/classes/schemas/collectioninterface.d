module uim.databases.schemas;

import uim.cake;

@safe:

/* * Represents a database schema collection
 *
 * Used to access information about the tables,
 * and other data in a database.
 *
 * @method string[] listTablesWithoutViews() Get the list of tables available in the current connection.
 * This will exclude any views in the schema.
 */
interface ICollection {
    /**
     * Get the list of tables available in the current connection.
     *
     * The list of tables in the connected database/schema.
     */
    string[] listTables();

    /**
     * Get the column metadata for a table.
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
     * @param Json[string] $options The options to use, see above.
     * returns Object with column metadata.
     * @throws \UIM\Database\Exception\DatabaseException when table cannot be described.
     */
    TableISchema describe(string tableName, Json[string] options = null);
}
