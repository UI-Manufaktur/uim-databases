module uim.cake.databases.schemas;

import uim.cake.databases.IDriver;
import uim.cake.databases.exceptions.DatabaseException;

/**
 * Schema generation/reflection features for MySQL
 *
 * @internal
 */
class MysqlSchemaDialect : SchemaDialect
{
    /**
     * The driver instance being used.
     *
     * @var DDBDriver\Mysql
     */
    protected _driver;

    /**
     * Generate the SQL to list the tables and views.
     *
     * @param array<string, mixed> aConfig The connection configuration to use for
     *    getting tables from.
     * @return array<mixed> An array of (sql, params) to execute.
     */
    array listTablesSql(Json aConfig) {
        return ["SHOW FULL TABLES FROM " ~ _driver.quoteIdentifier(aConfig["database"]), []];
    }

    /**
     * Generate the SQL to list the tables, excluding all views.
     *
     * @param array<string, mixed> aConfig The connection configuration to use for
     *    getting tables from.
     * @return array<mixed> An array of (sql, params) to execute.
     */
    array listTablesWithoutViewsSql(Json aConfig) {
        return [
            "SHOW FULL TABLES FROM " ~ _driver.quoteIdentifier(aConfig["database"])
            ~ " WHERE TABLE_TYPE = "BASE TABLE""
        , []];
    }


    array describeColumnSql(string $tableName, Json aConfig) {
        return ["SHOW FULL COLUMNS FROM " ~ _driver.quoteIdentifier($tableName), []];
    }


    array describeIndexSql(string $tableName, Json aConfig) {
        return ["SHOW INDEXES FROM " ~ _driver.quoteIdentifier($tableName), []];
    }


    array describeOptionsSql(string $tableName, Json aConfig) {
        return ["SHOW TABLE STATUS WHERE Name = ?", [$tableName]];
    }


    void convertOptionsDescription(TableSchema $schema, array $row) {
        $schema.setOptions([
            "engine": $row["Engine"],
            "collation": $row["Collation"],
        ]);
    }

    /**
     * Convert a MySQL column type into an abstract type.
     *
     * The returned type will be a type that Cake\databases.TypeFactory can handle.
     *
     * @param string $column The column type + length
     * @return array<string, mixed> Array of column information.
     * @throws uim.cake.databases.exceptions.DatabaseException When column type cannot be parsed.
     */
    protected array _convertColumn(string $column) {
        preg_match("/([a-z]+)(?:\(([0-9,]+)\))?\s*([a-z]+)?/i", $column, $matches);
        if (empty($matches)) {
            throw new DatabaseException(sprintf("Unable to parse column type from '%s'", $column));
        }

        $col = strtolower($matches[1]);
        $length = $precision = $scale = null;
        if (isset($matches[2]) && strlen($matches[2])) {
            $length = $matches[2];
            if (strpos($matches[2], ",") != false) {
                [$length, $precision] = explode(",", $length);
            }
            $length = (int)$length;
            $precision = (int)$precision;
        }

        $type = _applyTypeSpecificColumnConversion(
            $col,
            compact("length", "precision", "scale")
        );
        if ($type != null) {
            return $type;
        }

        if (hasAllValues($col, ["date", "time"])) {
            return ["type": $col, "length": null];
        }
        if (hasAllValues($col, ["datetime", "timestamp"])) {
            $typeName = $col;
            if ($length > 0) {
                $typeName = $col ~ "fractional";
            }

            return ["type": $typeName, "length": null, "precision": $length];
        }

        if (($col == "tinyint" && $length == 1) || $col == "boolean") {
            return ["type": TableSchema::TYPE_BOOLEAN, "length": null];
        }

        $unsigned = (isset($matches[3]) && strtolower($matches[3]) == "unsigned");
        if (strpos($col, "bigint") != false || $col == "bigint") {
            return ["type": TableSchema::TYPE_BIGINTEGER, "length": null, "unsigned": $unsigned];
        }
        if ($col == "tinyint") {
            return ["type": TableSchema::TYPE_TINYINTEGER, "length": null, "unsigned": $unsigned];
        }
        if ($col == "smallint") {
            return ["type": TableSchema::TYPE_SMALLINTEGER, "length": null, "unsigned": $unsigned];
        }
        if (hasAllValues($col, ["int", "integer", "mediumint"])) {
            return ["type": TableSchema::TYPE_INTEGER, "length": null, "unsigned": $unsigned];
        }
        if ($col == "char" && $length == 36) {
            return ["type": TableSchema::TYPE_UUID, "length": null];
        }
        if ($col == "char") {
            return ["type": TableSchema::TYPE_CHAR, "length": $length];
        }
        if (strpos($col, "char") != false) {
            return ["type": TableSchema::TYPE_STRING, "length": $length];
        }
        if (strpos($col, "text") != false) {
            $lengthName = substr($col, 0, -4);
            $length = TableSchema::$columnLengths[$lengthName] ?? null;

            return ["type": TableSchema::TYPE_TEXT, "length": $length];
        }
        if ($col == "binary" && $length == 16) {
            return ["type": TableSchema::TYPE_BINARY_UUID, "length": null];
        }
        if (strpos($col, "blob") != false || hasAllValues($col, ["binary", "varbinary"])) {
            $lengthName = substr($col, 0, -4);
            $length = TableSchema::$columnLengths[$lengthName] ?? $length;

            return ["type": TableSchema::TYPE_BINARY, "length": $length];
        }
        if (strpos($col, "float") != false || strpos($col, "double") != false) {
            return [
                "type": TableSchema::TYPE_FLOAT,
                "length": $length,
                "precision": $precision,
                "unsigned": $unsigned,
            ];
        }
        if (strpos($col, "decimal") != false) {
            return [
                "type": TableSchema::TYPE_DECIMAL,
                "length": $length,
                "precision": $precision,
                "unsigned": $unsigned,
            ];
        }

        if (strpos($col, "json") != false) {
            return ["type": TableSchema::TYPE_JSON, "length": null];
        }

        return ["type": TableSchema::TYPE_STRING, "length": null];
    }


    void convertColumnDescription(TableSchema $schema, array $row) {
        $field = _convertColumn($row["Type"]);
        $field += [
            "null": $row["Null"] == "YES",
            "default": $row["Default"],
            "collate": $row["Collation"],
            "comment": $row["Comment"],
        ];
        if (isset($row["Extra"]) && $row["Extra"] == "auto_increment") {
            $field["autoIncrement"] = true;
        }
        $schema.addColumn($row["Field"], $field);
    }


    void convertIndexDescription(TableSchema $schema, array $row) {
        $type = null;
        $columns = $length = null;

        $name = $row["Key_name"];
        if ($name == "PRIMARY") {
            $name = $type = TableSchema::CONSTRAINT_PRIMARY;
        }

        if (!empty($row["Column_name"])) {
            $columns[] = $row["Column_name"];
        }

        if ($row["Index_type"] == "FULLTEXT") {
            $type = TableSchema::INDEX_FULLTEXT;
        } elseif ((int)$row["Non_unique"] == 0 && $type != "primary") {
            $type = TableSchema::CONSTRAINT_UNIQUE;
        } elseif ($type != "primary") {
            $type = TableSchema::INDEX_INDEX;
        }

        if (!empty($row["Sub_part"])) {
            $length[$row["Column_name"]] = $row["Sub_part"];
        }
        $isIndex = (
            $type == TableSchema::INDEX_INDEX ||
            $type == TableSchema::INDEX_FULLTEXT
        );
        if ($isIndex) {
            $existing = $schema.getIndex($name);
        } else {
            $existing = $schema.getConstraint($name);
        }

        // MySQL multi column indexes come back as multiple rows.
        if (!empty($existing)) {
            $columns = array_merge($existing["columns"], $columns);
            $length = array_merge($existing["length"], $length);
        }
        if ($isIndex) {
            $schema.addIndex($name, [
                "type": $type,
                "columns": $columns,
                "length": $length,
            ]);
        } else {
            $schema.addConstraint($name, [
                "type": $type,
                "columns": $columns,
                "length": $length,
            ]);
        }
    }


    array describeForeignKeySql(string $tableName, Json aConfig) {
        $sql = "SELECT * FROM information_schema.key_column_usage AS kcu
            INNER JOIN information_schema.referential_constraints AS rc
            ON (
                kcu.CONSTRAINT_NAME = rc.CONSTRAINT_NAME
                AND kcu.CONSTRAINT_SCHEMA = rc.CONSTRAINT_SCHEMA
            )
            WHERE kcu.TABLE_SCHEMA = ? AND kcu.TABLE_NAME = ? AND rc.TABLE_NAME = ?
            ORDER BY kcu.ORDINAL_POSITION ASC";

        return [$sql, [aConfig["database"], $tableName, $tableName]];
    }


    void convertForeignKeyDescription(TableSchema $schema, array $row) {
        $data = [
            "type": TableSchema::CONSTRAINT_FOREIGN,
            "columns": [$row["COLUMN_NAME"]],
            "references": [$row["REFERENCED_TABLE_NAME"], $row["REFERENCED_COLUMN_NAME"]],
            "update": _convertOnClause($row["UPDATE_RULE"]),
            "delete": _convertOnClause($row["DELETE_RULE"]),
        ];
        $name = $row["CONSTRAINT_NAME"];
        $schema.addConstraint($name, $data);
    }


    array truncateTableSql(TableSchema $schema) {
        return [sprintf("TRUNCATE TABLE `%s`", $schema.name())];
    }


    array createTableSql(TableSchema $schema, array $columns, array $constraints, array $indexes) {
        $content = implode(",\n", array_merge($columns, $constraints, $indexes));
        $temporary = $schema.isTemporary() ? " TEMPORARY " : " ";
        $content = sprintf("CREATE%sTABLE `%s` (\n%s\n)", $temporary, $schema.name(), $content);
        $options = $schema.getOptions();
        if (isset($options["engine"])) {
            $content ~= sprintf(" ENGINE=%s", $options["engine"]);
        }
        if (isset($options["charset"])) {
            $content ~= sprintf(" DEFAULT CHARSET=%s", $options["charset"]);
        }
        if (isset($options["collate"])) {
            $content ~= sprintf(" COLLATE=%s", $options["collate"]);
        }

        return [$content];
    }


    string columnSql(TableSchema $schema, string aName) {
        /** @var array $data */
        $data = $schema.getColumn($name);

        $sql = _getTypeSpecificColumnSql($data["type"], $schema, $name);
        if ($sql != null) {
            return $sql;
        }

        $out = _driver.quoteIdentifier($name);
        $nativeJson = _driver.supports(IDriver::FEATURE_JSON);

        $typeMap = [
            TableSchema::TYPE_TINYINTEGER: " TINYINT",
            TableSchema::TYPE_SMALLINTEGER: " SMALLINT",
            TableSchema::TYPE_INTEGER: " INTEGER",
            TableSchema::TYPE_BIGINTEGER: " BIGINT",
            TableSchema::TYPE_BINARY_UUID: " BINARY(16)",
            TableSchema::TYPE_BOOLEAN: " BOOLEAN",
            TableSchema::TYPE_FLOAT: " FLOAT",
            TableSchema::TYPE_DECIMAL: " DECIMAL",
            TableSchema::TYPE_DATE: " DATE",
            TableSchema::TYPE_TIME: " TIME",
            TableSchema::TYPE_DATETIME: " DATETIME",
            TableSchema::TYPE_DATETIME_FRACTIONAL: " DATETIME",
            TableSchema::TYPE_TIMESTAMP: " TIMESTAMP",
            TableSchema::TYPE_TIMESTAMP_FRACTIONAL: " TIMESTAMP",
            TableSchema::TYPE_TIMESTAMP_TIMEZONE: " TIMESTAMP",
            TableSchema::TYPE_CHAR: " CHAR",
            TableSchema::TYPE_UUID: " CHAR(36)",
            TableSchema::TYPE_JSON: $nativeJson ? " JSON" : " LONGTEXT",
        ];
        $specialMap = [
            "string": true,
            "text": true,
            "char": true,
            "binary": true,
        ];
        if (isset($typeMap[$data["type"]])) {
            $out ~= $typeMap[$data["type"]];
        }
        if (isset($specialMap[$data["type"]])) {
            switch ($data["type"]) {
                case TableSchema::TYPE_STRING:
                    $out ~= " VARCHAR";
                    if (!isset($data["length"])) {
                        $data["length"] = 255;
                    }
                    break;
                case TableSchema::TYPE_TEXT:
                    $isKnownLength = hasAllValues($data["length"], TableSchema::$columnLengths);
                    if (empty($data["length"]) || !$isKnownLength) {
                        $out ~= " TEXT";
                        break;
                    }

                    /** @var string $length */
                    $length = array_search($data["length"], TableSchema::$columnLengths);
                    $out ~= " " ~ $length.toUpper ~ "TEXT";

                    break;
                case TableSchema::TYPE_BINARY:
                    $isKnownLength = hasAllValues($data["length"], TableSchema::$columnLengths);
                    if ($isKnownLength) {
                        /** @var string $length */
                        $length = array_search($data["length"], TableSchema::$columnLengths);
                        $out ~= " " ~ $length.toUpper ~ "BLOB";
                        break;
                    }

                    if (empty($data["length"])) {
                        $out ~= " BLOB";
                        break;
                    }

                    if ($data["length"] > 2) {
                        $out ~= " VARBINARY(" ~ $data["length"] ~ ")";
                    } else {
                        $out ~= " BINARY(" ~ $data["length"] ~ ")";
                    }
                    break;
            }
        }
        $hasLength = [
            TableSchema::TYPE_INTEGER,
            TableSchema::TYPE_CHAR,
            TableSchema::TYPE_SMALLINTEGER,
            TableSchema::TYPE_TINYINTEGER,
            TableSchema::TYPE_STRING,
        ];
        if (hasAllValues($data["type"], $hasLength, true) && isset($data["length"])) {
            $out ~= "(" ~ $data["length"] ~ ")";
        }

        $lengthAndPrecisionTypes = [TableSchema::TYPE_FLOAT, TableSchema::TYPE_DECIMAL];
        if (hasAllValues($data["type"], $lengthAndPrecisionTypes, true) && isset($data["length"])) {
            if (isset($data["precision"])) {
                $out ~= "(" ~ (int)$data["length"] ~ "," ~ (int)$data["precision"] ~ ")";
            } else {
                $out ~= "(" ~ (int)$data["length"] ~ ")";
            }
        }

        $precisionTypes = [TableSchema::TYPE_DATETIME_FRACTIONAL, TableSchema::TYPE_TIMESTAMP_FRACTIONAL];
        if (hasAllValues($data["type"], $precisionTypes, true) && isset($data["precision"])) {
            $out ~= "(" ~ (int)$data["precision"] ~ ")";
        }

        $hasUnsigned = [
            TableSchema::TYPE_TINYINTEGER,
            TableSchema::TYPE_SMALLINTEGER,
            TableSchema::TYPE_INTEGER,
            TableSchema::TYPE_BIGINTEGER,
            TableSchema::TYPE_FLOAT,
            TableSchema::TYPE_DECIMAL,
        ];
        if (
            hasAllValues($data["type"], $hasUnsigned, true) &&
            isset($data["unsigned"]) &&
            $data["unsigned"] == true
        ) {
            $out ~= " UNSIGNED";
        }

        $hasCollate = [
            TableSchema::TYPE_TEXT,
            TableSchema::TYPE_CHAR,
            TableSchema::TYPE_STRING,
        ];
        if (hasAllValues($data["type"], $hasCollate, true) && isset($data["collate"]) && $data["collate"] != "") {
            $out ~= " COLLATE " ~ $data["collate"];
        }

        if (isset($data["null"]) && $data["null"] == false) {
            $out ~= " NOT NULL";
        }
        $addAutoIncrement = (
            $schema.getPrimaryKeys() == [$name] &&
            !$schema.hasAutoincrement() &&
            !isset($data["autoIncrement"])
        );
        if (
            hasAllValues($data["type"], [TableSchema::TYPE_INTEGER, TableSchema::TYPE_BIGINTEGER]) &&
            (
                $data["autoIncrement"] == true ||
                $addAutoIncrement
            )
        ) {
            $out ~= " AUTO_INCREMENT";
        }

        $timestampTypes = [
            TableSchema::TYPE_TIMESTAMP,
            TableSchema::TYPE_TIMESTAMP_FRACTIONAL,
            TableSchema::TYPE_TIMESTAMP_TIMEZONE,
        ];
        if (isset($data["null"]) && $data["null"] == true && hasAllValues($data["type"], $timestampTypes, true)) {
            $out ~= " NULL";
            unset($data["default"]);
        }

        $dateTimeTypes = [
            TableSchema::TYPE_DATETIME,
            TableSchema::TYPE_DATETIME_FRACTIONAL,
            TableSchema::TYPE_TIMESTAMP,
            TableSchema::TYPE_TIMESTAMP_FRACTIONAL,
            TableSchema::TYPE_TIMESTAMP_TIMEZONE,
        ];
        if (
            isset($data["default"]) &&
            hasAllValues($data["type"], $dateTimeTypes) &&
            strpos(strtolower($data["default"]), "current_timestamp") != false
        ) {
            $out ~= " DEFAULT CURRENT_TIMESTAMP";
            if (isset($data["precision"])) {
                $out ~= "(" ~ $data["precision"] ~ ")";
            }
            unset($data["default"]);
        }
        if (isset($data["default"])) {
            $out ~= " DEFAULT " ~ _driver.schemaValue($data["default"]);
            unset($data["default"]);
        }
        if (isset($data["comment"]) && $data["comment"] != "") {
            $out ~= " COMMENT " ~ _driver.schemaValue($data["comment"]);
        }

        return $out;
    }


    string constraintSql(TableSchema $schema, string aName) {
        /** @var array $data */
        $data = $schema.getConstraint($name);
        if ($data["type"] == TableSchema::CONSTRAINT_PRIMARY) {
            $columns = array_map(
                [_driver, "quoteIdentifier"],
                $data["columns"]
            );

            return sprintf("PRIMARY KEY (%s)", implode(", ", $columns));
        }

        $out = "";
        if ($data["type"] == TableSchema::CONSTRAINT_UNIQUE) {
            $out = "UNIQUE KEY ";
        }
        if ($data["type"] == TableSchema::CONSTRAINT_FOREIGN) {
            $out = "CONSTRAINT ";
        }
        $out ~= _driver.quoteIdentifier($name);

        return _keySql($out, $data);
    }


    array addConstraintSql(TableSchema $schema) {
        $sqlPattern = "ALTER TABLE %s ADD %s;";
        $sql = null;

        foreach ($schema.constraints() as $name) {
            /** @var array $constraint */
            $constraint = $schema.getConstraint($name);
            if ($constraint["type"] == TableSchema::CONSTRAINT_FOREIGN) {
                $tableName = _driver.quoteIdentifier($schema.name());
                $sql[] = sprintf($sqlPattern, $tableName, this.constraintSql($schema, $name));
            }
        }

        return $sql;
    }


    array dropConstraintSql(TableSchema $schema) {
        $sqlPattern = "ALTER TABLE %s DROP FOREIGN KEY %s;";
        $sql = null;

        foreach ($schema.constraints() as $name) {
            /** @var array $constraint */
            $constraint = $schema.getConstraint($name);
            if ($constraint["type"] == TableSchema::CONSTRAINT_FOREIGN) {
                $tableName = _driver.quoteIdentifier($schema.name());
                $constraintName = _driver.quoteIdentifier($name);
                $sql[] = sprintf($sqlPattern, $tableName, $constraintName);
            }
        }

        return $sql;
    }


    string indexSql(TableSchema $schema, string aName) {
        /** @var array $data */
        $data = $schema.getIndex($name);
        $out = "";
        if ($data["type"] == TableSchema::INDEX_INDEX) {
            $out = "KEY ";
        }
        if ($data["type"] == TableSchema::INDEX_FULLTEXT) {
            $out = "FULLTEXT KEY ";
        }
        $out ~= _driver.quoteIdentifier($name);

        return _keySql($out, $data);
    }

    /**
     * Helper method for generating key SQL snippets.
     *
     * @param string $prefix The key prefix
     * @param array $data Key data.
     */
    protected string _keySql(string $prefix, array $data) {
        $columns = array_map(
            [_driver, "quoteIdentifier"],
            $data["columns"]
        );
        foreach ($data["columns"] as $i: $column) {
            if (isset($data["length"][$column])) {
                $columns[$i] ~= sprintf("(%d)", $data["length"][$column]);
            }
        }
        if ($data["type"] == TableSchema::CONSTRAINT_FOREIGN) {
            return $prefix . sprintf(
                " FOREIGN KEY (%s) REFERENCES %s (%s) ON UPDATE %s ON DELETE %s",
                implode(", ", $columns),
                _driver.quoteIdentifier($data["references"][0]),
                _convertConstraintColumns($data["references"][1]),
                _foreignOnClause($data["update"]),
                _foreignOnClause($data["delete"])
            );
        }

        return $prefix ~ " (" ~ implode(", ", $columns) ~ ")";
    }
}

// phpcs:disable
// Add backwards compatible alias.
class_alias("Cake\databases.Schema\MysqlSchemaDialect", "Cake\databases.Schema\MysqlSchema");
// phpcs:enable
