module uim.databases.schemas;

import uim.databases;

@safe:

/* * Schema management/reflection features for SQLServer.
 *
 * @internal
 */
class SqlserverSchemaDialect : SchemaDialect {
    const string DEFAULT_SCHEMA_NAME = "dbo";

    /**
     * Generate the SQL to list the tables and views.
     * Params:
     * IData[string] configData The connection configuration to use for getting tables from.
     */
    array listTablesSql(IData[string] configData = null) {
        auto sql = "SELECT TABLE_NAME
            FROM INFORMATION_SCHEMA.TABLES
            WHERE TABLE_SCHEMA = ?
            AND (TABLE_TYPE = 'BASE TABLE' OR TABLE_TYPE = "VIEW")
            ORDER BY TABLE_NAME";
        tableSchema = empty(configData["schema"]) ? DEFAULT_SCHEMA_NAME : configData["schema"];

        return [sql, [tableSchema]];
    }
    
    /**
     * Generate the SQL to list the tables, excluding all views.
     * Params:
     * IData[string] configData The connection configuration to use for
     *   getting tables from.
     */
    Json[] listTablesWithoutViewsSql(IData[string] configData = null) {
        auto sql = "SELECT TABLE_NAME
            FROM INFORMATION_SCHEMA.TABLES
            WHERE TABLE_SCHEMA = ?
            AND (TABLE_TYPE = 'BASE TABLE')
            ORDER BY TABLE_NAME";
        
        auto schema = empty(configData["schema"]) ? DEFAULT_SCHEMA_NAME : configData["schema"];

        return [sql, [schema]];
    }
 
    array describeColumnSql(string atableName, IData[string] configData) {
        auto mySql = "SELECT DISTINCT
            AC.column_id AS [column_id],
            AC.name AS [name],
            TY.name AS [type],
            AC.max_length AS [char_length],
            AC.precision AS [precision],
            AC.scale AS [scale],
            AC.is_identity AS [autoincrement],
            AC.isNullable AS [null],
            OBJECT_DEFINITION(AC.default_object_id) AS [default],
            AC.collation_name AS [collation_name]
            FROM sys.[objects] T
            INNER JOIN sys.[schemas] S ON S.[schema_id] = T.[schema_id]
            INNER JOIN sys.[all_columns] AC ON T.[object_id] = AC.[object_id]
            INNER JOIN sys.[types] TY ON TY.[user_type_id] = AC.[user_type_id]
            WHERE T.[name] = ? AND S.[name] = ?
            ORDER BY column_id";

        tableSchema = empty(configData["schema"]) ? DEFAULT_SCHEMA_NAME : configData["schema"];

        return [$sql, [aTableName, tableSchema]];
    }
    
    /**
     * Convert a column definition to the abstract types.
     *
     * The returned type will be a type that
     * UIM\Database\TypeFactory  can handle.
     * Params:
     * string acol The column type
     * @param int $length the column length
     * @param int $precision The column precision
     * @param int $scale The column scale
     * @link https://technet.microsoft.com/en-us/library/ms187752.aspx
     */
    protected Json[string] _convertColumn(
        string columnType,
        ?size_t aLength = null,
        int $precision = null,
        int $scale = null
    ) {
        string loweredColumnType = columnType.toLower;

        $type = _applyTypeSpecificColumnConversion(
            loweredColumnType,
            compact("length", "precision", "scale")
        );
        if ($type !isNull) {
            return $type;
        }
        if (in_array(loweredColumnType, ["date", "time"])) {
            return ["type": loweredColumnType, "length": null];
        }
        if (loweredColumnType == "datetime") {
            // datetime cannot parse more than 3 digits of precision and isn`t accurate
            return ["type": TableISchema.TYPE_DATETIME, "length": null];
        }
        if (loweredColumnType.has("datetime")) {
            auto $typeName = TableISchema.TYPE_DATETIME;
            if ($scale > 0) {
                $typeName = TableISchema.TYPE_DATETIME_FRACTIONAL;
            }
            return ["type": $typeName, "length": null, "precision": $scale];
        }
        if (loweredColumnType == "char") {
            return ["type": TableISchema.TYPE_CHAR, "length": $length];
        }
        if (loweredColumnType == "tinyint") {
            return ["type": TableISchema.TYPE_TINYINTEGER, "length": $precision ?: 3];
        }
        if (loweredColumnType == "Smallint") {
            return ["type": TableISchema.TYPE_SMALLINTEGER, "length": $precision ?: 5];
        }
        if (loweredColumnType == "int" || loweredColumnType == "integer") {
            return ["type": TableISchema.TYPE_INTEGER, "length": $precision ?: 10];
        }
        if (loweredColumnType == "bigint") {
            return ["type": TableISchema.TYPE_BIGINTEGER, "length": $precision ?: 20];
        }
        if (loweredColumnType == "bit") {
            return ["type": TableISchema.TYPE_BOOLEAN, "length": null];
        }
        if (
            loweredColumnType.has("numeric") ||
            loweredColumnType.has("money") ||
            loweredColumnType.has("decimal")
        ) {
            return ["type": TableISchema.TYPE_DECIMAL, "length": $precision, "precision": $scale];
        }
        if (loweredColumnType == "real" || loweredColumnType == "float") {
            return ["type": TableISchema.TYPE_FLOAT, "length": null];
        }
        // SqlServer schema reflection returns double length for unicode
        // columns because internally it uses UTF16/UCS2
        if (loweredColumnType == "nvarchar" || loweredColumnType == "nchar" || loweredColumnType == "ntext") {
            $length /= 2;
        }
        if (loweredColumnType.has("varchar") && $length < 0) {
            return ["type": TableISchema.TYPE_TEXT, "length": null];
        }
        if (loweredColumnType.has("varchar")) {
            return ["type": TableISchema.TYPE_STRING, "length": $length ?: 255];
        }
        if (loweredColumnType.has("char")) {
            return ["type": TableISchema.TYPE_CHAR, "length": $length];
        }
        if (loweredColumnType.has("text")) {
            return ["type": TableISchema.TYPE_TEXT, "length": null];
        }
        if (loweredColumnType == "image" || loweredColumnType.has("binary")) {
            // -1 is the value for MAX which we treat as a 'long' binary
            if ($length == -1) {
                $length = TableSchema.LENGTH_LONG;
            }
            return ["type": TableISchema.TYPE_BINARY, "length": $length];
        }
        if (loweredColumnType == "uniqueidentifier") {
            return ["type": TableISchema.TYPE_UUID];
        }
        return ["type": TableISchema.TYPE_STRING, "length": null];
    }
 
    void convertColumnDescription(TableSchema tableSchema, array $row) {
        auto $field = _convertColumn(
            $row["type"],
            $row["char_length"] !isNull ? (int)$row["char_length"] : null,
            $row["precision"] !isNull ? (int)$row["precision"] : null,
            $row["scale"] !isNull ? (int)$row["scale"] : null
        );

        if (!empty($row["autoincrement"])) {
            $field["autoIncrement"] = true;
        }
        $field += [
            "null": $row["null"] == "1",
            "default": _defaultValue($field["type"], $row["default"]),
            "collate": $row["collation_name"],
        ];
        tableSchema.addColumn($row["name"], $field);
    }
    
    /**
     * Manipulate the default value.
     *
     * Removes () wrapping default values, extracts strings from
     * N"" wrappers and collation text and converts NULL strings.
     * Params:
     * string atype The schema type
     * @param string|null $default The default value.
     */
    protected string|int _defaultValue(string atype, string adefault) {
        if ($default.isNull) {
            return null;
        }
        // remove () surrounding value (NULL) but leave () at the end of functions
        // integers might have two ((0)) wrapping value
        if (preg_match("/^\(+(.*?(\(\))?)\)+$/", $default, $matches)) {
            $default = $matches[1];
        }
        if ($default == "NULL") {
            return null;
        }
        if ($type == TableISchema.TYPE_BOOLEAN) {
            return (int)$default;
        }
        // Remove quotes
        if (preg_match("/^\(?N?'(.*)'\)?/", $default, $matches)) {
            return $matches[1].replace("""", "'");
        }
        return $default;
    }
    array describeIndexSql(string atableName, IData[string] configData) {
        auto mySql = "SELECT
                I.[name] AS [index_name],
                IC.[index_column_id] AS [index_order],
                AC.[name] AS [column_name],
                I.[is_unique], I.[isPrimaryKey],
                I.[is_unique_constraint]
            FROM sys.[tables] AS T
            INNER JOIN sys.[schemas] S ON S.[schema_id] = T.[schema_id]
            INNER JOIN sys.[indexes] I ON T.[object_id] = I.[object_id]
            INNER JOIN sys.[index_columns] IC ON I.[object_id] = IC.[object_id] AND I.[index_id] = IC.[index_id]
            INNER JOIN sys.[all_columns] AC ON T.[object_id] = AC.[object_id] AND IC.[column_id] = AC.[column_id]
            WHERE T.[is_ms_shipped] = 0 AND I.[type_desc] <> 'HEAP' AND T.[name] = ? AND S.[name] = ?
            ORDER BY I.[index_id], IC.[index_column_id]";

        tableSchema = empty(configData["schema"]) ? DEFAULT_SCHEMA_NAME : configData["schema"];

        return [$sql, [aTableName, tableSchema]];
    }
 
    void convertIndexDescription(TableSchema tableSchema, array $row) {
        auto $type = TableSchema.INDEX_INDEX;
        auto $name = $row["index_name"];
        if ($row["isPrimaryKey"]) {
            $name = $type = TableSchema.CONSTRAINT_PRIMARY;
        }
        if (($row["is_unique"] || $row["is_unique_constraint"]) && $type == TableSchema.INDEX_INDEX) {
            $type = TableSchema.CONSTRAINT_UNIQUE;
        }

        auto $existing = $type == TableSchema.INDEX_INDEX 
            ? tableSchema.getIndex($name)
            : tableSchema.getConstraint($name);
        
        auto someColumns = [$row["column_name"]];
        if (!empty($existing)) {
            someColumns = array_merge($existing["columns"], someColumns);
        }
        if ($type == TableSchema.CONSTRAINT_PRIMARY || $type == TableSchema.CONSTRAINT_UNIQUE) {
            tablSchema.addConstraint($name, [
                "type": $type,
                "columns": someColumns,
            ]);

            return;
        }
        tableSchema.addIndex($name, [
            "type": $type,
            "columns": someColumns,
        ]);
    }
 
    array describeForeignKeySql(string atableName, IData[string] configData) {
        // phpcs:disable Generic.Files.LineLength
        string mySql = "SELECT FK.[name] AS [foreign_key_name], FK.[delete_referential_action_desc] AS [delete_type],
                FK.[update_referential_action_desc] AS [update_type], C.name AS [column], RT.name AS [reference_table],
                RC.name AS [reference_column]
            FROM sys.foreign_keys FK
            INNER JOIN sys.foreign_key_columns FKC ON FKC.constraint_object_id = FK.object_id
            INNER JOIN sys.tables T ON T.object_id = FKC.parent_object_id
            INNER JOIN sys.tables RT ON RT.object_id = FKC.referenced_object_id
            INNER JOIN sys.schemas S ON S.schema_id = T.schema_id AND S.schema_id = RT.schema_id
            INNER JOIN sys.columns C ON C.column_id = FKC.parent_column_id AND C.object_id = FKC.parent_object_id
            INNER JOIN sys.columns RC ON RC.column_id = FKC.referenced_column_id AND RC.object_id = FKC.referenced_object_id
            WHERE FK.is_ms_shipped = 0 AND T.name = ? AND S.name = ?
            ORDER BY FKC.constraint_column_id";
        // phpcs:enable Generic.Files.LineLength

        tableSchema = empty(configData["schema"]) ? DEFAULT_SCHEMA_NAME : configData["schema"];

        return [$sql, [aTableName, tableSchema]];
    }
 
    void convertForeignKeyDescription(TableSchema tableSchema, array $row) {
        someData = [
            "type": TableSchema.CONSTRAINT_FOREIGN,
            "columns": [$row["column"]],
            "references": [$row["reference_table"], $row["reference_column"]],
            "update": _convertOnClause($row["update_type"]),
            "delete": _convertOnClause($row["delete_type"]),
        ];
        $name = $row["foreign_key_name"];
        tableSchema.addConstraint($name, someData);
    }
 
    protected string _foreignOnClause(string aon) {
        $parent = super._foreignOnClause($on);

        return $parent == "RESTRICT' ? super._foreignOnClause(TableSchema.ACTION_NO_ACTION): $parent;
    }
 
    protected string _convertOnClause(string aclause) {
        return match ($clause) {
            'NO_ACTION": TableSchema.ACTION_NO_ACTION,
            'CASCADE": TableSchema.ACTION_CASCADE,
            `sET_NULL": TableSchema.ACTION_SET_NULL,
            `sET_DEFAULT": TableSchema.ACTION_SET_DEFAULT,
            default: TableSchema.ACTION_SET_NULL,
        };
    }
 
    string columnSql(TableSchema tableSchema, string aName) {
        someData = tableSchema.getColumn($name);
        assert(someData !isNull);

        $sql = _getTypeSpecificColumnSql(someData["type"], tableSchema, $name);
        if ($sql !isNull) {
            return $sql;
        }
         result = _driver.quoteIdentifier($name);
        $typeMap = [
            TableISchema.TYPE_TINYINTEGER: ' TINYINT",
            TableISchema.TYPE_SMALLINTEGER: ' SMALLINT",
            TableISchema.TYPE_INTEGER: ' INTEGER",
            TableISchema.TYPE_BIGINTEGER: ' BIGINT",
            TableISchema.TYPE_BINARY_UUID: ' UNIQUEIDENTIFIER",
            TableISchema.TYPE_BOOLEAN: ' BIT",
            TableISchema.TYPE_CHAR: ' NCHAR",
            TableISchema.TYPE_FLOAT: ' FLOAT",
            TableISchema.TYPE_DECIMAL: ' DECIMAL",
            TableISchema.TYPE_DATE: ' DATE",
            TableISchema.TYPE_TIME: ' TIME",
            TableISchema.TYPE_DATETIME: ' DATETIME2",
            TableISchema.TYPE_DATETIME_FRACTIONAL: ' DATETIME2",
            TableISchema.TYPE_TIMESTAMP: ' DATETIME2",
            TableISchema.TYPE_TIMESTAMP_FRACTIONAL: ' DATETIME2",
            TableISchema.TYPE_TIMESTAMP_TIMEZONE: ' DATETIME2",
            TableISchema.TYPE_UUID: ' UNIQUEIDENTIFIER",
            TableISchema.TYPE_JSON: ' NVARCHAR(MAX)",
        ];

        if (isSet($typeMap[someData["type"]])) {
             result ~= $typeMap[someData["type"]];
        }
        $autoIncrementTypes = [
            TableISchema.TYPE_TINYINTEGER,
            TableISchema.TYPE_SMALLINTEGER,
            TableISchema.TYPE_INTEGER,
            TableISchema.TYPE_BIGINTEGER,
        ];
        if (
            in_array(someData["type"], $autoIncrementTypes, true) &&
            (
                (tableSchema.getPrimaryKey() == [$name] && $name == "id") || someData["autoIncrement"]
            )
        ) {
             result ~= " IDENTITY(1, 1)";
            unset(someData["default"]);
        }
        if (someData["type"] == TableISchema.TYPE_TEXT && someData["length"] != TableSchema.LENGTH_TINY) {
             result ~= " NVARCHAR(MAX)";
        }
        if (someData["type"] == TableISchema.TYPE_CHAR) {
             result ~= "(" ~ someData["length"] ~ ")";
        }
        if (someData["type"] == TableISchema.TYPE_BINARY) {
            if (
                !isSet(someData["length"])
                || in_array(someData["length"], [TableSchema.LENGTH_MEDIUM, TableSchema.LENGTH_LONG], true)
            ) {
                someData["length"] = "MAX";
            }
            if (someData["length"] == 1) {
                 result ~= " BINARY(1)";
            } else {
                 result ~= " VARBINARY";

                 result ~= "(%s)".format(someData["length"]);
            }
        }
        if (
            someData["type"] == TableISchema.TYPE_STRING ||
            (
                someData["type"] == TableISchema.TYPE_TEXT &&
                someData["length"] == TableSchema.LENGTH_TINY
            )
        ) {
            $type = " NVARCHAR";
            $length = someData["length"] ?? TableSchema.LENGTH_TINY;
             result ~= "%s(%d)".format($type, $length);
        }
        $hasCollate = [
            TableISchema.TYPE_TEXT,
            TableISchema.TYPE_STRING,
            TableISchema.TYPE_CHAR,
        ];
        if (in_array(someData["type"], $hasCollate, true) && isSet(someData["collate"]) && someData["collate"] != "") {
             result ~= " COLLATE " ~ someData["collate"];
        }
        $precisionTypes = [
            TableISchema.TYPE_FLOAT,
            TableISchema.TYPE_DATETIME,
            TableISchema.TYPE_DATETIME_FRACTIONAL,
            TableISchema.TYPE_TIMESTAMP,
            TableISchema.TYPE_TIMESTAMP_FRACTIONAL,
        ];
        if (in_array(someData["type"], $precisionTypes, true) && isSet(someData["precision"])) {
             result ~= "(" ~ (int)someData["precision"] ~ ")";
        }
        if (
            someData["type"] == TableISchema.TYPE_DECIMAL &&
            (
                isSet(someData["length"]) ||
                isSet(someData["precision"])
            )
        ) {
             result ~= "(" ~ (int)someData["length"] ~ "," ~ (int)someData["precision"] ~ ")";
        }
        if (isSet(someData["null"]) && someData["null"] == false) {
             result ~= " NOT NULL";
        }
        $dateTimeTypes = [
            TableISchema.TYPE_DATETIME,
            TableISchema.TYPE_DATETIME_FRACTIONAL,
            TableISchema.TYPE_TIMESTAMP,
            TableISchema.TYPE_TIMESTAMP_FRACTIONAL,
        ];
        $dateTimeDefaults = [
            "current_timestamp",
            "getdate()",
            "getutcdate()",
            "sysdatetime()",
            "sysutcdatetime()",
            "sysdatetimeoffset()",
        ];
        if (
            isSet(someData["default"]) &&
            in_array(someData["type"], $dateTimeTypes, true) &&
            in_array(someData["default"].toLower, $dateTimeDefaults, true)
        ) {
             result ~= " DEFAULT " ~ strtoupper(someData["default"]);
        } elseif (isSet(someData["default"])) {
            $default = isBool(someData["default"])
                ? (int)someData["default"]
                : _driver.schemaValue(someData["default"]);
             result ~= " DEFAULT " ~ $default;
        } elseif (isSet(someData["null"]) && someData["null"] != false) {
             result ~= " DEFAULT NULL";
        }
        return result;
    }
    array addConstraintSql(TableSchema tableSchema) {
        string sqlPattern = "ALTER TABLE %s ADD %s;";
        string[] sqlResults;

        foreach ($name; tableSchema.constraints()) {
            $constraint = tableSchema.getConstraint($name);
            assert($constraint !isNull);
            if ($constraint["type"] == TableSchema.CONSTRAINT_FOREIGN) {
                aTableName = _driver.quoteIdentifier(tableSchema.name());
                sqlResults ~= sqlPattern.format(aTableName, this.constraintSql(tableSchema, $name));
            }
        }
        return sqlResults;
    }
 
    array dropConstraintSql(TableSchema tableSchema) {
        string sqlPattern = "ALTER TABLE %s DROP CONSTRAINT %s;";
        string[] sqlResults;

        foreach (tableSchema.constraints() as $name) {
            $constraint = tableSchema.getConstraint($name);
            assert($constraint !isNull);
            if ($constraint["type"] == TableSchema.CONSTRAINT_FOREIGN) {
                aTableName = _driver.quoteIdentifier(tableSchema.name());
                $constraintName = _driver.quoteIdentifier($name);
                sqlResults ~= sqlPattern.format(aTableName, $constraintName);
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

        return 
            "CREATE INDEX %s ON %s (%s)"
            .format(
                _driver.quoteIdentifier($name),
                _driver.quoteIdentifier(tableSchema.name()),
                join(", ", someColumns)
            );
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
     * @param array data Key data.
     */
    protected string _keySql(string aprefix, array data) {
        someColumns = array_map(
            [_driver, "quoteIdentifier"],
            someData["columns"]
        );
        if (someData["type"] == TableSchema.CONSTRAINT_FOREIGN) {
            return $prefix ~ 
                " FOREIGN KEY (%s) REFERENCES %s (%s) ON UPDATE %s ON DELETE %s"
                .format(
                join(", ", someColumns),
               _driver.quoteIdentifier(someData["references"][0]),
               _convertConstraintColumns(someData["references"][1]),
               _foreignOnClause(someData["update"]),
               _foreignOnClause(someData["delete"])
            );
        }
        return $prefix ~ " (" ~ join(", ", someColumns) ~ ")";
    }

    array createTableSql(TableSchema tableSchema, array someColumns, array $constraints, array  anIndexes) {
        $content = array_merge(someColumns, $constraints);
        $content = join(",\n", array_filter($content));
        aTableName = _driver.quoteIdentifier(tableSchema.name());
         auto result;
         result ~= "CREATE TABLE %s (\n%s\n)".format(aTableName, $content);
        foreach (anIndexes as  anIndex) {
             result ~=  anIndex;
        }
        return result;
    }
 
    array truncateTableSql(TableSchema tableSchema) {
        $name = _driver.quoteIdentifier(tableSchema.name());
        $queries = [
            sprintf("DELETE FROM %s", $name),
        ];

        // Restart identity sequences
        $pk = tableSchema.getPrimaryKey();
        if (count($pk) == 1) {
            $column = tableSchema.getColumn($pk[0]);
            assert($column !isNull);
            if (in_array($column["type"], ["integer", "biginteger"])) {
                $queries ~= 
                    "IF EXISTS (SELECT * FROM sys.identity_columns WHERE OBJECT_NAME(OBJECT_ID) = "%s' AND " ~
                    "last_value IS NOT NULL) DBCC CHECKIDENT("%s", RESEED, 0)"
                    .format(tableSchema.name(), tableSchema.name());
            }
        }
        return $queries;
    }
}
