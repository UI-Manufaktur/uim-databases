module uim.databases.schemas;

import uim.databases.exceptions.DatabaseException;

use uim.databases.Exception\DatabaseException;

/**
 * Schema management/reflection features for Postgres.
 *
 * @internal
 */
class PostgresSchemaDialect : SchemaDialect
{
    /**
     * Generate the SQL to list the tables and views.
     *
     * @param array<string, mixed> config The connection configuration to use for
     *    getting tables from.
     * @return array An array of (sql, params) to execute.
     */
    function listTablesSql(array aConfig): array
    {
        mySql = "SELECT table_name as name FROM information_schema.tables
                WHERE table_schema = ? ORDER BY name";
        schema = empty(config["schema"]) ? "public" : config["schema"];

        return [mySql, [schema]];
    }

    /**
     * Generate the SQL to list the tables, excluding all views.
     *
     * @param array<string, mixed> config The connection configuration to use for
     *    getting tables from.
     * @return array<mixed> An array of (sql, params) to execute.
     */
    function listTablesWithoutViewsSql(array aConfig): array
    {
        mySql = "SELECT table_name as name FROM information_schema.tables
                WHERE table_schema = ? AND table_type = \"BASE TABLE\" ORDER BY name";
        schema = empty(config["schema"]) ? "public" : config["schema"];

        return [mySql, [schema]];
    }


    function describeColumnSql(string tableName, array aConfig): array
    {
        mySql = "SELECT DISTINCT table_schema AS schema,
            column_name AS name,
            data_type AS type,
            is_nullable AS null, column_default AS default,
            character_maximum_length AS char_length,
            c.collation_name,
            d.description as comment,
            ordinal_position,
            c.datetime_precision,
            c.numeric_precision as column_precision,
            c.numeric_scale as column_scale,
            pg_get_serial_sequence(attr.attrelid::regclass::text, attr.attname) IS NOT NULL AS has_serial
        FROM information_schema.columns c
        INNER JOIN pg_catalog.pg_namespace ns ON (ns.nspname = table_schema)
        INNER JOIN pg_catalog.pg_class cl ON (cl.relnamespace = ns.oid AND cl.relname = table_name)
        LEFT JOIN pg_catalog.pg_index i ON (i.indrelid = cl.oid AND i.indkey[0] = c.ordinal_position)
        LEFT JOIN pg_catalog.pg_description d on (cl.oid = d.objoid AND d.objsubid = c.ordinal_position)
        LEFT JOIN pg_catalog.pg_attribute attr ON (cl.oid = attr.attrelid AND column_name = attr.attname)
        WHERE table_name = ? AND table_schema = ? AND table_catalog = ?
        ORDER BY ordinal_position";

        schema = empty(config["schema"]) ? "public" : config["schema"];

        return [mySql, [tableName, schema, config["database"]]];
    }

    /**
     * Convert a column definition to the abstract types.
     *
     * The returned type will be a type that
     * uim.databases.TypeFactory can handle.
     *
     * @param string column The column type + length
     * @throws uim.databases.Exception\DatabaseException when column cannot be parsed.
     * @return array<string, mixed> Array of column information.
     */
    protected array _convertColumn(string column) {
        preg_match("/([a-z\s]+)(?:\(([0-9,]+)\))?/i", column, matches);
        if (empty(matches)) {
            throw new DatabaseException(sprintf("Unable to parse column type from "%s"", column));
        }

        string colType = matches[1].toLower;
        length = precision = scale = null;
        if (isset(matches[2])) {
            length = (int)matches[2];
        }

        type = this._applyTypeSpecificColumnConversion(
            colType,
            compact("length", "precision", "scale")
        );
        if (type != null) {
            return type;
        }

        if (colType.isIn(["date", "time", "boolean"])) {
            return ["type" : colType, "length" : null];
        }
        if (colType.isIn(["timestamptz", "timestamp with time zone"])) {
            return ["type" : TableTypes.TIMESTAMP_TIMEZONE, "length" : null];
        }
        if (strpos(colType, "timestamp") != false) {
            return ["type" : TableTypes.TIMESTAMP_FRACTIONAL, "length" : null];
        }
        if (strpos(colType, "time") != false) {
            return ["type" : TableTypes.TIME, "length" : null];
        }
        if (colType == "serial" || colType == "integer") {
            return ["type" : TableTypes.INTEGER, "length" : 10];
        }
        if (colType == "bigserial" || colType == "bigint") {
            return ["type" : TableTypes.BIGINTEGER, "length" : 20];
        }
        if (colType == "smallint") {
            return ["type" : TableTypes.SMALLINTEGER, "length" : 5];
        }
        if (colType == "inet") {
            return ["type" : TableTypes.STRING, "length" : 39];
        }
        if (colType == "uuid") {
            return ["type" : TableTypes.UUID, "length" : null];
        }
        if (colType == "char") {
            return ["type" : TableTypes.CHAR, "length" : length];
        }
        if (strpos(colType, "character") != false) {
            return ["type" : TableTypes.STRING, "length" : length];
        }
        // money is "string" as it includes arbitrary text content
        // before the number value.
        if (strpos(colType, "money") != false || colType == "string") {
            return ["type" : TableTypes.STRING, "length" : length];
        }
        if (strpos(colType, "text") != false) {
            return ["type" : TableTypes.TEXT, "length" : null];
        }
        if (colType == "bytea") {
            return ["type" : TableTypes.BINARY, "length" : null];
        }
        if (colType == "real" || strpos(colType, "double") != false) {
            return ["type" : TableTypes.FLOAT, "length" : null];
        }
        if (
            strpos(colType, "numeric") != false ||
            strpos(colType, "decimal") != false
        ) {
            return ["type" : TableTypes.DECIMAL, "length" : null];
        }

        if (strpos(colType, "json") != false) {
            return ["type" : TableTypes.JSON, "length" : null];
        }

        length = is_numeric(length) ? length : null;

        return ["type" : TableTypes.STRING, "length" : length];
    }


    void convertColumnDescription(TableSchema aSchema, array aRow) {
        field = this._convertColumn(aRow["type"]);

        if (field["type"] == TableTypes.BOOLEAN) {
            if (aRow["default"] == "true") {
                aRow["default"] = 1;
            }
            if (aRow["default"] == "false") {
                aRow["default"] = 0;
            }
        }
        if (!empty(aRow["has_serial"])) {
            field["autoIncrement"] = true;
        }

        field += [
            "default" : this._defaultValue(aRow["default"]),
            "null" : aRow["null"] == "YES",
            "collate" : aRow["collation_name"],
            "comment" : aRow["comment"],
        ];
        field["length"] = aRow["char_length"] ?: field["length"];

        if (field["type"] == "numeric" || field["type"] == "decimal") {
            field["length"] = aRow["column_precision"];
            field["precision"] = aRow["column_scale"] ?: null;
        }

        if (field["type"] == TableTypes.TIMESTAMP_FRACTIONAL) {
            field["precision"] = aRow["datetime_precision"];
            if (field["precision"] == 0) {
                field["type"] = TableTypes.TIMESTAMP;
            }
        }

        if (field["type"] == TableTypes.TIMESTAMP_TIMEZONE) {
            field["precision"] = aRow["datetime_precision"];
        }

        schema.addColumn(aRow["name"], field);
    }

    /**
     * Manipulate the default value.
     *
     * Postgres includes sequence data and casting information in default values.
     * We need to remove those.
     *
     * @param string|int|null default The default value.
     * @return string|int|null
     */
    protected function _defaultValue(default)
    {
        if (is_numeric(default) || default == null) {
            return default;
        }
        // Sequences
        if (strpos(default, "nextval") == 0) {
            return null;
        }

        if (strpos(default, "NULL::") == 0) {
            return null;
        }

        // Remove quotes and postgres casts
        return preg_replace(
            "/^"(.*)"(?:::.*)/",
            "1",
            default
        );
    }


    function describeIndexSql(string tableName, array aConfig): array
    {
        mySql = "SELECT
        c2.relname,
        a.attname,
        i.indisprimary,
        i.indisunique
        FROM pg_catalog.pg_namespace n
        INNER JOIN pg_catalog.pg_class c ON (n.oid = c.relnamespace)
        INNER JOIN pg_catalog.pg_index i ON (c.oid = i.indrelid)
        INNER JOIN pg_catalog.pg_class c2 ON (c2.oid = i.indexrelid)
        INNER JOIN pg_catalog.pg_attribute a ON (a.attrelid = c.oid AND i.indrelid::regclass = a.attrelid::regclass)
        WHERE n.nspname = ?
        AND a.attnum = ANY(i.indkey)
        AND c.relname = ?
        ORDER BY i.indisprimary DESC, i.indisunique DESC, c.relname, a.attnum";

        schema = "public";
        if (!empty(config["schema"])) {
            schema = config["schema"];
        }

        return [mySql, [schema, tableName]];
    }


    function convertIndexDescription(TableSchema aSchema, array aRow): void
    {
        type = TableSchema::INDEX_INDEX;
        name = aRow["relname"];
        if (aRow["indisprimary"]) {
            name = type = TableSchema::CONSTRAINT_PRIMARY;
        }
        if (aRow["indisunique"] && type == TableSchema::INDEX_INDEX) {
            type = TableSchema::CONSTRAINT_UNIQUE;
        }
        if (type == TableSchema::CONSTRAINT_PRIMARY || type == TableSchema::CONSTRAINT_UNIQUE) {
            this._convertConstraint(schema, name, type, aRow);

            return;
        }
        index = schema.getIndex(name);
        if (!index) {
            index = [
                "type" : type,
                "columns" : [],
            ];
        }
        index["columns"][] = aRow["attname"];
        schema.addIndex(name, index);
    }

    /**
     * Add/update a constraint into the schema object.
     *
     * @param uim.databases.Schema\TableSchema aSchema The table to update.
     * @param string name The index name.
     * @param string type The index type.
     * @param array aRow The metadata record to update with.
     * @return void
     */
    protected function _convertConstraint(TableSchema aSchema, string name, string type, array aRow): void
    {
        constraint = schema.getConstraint(name);
        if (!constraint) {
            constraint = [
                "type" : type,
                "columns" : [],
            ];
        }
        constraint["columns"][] = aRow["attname"];
        schema.addConstraint(name, constraint);
    }


    function describeForeignKeySql(string tableName, array aConfig): array
    {
        // phpcs:disable Generic.Files.LineLength
        mySql = "SELECT
        c.conname AS name,
        c.contype AS type,
        a.attname AS column_name,
        c.confmatchtype AS match_type,
        c.confupdtype AS on_update,
        c.confdeltype AS on_delete,
        c.confrelid::regclass AS references_table,
        ab.attname AS references_field
        FROM pg_catalog.pg_namespace n
        INNER JOIN pg_catalog.pg_class cl ON (n.oid = cl.relnamespace)
        INNER JOIN pg_catalog.pg_constraint c ON (n.oid = c.connamespace)
        INNER JOIN pg_catalog.pg_attribute a ON (a.attrelid = cl.oid AND c.conrelid = a.attrelid AND a.attnum = ANY(c.conkey))
        INNER JOIN pg_catalog.pg_attribute ab ON (a.attrelid = cl.oid AND c.confrelid = ab.attrelid AND ab.attnum = ANY(c.confkey))
        WHERE n.nspname = ?
        AND cl.relname = ?
        ORDER BY name, a.attnum, ab.attnum DESC";
        // phpcs:enable Generic.Files.LineLength

        schema = empty(config["schema"]) ? "public" : config["schema"];

        return [mySql, [schema, tableName]];
    }


    function convertForeignKeyDescription(TableSchema aSchema, array aRow): void
    {
        data = [
            "type" : TableSchema::CONSTRAINT_FOREIGN,
            "columns" : aRow["column_name"],
            "references" : [aRow["references_table"], aRow["references_field"]],
            "update" : this._convertOnClause(aRow["on_update"]),
            "delete" : this._convertOnClause(aRow["on_delete"]),
        ];
        schema.addConstraint(aRow["name"], data);
    }


    protected function _convertOnClause(string clause): string
    {
        if (clause == "r") {
            return TableSchema::ACTION_RESTRICT;
        }
        if (clause == "a") {
            return TableSchema::ACTION_NO_ACTION;
        }
        if (clause == "c") {
            return TableSchema::ACTION_CASCADE;
        }

        return TableSchema::ACTION_SET_NULL;
    }


    string columnSql(TableSchema aSchema, string name) {
        /** @var array data */
        data = schema.getColumn(name);

        mySql = this._getTypeSpecificColumnSql(data["type"], schema, name);
        if (mySql != null) {
            return mySql;
        }

        string out = this._driver.quoteIdentifier(name);
        typeMap = [
            TableTypes.TINYINTEGER : " SMALLINT",
            TableTypes.SMALLINTEGER : " SMALLINT",
            TableTypes.BINARY_UUID : " UUID",
            TableTypes.BOOLEAN : " BOOLEAN",
            TableTypes.FLOAT : " FLOAT",
            TableTypes.DECIMAL : " DECIMAL",
            TableTypes.DATE : " DATE",
            TableTypes.TIME : " TIME",
            TableTypes.DATETIME : " TIMESTAMP",
            TableTypes.DATETIME_FRACTIONAL : " TIMESTAMP",
            TableTypes.TIMESTAMP : " TIMESTAMP",
            TableTypes.TIMESTAMP_FRACTIONAL : " TIMESTAMP",
            TableTypes.TIMESTAMP_TIMEZONE : " TIMESTAMPTZ",
            TableTypes.UUID : " UUID",
            TableTypes.CHAR : " CHAR",
            TableTypes.JSON : " JSONB",
        ];

        if (isset(typeMap[data["type"]])) {
            out ~= typeMap[data["type"]];
        }

        if (data["type"] == TableTypes.INTEGER || data["type"] == TableTypes.BIGINTEGER) {
            type = data["type"] == TableTypes.INTEGER ? " INTEGER" : " BIGINT";
            if (schema.getPrimaryKey() == [name] || data["autoIncrement"] == true) {
                type = data["type"] == TableTypes.INTEGER ? " SERIAL" : " BIGSERIAL";
                unset(data["null"], data["default"]);
            }
            out ~= type;
        }

        if (data["type"] == TableTypes.TEXT && data["length"] != TableSchema::LENGTH_TINY) {
            out ~= " TEXT";
        }
        if (data["type"] == TableTypes.BINARY) {
            out ~= " BYTEA";
        }

        if (data["type"] == TableTypes.CHAR) {
            out ~= "(" . data["length"] . ")";
        }

        if (
            data["type"] == TableTypes.STRING ||
            (
                data["type"] == TableTypes.TEXT &&
                data["length"] == TableSchema::LENGTH_TINY
            )
        ) {
            out ~= " VARCHAR";
            if (isset(data["length"]) && data["length"] != "") {
                out ~= "(" . data["length"] . ")";
            }
        }

        hasCollate = [TableTypes.TEXT, TableTypes.STRING, TableTypes.CHAR];
        if (in_array(data["type"], hasCollate, true) && isset(data["collate"]) && data["collate"] != "") {
            out ~= " COLLATE "" . data["collate"] . """;
        }

        hasPrecision = [
            TableTypes.FLOAT,
            TableTypes.DATETIME,
            TableTypes.DATETIME_FRACTIONAL,
            TableTypes.TIMESTAMP,
            TableTypes.TIMESTAMP_FRACTIONAL,
            TableTypes.TIMESTAMP_TIMEZONE,
        ];
        if (in_array(data["type"], hasPrecision) && isset(data["precision"])) {
            out ~= "(" . data["precision"] . ")";
        }

        if (
            data["type"] == TableTypes.DECIMAL &&
            (
                isset(data["length"]) ||
                isset(data["precision"])
            )
        ) {
            out ~= "(" . data["length"] . "," . (int)data["precision"] . ")";
        }

        if (isset(data["null"]) && data["null"] == false) {
            out ~= " NOT NULL";
        }

        datetimeTypes = [
            TableTypes.DATETIME,
            TableTypes.DATETIME_FRACTIONAL,
            TableTypes.TIMESTAMP,
            TableTypes.TIMESTAMP_FRACTIONAL,
            TableTypes.TIMESTAMP_TIMEZONE,
        ];
        if (
            isset(data["default"]) &&
            in_array(data["type"], datetimeTypes) &&
            strtolower(data["default"]) == "current_timestamp"
        ) {
            out ~= " DEFAULT CURRENT_TIMESTAMP";
        } elseif (isset(data["default"])) {
            defaultValue = data["default"];
            if (data["type"] == "boolean") {
                defaultValue = (bool)defaultValue;
            }
            out ~= " DEFAULT " . this._driver.schemaValue(defaultValue);
        } elseif (isset(data["null"]) && data["null"] != false) {
            out ~= " DEFAULT NULL";
        }

        return out;
    }


    function addConstraintSql(TableSchema aSchema): array
    {
        mySqlPattern = "ALTER TABLE %s ADD %s;";
        mySql = [];

        foreach (schema.constraints() as name) {
            /** @var array constraint */
            constraint = schema.getConstraint(name);
            if (constraint["type"] == TableSchema::CONSTRAINT_FOREIGN) {
                tableName = this._driver.quoteIdentifier(schema.name());
                mySql[] = sprintf(mySqlPattern, tableName, this.constraintSql(schema, name));
            }
        }

        return mySql;
    }


    function dropConstraintSql(TableSchema aSchema): array
    {
        mySqlPattern = "ALTER TABLE %s DROP CONSTRAINT %s;";
        mySql = [];

        foreach (schema.constraints() as name) {
            /** @var array constraint */
            constraint = schema.getConstraint(name);
            if (constraint["type"] == TableSchema::CONSTRAINT_FOREIGN) {
                tableName = this._driver.quoteIdentifier(schema.name());
                constraintName = this._driver.quoteIdentifier(name);
                mySql[] = sprintf(mySqlPattern, tableName, constraintName);
            }
        }

        return mySql;
    }


    function indexSql(TableSchema aSchema, string name): string
    {
        /** @var array data */
        data = schema.getIndex(name);
        columns = array_map(
            [this._driver, "quoteIdentifier"],
            data["columns"]
        );

        return sprintf(
            "CREATE INDEX %s ON %s (%s)",
            this._driver.quoteIdentifier(name),
            this._driver.quoteIdentifier(schema.name()),
            implode(", ", columns)
        );
    }


    function constraintSql(TableSchema aSchema, string name): string
    {
        /** @var array<string, mixed> data */
        data = schema.getConstraint(name);
        out = "CONSTRAINT " . this._driver.quoteIdentifier(name);
        if (data["type"] == TableSchema::CONSTRAINT_PRIMARY) {
            out = "PRIMARY KEY";
        }
        if (data["type"] == TableSchema::CONSTRAINT_UNIQUE) {
            out ~= " UNIQUE";
        }

        return this._keySql(out, data);
    }

    /**
     * Helper method for generating key SQL snippets.
     *
     * @param string prefix The key prefix
     * @param array<string, mixed> data Key data.
     * @return string
     */
    protected function _keySql(string prefix, array data): string
    {
        columns = array_map(
            [this._driver, "quoteIdentifier"],
            data["columns"]
        );
        if (data["type"] == TableSchema::CONSTRAINT_FOREIGN) {
            return prefix . sprintf(
                " FOREIGN KEY (%s) REFERENCES %s (%s) ON UPDATE %s ON DELETE %s DEFERRABLE INITIALLY IMMEDIATE",
                implode(", ", columns),
                this._driver.quoteIdentifier(data["references"][0]),
                this._convertConstraintColumns(data["references"][1]),
                this._foreignOnClause(data["update"]),
                this._foreignOnClause(data["delete"])
            );
        }

        return prefix . " (" . implode(", ", columns) . ")";
    }


    function createTableSql(TableSchema aSchema, array columns, array constraints, array indexes): array
    {
        content = array_merge(columns, constraints);
        content = implode(",\n", array_filter(content));
        tableName = this._driver.quoteIdentifier(schema.name());
        temporary = schema.isTemporary() ? " TEMPORARY " : " ";
        out = [];
        out[] = sprintf("CREATE%sTABLE %s (\n%s\n)", temporary, tableName, content);
        foreach (indexes as index) {
            out[] = index;
        }
        foreach (schema.columns() as column) {
            columnData = schema.getColumn(column);
            if (isset(columnData["comment"])) {
                out[] = sprintf(
                    "COMMENT ON COLUMN %s.%s IS %s",
                    tableName,
                    this._driver.quoteIdentifier(column),
                    this._driver.schemaValue(columnData["comment"])
                );
            }
        }

        return out;
    }


    function truncateTableSql(TableSchema aSchema): array
    {
        name = this._driver.quoteIdentifier(schema.name());

        return [
            sprintf("TRUNCATE %s RESTART IDENTITY CASCADE", name),
        ];
    }

    /**
     * Generate the SQL to drop a table.
     *
     * @param uim.databases.Schema\TableSchema aSchema Table instance
     * @return array SQL statements to drop a table.
     */
    function dropTableSql(TableSchema aSchema): array
    {
        mySql = sprintf(
            "DROP TABLE %s CASCADE",
            this._driver.quoteIdentifier(schema.name())
        );

        return [mySql];
    }
}

// phpcs:disable
// Add backwards compatible alias.
class_alias("uim.databases.Schema\PostgresSchemaDialect", "uim.databases.Schema\PostgresSchema");
// phpcs:enable
