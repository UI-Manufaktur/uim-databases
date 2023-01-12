<?php
declare(strict_types=1);

/**
 * CakePHP(tm) : Rapid Development Framework (https://cakephp.org)
 * Copyright (c) Cake Software Foundation, Inc. (https://cakefoundation.org)
 *
 * Licensed under The MIT License
 * For full copyright and license information, please see the LICENSE.txt
 * Redistributions of files must retain the above copyright notice.
 *
 * @copyright     Copyright (c) Cake Software Foundation, Inc. (https://cakefoundation.org)
 * @link          https://cakephp.org CakePHP(tm) Project
 * @since         3.0.0
 * @license       https://opensource.org/licenses/mit-license.php MIT License
 */
namespace uim.databases.Driver;

use uim.databases.Driver;
use uim.databases.Expression\FunctionExpression;
use uim.databases.Expression\IdentifierExpression;
use uim.databases.Expression\StringExpression;
use uim.databases.PostgresCompiler;
use uim.databases.Query;
use uim.databases.QueryCompiler;
use uim.databases.Schema\PostgresSchemaDialect;
use uim.databases.Schema\SchemaDialect;
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
        "persistent" : true,
        "host" : "localhost",
        "username" : "root",
        "password" : "",
        "database" : "cake",
        "schema" : "public",
        "port" : 5432,
        "encoding" : "utf8",
        "timezone" : null,
        "flags" : [],
        "init" : [],
    ];

    /**
     * The schema dialect class for this driver
     *
     * @var uim.databases.Schema\PostgresSchemaDialect|null
     */
    protected _schemaDialect;

    /**
     * String used to start a database identifier quoting to make it safe
     *
     * @var string
     */
    protected _startQuote = """;

    /**
     * String used to end a database identifier quoting to make it safe
     *
     * @var string
     */
    protected _endQuote = """;

    /**
     * Establishes a connection to the database server
     *
     * @return bool true on success
     */
    function connect(): bool
    {
        if (this._connection) {
            return true;
        }
        $config = this._config;
        $config["flags"] += [
            PDO::ATTR_PERSISTENT : $config["persistent"],
            PDO::ATTR_EMULATE_PREPARES : false,
            PDO::ATTR_ERRMODE : PDO::ERRMODE_EXCEPTION,
        ];
        if (empty($config["unix_socket"])) {
            $dsn = "pgsql:host={$config["host"]};port={$config["port"]};dbname={$config["database"]}";
        } else {
            $dsn = "pgsql:dbname={$config["database"]}";
        }

        this._connect($dsn, $config);
        this._connection = $connection = this.getConnection();
        if (!empty($config["encoding"])) {
            this.setEncoding($config["encoding"]);
        }

        if (!empty($config["schema"])) {
            this.setSchema($config["schema"]);
        }

        if (!empty($config["timezone"])) {
            $config["init"][] = "SET timezone = %s".format($connection.quote($config["timezone"]));
        }

        foreach ($config["init"] as $command) {
            $connection.exec($command);
        }

        return true;
    }

    /**
     * Returns whether php is able to use this driver for connecting to database
     *
     * @return bool true if it is valid to use this driver
     */
    function enabled(): bool
    {
        return in_array("pgsql", PDO::getAvailableDrivers(), true);
    }


    function schemaDialect(): SchemaDialect
    {
        if (this._schemaDialect == null) {
            this._schemaDialect = new PostgresSchemaDialect(this);
        }

        return this._schemaDialect;
    }

    /**
     * Sets connection encoding
     *
     * @param string $encoding The encoding to use.
     * @return void
     */
    void setEncoding(string $encoding)
    {
        this.connect();
        this._connection.exec("SET NAMES " . this._connection.quote($encoding));
    }

    /**
     * Sets connection default schema, if any relation defined in a query is not fully qualified
     * postgres will fallback to looking the relation into defined default schema
     *
     * @param string $schema The schema names to set `search_path` to.
     * @return void
     */
    void setSchema(string $schema)
    {
        this.connect();
        this._connection.exec("SET search_path TO " . this._connection.quote($schema));
    }


    function disableForeignKeySQL(): string
    {
        return "SET CONSTRAINTS ALL DEFERRED";
    }


    function enableForeignKeySQL(): string
    {
        return "SET CONSTRAINTS ALL IMMEDIATE";
    }


    function supports(string $feature): bool
    {
        switch ($feature) {
            case static::FEATURE_CTE:
            case static::FEATURE_JSON:
            case static::FEATURE_TRUNCATE_WITH_CONSTRAINTS:
            case static::FEATURE_WINDOW:
                return true;

            case static::FEATURE_DISABLE_CONSTRAINT_WITHOUT_TRANSACTION:
                return false;
        }

        return parent::supports($feature);
    }


    function supportsDynamicConstraints(): bool
    {
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


    protected function _expressionTranslators(): array
    {
        return [
            IdentifierExpression::class : "_transformIdentifierExpression",
            FunctionExpression::class : "_transformFunctionExpression",
            StringExpression::class : "_transformStringExpression",
        ];
    }

    /**
     * Changes identifer expression into postgresql format.
     *
     * @param uim.databases.Expression\IdentifierExpression $expression The expression to tranform.
     * @return void
     */
    protected void _transformIdentifierExpression(IdentifierExpression $expression)
    {
        $collation = $expression.getCollation();
        if ($collation) {
            // use trim() to work around expression being transformed multiple times
            $expression.setCollation(""" . trim($collation, """) . """);
        }
    }

    /**
     * Receives a FunctionExpression and changes it so that it conforms to this
     * SQL dialect.
     *
     * @param uim.databases.Expression\FunctionExpression $expression The function expression to convert
     *   to postgres SQL.
     * @return void
     */
    protected void _transformFunctionExpression(FunctionExpression $expression)
    {
        switch ($expression.getName()) {
            case "CONCAT":
                // CONCAT function is expressed as exp1 || exp2
                $expression.setName("").setConjunction(" ||");
                break;
            case "DATEDIFF":
                $expression
                    .setName("")
                    .setConjunction("-")
                    .iterateParts(function ($p) {
                        if (is_string($p)) {
                            $p = ["value" : [$p : "literal"], "type" : null];
                        } else {
                            $p["value"] = [$p["value"]];
                        }

                        return new FunctionExpression("DATE", $p["value"], [$p["type"]]);
                    });
                break;
            case "CURRENT_DATE":
                $time = new FunctionExpression("LOCALTIMESTAMP", [" 0 " : "literal"]);
                $expression.setName("CAST").setConjunction(" AS ").add([$time, "date" : "literal"]);
                break;
            case "CURRENT_TIME":
                $time = new FunctionExpression("LOCALTIMESTAMP", [" 0 " : "literal"]);
                $expression.setName("CAST").setConjunction(" AS ").add([$time, "time" : "literal"]);
                break;
            case "NOW":
                $expression.setName("LOCALTIMESTAMP").add([" 0 " : "literal"]);
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
                            $p = ""%s"".format($p);
                        }

                        return $p;
                    });
                break;
            case "DAYOFWEEK":
                $expression
                    .setName("EXTRACT")
                    .setConjunction(" ")
                    .add(["DOW FROM" : "literal"], [], true)
                    .add([") + (1" : "literal"]); // Postgres starts on index 0 but Sunday should be 1
                break;
        }
    }

    /**
     * Changes string expression into postgresql format.
     *
     * @param uim.databases.Expression\StringExpression $expression The string expression to tranform.
     * @return void
     */
    protected void _transformStringExpression(StringExpression $expression)
    {
        // use trim() to work around expression being transformed multiple times
        $expression.setCollation(""" . trim($expression.getCollation(), """) . """);
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
