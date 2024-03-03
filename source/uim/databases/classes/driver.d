module uim.databases.classes.driver;

import uim.databases;

@safe:

/**
 * Represents a database driver containing all specificities for
 * a database engine including its SQL dialect.
 */
abstract class Driver {
    mixin LoggerAwareTrait;

 	override bool initialize(IData[string] configData = null) {
        _config = Configuration; 
        _baseConfig = Configuration; 
    }

    /**
     * @var int Maximum alias length or null if no limit
     */
    protected const int MAX_ALIAS_LENGTH = null;

    /**
     * @var array<int>  DB-specific error codes that allow connect retry
     */
    protected const RETRY_ERROR_CODES = [];

    protected const string STATEMENT_CLASS = Statement.classname;

    // Instance of PDO.
    protected PDO $pdo = null;

    // Configuration data.
    protected IConfiguration _config;

    /**
     * Base configuration that is merged into the user
     * supplied configuration data.
     */
    protected IConfiguration _baseConfig;

    /**
     * Indicates whether the driver is doing automatic identifier quoting
     * for all queries
     */
    protected bool _autoQuoting = false;

    // String used to start a database identifier quoting to make it safe
    protected string _startQuote = "";

    /**
     * String used to end a database identifier quoting to make it safe
     */
    protected string _endQuote = "";

    /**
     * Identifier quoter
     *
     * @var \UIM\Database\IdentifierQuoter|null
     */
    protected IdentifierQuoter $quoter = null;

    /**
     * The server version
     * @var string|null
     */
    protected string _version = null;

    // The last number of connection retry attempts.
    protected int connectRetries = 0;

    // The schema dialect for this driver
    protected SchemaDialect _schemaDialect;

    /**
     * Constructor
     *
     * configData - The configuration for the driver.
     * @throws \InvalidArgumentException
     */
    this(IData[string] configData = null) {
        if (isEmpty(configData["username"]) && !empty(configData["login"])) {
            throw new InvalidArgumentException(
                'Please pass "username" instead of "login" for connecting to the database'
            );
        }
        configData += _baseConfig ~ ["log": false];
       _config = configData;
        if (!empty(configData["quoteIdentifiers"])) {
            this.enableAutoQuoting();
        }
        if (configData["log"] != false) {
            this.logger = this.createLogger(configData["log"] == true ? null : configData["log"]);
        }
    }
    
    /**
     * Get the configuration data used to create the driver.
     
     */
    IData[string] config() {
        return _config;
    }
    
    /**
     * Establishes a connection to the database server
     * Params:
     * string adsn A Driver-specific PDO-DSN
     * configData - configuration to be used for creating connection
     */
    protected PDO createPdo(string adsn, IData[string] configData = null) {
        action = fn (): new PDO(
            dsn,
            configData["username"] ?: null,
            configData["password"] ?: null,
            configData["flags"]
        );

        $retry = new CommandRetry(new ErrorCodeWaitStrategy(RETRY_ERROR_CODES, 5), 4);
        try {
            return $retry.run(action);
        } catch (PDOException  anException) {
            throw new MissingConnectionException(
                [
                    "driver": App.shortName(class, "Database/Driver"),
                    "reason":  anException.getMessage(),
                ],
                null,
                 anException
            );
        } finally {
            this.connectRetries = $retry.getRetries();
        }
    }
    
    /**
     * Establishes a connection to the database server.
     *
     * @throws \UIM\Database\Exception\MissingConnectionException If database connection could not be established.
     */
    abstract void connect();

    /**
     * Disconnects from database server.
     */
    void disconnect() {
        this.pdo = null;
       _version = null;
    }
    
    /**
     * Returns connected server version.
     */
    string currentVersion() {
        return _version ??= (string)this.getPdo().getAttribute(PDO.ATTR_SERVER_VERSION);
    }
    
    /**
     * Get the PDO connection instance.
     */
    protected PDO getPdo() {
        if (this.pdo.isNull) {
            this.connect();
        }
        assert(this.pdo !isNull);

        return this.pdo;
    }
    
    // Execute the SQL query using the internal PDO instance.
    int exec(string sqlQuery) {
        return this.getPdo().exec(sqlQuery);
    }
    
    // Returns whether D is able to use this driver for connecting to database.
    abstract bool enabled();

    /**
     * Executes a query using $params for interpolating values and types as a hint for each
     * those params.
     * Params:
     * string asql SQL to be executed and interpolated with $params
     * @param array $params List or associative array of params to be interpolated in sql as values.
     * @param array types List or associative array of types to be used for casting values in query.
     */
    IStatement execute(string asql, array $params = [], array types = []) {
        $statement = this.prepare(sql);
        if (!empty($params)) {
            $statement.bind($params, types);
        }
        this.executeStatement($statement);

        return $statement;
    }
    
    /**
     * Executes the provided query after compiling it for the specific driver
     * dialect and returns the executed Statement object.
     * Params:
     * \UIM\Database\Query queryToExecute The query to be executed.
     */
    IStatement run(Query queryToExecute) {
        auto queryStatement = this.prepare(queryToExecute);
        queryToExecute.getValueBinder().attachTo(queryStatement);
        this.executeStatement(queryStatement);

        return queryStatement;
    }
    
    /**
     * Execute the statement and log the query string.
     * Params:
     * \UIM\Database\IStatement $statement Statement to execute.
     * @param array|null $params List of values to be bound to query.
     */
    protected void executeStatement(IStatement statementToExecute, array $params = null) {
        if (this.logger.isNull) {
            statementToExecute.execute($params);

            return;
        }
        auto $exception = null;
        auto took = 0.0;

        try {
            $start = microtime(true);
            statementToExecute.execute($params);
            took = (float)number_format((microtime(true) - $start) * 1000, 1);
        } catch (PDOException  anException) {
            $exception =  anException;
        }
        $logContext = [
            'driver": this,
            'error": $exception,
            'params": $params ?? statementToExecute.getBoundParams(),
        ];
        if (!$exception) {
            $logContext["numRows"] = statementToExecute.rowCount();
            $logContext["took"] = took;
        }
        this.log(statementToExecute.queryString(), $logContext);

        if ($exception) {
            throw $exception;
        }
    }
    
    /**
     * Prepares a sql statement to be executed.
     * Params:
     * \UIM\Database\Query|string aquery The query to turn into a prepared statement.
     */
    IStatement prepare(Query|string aquery) {
        $statement = this.getPdo().prepare(cast(Query)aQuery  ? aQuery.sql(): aQuery);

        typeMap = null;
        if (cast(SelectQuery)aQuery  && aQuery.isResultsCastingEnabled()) {
            typeMap = aQuery.getSelectTypeMap();
        }
        /** @var \UIM\Database\IStatement */
        return new (STATEMENT_CLASS)($statement, this, typeMap);
    }
    
    /**
     * Starts a transaction.
     */
    bool beginTransaction() {
        if (this.getPdo().inTransaction()) {
            return true;
        }
        this.log("BEGIN");

        return this.getPdo().beginTransaction();
    }
    
    /**
     * Commits a transaction.
     */
    bool commitTransaction() {
        if (!this.getPdo().inTransaction()) {
            return false;
        }
        this.log("COMMIT");

        return this.getPdo().commit();
    }
    
    /**
     * Rollbacks a transaction.
     */
    bool rollbackTransaction() {
        if (!this.getPdo().inTransaction()) {
            return false;
        }
        this.log("ROLLBACK");

        return this.getPdo().rollBack();
    }
    
    /**
     * Returns whether a transaction is active for connection.
     */
   bool inTransaction() {
        return this.getPdo().inTransaction();
    }
    
    /**
     * Returns a SQL snippet for creating a new transaction savepoint
     * Params:
     * string|int savepointName save point name
     */
    string savePointSQL(string|int savepointName) {
        return "SAVEPOINT LEVEL" ~ savepointName;
    }
    
    /**
     * Returns a SQL snippet for releasing a previously created save point
     * Params:
     * string|int savepointName save point name
     */
    string releaseSavePointSQL(string|int savepointName) {
        return "RELEASE SAVEPOINT LEVEL" ~ savepointName;
    }
    
    /**
     * Returns a SQL snippet for rollbacking a previously created save point
     * Params:
     * string|int savepointName save point name
     */
    string rollbackSavePointSQL(string|int savepointName) {
        return "ROLLBACK TO SAVEPOINT LEVEL" ~ savepointName;
    }
    
    // Get the SQL for disabling foreign keys.
    abstract string disableForeignKeySQL();

    // Get the SQL for enabling foreign keys.
    abstract string enableForeignKeySQL();

    /**
     * Transform the query to accommodate any specificities of the SQL dialect in use.
     *
     * It will also quote the identifiers if auto quoting is enabled.
     * Params:
     * \UIM\Database\Query aQuery Query to transform.
     */
    protected Query transformQuery(Query aQuery) {
        if (this.isAutoQuotingEnabled()) {
            aQuery = this.quoter().quote(aQuery);
        }
        aQuery = match (true) {
            cast(SelectQuery)aQuery : _selectQueryTranslator(aQuery),
            cast(InsertQuery)aQuery : _insertQueryTranslator(aQuery),
            cast(UpdateQuery)aQuery : _updateQueryTranslator(aQuery),
            cast(DeleteQuery)aQuery : _deleteQueryTranslator(aQuery),
            default: throw new InvalidArgumentException(
                "Instance of SelectQuery, UpdateQuery, InsertQuery, DeleteQuery expected. Found `%s` instead."
                .format(get_debug_type(aQuery))
            ),
        };

        translators = _expressionTranslators();
        if (!$translators) {
            return aQuery;
        }
        aQuery.traverseExpressions(function ($expression) use ($translators, aQuery) {
            foreach ($translators as  className: $method) {
                if (cast8className)$expression) {
                    this.{$method}($expression, aQuery);
                }
            }
        });

        return aQuery;
    }
    
    /**
     * Returns an associative array of methods that will transform Expression
     * objects to conform with the specific SQL dialect. Keys are class names
     * and values a method in this class.
     */
    protected STRINGAA _expressionTranslators() {
        return null;
    }
    
    /**
     * Apply translation steps to select queries.
     * Params:
     * \UIM\Database\Query\SelectQuery<mixed> aQuery The query to translate
     */
    protected SelectQuery<mixed> _selectQueryTranslator(SelectQuery aQuery) {
        return _transformDistinct(aQuery);
    }
    
    /**
     * Returns the passed query after rewriting the DISTINCT clause, so that drivers
     * that do not support the "ON" part can provide the actual way it should be done
     * Params:
     * \UIM\Database\Query\SelectQuery<mixed> aQuery The query to be transformed
     */
    protected SelectQuery _transformDistinct(SelectQuery aQuery) {
        if (isArray(aQuery.clause("distinct"))) {
            aQuery.groupBy(aQuery.clause("distinct"), true);
            aQuery.distinct(false);
        }
        return aQuery;
    }
    
    /**
     * Apply translation steps to delete queries.
     *
     * Chops out aliases on delete query conditions as most database dialects do not
     * support aliases in delete queries. This also removes aliases
     * in table names as they frequently don`t work either.
     *
     * We are intentionally not supporting deletes with joins as they have even poorer support.
     */
    protected DeleteQuery _deleteQueryTranslator(DeleteQuery queryToTranslate) {
        bool hadAlias = queryToTranslate.clause("from").byKeyValue
            .filter!(aliasTable => isString(aliasTable.key))
            .length > 0;

        auto tables = queryToTranslate.clause("from").values;
        
        if (!hadAlias) { return queryToTranslate; }

        queryToTranslate.from(aTables, true);
        return _removeAliasesFromConditions(queryToTranslate);
    }
    
    /**
     * Apply translation steps to update queries.
     *
     * Chops out aliases on update query conditions as not all database dialects do support
     * aliases in update queries.
     *
     * Just like for delete queries, joins are currently not supported for update queries.
     * Params:
     * \UIM\Database\Query\UpdateQuery queryToTranslate The query to translate
     */
    protected UpdateQuery _updateQueryTranslator(UpdateQuery queryToTranslate) {
        return _removeAliasesFromConditions(queryToTranslate);
    }
    
    /**
     * Removes aliases from the `WHERE` clause of a query.
     * Params:
     * \UIM\Database\Query\UpdateQuery|\UIM\Database\Query\DeleteQuery queryToProcess The query to process.
     */
    protected UpdateQuery|DeleteQuery _removeAliasesFromConditions(UpdateQuery|DeleteQuery queryToProcess) {
        if (queryToProcess.clause("join")) {
            throw new DatabaseException(
                "Aliases are being removed from conditions for UPDATE/DELETE queries, " .
                "this can break references to joined tables."
            );
        }
        conditions = queryToProcess.clause("where");
        assert(conditions.isNull || cast(IExpression)conditions);
        if (conditions) {
            conditions.traverse(function ($expression) {
                if (cast(ComparisonExpression)$expression) {
                    field = $expression.getFieldNames();
                    if (
                        isString(field) &&
                        field.has(".")
                    ) {
                        [, $unaliasedField] = split(".", field, 2);
                        $expression.setFieldNames($unaliasedField);
                    }
                    return $expression;
                }
                if (cast(IdentifierExpression)$expression) {
                     anIdentifier = $expression.getIdentifier();
                    if (anIdentifier.has(".")) {
                        [, $unaliasedIdentifier] = split(".",  anIdentifier, 2);
                        $expression.setIdentifier($unaliasedIdentifier);
                    }
                    return $expression;
                }
                return $expression;
            });
        }
        return queryToProcess;
    }

    // Apply translation steps to insert queries.
    protected InsertQuery _insertQueryTranslator(InsertQuery queryToTranslate) {
        return queryToTranslate;
    }
    
    /**
     * Get the schema dialect.
     *
     * Used by {@link \UIM\Database\Schema} package to reflect schema and
     * generate schema.
     *
     * If all the tables that use this Driver specify their
     * own schemas, then this may return null.
     */
    abstract SchemaDialect schemaDialect();

    /**
     * Quotes a database identifier (a column name, table name, etc..) to
     * be used safely in queries without the risk of using reserved words
     * Params:
     * string aidentifier The identifier to quote.
     */
    string quoteIdentifier(string aidentifier) {
        return this.quoter().quoteIdentifier(anIdentifier);
    }

    // Get identifier quoter instance.
    IdentifierQuoter quoter() {
        return this.quoter ??= new IdentifierQuoter(_startQuote, _endQuote);
    }
    
    /**
     * Escapes values for use in schema definitions.
     * Params:
     * Json aValue The value to escape.
     */
    string schemaValue(Json escapeValue) {
        if (escapeValue.isNull) {
            return "NULL";
        }
        if (escapeValue == false) {
            return "FALSE";
        }
        if (escapeValue == true) {
            return "TRUE";
        }
        if (isFloat(escapeValue)) {
            return ((string)escapeValue).replace(",", ".");
        }
        if (
            (
                isInt(escapeValue) ||
                escapeValue == "0"
            ) ||
            (
                isNumeric(escapeValue) &&
                !escapeValue.has(",") &&
                !escapeValue.startsWith("0") &&
                !escapeValue.has("e")
            )
        ) {
            return (string)escapeValue;
        }
        return this.getPdo().quote((string)escapeValue, PDO.PARAM_STR);
    }

    // Returns the schema name that`s being used.
    string schema() {
        return _config["schema"];
    }

    /**
     * Returns last id generated for a table or sequence in database.
     * Params:
     * string|null aTable table name or sequence to get last insert value from.
     */
    string lastInsertId(string atable = null) {
        return (string)this.getPdo().lastInsertId(aTable);
    }

    // Checks whether the driver is connected.
    bool isConnected() {
        if (isSet(this.pdo)) {
            try {
                connected = (bool)this.pdo.query("SELECT 1");
            } catch (PDOException  anException) {
                connected = false;
            }
        } else {
            connected = false;
        }
        return connected;
    }

    // Sets whether this driver should automatically quote identifiers in queries.
    void enableAutoQuoting(bool isEnable = true) {
       _autoQuoting = isEnable;
    }

    // Disable auto quoting of identifiers in queries.
    void disableAutoQuoting() {
       _autoQuoting = false;
    }

    // Returns whether this driver should automatically quote identifiers in queries.
    bool isAutoQuotingEnabled() {
        return _autoQuoting;
    }

    /**
     * Returns whether the driver supports the feature.
     * Should return false for unknown features.
     */
    abstract bool supports(DriverFeatures driverFeature);

    /**
     * Transforms the passed query to this Driver`s dialect and returns an instance
     * of the transformed query and the full compiled SQL string.
     * Params:
     * \UIM\Database\Query queryToCompile The query to compile.
     * @param \UIM\Database\ValueBinder aBinder The value binder to use.
     */
    string compileQuery(Query queryToCompile, ValueBinder valueBinder) {
        auto processor = this.newCompiler();
        auto transformedQuery = this.transformQuery(queryToCompile);

        return processor.compile(transformedQuery, valueBinder);
    }
    
    QueryCompiler newCompiler() {
        return new QueryCompiler();
    }

    /**
     * Constructs new TableSchema.
     * @param array someColumns The list of columns for the schema.
     */
    TableISchema newTableSchema(string tableName, array someColumns = []) {
        auto className = _config["tableSchema"] ?? TableSchema.class;

        return new  className(tableName, someColumns);
    }

    /**
     * Returns the maximum alias length allowed.
     * This can be different from the maximum identifier length for columns.
     */
    int getMaxAliasLength() {
        return MAX_ALIAS_LENGTH;
    }
    
    ILogger getLogger() {
        return this.logger;
    }

    // Create logger instance.
    protected ILogger createLogger(string className) {
         className ??= QueryLogger.classname;

        /** @var class-string<\Psr\Log\ILogger>|null  className */
         className = App.className(className, "Cake/Log", "Log");
        if (className.isNull) {
            throw new UimException(
                "For logging you must either set the `log` config to a FQCN which implemnts Psr\Log\ILogger" ~
                " or require the UIM/log package in your composer config."
            );
        }
        return new  className();
    }

    /**
     * Logs a message or query using the configured logger object.
     * Params:
     * \Stringable|string amessage Message string or query.
     * @param array context Logging context.
     */
    bool log(Stringable|string amessage, array context = []) {
        if (this.logger.isNull) {
            return false;
        }

        auto context["query"] = $message;
        auto loggedQuery = new LoggedQuery();
        loggedQuery.setContext(context);

        this.logger.debug((string)loggedQuery, ["query": loggedQuery]);

        return true;
    }

    // Returns the connection role this driver performs.
    string getRole() {
        return _config["_role"] ?? Connection.ROLE_WRITE;
    }

    // Destructor
    auto __destruct() {
        this.pdo = null;
    }

    // Returns an array that can be used to describe the internal state of this object.
    IData[string] debugInfo() {
        return [
            "connected": !this.pdo.isNull,
            "role": this.getRole(),
        ];
    }
}
