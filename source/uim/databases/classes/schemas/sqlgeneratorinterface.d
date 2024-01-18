module uim.databases.schemas;

import uim.cake;

@safe:

/**
 * An interface used by TableSchema objects.
 */
interface ISqlGenerator {
    /**
     * Generate the SQL to create the Table.
     *
     * Uses the connection to access the schema dialect
     * to generate platform specific SQL.
     * Params:
     * \UIM\Database\Connection aConnection The connection to generate SQL for.
     */
    array createSql(Connection aConnection);

    /**
     * Generate the SQL to drop a table.
     *
     * Uses the connection to access the schema dialect to generate platform
     * specific SQL.
     * Params:
     * \UIM\Database\Connection aConnection The connection to generate SQL for.
     */
    array dropSql(Connection aConnection);

    // Generate the SQL statements to truncate a table
    array truncateSql(Connection sqlConnection);

    /**
     * Generate the SQL statements to add the constraints to the table
     * Params:
     * \UIM\Database\Connection aConnection The connection to generate SQL for.
     */
    array addConstraintSql(Connection aConnection);

    /**
     * Generate the SQL statements to drop the constraints to the table
     * Params:
     * \UIM\Database\Connection aConnection The connection to generate SQL for.
     */
    array dropConstraintSql(Connection aConnection);
}
