module uim.databases.Driver;

import uim.databases;

@safe:

class Sqlserver : Driver {
    use TupleComparisonTranslatorTrait;

    protected const MAX_ALIAS_LENGTH = 128;
 
    protected const RETRY_ERROR_CODES = [
        40613, // Azure Sql Database paused
    ];

 
    protected const STATEMENT_CLASS = SqlserverStatement.classname;

    // Base configuration settings for Sqlserver driver
    protected Json[string] _baseConfig = [
        "host": "localhost\SQLEXPRESS",
        "username": "",
        "password": "",
        "database": "uim",
        "port": "",
        // PDO.SQLSRV_ENCODING_UTF8
        "encoding": 65001,
        "flags": [],
        "init": [],
        "settings": [],
        "attributes": [],
        "app": null,
        "connectionPooling": null,
        "failoverPartner": null,
        "loginTimeout": null,
        "multiSubnetFailover": null,
        "encrypt": null,
        "trustServerCertificate": null,
    ];

    // String used to start a database identifier quoting to make it safe
    protected string _startQuote = "[";

    // String used to end a database identifier quoting to make it safe
    protected string _endQuote = "]";

    /**
     * Establishes a connection to the database server.
     *
     * Please note that the PDO.ATTR_PERSISTENT attribute is not supported by
     * the SQL Server PHP PDO drivers.  As a result you cannot use the
     * persistent config option when connecting to a SQL Server  (for more
     * information see: https://github.com/Microsoft/msphpsql/issues/65).
     *
     * @throws \InvalidArgumentException if an unsupported setting is in the driver config
     */
    void connect() {
        if (isSet(this.pdo)) {
            return;
        }
        auto configData = _config;

        if (isSet(configData["persistent"]) && configData["persistent"]) {
            throw new InvalidArgumentException(
                'Config setting "persistent" cannot be set to true, "
                ~ "as the Sqlserver PDO driver does not support PDO.ATTR_PERSISTENT'
            );
        }
        configData["flags"] += [
            PDO.ATTR_ERRMODE: PDO.ERRMODE_EXCEPTION,
        ];

        if (!empty(configData["encoding"])) {
            configData["flags"][PDO.SQLSRV_ATTR_ENCODING] = configData["encoding"];
        }
        $port = "";
        if (configData["port"]) {
            $port = "," ~ configData["port"];
        }
        string dsn = "sqlsrv:Server={configData["host"]}{$port};Database={configData["database"]};MultipleActiveResultSets=false";
        dsn ~= !configData["app"].isNull ? ";APP=%s".format(configData["app"]) : null;
        dsn ~= !configData["connectionPooling"].isNull ? ";ConnectionPooling={configData["connectionPooling"]}" : null;
        dsn ~= !configData["failoverPartner"].isNull ? ";Failover_Partner={configData["failoverPartner"]}" : null;
        dsn ~= !configData["loginTimeout"].isNull ? ";LoginTimeout={configData["loginTimeout"]}" : null;
        dsn ~= !configData["multiSubnetFailover"].isNull ? ";MultiSubnetFailover={configData["multiSubnetFailover"]}" : null;
        dsn ~= !configData["encrypt"].isNull ? ";Encrypt={configData["encrypt"]}" : null;
        dsn ~= !configData["trustServerCertificate"].isNull ? ";TrustServerCertificate={configData["trustServerCertificate"]}" : null;
        
        this.pdo = this.createPdo(dsn, configData);
        if (!empty(configData["init"])) {
            (array)configData["init"])
                .each!(command => this.pdo.exec(command));
        }
        if (!empty(configData["settings"]) && isArray(configData["settings"])) {
            configData["settings"].byKeyValue
                .each!(kv => this.pdo.exec("SET %s %s".format(kv.key, kv.value)));
        }
        if (!empty(configData["attributes"]) && isArray(configData["attributes"])) {
            configData["attributes"].byKeyValue
                .each(kv => this.pdo.setAttribute(kv.key, kv.value));
        }
    }
    
    /**
     * Returns whether PHP is able to use this driver for connecting to database
     */
    bool enabled() {
        return in_array("sqlsrv", PDO.getAvailableDrivers(), true);
    }
 
    IStatement prepare(Query queryToPrepare) { 
        if (count(queryToPrepare.getValueBinder().bindings()) > 2100) {
            throw new InvalidArgumentException(
                "Exceeded maximum number of parameters (2100) for prepared statements in Sql Server. " ~
                "This is probably due to a very large WHERE IN () clause which generates a parameter " ~
                "for each value in the array. " ~
                "If using an Association, try changing the `strategy` from select to subquery."
            );
        }
        return prepare(queryToPrepare.sql());
    }

    IStatement prepare(string queryToPrepare) {
        string sql = queryToPrepare;

        $statement = this.getPdo().prepare(
            sql,
            [
                PDO.ATTR_CURSOR: PDO.CURSOR_SCROLL,
                PDO.SQLSRV_ATTR_CURSOR_SCROLL_TYPE: PDO.SQLSRV_CURSOR_BUFFERED,
            ]
        );

        $typeMap = null;
        if (cast(SelectQuery)aQuery  && aQuery.isResultsCastingEnabled()) {
            $typeMap = aQuery.getSelectTypeMap();
        }

        return new (STATEMENT_CLASS)($statement, this, $typeMap);
    }

    string savePointSQL($name) {
        return "SAVE TRANSACTION t" ~ $name;
    }

    string releaseSavePointSQL($name) {
        // SQLServer has no release save point operation.
        return "";
    }

    string rollbackSavePointSQL($name) {
        return "ROLLBACK TRANSACTION t" ~ $name;
    }

    string disableForeignKeySQL() {
        return "EXEC sp_MSforeachtable "ALTER TABLE ? NOCHECK CONSTRAINT all"";
    }
    
    string enableForeignKeySQL() {
        return "EXEC sp_MSforeachtable "ALTER TABLE ? WITH CHECK CHECK CONSTRAINT all"";
    }
 
    bool supports(DriverFeatures $feature) {
        return match ($feature) {
            DriverFeatures.CTE,
            DriverFeatures.DISABLE_CONSTRAINT_WITHOUT_TRANSACTION,
            DriverFeatures.SAVEPOINT,
            DriverFeatures.TRUNCATE_WITH_CONSTRAINTS,
            DriverFeatures.WINDOW: true,

            DriverFeatures.JSON: false,
        };
    }
 
    auto schemaDialect(): SchemaDialect
    {
        return _schemaDialect ??= new SqlserverSchemaDialect(this);
    }
    
    QueryCompiler newCompiler() {
        return new SqlserverCompiler();
    }
 
    protected auto _selectQueryTranslator(SelectQuery aQuery): SelectQuery
    {
        aLimit = aQuery.clause("limit");
         anOffset = aQuery.clause("offset");

        if (aLimit &&  anOffset.isNull) {
            aQuery.modifier(["_auto_top_": "TOP %d".format(aLimit)]);
        }
        if (anOffset !isNull && !aQuery.clause("order")) {
            aQuery.orderBy(aQuery.newExpr().add("(SELECT NULL)"));
        }
        if (this.currentVersion() < 11 &&  anOffset !isNull) {
            return _pagingSubquery(aQuery, aLimit,  anOffset);
        }
        return _transformDistinct(aQuery);
    }
    
    /**
     * Generate a paging subquery for older versions of SQLserver.
     *
     * Prior to SQLServer 2012 there was no equivalent to LIMIT OFFSET, so a subquery must
     * be used.
     * Params:
     * \UIM\Database\Query\SelectQuery<mixed> $original The query to wrap in a subquery.
     * @param int aLimit The number of rows to fetch.
     * @param int  anOffset The number of rows to offset.
     */
    protected SelectQuery _pagingSubquery(SelectQuery $original, int aLimit, int anOffset) {
        auto $field = "_cake_paging_._cake_page_rownum_";

        if ($original.clause("order")) {
            // SQL server does not support column aliases in OVER clauses.  But
            // the only practical way to specify the use of calculated columns
            // is with their alias.  So substitute the select SQL in place of
            // any column aliases for those entries in the order clause.
            auto $select = $original.clause("select");
            auto $order = new OrderByExpression();
            $original
                .clause("order")
                .iterateParts(function ($direction, $orderBy) use ($select, $order) {
                    aKey = $orderBy;
                    if (
                        isSet($select[$orderBy]) &&
                        cast(IExpression)$select[$orderBy] 
                    ) {
                        $order.add(new OrderClauseExpression($select[$orderBy], $direction));
                    } else {
                        $order.add([aKey: $direction]);
                    }
                    // Leave original order clause unchanged.
                    return $orderBy;
                });
        } else {
            $order = new OrderByExpression("(SELECT NULL)");
        }

        auto aQuery = clone $original;
        aQuery.select([
                "_cake_page_rownum_": new UnaryExpression("ROW_NUMBER() OVER", $order),
            ]).limit(null)
            .offset(null)
            .orderBy([], true);

        auto $outer = aQuery.getConnection().selectQuery();
        $outer.select("*")
            .from(["_cake_paging_": aQuery]);

        if (anOffset) {
            $outer.where(["$field > " ~  anOffset]);
        }
        if (aLimit) {
            aValue = (int) anOffset + aLimit;
            $outer.where(["$field <= aValue"]);
        }
        // Decorate the original query as that is what the
        // end developer will be calling execute() on originally.
        $original.decorateResults(function ($row) {
            if (isSet($row["_cake_page_rownum_"])) {
                unset($row["_cake_page_rownum_"]);
            }
            return $row;
        });

        return $outer;
    }
 
    protected auto _transformDistinct(SelectQuery aQuery): SelectQuery
    {
        if (!isArray(aQuery.clause("distinct"))) {
            return aQuery;
        }
        $original = aQuery;
        aQuery = clone $original;

        $distinct = aQuery.clause("distinct");
        aQuery.distinct(false);

        $order = new OrderByExpression($distinct);
        aQuery
            .select(function ($q) use ($distinct, $order) {
                $over = $q.newExpr("ROW_NUMBER() OVER")
                    .add("(PARTITION BY")
                    .add($q.newExpr().add($distinct).setConjunction(","))
                    .add($order)
                    .add(")")
                    .setConjunction(" ");

                return [
                    '_cake_distinct_pivot_": $over,
                ];
            })
            .limit(null)
            .offset(null)
            .orderBy([], true);

        $outer = new SelectQuery(aQuery.getConnection());
        $outer.select("*")
            .from(["_cake_distinct_": aQuery])
            .where(["_cake_distinct_pivot_": 1]);

        // Decorate the original query as that is what the
        // end developer will be calling execute() on originally.
        $original.decorateResults(function ($row) {
            if (isSet($row["_cake_distinct_pivot_"])) {
                unset($row["_cake_distinct_pivot_"]);
            }
            return $row;
        });

        return $outer;
    }
 
    protected array _expressionTranslators() {
        return [
            FunctionExpression.classname: '_transformFunctionExpression",
            TupleComparison.classname: '_transformTupleComparison",
        ];
    }
    
    /**
     * Receives a FunctionExpression and changes it so that it conforms to this
     * SQL dialect.
     * Params:
     * \UIM\Database\Expression\FunctionExpression $expression The auto expression to convert to TSQL.
     */
    protected void _transformFunctionExpression(FunctionExpression $expression) {
        switch ($expression.name) {
            case "CONCAT":
                // CONCAT bool is expressed as exp1 + exp2
                $expression.name("").setConjunction(" +");
                break;
            case "DATEDIFF":
                $hasDay = false;
                $visitor = auto (aValue) use (&$hasDay) {
                    if (aValue == "day") {
                        $hasDay = true;
                    }
                    return aValue;
                };
                $expression.iterateParts($visitor);

                if (!$hasDay) {
                    $expression.add(["day": 'literal"], [], true);
                }
                break;
            case "CURRENT_DATE":
                $time = new FunctionExpression("GETUTCDATE");
                $expression.name("CONVERT").add(["date": 'literal", $time]);
                break;
            case "CURRENT_TIME":
                $time = new FunctionExpression("GETUTCDATE");
                $expression.name("CONVERT").add(["time": 'literal", $time]);
                break;
            case "NOW":
                $expression.name("GETUTCDATE");
                break;
            case "EXTRACT":
                $expression.name("DATEPART").setConjunction(" ,");
                break;
            case "DATE_ADD":
                $params = [];
                $visitor = auto ($p, aKey) use (&$params) {
                    if (aKey == 0) {
                        $params[2] = $p;
                    } else {
                        string[] $valueUnit = split(" ", $p);
                        $params[0] = rtrim($valueUnit[1], "s");
                        $params[1] = $valueUnit[0];
                    }
                    return $p;
                };
                $manipulator = auto ($p, aKey) use (&$params) {
                    return $params[aKey];
                };

                $expression
                    .name("DATEADD")
                    .setConjunction(",")
                    .iterateParts($visitor)
                    .iterateParts($manipulator)
                    .add([$params[2]: 'literal"]);
                break;
            case "DAYOFWEEK":
                $expression
                    .name("DATEPART")
                    .setConjunction(" ")
                    .add(["weekday, ": 'literal"], [], true);
                break;
            case `sUBSTR":
                $expression.name("SUBSTRING");
                if (count($expression) < 4) {
                    $params = [];
                    $expression
                        .iterateParts(function ($p) use (&$params) {
                            return $params ~= $p;
                        })
                        .add([new FunctionExpression("LEN", [$params[0]]), ["string"]]);
                }
                break;
        }
    }
}