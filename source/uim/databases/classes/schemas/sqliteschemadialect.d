module uim.databases.schemas;

import uim.databases;

@safe:

/**
 * Schema management/reflection features for Sqlite
 *
 * @internal
 */
class SqliteSchemaDialect : SchemaDialect {
    // Whether there is any table in this connection to SQLite containing sequences.
    protected bool _hasSequences;

    /**
     * Convert a column definition to the abstract types.
     *
     * The returned type will be a type that
     * UIM\Database\TypeFactory can handle.
     * Params:
     * string acolumn The column type + length
     * @throws \UIM\Database\Exception\DatabaseException when unable to parse column type
     */
    protected IData[string] _convertColumn(string aColumn) {
        if (aColumn.isEmpty) {
            return ["type": TableISchema.TYPE_TEXT, "length": null];
        }
        preg_match("/(unsigned)?\s*([a-z]+)(?:\(([0-9,]+)\))?/i", aColumn, $matches);
        if (!$matches) {
            throw new DatabaseException("Unable to parse column type from `%s`".format(aColumn));
        }
        bool isUnsigned = false;
        if ($matches[1].toLower == "unsigned") {
            isUnsigned = true;
        }
        auto col = $matches[2].toLower;
        size_t columnLength = precision = scale = null;
        if (isSet($matches[3])) {
            columnLength = $matches[3];
            if (columnLength.has(",")) {
                [columnLength, precision] = split(",", columnLength);
            }
            columnLength = (int)columnLength;
            precision = (int)precision;
        }
        type = _applyTypeSpecificColumnConversion(
            col,
            compact("length", "precision", "scale")
        );
        if (type !isNull) {
            return type;
        }
        if (col == "bigint") {
            return ["type": TableISchema.TYPE_BIGINTEGER, "length": columnLength, "unsigned": isUnsigned];
        }
        if (col == "smallint") {
            return ["type": TableISchema.TYPE_SMALLINTEGER, "length": columnLength, "unsigned": isUnsigned];
        }
        if (col == "tinyint") {
            return ["type": TableISchema.TYPE_TINYINTEGER, "length": columnLength, "unsigned": isUnsigned];
        }
        if (col.has("int")) {
            return ["type": TableISchema.TYPE_INTEGER, "length": columnLength, "unsigned": isUnsigned];
        }
        if (col.has("decimal")) {
            return [
                "type": TableISchema.TYPE_DECIMAL,
                "length": columnLength,
                "precision": precision,
                "unsigned": unsigned,
            ];
        }
        if (in_array(col, ["float", "real", "double"])) {
            return [
                "type": TableISchema.TYPE_FLOAT,
                "length": columnLength,
                "precision": precision,
                "unsigned": unsigned,
            ];
        }
        if (col.has("boolean")) {
            return ["type": TableISchema.TYPE_BOOLEAN, "length": null];
        }
        if ((col == "binary" && columnLength == 16) || strtolower(aColumn) == "uuid_blob") {
            return ["type": TableISchema.TYPE_BINARY_UUID, "length": null];
        }
        if ((col == "char" && columnLength == 36) || col == "uuid") {
            return ["type": TableISchema.TYPE_UUID, "length": null];
        }
        if (col == "char") {
            return ["type": TableISchema.TYPE_CHAR, "length": columnLength];
        }
        if (col.has("char")) {
            return ["type": TableISchema.TYPE_STRING, "length": columnLength];
        }
        if (in_array(col, ["blob", "clob", "binary", "varbinary"])) {
            return ["type": TableISchema.TYPE_BINARY, "length": columnLength];
        }
        $datetimeTypes = [
            "date",
            "time",
            "timestamp",
            "timestampfractional",
            "timestamptimezone",
            "datetime",
            "datetimefractional",
        ];
        if (in_array(col, $datetimeTypes)) {
            return ["type": col, "length": null];
        }
        return ["type": TableISchema.TYPE_TEXT, "length": null];
    }
    
    /**
     * Generate the SQL to list the tables and views.
     * Params:
     */
    array listTablesSql(IData[string] connectionConfig = null) {
        return [
            "SELECT name FROM sqlite_master " ~
            "WHERE (type=\"table\" OR type=\"view\") " ~
            "AND name != \"sqlite_sequence\" ORDER BY name",
            [],
        ];
    }
    
    /**
     * Generate the SQL to list the tables, excluding all views.
     * Params:
     * IData[string] configData The connection configuration to use for
     *   getting tables from.
     */
    Json[] listTablesWithoutViewsSql(IData[string] configData = null) {
        return [
            "sELECT name FROM sqlite_master WHERE type="table" " ~
            "AND name != "sqlite_sequence" ORDER BY name",
            [],
        ];
    }
 
    array describeColumnSql(string atableName, IData[string] configData) {
        sql = "PRAGMA table_info(%s)".format(_driver.quoteIdentifier(aTableName)
        );

        return [sql, []];
    }
 
    void convertColumnDescription(TableSchema tableSchema, array  row) {
        auto myField = _convertColumn( row["type"]);
        myField += [
            "null": ! row["notnull"],
            "default": _defaultValue( row["dflt_value"]),
        ];
        primary = tableSchema.getConstraint("primary");

        if ( row["pk"] && empty(primary)) {
            myField["null"] = false;
            myField["autoIncrement"] = true;
        }
        // SQLite does not support autoincrement on composite keys.
        if ( row["pk"] && !empty(primary)) {
            existingColumn = primary["columns"][0];
            /** @psalm-suppress PossiblyNullOperand */
            tableSchema.addColumn(existingColumn, ["autoIncrement": null] + tableSchema.getColumn(existingColumn));
        }
        tableSchema.addColumn( row["name"], myField);
        if ( row["pk"]) {
            constraint = (array)tableSchema.getConstraint("primary") ~ [
                "type": TableSchema.CONSTRAINT_PRIMARY,
                "columns": [],
            ];
            constraint["columns"] = array_merge(constraint["columns"], [ row["name"]]);
            tableSchema.addConstraint("primary", constraint);
        }
    }
    
    /**
     * Manipulate the default value.
     *
     * Sqlite includes quotes and bared NULLs in default values.
     * We need to remove those.
     * Params:
     * string|int $default The default value.
     */
    protected string|int _defaultValue(string|int $default) {
        if ($default == "NULL" || $default.isNull) {
            return null;
        }
        // Remove quotes
        if (isString($default) && preg_match("/^'(.*)'$/", $default, $matches)) {
            return $matches[1].replace("\"\"", "'");
        }
        return $default;
    }
 
    array describeIndexSql(string atableName, IData[string] configData) {
        string sql = "PRAGMA index_list(%s)"
            .format(_driver.quoteIdentifier(aTableName)
        );

        return [sql, []];
    }
    
    /**
     * Generates a regular expression to match identifiers that may or
     * may not be quoted with any of the supported quotes.
     * Params:
     * string aidentifier The identifier to match.
     */
    protected string possiblyQuotedIdentifierRegex(string aidentifier) {
         anIdentifiers = [];
         anIdentifier = preg_quote(anIdentifier, "/");

        $hasTick = anIdentifier.has("`");
        $hasDoubleQuote = anIdentifier.has("\"");
        $hasSingleQuote = anIdentifier.has("'");

         anIdentifiers ~= "\[" ~  anIdentifier ~ "\]";
         anIdentifiers ~= "`" ~ ($hasTick ? anIdentifier.replace("`", "``"):  anIdentifier) ~ "`";
         anIdentifiers ~= "\"" ~ ($hasDoubleQuote ? anIdentifier.replace("\"", "\"\""):  anIdentifier) ~ """;
         anIdentifiers ~= "'" ~ ($hasSingleQuote ? anIdentifier.replace("'", "\"\""):  anIdentifier) ~ "'";

        if (!$hasTick && !$hasDoubleQuote && !$hasSingleQuote) {
             anIdentifiers ~=  anIdentifier;
        }
        return join("|",  anIdentifiers);
    }
    
    /**
     * Removes possible escape characters and surrounding quotes from identifiers.
     */
    protected string normalizePossiblyQuotedIdentifier(string identifierToNormalize) {
        identifierToNormalize = trim(identifierToNormalize);

        if (identifierToNormalize.startsWith("[") && identifierToNormalize.endsWith("]")) {
            return mb_substr(identifierToNormalize, 1, -1);
        }
        ["`", "'", "\""].each!((quote) {
            if (identifierToNormalize.startsWith( quote) && identifierToNormalize.endsWith( quote)) {
                identifierToNormalize = identifierToNormalize.replace( quote ~  quote,  quote);

                return mb_substr(identifierToNormalize, 1, -1);
            }
        });
        return identifierToNormalize;
    }
    
    /**

     * Since SQLite does not have a way to get metadata about all indexes at once,
     * additional queries are done here. Sqlite constraint names are not
     * stable, and the names for constraints will not match those used to create
     * the table. This is a limitation in Sqlite`s metadata features.
     * Params:
     * \UIM\Database\Schema\TableSchema tableSchema The table object to append
     *   an index or constraint to.
     * @param array  row The row data from `describeIndexSql`.
     */
    void convertIndexDescription(TableSchema tableSchema, array  row) {
        // Skip auto-indexes created for non-ROWID primary keys.
        if ( row["origin"] == "pk") {
            return;
        }
        string sql = "PRAGMA index_info(%s)".format(_driver.quoteIdentifier( row["name"]));
        auto statement = _driver.prepare(sql);
        statement.execute();
        string[] myColumns = statement.fetchAll("assoc")
            .map!(column => column["name"])
            .array;

        if ( row["unique"]) {
            if ( row["origin"] == "u") {
                // Try to obtain the actual constraint name for indexes that are
                // created automatically for unique constraints.

                string sql = "SELECT sql FROM sqlite_master WHERE type = \"table\" AND tbl_name = %s"
                    .format(_driver.quoteIdentifier(tableSchema.name()));
                statement = _driver.prepare(sql);
                statement.execute();

                aTableRow = statement.fetchAssoc();
                aTableSql = aTableRow["sql"] ??= null;

                if (aTableSql) {
                    someColumnsPattern = join(
                        "\s*,\s*",
                        array_map(
                            fn (column): "(?:" ~ this.possiblyQuotedIdentifierRegex(column) ~ ")",
                            someColumns
                        )
                    );

                     regex = "/CONSTRAINT\s*(["\"`\[].+?["\"`\] ])\s*UNIQUE\s*\(\s*(?:{someColumnsPattern})\s*\)/i";
                    if (preg_match( regex, aTableSql, $matches)) {
                         row["name"] = this.normalizePossiblyQuotedIdentifier($matches[1]);
                    }
                }
            }
            tableSchema.addConstraint( row["name"], [
                "type": TableSchema.CONSTRAINT_UNIQUE,
                "columns": someColumns,
            ]);
        } else {
            tableSchema.addIndex( row["name"], [
                "type": TableSchema.INDEX_INDEX,
                "columns": someColumns,
            ]);
        }
    }
 
    array describeForeignKeySql(string atableName, IData[string] configData)
    {
        string sql = 
            "SELECT id FROM pragma_foreign_key_list(%s) GROUP BY id"
            .format(
           _driver.quoteIdentifier(aTableName)
        );

        return [sql, []];
    }
 
    void convertForeignKeyDescription(TableSchema tableSchema, array  row) {
        string sql = sprintf(
            `SELECT * FROM pragma_foreign_key_list(%s) WHERE id = %d ORDER BY seq`
            .format(_driver.quoteIdentifier(tableSchema.name()),  row["id"]));

        statement = _driver.prepare(sql);
        statement.execute();

        someData = [
            "type": TableSchema.CONSTRAINT_FOREIGN,
            "columns": [],
            "references": [],
        ];

        auto foreignKey = null;
        statement.fetchAll("assoc").each!((foreignKey) {
            someData["columns"] ~= foreignKey["from"];
            someData["references"] ~= foreignKey["to"];
        });
        if (count(someData["references"]) == 1) {
            someData["references"] = [foreignKey["table"], someData["references"][0]];
        } else {
            someData["references"] = [foreignKey["table"], someData["references"]];
        }
        someData["update"] = _convertOnClause(foreignKey["on_update"] ?? "");
        someData["delete"] = _convertOnClause(foreignKey["on_delete"] ?? "");

        string name = join("_", someData["columns"]) ~ "_" ~  row["id"] ~ "_fk";

        tableSchema.addConstraint(name, someData);
    }
    
    /**
 Params:
     * \UIM\Database\Schema\TableSchema tableSchema The table instance the column is in.
     * @param string aName The name of the column.
     */
    string columnSql(TableSchema tableSchema, string aName) {
        someData = tableSchema.getColumn(name);
        assert(someData !isNull);

        sql = _getTypeSpecificColumnSql(someData["type"], tableSchema, name);
        if (sql !isNull) {
            return sql;
        }
        typeMap = [
            TableISchema.TYPE_BINARY_UUID: ' BINARY(16)",
            TableISchema.TYPE_UUID: ' CHAR(36)",
            TableISchema.TYPE_CHAR: ' CHAR",
            TableISchema.TYPE_TINYINTEGER: ' TINYINT",
            TableISchema.TYPE_SMALLINTEGER: ' SMALLINT",
            TableISchema.TYPE_INTEGER: ' INTEGER",
            TableISchema.TYPE_BIGINTEGER: ' BIGINT",
            TableISchema.TYPE_BOOLEAN: ' BOOLEAN",
            TableISchema.TYPE_FLOAT: ' FLOAT",
            TableISchema.TYPE_DECIMAL: ' DECIMAL",
            TableISchema.TYPE_DATE: ' DATE",
            TableISchema.TYPE_TIME: ' TIME",
            TableISchema.TYPE_DATETIME: ' DATETIME",
            TableISchema.TYPE_DATETIME_FRACTIONAL: ' DATETIMEFRACTIONAL",
            TableISchema.TYPE_TIMESTAMP: ' TIMESTAMP",
            TableISchema.TYPE_TIMESTAMP_FRACTIONAL: ' TIMESTAMPFRACTIONAL",
            TableISchema.TYPE_TIMESTAMP_TIMEZONE: ' TIMESTAMPTIMEZONE",
            TableISchema.TYPE_JSON: ' TEXT",
        ];

         result = _driver.quoteIdentifier(name);
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
            if (someData["type"] != TableISchema.TYPE_INTEGER || tableSchema.getPrimaryKey() != [name]) {
                 result ~= " UNSIGNED";
            }
        }
        if (isSet(typeMap[someData["type"]])) {
             result ~= typeMap[someData["type"]];
        }
        if (someData["type"] == TableISchema.TYPE_TEXT && someData["length"] != TableSchema.LENGTH_TINY) {
             result ~= " TEXT";
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

            if (isSet(someData["length"])) {
                 result ~= "(" ~ someData["length"] ~ ")";
            }
        }
        if (someData["type"] == TableISchema.TYPE_BINARY) {
            if (isSet(someData["length"])) {
                 result ~= " BLOB(" ~ someData["length"] ~ ")";
            } else {
                 result ~= " BLOB";
            }
        }
         anIntegerTypes = [
            TableISchema.TYPE_TINYINTEGER,
            TableISchema.TYPE_SMALLINTEGER,
            TableISchema.TYPE_INTEGER,
        ];
        if (
            in_array(someData["type"],  anIntegerTypes, true) &&
            isSet(someData["length"]) &&
            tableSchema.getPrimaryKey() != [name]
        ) {
             result ~= "(" ~ (int)someData["length"] ~ ")";
        }
        $hasPrecision = [TableISchema.TYPE_FLOAT, TableISchema.TYPE_DECIMAL];
        if (
            in_array(someData["type"], $hasPrecision, true) &&
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
        if (someData["type"] == TableISchema.TYPE_INTEGER) {
            if (tableSchema.getPrimaryKey() == [name]) {
                 result ~= " PRIMARY KEY";

                if ((name == "id" || someData["autoIncrement"]) && someData["autoIncrement"] != false) {
                     result ~= " AUTOINCREMENT";
                    unset(someData["default"]);
                }
            }
        }
        timestampTypes = [
            TableISchema.TYPE_DATETIME,
            TableISchema.TYPE_DATETIME_FRACTIONAL,
            TableISchema.TYPE_TIMESTAMP,
            TableISchema.TYPE_TIMESTAMP_FRACTIONAL,
            TableISchema.TYPE_TIMESTAMP_TIMEZONE,
        ];
        if (isSet(someData["null"]) && someData["null"] == true && in_array(someData["type"], timestampTypes, true)) {
             result ~= " DEFAULT NULL";
        }
        if (isSet(someData["default"])) {
             result ~= " DEFAULT " ~ _driver.schemaValue(someData["default"]);
        }
        return result;
    }
    
    /**

     * Note integer primary keys will return "". This is intentional as Sqlite requires
     * that integer primary keys be defined in the column definition.
     * Params:
     * \UIM\Database\Schema\TableSchema tableSchema The table instance the column is in.
     * @param string aName The name of the column.
     */
    string constraintSql(TableSchema tableSchema, string aName) {
        someData = tableSchema.getConstraint(name);
        assert(someData !isNull, "Data does not exist");

        column = tableSchema.getColumn(someData["columns"][0]);
        assert(column !isNull, "Data does not exist");

        if (
            someData["type"] == TableSchema.CONSTRAINT_PRIMARY &&
            count(someData["columns"]) == 1 &&
            column["type"] == TableISchema.TYPE_INTEGER
        ) {
            return "";
        }
        clause = "";
        type = "";
        if (someData["type"] == TableSchema.CONSTRAINT_PRIMARY) {
            type = "PRIMARY KEY";
        }
        if (someData["type"] == TableSchema.CONSTRAINT_UNIQUE) {
            type = "UNIQUE";
        }
        if (someData["type"] == TableSchema.CONSTRAINT_FOREIGN) {
            type = "FOREIGN KEY";

            clause = sprintf(
                " REFERENCES %s (%s) ON UPDATE %s ON DELETE %s",
               _driver.quoteIdentifier(someData["references"][0]),
               _convertConstraintColumns(someData["references"][1]),
               _foreignOnClause(someData["update"]),
               _foreignOnClause(someData["delete"])
            );
        }
        someColumns = array_map(
            [_driver, "quoteIdentifier"],
            someData["columns"]
        );

        return 
            "CONSTRAINT %s %s (%s)%s"
            .format(_driver.quoteIdentifier(name),
            type,
            join(", ", someColumns),
            clause
        );
    }
    
    /**

     * SQLite can not properly handle adding a constraint to an existing table.
     * This method is no-op
     * Params:
     * \UIM\Database\Schema\TableSchema tableSchema The table instance the foreign key constraints are.
     */
    array addConstraintSql(TableSchema tableSchema) {
        return null;
    }
    
    /**
     * SQLite can not properly handle dropping a constraint to an existing table.
     * This method is no-op
     * Params:
     * \UIM\Database\Schema\TableSchema tableSchema The table instance the foreign key constraints are.
     */
    array dropConstraintSql(TableSchema tableSchema) {
        return null;
    }
 
    string indexSql(TableSchema tableSchema, string aName) {
        someData = tableSchema.getIndex(name);
        assert(someData !isNull);
        
        someColumns = array_map(
            [_driver, "quoteIdentifier"],
            someData["columns"]
        );

        return "CREATE INDEX %s ON %s (%s)"
            .format(_driver.quoteIdentifier(name), _driver.quoteIdentifier(tableSchema.name()), join(", ", someColumns));
    }
 
    array createTableSql(TableSchema tableSchema, array someColumns, array constraints, array  anIndexes) {
        auto  lines = array_merge(someColumns, constraints);
        string content = join(",\n", array_filter( lines));
        string sqlTemporary = tableSchema.isTemporary() ? " TEMPORARY ' : ' ";
        aTable = sprintf("CREATE%sTABLE \"%s\" (\n%s\n)", sqlTemporary, tableSchema.name(), content);
        
        auto result = [aTable];
        anIndexes.each!(index => result ~=  anIndex);
        return result;
    }
 
    array truncateTableSql(TableSchema tableSchema) {
        auto schemaName = tableSchema.name();
        string[] sqlResults;
        if (this.hasSequences()) {
            sqlResults ~= "DELETE FROM sqlite_sequence WHERE name=\"%s\"".format(schemaName);
        }
        sqlResults ~= "DELETE FROM \"%s\"".format(schemaName);

        return sqlResults;
    }
    
    /**
     * Returns whether there is any table in this connection to SQLite containing
     * sequences
     */
   bool hasSequences() {
        result = _driver.prepare(
            "SELECT 1 FROM sqlite_master WHERE name = "sqlite_sequence"'
        );
        result.execute();
       _hasSequences = (bool)result.fetch();

        return _hasSequences;
    }
}
