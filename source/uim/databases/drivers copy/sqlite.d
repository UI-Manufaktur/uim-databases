module uim.cake.databases.drivers;

@safe:
import uim.cake;

use InvalidArgumentException;
use PDO;
use RuntimeException;

/**
 * Class Sqlite
 */
class Sqlite : Driver
{
    use SqlDialectTrait;
    use TupleComparisonTranslatorTrait;

    /**
     * Base configuration settings for Sqlite driver
     *
     * - `mask` The mask used for created database
     *
     * @var array<string, mixed>
     */
    protected _baseConfig = [
        "persistent": false,
        "username": null,
        "password": null,
        "database": ":memory:",
        "encoding": "utf8",
        "mask": 0644,
        "cache": null,
        "mode": null,
        "flags": [],
        "init": [],
    ];

    /**
     * The schema dialect class for this driver
     *
     * @var DDBSchema\SqliteSchemaDialect|null
     */
    protected _schemaDialect;

    /**
     * Whether the connected server supports window functions.
     *
     * @var bool|null
     */
    protected _supportsWindowFunctions;

    /**
     * String used to start a database identifier quoting to make it safe
     */
    protected string _startQuote = """;

    /**
     * String used to end a database identifier quoting to make it safe
     */
    protected string _endQuote = """;

    /**
     * Mapping of date parts.
     *
     * @var array<string, string>
     */
    protected _dateParts = [
        "day": "d",
        "hour": "H",
        "month": "m",
        "minute": "M",
        "second": "S",
        "week": "W",
        "year": "Y",
    ];

    /**
     * Mapping of feature to db server version for feature availability checks.
     *
     * @var array<string, string>
     */
    protected $featureVersions = [
        "cte": "3.8.3",
        "window": "3.28.0",
    ];

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
        if (!is_string(aConfig["database"]) || aConfig["database"] == "") {
            $name = aConfig["name"] ?? "unknown";
            throw new InvalidArgumentException(
                "The `database` key for the `{$name}` SQLite connection needs to be a non-empty string."
            );
        }

        $chmodFile = false;
        if (aConfig["database"] != ":memory:" && aConfig["mode"] != "memory") {
            $chmodFile = !file_exists(aConfig["database"]);
        }

        $params = null;
        if (aConfig["cache"]) {
            $params[] = "cache=" ~ aConfig["cache"];
        }
        if (aConfig["mode"]) {
            $params[] = "mode=" ~ aConfig["mode"];
        }

        if ($params) {
            if (PHP_VERSION_ID < 80100) {
                throw new RuntimeException("SQLite URI support requires PHP 8.1.");
            }
            $dsn = "sqlite:file:" ~ aConfig["database"] ~ "?" ~ implode("&", $params);
        } else {
            $dsn = "sqlite:" ~ aConfig["database"];
        }

        _connect($dsn, aConfig);
        if ($chmodFile) {
            // phpcs:disable
            @chmod(aConfig["database"], aConfig["mask"]);
            // phpcs:enable
        }

        if (!empty(aConfig["init"])) {
            foreach ((array)aConfig["init"] as $command) {
                this.getConnection().exec($command);
            }
        }

        return true;
    }

    /**
     * Returns whether php is able to use this driver for connecting to database
     *
     * @return bool true if it is valid to use this driver
     */
    bool enabled() {
        return hasAllValues("sqlite", PDO::getAvailableDrivers(), true);
    }

    /**
     * Prepares a sql statement to be executed
     *
     * @param uim.cake.databases.Query|string $query The query to prepare.
     * @return uim.cake.databases.IStatement
     */
    function prepare($query): IStatement
    {
        this.connect();
        $isObject = $query instanceof Query;
        /**
         * @psalm-suppress PossiblyInvalidMethodCall
         * @psalm-suppress PossiblyInvalidArgument
         */
        $statement = _connection.prepare($isObject ? $query.sql() : $query);
        $result = new SqliteStatement(new PDOStatement($statement, this), this);
        /** @psalm-suppress PossiblyInvalidMethodCall */
        if ($isObject && $query.isBufferedResultsEnabled() == false) {
            $result.bufferResults(false);
        }

        return $result;
    }


    string disableForeignKeySQL() {
        return "PRAGMA foreign_keys = OFF";
    }


    string enableForeignKeySQL() {
        return "PRAGMA foreign_keys = ON";
    }


    bool supports(string $feature) {
        switch ($feature) {
            case static::FEATURE_CTE:
            case static::FEATURE_WINDOW:
                return version_compare(
                    this.version(),
                    this.featureVersions[$feature],
                    ">="
                );

            case static::FEATURE_TRUNCATE_WITH_CONSTRAINTS:
                return true;
        }

        return super.supports($feature);
    }


    bool supportsDynamicConstraints() {
        return false;
    }


    function schemaDialect(): SchemaDialect
    {
        if (_schemaDialect == null) {
            _schemaDialect = new SqliteSchemaDialect(this);
        }

        return _schemaDialect;
    }


    function newCompiler(): QueryCompiler
    {
        return new SqliteCompiler();
    }


    protected array _expressionTranslators() {
        return [
            FunctionExpression::class: "_transformFunctionExpression",
            TupleComparison::class: "_transformTupleComparison",
        ];
    }

    /**
     * Receives a FunctionExpression and changes it so that it conforms to this
     * SQL dialect.
     *
     * @param uim.cake.databases.Expression\FunctionExpression $expression The function expression to convert to TSQL.
     */
    protected void _transformFunctionExpression(FunctionExpression $expression) {
        switch ($expression.getName()) {
            case "CONCAT":
                // CONCAT bool is expressed as exp1 || exp2
                $expression.setName("").setConjunction(" ||");
                break;
            case "DATEDIFF":
                $expression
                    .setName("ROUND")
                    .setConjunction("-")
                    .iterateParts(function ($p) {
                        return new FunctionExpression("JULIANDAY", [$p["value"]], [$p["type"]]);
                    });
                break;
            case "NOW":
                $expression.setName("DATETIME").add([""now"": "literal"]);
                break;
            case "RAND":
                $expression
                    .setName("ABS")
                    .add(["RANDOM() % 1": "literal"], [], true);
                break;
            case "CURRENT_DATE":
                $expression.setName("DATE").add([""now"": "literal"]);
                break;
            case "CURRENT_TIME":
                $expression.setName("TIME").add([""now"": "literal"]);
                break;
            case "EXTRACT":
                $expression
                    .setName("STRFTIME")
                    .setConjunction(" ,")
                    .iterateParts(function ($p, $key) {
                        if ($key == 0) {
                            $value = rtrim(strtolower($p), "s");
                            if (isset(_dateParts[$value])) {
                                $p = ["value": "%" ~ _dateParts[$value], "type": null];
                            }
                        }

                        return $p;
                    });
                break;
            case "DATE_ADD":
                $expression
                    .setName("DATE")
                    .setConjunction(",")
                    .iterateParts(function ($p, $key) {
                        if ($key == 1) {
                            $p = ["value": $p, "type": null];
                        }

                        return $p;
                    });
                break;
            case "DAYOFWEEK":
                $expression
                    .setName("STRFTIME")
                    .setConjunction(" ")
                    .add([""%w", ": "literal"], [], true)
                    .add([") + (1": "literal"]); // Sqlite starts on index 0 but Sunday should be 1
                break;
        }
    }

    /**
     * Returns true if the server supports common table expressions.
     *
     * @return bool
     * @deprecated 4.3.0 Use `supports(IDriver::FEATURE_CTE)` instead
     */
    bool supportsCTEs() {
        deprecationWarning("Feature support checks are now implemented by `supports()` with FEATURE_* constants.");

        return this.supports(static::FEATURE_CTE);
    }

    /**
     * Returns true if the connected server supports window functions.
     *
     * @return bool
     * @deprecated 4.3.0 Use `supports(IDriver::FEATURE_WINDOW)` instead
     */
    bool supportsWindowFunctions() {
        deprecationWarning("Feature support checks are now implemented by `supports()` with FEATURE_* constants.");

        return this.supports(static::FEATURE_WINDOW);
    }
}
