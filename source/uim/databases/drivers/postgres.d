/*********************************************************************************************************
	Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        
	License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  
	Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      
**********************************************************************************************************/
module uim.databases.drivers.postgres;

@safe:
import uim.databases;

use PDO;

/**
 * Class Postgres
 */
class Postgres : Driver
{
    use SqlDialectTrait;


    protected const MAX_ALIAS_LENGTH = 63;

    /**
     * Base configuration settings for Postgres driver
     *
     * @var array<string, mixed>
     */
    protected _baseConfig = [
        "persistent": true,
        "host": "localhost",
        "username": "root",
        "password": "",
        "database": "cake",
        "schema": "public",
        "port": 5432,
        "encoding": "utf8",
        "timezone": null,
        "flags": [],
        "init": [],
    ];

    /**
     * The schema dialect class for this driver
     *
     * @var DDBSchema\PostgresSchemaDialect|null
     */
    protected _schemaDialect;

    /**
     * String used to start a database identifier quoting to make it safe
     */
    protected string _startQuote = """;

    /**
     * String used to end a database identifier quoting to make it safe
     */
    protected string _endQuote = """;

    /**
     * Establishes a connection to the database server
     *
     * @return bool true on success
     */
    bool connect() {
        if (_connection) {
            return true;
        }
        aConfig = _config;
        aConfig["flags"] += [
            PDO::ATTR_PERSISTENT: aConfig["persistent"],
            PDO::ATTR_EMULATE_PREPARES: false,
            PDO::ATTR_ERRMODE: PDO::ERRMODE_EXCEPTION,
        ];
        if (empty(aConfig["unix_socket"])) {
            $dsn = "pgsql:host={aConfig["host"]};port={aConfig["port"]};dbname={aConfig["database"]}";
        } else {
            $dsn = "pgsql:dbname={aConfig["database"]}";
        }

        _connect($dsn, aConfig);
        _connection = $connection = this.getConnection();
        if (!empty(aConfig["encoding"])) {
            this.setEncoding(aConfig["encoding"]);
        }

        if (!empty(aConfig["schema"])) {
            this.setSchema(aConfig["schema"]);
        }

        if (!empty(aConfig["timezone"])) {
            aConfig["init"][] = sprintf("SET timezone = %s", $connection.quote(aConfig["timezone"]));
        }

        foreach (aConfig["init"] as $command) {
            $connection.exec($command);
        }

        return true;
    }

    /**
     * Returns whether D is able to use this driver for connecting to database
     *
     * @return bool true if it is valid to use this driver
     */
    bool enabled() {
        return hasAllValues("pgsql", PDO::getAvailableDrivers(), true);
    }


    function schemaDialect(): SchemaDialect
    {
        if (_schemaDialect == null) {
            _schemaDialect = new PostgresSchemaDialect(this);
        }

        return _schemaDialect;
    }

    /**
     * Sets connection encoding
     *
     * @param string $encoding The encoding to use.
     */
    void setEncoding(string $encoding) {
        this.connect();
        _connection.exec("SET NAMES " ~ _connection.quote($encoding));
    }

    /**
     * Sets connection default schema, if any relation defined in a query is not fully qualified
     * postgres will fallback to looking the relation into defined default schema
     *
     * @param string $schema The schema names to set `search_path` to.
     */
    void setSchema(string $schema) {
        this.connect();
        _connection.exec("SET search_path TO " ~ _connection.quote($schema));
    }


    string disableForeignKeySQL() {
        return "SET CONSTRAINTS ALL DEFERRED";
    }


    string enableForeignKeySQL() {
        return "SET CONSTRAINTS ALL IMMEDIATE";
    }


    bool supports(string $feature) {
        switch ($feature) {
            case FEATURE_CTE:
            case FEATURE_JSON:
            case FEATURE_TRUNCATE_WITH_CONSTRAINTS:
            case FEATURE_WINDOW:
                return true;

            case FEATURE_DISABLE_CONSTRAINT_WITHOUT_TRANSACTION:
                return false;
        }

        return super.supports($feature);
    }


    bool supportsDynamicConstraints() {
        return true;
    }


    protected function _transformDistinct(Query $query): Query
    {
        return $query;
    }


    protected function _insertQueryTranslator(Query $query): Query
    {
        if (!$query.clause("epilog")) {
            $query.epilog("RETURNING *");
        }

        return $query;
    }


    protected array _expressionTranslators() {
        return [
            IdentifierExpression::class: "_transformIdentifierExpression",
            FunctionExpression::class: "_transformFunctionExpression",
            StringExpression::class: "_transformStringExpression",
        ];
    }

    /**
     * Changes identifer expression into postgresql format.
     *
     * @param uim.databases.Expression\IdentifierExpression $expression The expression to tranform.
     */
    protected void _transformIdentifierExpression(IdentifierExpression $expression) {
        $collation = $expression.getCollation();
        if ($collation) {
            // use trim() to work around expression being transformed multiple times
            $expression.setCollation(""" ~ trim($collation, """) ~ """);
        }
    }

    /**
     * Receives a FunctionExpression and changes it so that it conforms to this
     * SQL dialect.
     *
     * @param uim.databases.Expression\FunctionExpression $expression The function expression to convert
     *   to postgres SQL.
     */
    protected void _transformFunctionExpression(FunctionExpression $expression) {
        switch ($expression.getName()) {
            case "CONCAT":
                // CONCAT bool is expressed as exp1 || exp2
                $expression.setName("").setConjunction(" ||");
                break;
            case "DATEDIFF":
                $expression
                    .setName("")
                    .setConjunction("-")
                    .iterateParts(function ($p) {
                        if (is_string($p)) {
                            $p = ["value": [$p: "literal"], "type": null];
                        } else {
                            $p["value"] = [$p["value"]];
                        }

                        return new FunctionExpression("DATE", $p["value"], [$p["type"]]);
                    });
                break;
            case "CURRENT_DATE":
                time = new FunctionExpression("LOCALTIMESTAMP", [" 0 ": "literal"]);
                $expression.setName("CAST").setConjunction(" AS ").add([$time, "date": "literal"]);
                break;
            case "CURRENT_TIME":
                time = new FunctionExpression("LOCALTIMESTAMP", [" 0 ": "literal"]);
                $expression.setName("CAST").setConjunction(" AS ").add([$time, "time": "literal"]);
                break;
            case "NOW":
                $expression.setName("LOCALTIMESTAMP").add([" 0 ": "literal"]);
                break;
            case "RAND":
                $expression.setName("RANDOM");
                break;
            case "DATE_ADD":
                $expression
                    .setName("")
                    .setConjunction(" + INTERVAL")
                    .iterateParts(function ($p, $key) {
                        if ($key == 1) {
                            $p = sprintf("'%s'", $p);
                        }

                        return $p;
                    });
                break;
            case "DAYOFWEEK":
                $expression
                    .setName("EXTRACT")
                    .setConjunction(" ")
                    .add(["DOW FROM": "literal"], [], true)
                    .add([") + (1": "literal"]); // Postgres starts on index 0 but Sunday should be 1
                break;
        }
    }

    /**
     * Changes string expression into postgresql format.
     *
     * @param uim.databases.Expression\StringExpression $expression The string expression to tranform.
     */
    protected void _transformStringExpression(StringExpression $expression) {
        // use trim() to work around expression being transformed multiple times
        $expression.setCollation(""" ~ trim($expression.getCollation(), """) ~ """);
    }

    /**
     * {@inheritDoc}
     *
     * @return uim.databases.PostgresCompiler
     */
    function newCompiler(): QueryCompiler
    {
        return new PostgresCompiler();
    }
}
