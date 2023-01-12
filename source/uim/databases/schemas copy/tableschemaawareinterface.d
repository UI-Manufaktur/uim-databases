module uim.cake.databases.schemas;

/**
 * Defines the interface for getting the schema.
 */
interface TableSchemaAwareInterface
{
    /**
     * Get and set the schema for this fixture.
     *
     * @return uim.cake.databases.Schema\TableISchema&uim.cake.databases.Schema\ISqlGenerator
     */
    function getTableSchema();

    /**
     * Get and set the schema for this fixture.
     *
     * @param uim.cake.databases.Schema\TableISchema&uim.cake.databases.Schema\ISqlGenerator $schema The table to set.
     * @return this
     */
    function setTableSchema($schema);
}
