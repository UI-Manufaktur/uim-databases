module uim.databases.schemas;

import uim.databases;

@safe:

/**
 * tableSchema generation/reflection features for MySQL
 *
 * @internal
 */
class MysqlSchemaDialect : SchemaDialect {
    /**
     * Generate the SQL to list the tables and views.
     *
     * configData - The connection configuration to use for
     *   getting tables from.
     */
    array<mixed> listTablesSql(IData[string] configData = null) {
        return ["SHOW FULL TABLES FROM " ~ _driver.quoteIdentifier(configData["database"]), []];
    }
    
    /**
     * Generate the SQL to list the tables, excluding all views.
     * Params:
     * IData[string] configData The connection configuration to use for
     *   getting tables from.
     */
    Json[] listTablesWithoutViewsSql(IData[string] configData = null) {
        return [
            "SHOW FULL TABLES FROM " ~ _driver.quoteIdentifier(configData["database"])
            ~ " WHERE TABLE_TYPE = 'BASE TABLE'"
        , []];
    }
 
    array describeColumnSql(string aTableName, IData[string] configData) {
        return ["SHOW FULL COLUMNS FROM " ~ _driver.quoteIdentifier(aTableName), []];
    }
 
    array describeIndexSql(string aTableName, IData[string] configData) {
        return ["SHOW INDEXES FROM " ~ _driver.quoteIdentifier(aTableName), []];
    }
 
    array describeOptionsSql(string aTableName, IData[string] configData) {
        return ["SHOW TABLE STATUS WHERE Name = ?", [aTableName]];
    }
 
    void convertOptionsDescription(TableSchema tableSchema, array $row) {
        tableSchema.setOptions([
            "engine": $row["Engine"],
            "collation": $row["Collation"],
        ]);
    }
    
    /**
     * Convert a MySQL column type into an abstract type.
     *
     * The returned type will be a type that UIM\Database\TypeFactory can handle.
     * Params:
     * string acolumn The column type + length
     * @throws \UIM\Database\Exception\DatabaseException When column type cannot be parsed.
     */
    protected IData[string] _convertColumn(string acolumn) {
        preg_match("/([a-z]+)(?:\(([0-9,]+)\))?\s*([a-z]+)?/i", $column, $matches);
        if (isEmpty($matches)) {
            throw new DatabaseException("Unable to parse column type from `%s`".format($column));
        }
        $col = $matches[1].toLower;
        $length = $precision = $scale = null;
        if (isSet($matches[2]) && $matches[2].length {
            $length = $matches[2];
            if ($matches[2].has(",")) {
                [$length, $precision] = split(",", $length);
            }
            $length = (int)$length;
            $precision = (int)$precision;
        }
        $type = _applyTypeSpecificColumnConversion(
            $col,
            compact("length", "precision", "scale")
        );
        if (!$type.isNull) {
            return $type;
        }
        if (in_array($col, ["date", "time"])) {
            return ["type": $col, "length": null];
        }
        if (in_array($col, ["datetime", "timestamp"])) {
            $typeName = $col;
            if ($length > 0) {
                $typeName = $col ~ "fractional";
            }
            return ["type": $typeName, "length": null, "precision": $length];
        }
        if (($col == "tinyint" && $length == 1) || $col == "boolean") {
            return ["type": TableISchema.TYPE_BOOLEAN, "length": null];
        }
        $unsigned = (isSet($matches[3]) && $matches[3].toLower) == "unsigned");
        if ($col.has("bigint") || $col == "bigint") {
            return ["type": TableISchema.TYPE_BIGINTEGER, "length": null, "unsigned": $unsigned];
        }
        if ($col == "tinyint") {
            return ["type": TableISchema.TYPE_TINYINTEGER, "length": null, "unsigned": $unsigned];
        }
        if ($col == "smallint") {
            return ["type": TableISchema.TYPE_SMALLINTEGER, "length": null, "unsigned": $unsigned];
        }
        if (in_array($col, ["int", "integer", "mediumint"])) {
            return ["type": TableISchema.TYPE_INTEGER, "length": null, "unsigned": $unsigned];
        }
        if ($col == "char" && $length == 36) {
            return ["type": TableISchema.TYPE_UUID, "length": null];
        }
        if ($col == "char") {
            return ["type": TableISchema.TYPE_CHAR, "length": $length];
        }
        if ($col.has("char")) {
            return ["type": TableISchema.TYPE_STRING, "length": $length];
        }
        if ($col.has("text")) {
            $lengthName = substr($col, 0, -4);
            $length = TableSchema.$columnLengths[$lengthName] ?? null;

            return ["type": TableISchema.TYPE_TEXT, "length": $length];
        }
        if ($col == "binary" && $length == 16) {
            return ["type": TableISchema.TYPE_BINARY_UUID, "length": null];
        }
        if ($col.has("blob") || in_array($col, ["binary", "varbinary"])) {
            $lengthName = substr($col, 0, -4);
            $length = TableSchema.$columnLengths[$lengthName] ?? $length;

            return ["type": TableISchema.TYPE_BINARY, "length": $length];
        }
        if ($col.has("float") || $col.has("double")) {
            return [
                "type": TableISchema.TYPE_FLOAT,
                "length": $length,
                "precision": $precision,
                "unsigned": $unsigned,
            ];
        }
        if ($col.has("decimal")) {
            return [
                "type": TableISchema.TYPE_DECIMAL,
                "length": $length,
                "precision": $precision,
                "unsigned": $unsigned,
            ];
        }
        if ($col.has("json")) {
            return ["type": TableISchema.TYPE_JSON, "length": null];
        }
        return ["type": TableISchema.TYPE_STRING, "length": null];
    }
 
    void convertColumnDescription(TableSchema tableSchema, array $row) {
        auto field = _convertColumn($row["Type"]);
        field = field.update([
            "null": $row["Null"] == "YES",
            "default": $row["default"],
            "collate": $row["Collation"],
            "comment": $row["Comment"],
        ];

        if ($row.isSet("Extra") && $row["Extra"] == "auto_increment") {
            field["autoIncrement"] = true;
        }
        tableSchema.addColumn($row["Field"], field);
    }
 
    void convertIndexDescription(TableSchema tableSchema, array $row) {
        auto $type = null;
        someColumns = $length = [];

        auto keyName = $row["Key_name"];
        if (keyName == "PRIMARY") {
            keyName = $type = TableSchema.CONSTRAINT_PRIMARY;
        }
        if (!empty($row["Column_name"])) {
            someColumns ~= $row["Column_name"];
        }
        if ($row["Index_type"] == "FULLTEXT") {
            $type = TableSchema.INDEX_FULLTEXT;
        } elseif ((int)$row["Non_unique"] == 0 && $type != "primary") {
            $type = TableSchema.CONSTRAINT_UNIQUE;
        } elseif ($type != "primary") {
            $type = TableSchema.INDEX_INDEX;
        }
        if (!$row["Sub_part"])) {
            $length[$row["Column_name"]] = $row["Sub_part"];
        }
         isIndex = (
            $type == TableSchema.INDEX_INDEX ||
            $type == TableSchema.INDEX_FULLTEXT
        );
        if (isIndex) {
            $existing = tableSchema.getIndex($name);
        } else {
            $existing = tableSchema.getConstraint(keyName);
        }
        // MySQL multi column indexes come back as multiple rows.
        if (!empty($existing)) {
            someColumns = array_merge($existing["columns"], someColumns);
            $length = array_merge($existing["length"], $length);
        }
        if (isIndex) {
            tableSchema.addIndex($name, [
                "type": $type,
                "columns": someColumns,
                "length": $length,
            ]);
        } else {
            tableSchema.addConstraint(keyName, [
                "type": $type,
                "columns": someColumns,
                "length": $length,
            ]);
        }
    }
 
    array describeForeignKeySql(string aTableName, IData[string] configData) {
        auto mySql = "SELECT * FROM information_schema.key_column_usage AS kcu
            INNER JOIN information_schema.referential_constraints AS rc
            ON (
                kcu.CONSTRAINT_NAME = rc.CONSTRAINT_NAME
                AND kcu.CONSTRAINT_SCHEMA = rc.CONSTRAINT_SCHEMA
            )
            WHERE kcu.TABLE_SCHEMA = ? AND kcu.TABLE_NAME = ? AND rc.TABLE_NAME = ?
            ORDER BY kcu.ORDINAL_POSITION ASC";

        return [mySql, [configData["database"], aTableName, aTableName]];
    }
 
    void convertForeignKeyDescription(TableSchema tableSchema, array $row) {
        $data = [
            "type": TableSchema.CONSTRAINT_FOREIGN,
            "columns": [$row["COLUMN_NAME"]],
            "references": [$row["REFERENCED_TABLE_NAME"], $row["REFERENCED_COLUMN_NAME"]],
            "update": _convertOnClause($row["UPDATE_RULE"]),
            "delete": _convertOnClause($row["DELETE_RULE"]),
        ];
        auto contraintName = $row["CONSTRAINT_NAME"];
        tableSchema.addConstraint(contraintName, $data);
    }
 
    array truncateTableSql(TableSchema tableSchema) {
        return ["TRUNCATE TABLE `%s`".format(tableSchema.name())];
    }
 
    array createTableSql(TableSchema tableSchema, array someColumns, array $constraints, array  anIndexes) {
        $content = join(",\n", array_merge(someColumns, $constraints,  anIndexes));
        $temporary = tableSchema.isTemporary() ? " TEMPORARY " : " ";
        $content = "CREATE%sTABLE `%s` (\n%s\n)".format($temporary, tableSchema.name(), $content);
        $options = tableSchema.getOptions();
        if (isSet($options["engine"])) {
            $content ~= " ENGINE=%s".format($options["engine"]);
        }
        if (isSet($options["charset"])) {
            $content ~= " DEFAULT CHARSET=%s".format($options["charset"]);
        }
        if (isSet($options["collate"])) {
            $content ~= " COLLATE=%s".format($options["collate"]);
        }
        return [$content];
    }
 
    auto columnSql(TableSchema tableSchema, string aName) {
        someData = tableSchema.getColumn($name);
        assert(someData !isNull);

        $sql = _getTypeSpecificColumnSql(someData["type"], tableSchema, $name);
        if ($sql !isNull) {
            return $sql;
        }
         result = _driver.quoteIdentifier($name);
        $nativeJson = _driver.supports(DriverFeatures.JSON);

        $typeMap = [
            TableISchema.TYPE_TINYINTEGER: " TINYINT",
            TableISchema.TYPE_SMALLINTEGER: " SMALLINT",
            TableISchema.TYPE_INTEGER: " INTEGER",
            TableISchema.TYPE_BIGINTEGER: " BIGINT",
            TableISchema.TYPE_BINARY_UUID: " BINARY(16)",
            TableISchema.TYPE_BOOLEAN: " BOOLEAN",
            TableISchema.TYPE_FLOAT: " FLOAT",
            TableISchema.TYPE_DECIMAL: " DECIMAL",
            TableISchema.TYPE_DATE: " DATE",
            TableISchema.TYPE_TIME: " TIME",
            TableISchema.TYPE_DATETIME: " DATETIME",
            TableISchema.TYPE_DATETIME_FRACTIONAL: " DATETIME",
            TableISchema.TYPE_TIMESTAMP: " TIMESTAMP",
            TableISchema.TYPE_TIMESTAMP_FRACTIONAL: " TIMESTAMP",
            TableISchema.TYPE_TIMESTAMP_TIMEZONE: " TIMESTAMP",
            TableISchema.TYPE_CHAR: " CHAR",
            TableISchema.TYPE_UUID: " CHAR(36)",
            TableISchema.TYPE_JSON: $nativeJson ? " JSON" : " LONGTEXT",
        ];
        $specialMap = [
            "string": true,
            "text": true,
            "char": true,
            "binary": true,
        ];
        if (isSet($typeMap[someData["type"]])) {
             result ~= $typeMap[someData["type"]];
        }
        if (isSet($specialMap[someData["type"]])) {
            switch (someData["type"]) {
                case TableISchema.TYPE_STRING:
                     result ~= " VARCHAR";
                    if (!isSet(someData["length"])) {
                        someData["length"] = 255;
                    }
                    break;
                case TableISchema.TYPE_TEXT:
                     isKnownLength = in_array(someData["length"], TableSchema.$columnLengths);
                    if (isEmpty(someData["length"]) || !isKnownLength) {
                         result ~= " TEXT";
                        break;
                    }
                    $length = array_search(someData["length"], TableSchema.$columnLengths);
                    assert(isString($length));
                     result ~= " " ~ strtoupper($length) ~ "TEXT";

                    break;
                case TableISchema.TYPE_BINARY:
                     isKnownLength = in_array(someData["length"], TableSchema.$columnLengths);
                    if (isKnownLength) {
                        $length = array_search(someData["length"], TableSchema.$columnLengths);
                        assert(isString($length));
                         result ~= " " ~ strtoupper($length) ~ "BLOB";
                        break;
                    }
                    if (isEmpty(someData["length"])) {
                         result ~= " BLOB";
                        break;
                    }
                    if (someData["length"] > 2) {
                         result ~= " VARBINARY(" ~ someData["length"] ~ ")";
                    } else {
                         result ~= " BINARY(" ~ someData["length"] ~ ")";
                    }
                    break;
            }
        }
        $hasLength = [
            TableISchema.TYPE_INTEGER,
            TableISchema.TYPE_CHAR,
            TableISchema.TYPE_SMALLINTEGER,
            TableISchema.TYPE_TINYINTEGER,
            TableISchema.TYPE_STRING,
        ];
        if (in_array(someData["type"], $hasLength, true) && isSet(someData["length"])) {
             result ~= "(" ~ someData["length"] ~ ")";
        }
        $lengthAndPrecisionTypes = [
            TableISchema.TYPE_FLOAT,
            TableISchema.TYPE_DECIMAL,
        ];
        if (in_array(someData["type"], $lengthAndPrecisionTypes, true) && isSet(someData["length"])) {
            result ~= isSet(someData["precision"])
                ? "(" ~ (int)someData["length"] ~ "," ~ (int)someData["precision"] ~ ")"
                : "(" ~ (int)someData["length"] ~ ")";
        }
        $precisionTypes = [
            TableISchema.TYPE_DATETIME_FRACTIONAL,
            TableISchema.TYPE_TIMESTAMP_FRACTIONAL,
        ];
        if (in_array(someData["type"], $precisionTypes, true) && isSet(someData["precision"])) {
             result ~= "(" ~ (int)someData["precision"] ~ ")";
        }
        $hasUnsigned = [
            TableISchema.TYPE_TINYINTEGER,
            TableISchema.TYPE_SMALLINTEGER,
            TableISchema.TYPE_INTEGER,
            TableISchema.TYPE_BIGINTEGER,
            TableISchema.TYPE_FLOAT,
            TableISchema.TYPE_DECIMAL,
        ];
        if (
            in_array(someData["type"], $hasUnsigned, true) &&
            isSet(someData["unsigned"]) &&
            someData["unsigned"] == true
        ) {
             result ~= " UNSIGNED";
        }
        $hasCollate = [
            TableISchema.TYPE_TEXT,
            TableISchema.TYPE_CHAR,
            TableISchema.TYPE_STRING,
        ];
        if (in_array(someData["type"], $hasCollate, true) && isSet(someData["collate"]) && someData["collate"] != "") {
             result ~= " COLLATE " ~ someData["collate"];
        }
        if (isSet(someData["null"]) && someData["null"] == false) {
             result ~= " NOT NULL";
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
             result ~= " AUTO_INCREMENT";
            unset(someData["default"]);
        }
        $timestampTypes = [
            TableISchema.TYPE_TIMESTAMP,
            TableISchema.TYPE_TIMESTAMP_FRACTIONAL,
            TableISchema.TYPE_TIMESTAMP_TIMEZONE,
        ];
        if (isSet(someData["null"]) && someData["null"] == true && in_array(someData["type"], $timestampTypes, true)) {
             result ~= " NULL";
            unset(someData["default"]);
        }
        $dateTimeTypes = [
            TableISchema.TYPE_DATETIME,
            TableISchema.TYPE_DATETIME_FRACTIONAL,
            TableISchema.TYPE_TIMESTAMP,
            TableISchema.TYPE_TIMESTAMP_FRACTIONAL,
            TableISchema.TYPE_TIMESTAMP_TIMEZONE,
        ];
        if (
            isSet(someData["default"]) &&
            in_array(someData["type"], $dateTimeTypes) &&
            strtolower(someData["default"]).has("current_timestamp")
        ) {
             result ~= " DEFAULT CURRENT_TIMESTAMP";
            if (isSet(someData["precision"])) {
                 result ~= "(" ~ someData["precision"] ~ ")";
            }
            unset(someData["default"]);
        }
        if (isSet(someData["default"])) {
             result ~= " DEFAULT " ~ _driver.schemaValue(someData["default"]);
            unset(someData["default"]);
        }
        if (isSet(someData["comment"]) && someData["comment"] != "") {
             result ~= " COMMENT " ~ _driver.schemaValue(someData["comment"]);
        }
        return result;
    }
 
    string constraintSql(TableSchema tableSchema, string aName) {
        someData = tableSchema.getConstraint($name);
        assert(someData !isNull);
        if (someData["type"] == TableSchema.CONSTRAINT_PRIMARY) {
            someColumns = array_map(
                [_driver, "quoteIdentifier"],
                someData["columns"]
            );

            return "PRIMARY KEY (%s)".format(someColumns.join(", "));
        }
         result = "";
        if (someData["type"] == TableSchema.CONSTRAINT_UNIQUE) {
             result = "UNIQUE KEY ";
        }
        if (someData["type"] == TableSchema.CONSTRAINT_FOREIGN) {
             result = "CONSTRAINT ";
        }
         result ~= _driver.quoteIdentifier($name);

        return _keySql(result, someData);
    }
 
    string[] addConstraintSql(TableSchema tableSchema) {
        string sqlPattern = "ALTER TABLE %s ADD %s;";
        string[] sqlResults;

        tableSchema.constraints().each!((name) {
            $constraint = tableSchema.getConstraint(name);
            assert($constraint !isNull);
            if ($constraint["type"] == TableSchema.CONSTRAINT_FOREIGN) {
                auto ableName = _driver.quoteIdentifier(tableSchema.name());
                sqlResults ~= sqlPattern.format(aTableName, this.constraintSql(tableSchema, name));
            }
        });
        return sqlResults;
    }
 
    string[] dropConstraintSql(TableSchema tableSchema) {
        string sqlPattern = "ALTER TABLE %s DROP FOREIGN KEY %s;";
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
         result = "";
        if (someData["type"] == TableSchema.INDEX_INDEX) {
             result = "KEY ";
        }
        if (someData["type"] == TableSchema.INDEX_FULLTEXT) {
             result = "FULLTEXT KEY ";
        }
         result ~= _driver.quoteIdentifier($name);

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
        foreach (index, $column; someData["columns"]) {
            if (isSet(someData["length"][$column])) {
                someColumns[index] ~= "(%d)".format(someData["length"][$column]);
            }
        }
        if (someData["type"] == TableSchema.CONSTRAINT_FOREIGN) {
            return $prefix ~ sprintf(
                " FOREIGN KEY (%s) REFERENCES %s (%s) ON UPDATE %s ON DELETE %s",
                join(", ", someColumns),
               _driver.quoteIdentifier(someData["references"][0]),
               _convertConstraintColumns(someData["references"][1]),
               _foreignOnClause(someData["update"]),
               _foreignOnClause(someData["delete"])
            );
        }
        return $prefix ~ " (" ~ join(", ", someColumns) ~ ")";
    }
}
