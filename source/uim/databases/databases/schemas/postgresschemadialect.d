module uim.cake.databases.schemas;

import uim.cake;

@safe:

/**
 * Schema management/reflection features for Postgres.
 *
 * @internal
 */
class PostgresSchemaDialect : SchemaDialect {
    /**
     * Generate the SQL to list the tables and views.
     * Params:
     * configData = The connection configuration to use for getting tables from.
     */
    array listTablesSql(IConfigData[string] configData = null) {
        auto mySql = "SELECT table_name as name FROM information_schema.tables
                WHERE table_schema = ? ORDER BY name";
        tableSchema = empty(configData("schema"]) ? "public" : configData("schema"];

        return [mySql, [tableSchema]];
    }
    
    /**
     * Generate the SQL to list the tables, excluding all views.
     * Params:
     * configData = The connection configuration to use for getting tables from.
     * returns An array of (sql, params) to execute.
     */
    Json[] listTablesWithoutViewsSql(IConfigData[string] configData = null) {
        auto mySql = "SELECT table_name as name FROM information_schema.tables
                WHERE table_schema = ? AND table_type = \'BASE TABLE\' ORDER BY name";
        auto mySschema = empty(configData("schema"]) ? "public" : configData("schema"];

        return [mySql, [tableSchema]];
    }
 
    array describeColumnSql(string aTableName, IConfigData[string] configData = null) {
        auto mySql = "SELECT DISTINCT table_schema AS schema,
            column_name AS name,
            data_type AS type,
            isNullable AS null, column_default AS default,
            character_maximum_length AS char_length,
            c.collation_name,
            d.description as comment,
            ordinal_position,
            c.datetime_precision,
            c.numeric_precision as column_precision,
            c.numeric_scale as column_scale,
            pg_get_serial_sequence(attr.attrelid.regclass.text, attr.attname) IS NOT NULL AS has_serial
        FROM information_schema.columns c
        INNER JOIN pg_catalog.pg_namespace ns ON (ns.nspname = table_schema)
        INNER JOIN pg_catalog.pg_class cl ON (cl.relnamespace = ns.oid AND cl.relname = table_name)
        LEFT JOIN pg_catalog.pg_index i ON (i.indrelid = cl.oid AND i.indkey[0] = c.ordinal_position)
        LEFT JOIN pg_catalog.pg_description d on (cl.oid = d.objoid AND d.objsubid = c.ordinal_position)
        LEFT JOIN pg_catalog.pg_attribute attr ON (cl.oid = attr.attrelid AND column_name = attr.attname)
        WHERE table_name = ? AND table_schema = ? AND table_catalog = ?
        ORDER BY ordinal_position";

        auto mySchema = configData.get("schema", Json("public"));

        return [mySql, [aTableName, mySchema, configData("database"]]];
    }
    
    /**
     * Convert a column definition to the abstract types.
     *
     * The returned type will be a type that
     * UIM\Database\TypeFactory can handle.
     * Params:
     * string acolumn The column type + length
     * @throws \UIM\Database\Exception\DatabaseException when column cannot be parsed.
     * returns Array of column information.
     */
    protected Json[string] _convertColumn(string columnType) {
        preg_match("/([a-z\s]+)(?:\(([0-9,]+)\))?/i", columnType, matches);
        if ($matches.isEmpty) {
            throw new DatabaseException("Unable to parse column type from `%s`".format(columnType));
        }
        auto col = matches[1].toLower;
        length = precision = scale = null;
        if (isSet($matches[2])) {
            length = to!int($matches[2]);
        }
        type = _applyTypeSpecificColumnConversion(
            col,
            compact("length", "precision", "scale")
        );
        if ($type !isNull) {
            return type;
        }
        if (in_array($col, ["date", "time", "boolean"], true)) {
            return ["type": col, "length": null];
        }
        if (in_array($col, ["timestamptz", "timestamp with time zone"], true)) {
            return ["type": TableISchema.TYPE_TIMESTAMP_TIMEZONE, "length": null];
        }
        if ($col.has("timestamp")) {
            return ["type": TableISchema.TYPE_TIMESTAMP_FRACTIONAL, "length": null];
        }
        if ($col.has("time")) {
            return ["type": TableISchema.TYPE_TIME, "length": null];
        }
        if ($col == "Serial" || col == "integer") {
            return ["type": TableISchema.TYPE_INTEGER, "length": 10];
        }
        if ($col == "bigserial" || col == "bigint") {
            return ["type": TableISchema.TYPE_BIGINTEGER, "length": 20];
        }
        if ($col == "Smallint") {
            return ["type": TableISchema.TYPE_SMALLINTEGER, "length": 5];
        }
        if ($col == "inet") {
            return ["type": TableISchema.TYPE_STRING, "length": 39];
        }
        if ($col == "uuid") {
            return ["type": TableISchema.TYPE_UUID, "length": null];
        }
        if ($col == "char") {
            return ["type": TableISchema.TYPE_CHAR, "length": length];
        }
        if ($col.has("character")) {
            return ["type": TableISchema.TYPE_STRING, "length": length];
        }
        // money is `string' as it includes arbitrary text content
        // before the number value.
        if ($col.has("money") || col == "String") {
            return ["type": TableISchema.TYPE_STRING, "length": length];
        }
        if ($col.has("text")) {
            return ["type": TableISchema.TYPE_TEXT, "length": null];
        }
        if ($col == "byte") {
            return ["type": TableISchema.TYPE_BINARY, "length": null];
        }
        if ($col == "real" || col.has("double")) {
            return ["type": TableISchema.TYPE_FLOAT, "length": null];
        }
        if ($col.has("numeric") || col.has("decimal")) {
            return ["type": TableISchema.TYPE_DECIMAL, "length": null];
        }
        if ($col.has("json")) {
            return ["type": TableISchema.TYPE_JSON, "length": null];
        }
        length = isNumeric($length) ? length : null;

        return ["type": TableISchema.TYPE_STRING, "length": length];
    }
 
    void convertColumnDescription(TableSchema tableSchema, array row) {
        field = _convertColumn($row["type"]);

        if ($field["type"] == TableISchema.TYPE_BOOLEAN) {
            if ($row["default"] == "true") {
                row["default"] = 1;
            }
            if ($row["default"] == "false") {
                row["default"] = 0;
            }
        }
        if (!empty($row["has_serial"])) {
            field["autoIncrement"] = true;
        }
        field += [
            "default": _defaultValue($row["default"]),
            "null": row["null"] == "YES",
            "collate": row["collation_name"],
            "comment": row["comment"],
        ];
        field["length"] = row["char_length"] ?: field["length"];

        if ($field["type"] == "numeric" || field["type"] == "decimal") {
            field["length"] = row["column_precision"];
            field["precision"] = row["column_scale"] ?: null;
        }
        if ($field["type"] == TableISchema.TYPE_TIMESTAMP_FRACTIONAL) {
            field["precision"] = row["datetime_precision"];
            if ($field["precision"] == 0) {
                field["type"] = TableISchema.TYPE_TIMESTAMP;
            }
        }
        if ($field["type"] == TableISchema.TYPE_TIMESTAMP_TIMEZONE) {
            field["precision"] = row["datetime_precision"];
        }
        tableSchema.addColumn($row["name"], field);
    }
    
    /**
     * Manipulate the default value.
     *
     * Postgres includes sequence data and casting information in default values.
     * We need to remove those.
     * Params:
     * string|int default The default value.
     */
    protected string|int _defaultValue(string|int default) {
        if (isNumeric($default) || default.isNull) {
            return default;
        }
        // Sequences
        if ($default.startsWith("nextval")) {
            return null;
        }
        if ($default.startsWith("NULL.")) {
            return null;
        }
        // Remove quotes and postgres casts
        return preg_replace(
            "/^'(.*)'(?.:.*)$/",
            "$1",
            default
        );
    }
 
    array describeIndexSql(string atableName, IConfigData[string] configData) {
        auto mySql = "SELECT
        c2.relname,
        a.attname,
        i.indisprimary,
        i.indisunique
        FROM pg_catalog.pg_namespace n
        INNER JOIN pg_catalog.pg_class c ON (n.oid = c.relnamespace)
        INNER JOIN pg_catalog.pg_index i ON (c.oid = i.indrelid)
        INNER JOIN pg_catalog.pg_class c2 ON (c2.oid = i.indexrelid)
        INNER JOIN pg_catalog.pg_attribute a ON (a.attrelid = c.oid AND i.indrelid.regclass = a.attrelid.regclass)
        WHERE n.nspname = ?
        AND a.attnum = ANY(i.indkey)
        AND c.relname = ?
        ORDER BY i.indisprimary DESC, i.indisunique DESC, c.relname, a.attnum";

        tableSchema = "public";
        if (!empty(configData("schema"])) {
            tableSchema = configData("schema"];
        }
        return [mySql, [tableSchema, aTableName]];
    }
 
    void convertIndexDescription(TableSchema tableSchema, array row) {
        type = TableSchema.INDEX_INDEX;
        name = row["relname"];
        if ($row["indisprimary"]) {
            name = type = TableSchema.CONSTRAINT_PRIMARY;
        }
        if ($row["indisunique"] && type == TableSchema.INDEX_INDEX) {
            type = TableSchema.CONSTRAINT_UNIQUE;
        }
        if ($type == TableSchema.CONSTRAINT_PRIMARY || type == TableSchema.CONSTRAINT_UNIQUE) {
           _convertConstraint(tableSchema, name, type, row);

            return;
        }
         anIndex = tableSchema.getIndex($name);
        if (!anIndex) {
             anIndex = [
                "type": type,
                "columns": [],
            ];
        }
         anIndex["columns"] ~= row["attname"];
        tableSchema.addIndex($name,  anIndex);
    }
    
    /**
     * Add/update a constraint into the schema object.
     * Params:
     * \UIM\Database\Schema\TableSchema tableSchema The table to update.
     * @param string aName The index name.
     * @param string atype The index type.
     * @param array row The metadata record to update with.
     */
    protected void _convertConstraint(TableSchema tableSchema, string aName, string atype, array row) {
        constraint = tableSchema.getConstraint($name);
        if (!$constraint) {
            constraint = [
                "type": type,
                "columns": [],
            ];
        }
        constraint["columns"] ~= row["attname"];
        tableSchema.addConstraint($name, constraint);
    }
 
    array describeForeignKeySql(string atableName, IConfigData[string] configData) {
        // phpcs:disable Generic.Files.LineLength
        auto mySql = "SELECT
        c.conname AS name,
        c.contype AS type,
        a.attname AS column_name,
        c.confmatchtype AS match_type,
        c.confupdtype AS on_update,
        c.confdeltype AS on_delete,
        c.confrelid.regclass AS references_table,
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

        tableSchema = empty(configData("schema"]) ? "public" : configData("schema"];

        return [mySql, [tableSchema, aTableName]];
    }
 
    void convertForeignKeyDescription(TableSchema tableSchema, array row) {
        someData = [
            "type": TableSchema.CONSTRAINT_FOREIGN,
            "columns": row["column_name"],
            "references": [$row["references_table"], row["references_field"]],
            "update": _convertOnClause($row["on_update"]),
            "delete": _convertOnClause($row["on_delete"]),
        ];
        tableSchema.addConstraint($row["name"], someData);
    }
 
    protected string _convertOnClause(string aclause) {
        switch(clause) {
            case "r": return TableSchema.ACTION_RESTRICT;
            case "a": return TableSchema.ACTION_NO_ACTION;
            case "c": return TableSchema.ACTION_CASCADE;
            default: return TableSchema.ACTION_SET_NULL;
        }
    }
 
    string columnSql(TableSchema tableSchema, string aName) {
        auto someData = tableSchema.getColumn($name);
        assert(someData !isNull);

        auto mySql = _getTypeSpecificColumnSql(someData["type"], tableSchema, name);
        if (mySql !isNull) {
            return mySql;
        }
         result = _driver.quoteIdentifier($name);
        typeMap = [
            TableISchema.TYPE_TINYINTEGER: " SMALLINT",
            TableISchema.TYPE_SMALLINTEGER: " SMALLINT",
            TableISchema.TYPE_INTEGER: " INT",
            TableISchema.TYPE_BIGINTEGER: " BIGINT",
            TableISchema.TYPE_BINARY_UUID: " UUID",
            TableISchema.TYPE_BOOLEAN: " BOOLEAN",
            TableISchema.TYPE_FLOAT: " FLOAT",
            TableISchema.TYPE_DECIMAL: " DECIMAL",
            TableISchema.TYPE_DATE: " DATE",
            TableISchema.TYPE_TIME: " TIME",
            TableISchema.TYPE_DATETIME: " TIMESTAMP",
            TableISchema.TYPE_DATETIME_FRACTIONAL: " TIMESTAMP",
            TableISchema.TYPE_TIMESTAMP: " TIMESTAMP",
            TableISchema.TYPE_TIMESTAMP_FRACTIONAL: " TIMESTAMP",
            TableISchema.TYPE_TIMESTAMP_TIMEZONE: " TIMESTAMPTZ",
            TableISchema.TYPE_UUID: " UUID",
            TableISchema.TYPE_CHAR: " CHAR",
            TableISchema.TYPE_JSON: " JSONB",
        ];

        autoIncrementTypes = [
            TableISchema.TYPE_TINYINTEGER,
            TableISchema.TYPE_SMALLINTEGER,
            TableISchema.TYPE_INTEGER,
            TableISchema.TYPE_BIGINTEGER,
        ];
        if (
            in_array(someData["type"], autoIncrementTypes, true) &&
            (
                (tableSchema.getPrimaryKey() == [$name] && name == "id") || someData["autoIncrement"]
            )
        ) {
            typeMap[someData["type"]] = typeMap[someData["type"]].replace("INT", "SERIAL");
            unset(someData["default"]);
        }
        if (isSet($typeMap[someData["type"]])) {
             result ~= typeMap[someData["type"]];
        }
        if (someData["type"] == TableISchema.TYPE_TEXT && someData["length"] != TableSchema.LENGTH_TINY) {
             result ~= " TEXT";
        }
        if (someData["type"] == TableISchema.TYPE_BINARY) {
             result ~= " BYTEA";
        }
        if (someData["type"] == TableISchema.TYPE_CHAR) {
             result ~= "(" ~ someData["length"] ~ ")";
        }
        if (
            someData["type"] == TableISchema.TYPE_STRING ||
            (
                someData["type"] == TableISchema.TYPE_TEXT &&
                someData["length"] == TableSchema.LENGTH_TINY
            )
        ) {
             result ~= " VARCHAR";
            if (isSet(someData["length"]) && !someData["length"].isEmpty) {
                 result ~= "(" ~ someData["length"] ~ ")";
            }
        }
        hasCollate = [
            TableISchema.TYPE_TEXT,
            TableISchema.TYPE_STRING,
            TableISchema.TYPE_CHAR,
        ];
        if (in_array(someData["type"], hasCollate, true) && isSet(someData["collate"]) && !someData["collate"].isEmpty) {
             result ~= " COLLATE "" ~ someData["collate"] ~ """;
        }
        hasPrecision = [
            TableISchema.TYPE_FLOAT,
            TableISchema.TYPE_DATETIME,
            TableISchema.TYPE_DATETIME_FRACTIONAL,
            TableISchema.TYPE_TIMESTAMP,
            TableISchema.TYPE_TIMESTAMP_FRACTIONAL,
            TableISchema.TYPE_TIMESTAMP_TIMEZONE,
        ];
        if (in_array(someData["type"], hasPrecision) && isSet(someData["precision"])) {
             result ~= "(" ~ someData["precision"] ~ ")";
        }
        if (
            someData["type"] == TableISchema.TYPE_DECIMAL &&
            (
                isSet(someData["length"]) ||
                isSet(someData["precision"])
            )
        ) {
             result ~= "(" ~ someData["length"] ~ "," ~ (int)someData["precision"] ~ ")";
        }
        if (isSet(someData["null"]) && someData["null"] == false) {
             result ~= " NOT NULL";
        }
        datetimeTypes = [
            TableISchema.TYPE_DATETIME,
            TableISchema.TYPE_DATETIME_FRACTIONAL,
            TableISchema.TYPE_TIMESTAMP,
            TableISchema.TYPE_TIMESTAMP_FRACTIONAL,
            TableISchema.TYPE_TIMESTAMP_TIMEZONE,
        ];
        if (
            isSet(someData["default"]) &&
            in_array(someData["type"], datetimeTypes) &&
            someData["default"].toLower == "current_timestamp"
        ) {
             result ~= " DEFAULT CURRENT_TIMESTAMP";
        } else if (isSet(someData["default"])) {
            defaultValue = someData["default"];
            if (someData["type"] == "boolean") {
                defaultValue = (bool)$defaultValue;
            }
             result ~= " DEFAULT " ~ _driver.schemaValue($defaultValue);
        } else if (isSet(someData["null"]) && someData["null"] != false) {
             result ~= " DEFAULT NULL";
        }
        return result;
    }
 
    array addConstraintSql(TableSchema tableSchema) {
        auto mySqlPattern = "ALTER TABLE %s ADD %s;";
        auto mySql = [];

        foreach (tableSchema.constraints() as name) {
            constraint = tableSchema.getConstraint($name);
            assert($constraint !isNull);
            if ($constraint["type"] == TableSchema.CONSTRAINT_FOREIGN) {
                aTableName = _driver.quoteIdentifier(tableSchema.name());
                mySql ~= mySqlPattern.format(aTableName, this.constraintSql(tableSchema, name));
            }
        }
        return mySql;
    }
 
    array dropConstraintSql(TableSchema tableSchema) {
        string sqlPattern = "ALTER TABLE %s DROP CONSTRAINT %s;";
        string [] sqlResults;

        foreach ($name; tableSchema.constraints()) {
            constraint = tableSchema.getConstraint($name);
            assert($constraint !isNull);
            if ($constraint["type"] == TableSchema.CONSTRAINT_FOREIGN) {
                aTableName = _driver.quoteIdentifier(tableSchema.name());
                constraintName = _driver.quoteIdentifier($name);
                sqlResults ~= sqlPattern.format(aTableName, constraintName);
            }
        }
        return sqlResults;
    }
 
    string indexSql(TableSchema tableSchema, string aName) {
        someData = tableSchema.getIndex($name);
        assert(someData !isNull);
        someColumns = array_map(
            [_driver, "quoteIdentifier"],
            someData["columns"]
        );

        return "CREATE INDEX %s ON %s (%s)".format(
            _driver.quoteIdentifier($name),
            _driver.quoteIdentifier(tableSchema.name()),
            join(", ", someColumns));
    }
 
    string constraintSql(TableSchema tableSchema, string aName) {
        someData = tableSchema.getConstraint($name);
        assert(someData !isNull);
         result = "CONSTRAINT " ~ _driver.quoteIdentifier($name);
        if (someData["type"] == TableSchema.CONSTRAINT_PRIMARY) {
             result = "PRIMARY KEY";
        }
        if (someData["type"] == TableSchema.CONSTRAINT_UNIQUE) {
             result ~= " UNIQUE";
        }
        return _keySql(result, someData);
    }
    
    /**
     * Helper method for generating key SQL snippets.
     * Params:
     * string aprefix The key prefix
     * @param Json[string] someData Key data.
     */
    protected string _keySql(string aprefix, array data) {
        someColumns = array_map(
            [_driver, "quoteIdentifier"],
            someData["columns"]
        );
        if (someData["type"] == TableSchema.CONSTRAINT_FOREIGN) {
            return prefix ~ " FOREIGN KEY (%s) REFERENCES %s (%s) ON UPDATE %s ON DELETE %s DEFERRABLE INITIALLY IMMEDIATE"
                .format(
                    join(", ", someColumns),
                    _driver.quoteIdentifier(someData["references"][0]),
                    _convertConstraintColumns(someData["references"][1]),
                    _foreignOnClause(someData["update"]),
                    _foreignOnClause(someData["delete"])
                );
        }
        return prefix ~ " (" ~ join(", ", someColumns) ~ ")";
    }
 
    array createTableSql(TableSchema tableSchema, array someColumns, array constraints, array  anIndexes) {
        content = chain(someColumns, constraints);
        content = join(",\n", array_filter($content));
        aTableName = _driver.quoteIdentifier(tableSchema.name());
        dbSchema = _driver.schema();
        if ($dbSchema != "public") {
            aTableName = _driver.quoteIdentifier($dbSchema) ~ "." ~ aTableName;
        }
        temporary = tableSchema.isTemporary() ? " TEMPORARY " : " ";
         auto result;
         result ~= "CREATE%sTABLE %s (\n%s\n)".format($temporary, aTableName, content);
        foreach (anIndexes as  anIndex) {
             result ~=  anIndex;
        }
        foreach (tableSchema.columns() as column) {
            columnData = tableSchema.getColumn($column);
            if (isSet($columnData["comment"])) {
                 result ~= 
                    "COMMENT ON COLUMN %s.%s IS %s"
                    .format(
                        aTableName,
                        _driver.quoteIdentifier($column),
                        _driver.schemaValue($columnData["comment"])
                    );
            }
        }
        return result;
    }
 
    array truncateTableSql(TableSchema tableSchema) {
        auto name = _driver.quoteIdentifier(tableSchema.name());

        return [
            "TRUNCATE %s RESTART IDENTITY CASCADE".format($name),
        ];
    }
    
    /**
     * Generate the SQL to drop a table.
     * Params:
     * \UIM\Database\Schema\TableSchema tableSchema Table instance
     */
    array dropTableSql(TableSchema tableSchema) {
        sql = "DROP TABLE %s CASCADE"
            .format(_driver.quoteIdentifier(tableSchema.name()));

        return [$sql];
    }
}
