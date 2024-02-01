module uim.cake.databases.schemas;

import uim.cake;

@safe:

// An interface used by database TableSchema objects.
interface TableISchema : ISchema {
    // Binary column type
    const string TYPE_BINARY = "binary";

    // Binary UUID column type
    const string TYPE_BINARY_UUID = "binaryuuid";

    // Date column type
    const string TYPE_DATE = "date";

    /**
     * Datetime column type
     */
    const string TYPE_DATETIME = "datetime";

    /**
     * Datetime with fractional seconds column type
     */
    const string TYPE_DATETIME_FRACTIONAL = "datetimefractional";

    /**
     * Time column type
     */
    const string TYPE_TIME = "time";

    /**
     * Timestamp column type
     */
    const string TYPE_TIMESTAMP = "timestamp";

    /**
     * Timestamp with fractional seconds column type
     */
    const string TYPE_TIMESTAMP_FRACTIONAL = "timestampfractional";

    /**
     * Timestamp with time zone column type
     */
    const string TYPE_TIMESTAMP_TIMEZONE = "timestamptimezone";

    // JSON column type
    const string TYPE_JSON = "json";

    /**
     * String column type
     */
    const string TYPE_STRING = "String";

    /**
     * Char column type
     */
    const string TYPE_CHAR = "char";

    /**
     * Text column type
     */
    const string TYPE_TEXT = "text";

    /**
     * Tiny Integer column type
     */
    const string TYPE_TINYINTEGER = "tinyinteger";

    /**
     * Small Integer column type
     */
    const string TYPE_SMALLINTEGER = "Smallinteger";

    /**
     * Integer column type
     */
    const string TYPE_INTEGER = "integer";

    /**
     * Big Integer column type
     */
    const string TYPE_BIGINTEGER = "biginteger";

    /**
     * Float column type
     */
    const string TYPE_FLOAT = "float";

    /**
     * Decimal column type
     */
    const string TYPE_DECIMAL = "decimal";

    /**
     * Boolean column type
     */
    const string TYPE_BOOLEAN = "boolean";

    /**
     * UUID column type
     */
    const string TYPE_UUID = "uuid";

    /**
     * Check whether a table has an autoIncrement column defined.
     */
   bool hasAutoincrement();

    /**
     * Sets whether the table is temporary in the database.
     * Params:
     * bool temporary Whether the table is to be temporary.
     */
    auto setTemporary(bool temporary);

    // Gets whether the table is temporary in the database.
    bool isTemporary();

    /**
     * Get the column(s) used for the primary key.
     */
    string[] getPrimaryKey();

    /**
     * Add an index.
     *
     * Used to add indexes, and full text indexes in platforms that support
     * them.
     *
     * ### Attributes
     *
     * - `type` The type of index being added.
     * - `columns` The columns in the index.
     * Params:
     * string aName The name of the index.
     * @param Json[string]|string aattrs The attributes for the index.
     *  If string it will be used as `type`.
     */
    void addIndex(string aName, string[] aattrs);

    /**
     * Read information about an index based on name.
     * Params:
     * string aName The name of the index.
     */
    Json[string] getIndex(string indexName);

    /**
     * Get the names of all the indexes in the table.
     */
    string[] indexNames();

    /**
     * Add a constraint.
     *
     * Used to add constraints to a table. For example primary keys, unique
     * keys and foreign keys.
     *
     * ### Attributes
     *
     * - `type` The type of constraint being added.
     * - `columns` The columns in the index.
     * - `references` The table, column a foreign key references.
     * - `update` The behavior on update. Options are 'restrict", "setNull", "cascade", "noAction'.
     * - `delete` The behavior on delete. Options are 'restrict", "setNull", "cascade", "noAction'.
     *
     * The default for 'update' & 'delete' is 'cascade'.
     * Params:
     * string aName The name of the constraint.
     * @param Json[string]|string aattrs The attributes for the constraint.
     *  If string it will be used as `type`.
     */
    void addConstraint(string aName, string[] aattrs);

    /**
     * Read information about a constraint based on name.
     * Params:
     * string aName The name of the constraint.
     */
    Json[string] getConstraint(string aName);

    // Remove a constraint.
    auto dropConstraint(string constraintName);

    // Get the names of all the constraints in the table.
    string[] constraintNames();
}
