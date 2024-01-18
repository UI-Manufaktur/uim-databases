module uim.databases.schemas;

import uim.cake;

@safe:

/**
 * Base class for schema implementations.
 *
 * This class contains methods that are common across
 * the various SQL dialects.
 *
 * @method array<mixed> listTablesWithoutViewsSql(Json[string] configData = null) Generate the SQL to list the tables, excluding all views.
 */
abstract class SchemaDialect
{
    // The driver instance being used.
    protected Driver _driver;

    /**
     * Constructor
     *
     * This constructor will connect the driver so that methods like columnSql() and others
     * will fail when the driver has not been connected.
     * Params:
     * \UIM\Database\Driver aDriver The driver to use.
     */
    this(Driver aDriver) {
        aDriver.connect();
       _driver = aDriver;
    }
    
    /**
     * Generate an ON clause for a foreign key.
     * Params:
     * string anOnClouse The on clause
     */
    protected string _foreignOnClause(string anOnClouse) {
        if (anOnClouse == TableSchema.ACTION_SET_NULL) {
            return "SET NULL";
        }
        if (anOnClouse == TableSchema.ACTION_SET_DEFAULT) {
            return "SET DEFAULT";
        }
        if (anOnClouse == TableSchema.ACTION_CASCADE) {
            return "CASCADE";
        }
        if (anOnClouse == TableSchema.ACTION_RESTRICT) {
            return "RESTRICT";
        }
        if (anOnClouse == TableSchema.ACTION_NO_ACTION) {
            return "NO ACTION";
        }
        throw new InvalidArgumentException("Invalid value for "on": " ~ anOnClouse);
    }
    
    /**
     * Convert string on clauses to the abstract ones.
     * Params:
     * string clauseToConvert The on clause to convert.
     */
    protected string _convertOnClause(string clauseToConvert) {
        if (clauseToConvert == "CASCADE" || clauseToConvert == "RESTRICT") {
            return clauseToConvert.toLower;
        }
        if (clauseToConvert == "NO ACTION") {
            return TableSchema.ACTION_NO_ACTION;
        }
        return TableSchema.ACTION_SET_NULL;
    }
    
    /**
     * Convert foreign key constraints references to a valid
     * stringified list
     * Params:
     * string[]|string areferences The referenced columns of a foreign key constraint statement
     */
    protected string _convertConstraintColumns(string[] areferences) {
        if (isString($references)) {
            return _driver.quoteIdentifier($references);
        }
        return join(", ", array_map(
            [_driver, "quoteIdentifier"],
            $references
        ));
    }
    
    /**
     * Tries to use a matching database type to generate the SQL
     * fragment for a single column in a table.
     * Params:
     * string acolumnType The column type.
     * @param \UIM\Database\Schema\TableISchema tableSchema The table schema instance the column is in.
     * @param string acolumn The name of the column.
     */
    protected string _getTypeSpecificColumnSql(
        string acolumnType,
        TableISchema tableSchema,
        string acolumn
    ) {
        if (!TypeFactory.getMap($columnType)) {
            return null;
        }
        $type = TypeFactory.build($columnType);
        if (!(cast(IColumnSchemaAware)$type)) {
            return null;
        }
        return $type.getColumnSql(tableSchema, $column, _driver);
    }
    
    /**
     * Tries to use a matching database type to convert a SQL column
     * definition to an abstract type definition.
     * Params:
     * string acolumnType The column type.
     * @param array $definition The column definition.
     */
    protected array _applyTypeSpecificColumnConversion(string acolumnType, array $definition) {
        if (!TypeFactory.getMap($columnType)) {
            return null;
        }
        $type = TypeFactory.build($columnType);
        if (!(cast(IColumnSchemaAware)$type)) {
            return null;
        }
        return $type.convertColumnDefinition($definition, _driver);
    }
    
    // Generate the SQL to drop a table.
    string[] dropTableSql(TableSchema schema) {
        string sql = "DROP TABLE %s"
            .format(_driver.quoteIdentifier(schema.name()));

        return [sql];
    }
    
    /**
     * Generate the SQL to list the tables.
     * Params:
     * Json[string] configData The connection configuration to use for
     *   getting tables from.
     */
    abstract array listTablesSql(Json[string] configData = null);

    /**
     * Generate the SQL to describe a table.
     * Params:
     * string atableName The table name to get information on.
     * @param Json[string] configData The connection configuration.
     */
    abstract array describeColumnSql(string atableName, Json[string] configData);

    /**
     * Generate the SQL to describe the indexes in a table.
     * Params:
     * string atableName The table name to get information on.
     * @param Json[string] configData The connection configuration.
     */
    abstract array describeIndexSql(string atableName, Json[string] configData = null);

    /**
     * Generate the SQL to describe the foreign keys in a table.
     * Params:
     * string atableName The table name to get information on.
     * configData - The connection configuration.
     */
    abstract array describeForeignKeySql(string atableName, Json[string] configData);

    /**
     * Generate the SQL to describe table options
     * Params:
     * string atableName Table name.
     * configData - The connection configuration.
     */
    array describeOptionsSql(string atableName, Json[string] configData) {
        return ["", ""];
    }
    
    /**
     * Convert field description results into abstract schema fields.
     * Params:
     * \UIM\Database\Schema\TableSchema tableSchema The table object to append fields to.
     * @param array $row The row data from `describeColumnSql`.
     */
    abstract void convertColumnDescription(TableSchema tableSchema, array $row);

    /**
     * Convert an index description results into abstract schema indexes or constraints.
     * Params:
     * \UIM\Database\Schema\TableSchema tableSchema The table object to append
     *   an index or constraint to.
     * @param array $row The row data from `describeIndexSql`.
     */
    abstract void convertIndexDescription(TableSchema tableSchema, array $row);

    /**
     * Convert a foreign key description into constraints on the Table object.
     * Params:
     * \UIM\Database\Schema\TableSchema tableSchema The table object to append
     *   a constraint to.
     * @param array $row The row data from `describeForeignKeySql`.
     */
    abstract void convertForeignKeyDescription(TableSchema tableSchema, array $row);

    /**
     * Convert options data into table options.
     * Params:
     * \UIM\Database\Schema\TableSchema tableSchema Table instance.
     * @param array $row The row of data.
     */
    void convertOptionsDescription(TableSchema tableSchema, array $row) {
    }
    
    /**
     * Generate the SQL to create a table.
     * Params:
     * \UIM\Database\Schema\TableSchema tableSchema Table instance.
     * @param string[] someColumns The columns to go inside the table.
     * @param string[] $constraints The constraints for the table.
     * @param string[] anIndexes The indexes for the table.
     * returns = SQL statements to create a table.
     */
    abstract string[] createTableSql(
        TableSchema tableSchema,
        string[] someColumns,
        string[] $constraints,
        string[] anIndexes
    );

    /**
     * Generate the SQL fragment for a single column in a table.
     * Params:
     * \UIM\Database\Schema\TableSchema tableSchema The table instance the column is in.
     * @param string aName The name of the column.
     */
    abstract string columnSql(TableSchema tableSchema, string columnName);

    /**
     * Generate the SQL queries needed to add foreign key constraints to the table
     * Params:
     * \UIM\Database\Schema\TableSchema tableSchema The table instance the foreign key constraints are.
     */
    abstract array addConstraintSql(TableSchema tableSchema);

    /**
     * Generate the SQL queries needed to drop foreign key constraints from the table
     * Params:
     * \UIM\Database\Schema\TableSchema tableSchema The table instance the foreign key constraints are.
     */
    abstract array dropConstraintSql(TableSchema tableSchema);

    /**
     * Generate the SQL fragments for defining table constraints.
     * Params:
     * \UIM\Database\Schema\TableSchema tableSchema The table instance the column is in.
     * @param string aName The name of the column.
     */
    abstract string constraintSql(TableSchema tableSchema, string aName);

    /**
     * Generate the SQL fragment for a single index in a table.
     * Params:
     * \UIM\Database\Schema\TableSchema tableSchema The table object the column is in.
     * @param string aName The name of the column.
     */
    abstract string indexSql(TableSchema tableSchema, string aName);

    /**
     * Generate the SQL to truncate a table.
     * Params:
     * \UIM\Database\Schema\TableSchema tableSchema Table instance.
     */
    abstract array truncateTableSql(TableSchema tableSchema);
}
