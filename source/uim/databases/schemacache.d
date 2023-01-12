/*********************************************************************************************************
	Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        
	License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  
	Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      
**********************************************************************************************************/module uim.cake.databases;

@safe:
import uim.cake;

module uim.cake.databases;

import uim.cake.databases.schemas.CachedCollection;

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
class SchemaCache
{
    /**
     * Schema
     *
     * @var DDBSchema\CachedCollection
     */
    protected _schema;

    /**
     * Constructor
     *
     * @param uim.cake.databases.Connection $connection Connection name to get the schema for or a connection instance
     */
    this(Connection $connection) {
        _schema = this.getSchema($connection);
    }

    /**
     * Build metadata.
     *
     * @param string|null $name The name of the table to build cache data for.
     * @return array<string> Returns a list build table caches
     */
    string[] build(Nullable!string aName = null) {
        if ($name) {
            $tables = [$name];
        } else {
            $tables = _schema.listTables();
        }

        foreach ($tables as $table) {
            /** @psalm-suppress PossiblyNullArgument */
            _schema.describe($table, ["forceRefresh": true]);
        }

        return $tables;
    }

    /**
     * Clear metadata.
     *
     * @param string|null $name The name of the table to clear cache data for.
     * @return array<string> Returns a list of cleared table caches
     */
    string[] clear(Nullable!string aName = null) {
        if ($name) {
            $tables = [$name];
        } else {
            $tables = _schema.listTables();
        }

        $cacher = _schema.getCacher();

        foreach ($tables as $table) {
            /** @psalm-suppress PossiblyNullArgument */
            $key = _schema.cacheKey($table);
            $cacher.delete($key);
        }

        return $tables;
    }

    /**
     * Helper method to get the schema collection.
     *
     * @param uim.cake.databases.Connection $connection Connection object
     * @return uim.cake.databases.Schema\CachedCollection
     * @throws \RuntimeException If given connection object is not compatible with schema caching
     */
    function getSchema(Connection $connection): CachedCollection
    {
        aConfig = $connection.config();
        if (empty(aConfig["cacheMetadata"])) {
            $connection.cacheMetadata(true);
        }

        /** @var DDBSchema\CachedCollection $schemaCollection */
        $schemaCollection = $connection.getSchemaCollection();

        return $schemaCollection;
    }
}
