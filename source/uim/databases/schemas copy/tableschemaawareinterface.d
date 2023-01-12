module uim.databases.schemas;

/**
 * Defines the interface for getting the schema.
 */
interface TableSchemaAwareInterface
{
    /**
     * Get and set the schema for this fixture.
     *
     * @return \Cake\Database\Schema\ITableSchema&\Cake\Database\Schema\SqlGeneratorInterface
     */
    function getTableSchema();

    /**
     * Get and set the schema for this fixture.
     *
     * @param \Cake\Database\Schema\ITableSchema&\Cake\Database\Schema\SqlGeneratorInterface $schema The table to set.
     * @return this
     */
    function setTableSchema($schema);
}
