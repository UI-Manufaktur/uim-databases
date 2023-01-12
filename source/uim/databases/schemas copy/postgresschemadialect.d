module uim.cake.databases.schemas;

import uim.cake.databases.exceptions.DatabaseException;

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
     * @param array<string, mixed> aConfig The connection configuration to use for
     *    getting tables from.
     * @return array An array of (sql, params) to execute.
     */
    array listTablesSql(Json aConfig) {
        $sql = "SELECT table_name as name FROM information_schema.tables
                WHERE table_schema = ? ORDER BY name";
        $schema = empty(aConfig["schema"]) ? "public" : aConfig["schema"];

        return [$sql, [$schema]];
    }

    /**
     * Generate the SQL to list the tables, excluding all views.
     *
     * @param array<string, mixed> aConfig The connection configuration to use for
     *    getting tables from.
     * @return array<mixed> An array of (sql, params) to execute.
     */
    array listTablesWithoutViewsSql(Json aConfig) {
        $sql = "SELECT table_name as name FROM information_schema.tables
                WHERE table_schema = ? AND table_type = \"BASE TABLE\" ORDER BY name";
        $schema = empty(aConfig["schema"]) ? "public" : aConfig["schema"];

        return [$sql, [$schema]];
    }


    array describeColumnSql(string $tableName, Json aConfig) {
        $sql = "SELECT DISTINCT table_schema AS schema,
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

        $schema = empty(aConfig["schema"]) ? "public" : aConfig["schema"];

        return [$sql, [$tableName, $schema, aConfig["database"]]];
    }

    /**
     * Convert a column definition to the abstract types.
     *
     * The returned type will be a type that
     * Cake\databases.TypeFactory can handle.
     *
     * @param string $column The column type + length
     * @throws uim.cake.databases.exceptions.DatabaseException when column cannot be parsed.
     * @return array<string, mixed> Array of column information.
     */
    protected array _convertColumn(string $column) {
        preg_match("/([a-z\s]+)(?:\(([0-9,]+)\))?/i", $column, $matches);
        if (empty($matches)) {
            throw new DatabaseException(sprintf("Unable to parse column type from '%s'", $column));
        }

        $col = strtolower($matches[1]);
        $length = $precision = $scale = null;
        if (isset($matches[2])) {
            $length = (int)$matches[2];
        }

        $type = _applyTypeSpecificColumnConversion(
            $col,
            compact("length", "precision", "scale")
        );
        if ($type != null) {
            return $type;
        }

        if (hasAllValues($col, ["date", "time", "boolean"], true)) {
            return ["type": $col, "length": null];
        }
        if (hasAllValues($col, ["timestamptz", "timestamp with time zone"], true)) {
            return ["type": TableSchema::TYPE_TIMESTAMP_TIMEZONE, "length": null];
        }
        if (strpos($col, "timestamp") != false) {
            return ["type": TableSchema::TYPE_TIMESTAMP_FRACTIONAL, "length": null];
        }
        if (strpos($col, "time") != false) {
            return ["type": TableSchema::TYPE_TIME, "length": null];
        }
        if ($col == "serial" || $col == "integer") {
            return ["type": TableSchema::TYPE_INTEGER, "length": 10];
        }
        if ($col == "bigserial" || $col == "bigint") {
            return ["type": TableSchema::TYPE_BIGINTEGER, "length": 20];
        }
        if ($col == "smallint") {
            return ["type": TableSchema::TYPE_SMALLINTEGER, "length": 5];
        }
        if ($col == "inet") {
            return ["type": TableSchema::TYPE_STRING, "length": 39];
        }
        if ($col == "uuid") {
            return ["type": TableSchema::TYPE_UUID, "length": null];
        }
        if ($col == "char") {
            return ["type": TableSchema::TYPE_CHAR, "length": $length];
        }
        if (strpos($col, "character") != false) {
            return ["type": TableSchema::TYPE_STRING, "length": $length];
        }
        // money is "string" as it includes arbitrary text content
        // before the number value.
        if (strpos($col, "money") != false || $col == "string") {
            return ["type": TableSchema::TYPE_STRING, "length": $length];
        }
        if (strpos($col, "text") != false) {
            return ["type": TableSchema::TYPE_TEXT, "length": null];
        }
        if ($col == "bytea") {
            return ["type": TableSchema::TYPE_BINARY, "length": null];
        }
        if ($col == "real" || strpos($col, "double") != false) {
            return ["type": TableSchema::TYPE_FLOAT, "length": null];
        }
        if (
            strpos($col, "numeric") != false ||
            strpos($col, "decimal") != false
        ) {
            return ["type": TableSchema::TYPE_DECIMAL, "length": null];
        }

        if (strpos($col, "json") != false) {
            return ["type": TableSchema::TYPE_JSON, "length": null];
        }

        $length = is_numeric($length) ? $length : null;

        return ["type": TableSchema::TYPE_STRING, "length": $length];
    }


    void convertColumnDescription(TableSchema $schema, array $row) {
        $field = _convertColumn($row["type"]);

        if ($field["type"] == TableSchema::TYPE_BOOLEAN) {
            if ($row["default"] == "true") {
                $row["default"] = 1;
            }
            if ($row["default"] == "false") {
                $row["default"] = 0;
            }
        }
        if (!empty($row["has_serial"])) {
            $field["autoIncrement"] = true;
        }

        $field += [
            "default": _defaultValue($row["default"]),
            "null": $row["null"] == "YES",
            "collate": $row["collation_name"],
            "comment": $row["comment"],
        ];
        $field["length"] = $row["char_length"] ?: $field["length"];

        if ($field["type"] == "numeric" || $field["type"] == "decimal") {
            $field["length"] = $row["column_precision"];
            $field["precision"] = $row["column_scale"] ?: null;
        }

        if ($field["type"] == TableSchema::TYPE_TIMESTAMP_FRACTIONAL) {
            $field["precision"] = $row["datetime_precision"];
            if ($field["precision"] == 0) {
                $field["type"] = TableSchema::TYPE_TIMESTAMP;
            }
        }

        if ($field["type"] == TableSchema::TYPE_TIMESTAMP_TIMEZONE) {
            $field["precision"] = $row["datetime_precision"];
        }

        $schema.addColumn($row["name"], $field);
    }

    /**
     * Manipulate the default value.
     *
     * Postgres includes sequence data and casting information in default values.
     * We need to remove those.
     *
     * @param string|int|null $default The default value.
     * @return string|int|null
     */
    protected function _defaultValue($default) {
        if (is_numeric($default) || $default == null) {
            return $default;
        }
        // Sequences
        if (strpos($default, "nextval") == 0) {
            return null;
        }

        if (strpos($default, "NULL::") == 0) {
            return null;
        }

        // Remove quotes and postgres casts
        return preg_replace(
            "/^"(.*)"(?:::.*)$/",
            "$1",
            $default
        );
    }


    array describeIndexSql(string $tableName, Json aConfig) {
        $sql = "SELECT
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

        $schema = "public";
        if (!empty(aConfig["schema"])) {
            $schema = aConfig["schema"];
        }

        return [$sql, [$schema, $tableName]];
    }


    void convertIndexDescription(TableSchema $schema, array $row) {
        $type = TableSchema::INDEX_INDEX;
        $name = $row["relname"];
        if ($row["indisprimary"]) {
            $name = $type = TableSchema::CONSTRAINT_PRIMARY;
        }
        if ($row["indisunique"] && $type == TableSchema::INDEX_INDEX) {
            $type = TableSchema::CONSTRAINT_UNIQUE;
        }
        if ($type == TableSchema::CONSTRAINT_PRIMARY || $type == TableSchema::CONSTRAINT_UNIQUE) {
            _convertConstraint($schema, $name, $type, $row);

            return;
        }
        $index = $schema.getIndex($name);
        if (!$index) {
            $index = [
                "type": $type,
                "columns": [],
            ];
        }
        $index["columns"][] = $row["attname"];
        $schema.addIndex($name, $index);
    }

    /**
     * Add/update a constraint into the schema object.
     *
     * @param uim.cake.databases.Schema\TableSchema $schema The table to update.
     * @param string aName The index name.
     * @param string $type The index type.
     * @param array $row The metadata record to update with.
     */
    protected void _convertConstraint(TableSchema $schema, string aName, string $type, array $row) {
        $constraint = $schema.getConstraint($name);
        if (!$constraint) {
            $constraint = [
                "type": $type,
                "columns": [],
            ];
        }
        $constraint["columns"][] = $row["attname"];
        $schema.addConstraint($name, $constraint);
    }


    array describeForeignKeySql(string $tableName, Json aConfig) {
        // phpcs:disable Generic.Files.LineLength
        $sql = "SELECT
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

        $schema = empty(aConfig["schema"]) ? "public" : aConfig["schema"];

        return [$sql, [$schema, $tableName]];
    }


    void convertForeignKeyDescription(TableSchema $schema, array $row) {
        $data = [
            "type": TableSchema::CONSTRAINT_FOREIGN,
            "columns": $row["column_name"],
            "references": [$row["references_table"], $row["references_field"]],
            "update": _convertOnClause($row["on_update"]),
            "delete": _convertOnClause($row["on_delete"]),
        ];
        $schema.addConstraint($row["name"], $data);
    }


    protected string _convertOnClause(string $clause) {
        if ($clause == "r") {
            return TableSchema::ACTION_RESTRICT;
        }
        if ($clause == "a") {
            return TableSchema::ACTION_NO_ACTION;
        }
        if ($clause == "c") {
            return TableSchema::ACTION_CASCADE;
        }

        return TableSchema::ACTION_SET_NULL;
    }


    string columnSql(TableSchema $schema, string aName) {
        /** @var array $data */
        $data = $schema.getColumn($name);

        $sql = _getTypeSpecificColumnSql($data["type"], $schema, $name);
        if ($sql != null) {
            return $sql;
        }

        $out = _driver.quoteIdentifier($name);
        $typeMap = [
            TableSchema::TYPE_TINYINTEGER: " SMALLINT",
            TableSchema::TYPE_SMALLINTEGER: " SMALLINT",
            TableSchema::TYPE_BINARY_UUID: " UUID",
            TableSchema::TYPE_BOOLEAN: " BOOLEAN",
            TableSchema::TYPE_FLOAT: " FLOAT",
            TableSchema::TYPE_DECIMAL: " DECIMAL",
            TableSchema::TYPE_DATE: " DATE",
            TableSchema::TYPE_TIME: " TIME",
            TableSchema::TYPE_DATETIME: " TIMESTAMP",
            TableSchema::TYPE_DATETIME_FRACTIONAL: " TIMESTAMP",
            TableSchema::TYPE_TIMESTAMP: " TIMESTAMP",
            TableSchema::TYPE_TIMESTAMP_FRACTIONAL: " TIMESTAMP",
            TableSchema::TYPE_TIMESTAMP_TIMEZONE: " TIMESTAMPTZ",
            TableSchema::TYPE_UUID: " UUID",
            TableSchema::TYPE_CHAR: " CHAR",
            TableSchema::TYPE_JSON: " JSONB",
        ];

        if (isset($typeMap[$data["type"]])) {
            $out ~= $typeMap[$data["type"]];
        }

        if ($data["type"] == TableSchema::TYPE_INTEGER || $data["type"] == TableSchema::TYPE_BIGINTEGER) {
            $type = $data["type"] == TableSchema::TYPE_INTEGER ? " INTEGER" : " BIGINT";
            if ($schema.getPrimaryKeys() == [$name] || $data["autoIncrement"] == true) {
                $type = $data["type"] == TableSchema::TYPE_INTEGER ? " SERIAL" : " BIGSERIAL";
                unset($data["null"], $data["default"]);
            }
            $out ~= $type;
        }

        if ($data["type"] == TableSchema::TYPE_TEXT && $data["length"] != TableSchema::LENGTH_TINY) {
            $out ~= " TEXT";
        }
        if ($data["type"] == TableSchema::TYPE_BINARY) {
            $out ~= " BYTEA";
        }

        if ($data["type"] == TableSchema::TYPE_CHAR) {
            $out ~= "(" ~ $data["length"] ~ ")";
        }

        if (
            $data["type"] == TableSchema::TYPE_STRING ||
            (
                $data["type"] == TableSchema::TYPE_TEXT &&
                $data["length"] == TableSchema::LENGTH_TINY
            )
        ) {
            $out ~= " VARCHAR";
            if (isset($data["length"]) && $data["length"] != "") {
                $out ~= "(" ~ $data["length"] ~ ")";
            }
        }

        $hasCollate = [TableSchema::TYPE_TEXT, TableSchema::TYPE_STRING, TableSchema::TYPE_CHAR];
        if (hasAllValues($data["type"], $hasCollate, true) && isset($data["collate"]) && $data["collate"] != "") {
            $out ~= " COLLATE "" ~ $data["collate"] ~ """;
        }

        $hasPrecision = [
            TableSchema::TYPE_FLOAT,
            TableSchema::TYPE_DATETIME,
            TableSchema::TYPE_DATETIME_FRACTIONAL,
            TableSchema::TYPE_TIMESTAMP,
            TableSchema::TYPE_TIMESTAMP_FRACTIONAL,
            TableSchema::TYPE_TIMESTAMP_TIMEZONE,
        ];
        if (hasAllValues($data["type"], $hasPrecision) && isset($data["precision"])) {
            $out ~= "(" ~ $data["precision"] ~ ")";
        }

        if (
            $data["type"] == TableSchema::TYPE_DECIMAL &&
            (
                isset($data["length"]) ||
                isset($data["precision"])
            )
        ) {
            $out ~= "(" ~ $data["length"] ~ "," ~ (int)$data["precision"] ~ ")";
        }

        if (isset($data["null"]) && $data["null"] == false) {
            $out ~= " NOT NULL";
        }

        $datetimeTypes = [
            TableSchema::TYPE_DATETIME,
            TableSchema::TYPE_DATETIME_FRACTIONAL,
            TableSchema::TYPE_TIMESTAMP,
            TableSchema::TYPE_TIMESTAMP_FRACTIONAL,
            TableSchema::TYPE_TIMESTAMP_TIMEZONE,
        ];
        if (
            isset($data["default"]) &&
            hasAllValues($data["type"], $datetimeTypes) &&
            strtolower($data["default"]) == "current_timestamp"
        ) {
            $out ~= " DEFAULT CURRENT_TIMESTAMP";
        } elseif (isset($data["default"])) {
            $defaultValue = $data["default"];
            if ($data["type"] == "boolean") {
                $defaultValue = (bool)$defaultValue;
            }
            $out ~= " DEFAULT " ~ _driver.schemaValue($defaultValue);
        } elseif (isset($data["null"]) && $data["null"] != false) {
            $out ~= " DEFAULT NULL";
        }

        return $out;
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
        $sqlPattern = "ALTER TABLE %s DROP CONSTRAINT %s;";
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
        $columns = array_map(
            [_driver, "quoteIdentifier"],
            $data["columns"]
        );

        return sprintf(
            "CREATE INDEX %s ON %s (%s)",
            _driver.quoteIdentifier($name),
            _driver.quoteIdentifier($schema.name()),
            implode(", ", $columns)
        );
    }


    string constraintSql(TableSchema $schema, string aName) {
        /** @var array<string, mixed> $data */
        $data = $schema.getConstraint($name);
        $out = "CONSTRAINT " ~ _driver.quoteIdentifier($name);
        if ($data["type"] == TableSchema::CONSTRAINT_PRIMARY) {
            $out = "PRIMARY KEY";
        }
        if ($data["type"] == TableSchema::CONSTRAINT_UNIQUE) {
            $out ~= " UNIQUE";
        }

        return _keySql($out, $data);
    }

    /**
     * Helper method for generating key SQL snippets.
     *
     * @param string $prefix The key prefix
     * @param array<string, mixed> $data Key data.
     */
    protected string _keySql(string $prefix, array $data) {
        $columns = array_map(
            [_driver, "quoteIdentifier"],
            $data["columns"]
        );
        if ($data["type"] == TableSchema::CONSTRAINT_FOREIGN) {
            return $prefix . sprintf(
                " FOREIGN KEY (%s) REFERENCES %s (%s) ON UPDATE %s ON DELETE %s DEFERRABLE INITIALLY IMMEDIATE",
                implode(", ", $columns),
                _driver.quoteIdentifier($data["references"][0]),
                _convertConstraintColumns($data["references"][1]),
                _foreignOnClause($data["update"]),
                _foreignOnClause($data["delete"])
            );
        }

        return $prefix ~ " (" ~ implode(", ", $columns) ~ ")";
    }


    array createTableSql(TableSchema $schema, array $columns, array $constraints, array $indexes) {
        $content = array_merge($columns, $constraints);
        $content = implode(",\n", array_filter($content));
        $tableName = _driver.quoteIdentifier($schema.name());
        $temporary = $schema.isTemporary() ? " TEMPORARY " : " ";
        $out = null;
        $out[] = sprintf("CREATE%sTABLE %s (\n%s\n)", $temporary, $tableName, $content);
        foreach ($indexes as $index) {
            $out[] = $index;
        }
        foreach ($schema.columns() as $column) {
            $columnData = $schema.getColumn($column);
            if (isset($columnData["comment"])) {
                $out[] = sprintf(
                    "COMMENT ON COLUMN %s.%s IS %s",
                    $tableName,
                    _driver.quoteIdentifier($column),
                    _driver.schemaValue($columnData["comment"])
                );
            }
        }

        return $out;
    }


    array truncateTableSql(TableSchema $schema) {
        $name = _driver.quoteIdentifier($schema.name());

        return [
            sprintf("TRUNCATE %s RESTART IDENTITY CASCADE", $name),
        ];
    }

    /**
     * Generate the SQL to drop a table.
     *
     * @param uim.cake.databases.Schema\TableSchema $schema Table instance
     * @return array SQL statements to drop a table.
     */
    array dropTableSql(TableSchema $schema) {
        $sql = sprintf(
            "DROP TABLE %s CASCADE",
            _driver.quoteIdentifier($schema.name())
        );

        return [$sql];
    }
}

// phpcs:disable
// Add backwards compatible alias.
class_alias("Cake\databases.Schema\PostgresSchemaDialect", "Cake\databases.Schema\PostgresSchema");
// phpcs:enable
