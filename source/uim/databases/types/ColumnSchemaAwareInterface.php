<?php
declare(strict_types=1);

namespace Cake\Database\Type;

use Cake\Database\IDTBDriver;
use Cake\Database\Schema\TableSchemaInterface;

interface ColumnSchemaAwareInterface
{
    /**
     * Generate the SQL fragment for a single column in a table.
     *
     * @param \Cake\Database\Schema\TableSchemaInterface $schema The table schema instance the column is in.
     * @param string $column The name of the column.
     * @param \Cake\Database\IDTBDriver $driver The driver instance being used.
     * @return string|null An SQL fragment, or `null` in case the column isn't processed by this type.
     */
    function getColumnSql(TableSchemaInterface $schema, string $column, IDTBDriver $driver): ?string;

    /**
     * Convert a SQL column definition to an abstract type definition.
     *
     * @param array $definition The column definition.
     * @param \Cake\Database\IDTBDriver $driver The driver instance being used.
     * @return array<string, mixed>|null Array of column information, or `null` in case the column isn't processed by this type.
     */
    function convertColumnDefinition(array $definition, IDTBDriver $driver): ?array;
}
