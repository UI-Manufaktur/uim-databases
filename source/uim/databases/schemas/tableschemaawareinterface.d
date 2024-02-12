module uim.databases.schemas;

/**
 * Defines the interface for getting the schema.
 */
interface TableSchemaAwareInterface
{
    /**
     * Get and set the schema for this fixture.
     *
     * @return uim.databases.Schema\ITableSchema&uim.databases.Schema\SqlGeneratorInterface
     */
    function getTableSchema();

    /**
     * Get and set the schema for this fixture.
     *
     * @param uim.databases.Schema\ITableSchema&uim.databases.Schema\SqlGeneratorInterface schema The table to set.
     * @return this
     */
    function setTableSchema(schema);
}
