module uim.cake.databases;

import uim.cake;

@safe:

/**
 * Schema Cache.
 *
 * This tool is intended to be used by deployment scripts so that you
 * can prevent thundering herd effects on the metadata cache when new
 * versions of your application are deployed, or when migrations
 * requiring updated metadata are required.
 *
 * @link https://en.wikipedia.org/wiki/Thundering_herd_problem About the thundering herd problem
 */
class SchemaCache {
    // Schema
    protected CachedCollection _schema;

    /**
     * Constructor
     * Params:
     * aConnection = Connection to get the schema for or a connection instance
     */
    this(Connection aConnection) {
       _schema = this.getSchema(aConnection);
    }
    
    /**
     * Build metadata. Returns a list build table caches
     */
    string[] build(string tableName = null) {
        string[] tables = tableName.isEmpty 
            ? _schema.listTables()
            : [tableName];

        tables.each!(table => _schema.describe(table, ["forceRefresh": true]));

        return tables;
    }
    
    /**
     * Clear metadata.
     * Params:
     * string|null tableName The name of the table to clear cache data for.
     */
    string[] clear(string tableName = null) {
        auto tables = tableName 
            ? [tableName]
            : _schema.listTables();

        auto cacher = _schema.getCacher();

        tables
            .map!(table => _schema.cacheKey(table))
            .each!(key => cacher.delete(key));

        return tables;
    }
    
    /**
     * Helper method to get the schema collection.
     * Params:
     * \UIM\Database\Connection aConnection Connection object
     * @throws \RuntimeException If given connection object is not compatible with schema caching
     */
    CachedCollection getSchema(Connection aconnection) {
        auto configData = aConnection.config();
        if (configData["cacheMetadata"].isEmpty) {
            aConnection.cacheMetadata(true);
        }
        return aConnection.getSchemaCollection();
    }
}
