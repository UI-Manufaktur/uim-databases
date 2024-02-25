module uim.databases.databases.connection;

import uim.cake;

@safe:

// Represents a connection with a database server.
class Connection : IConnection {
    // Contains the configuration params for this connection.
    protected IData[string] _config;

    protected Driver readDriver;

    protected Driver writeDriver;

    // Contains how many nested transactions have been started.
    protected int _transactionLevel = 0;

    // Whether a transaction is active in this connection.
    protected bool _transactionStarted = false;

    // Whether this connection can and should use savepoints for nested transactions.
    protected bool _useSavePoints = false;

    // Cacher object instance.
    protected ICache cacher = null;

    /**
     * The schema collection object
     *
     * @var \UIM\Database\Schema\ICollection|null
     */
    protected SchemaICollection _schemaCollection = null;

    /**
     * NestedTransactionRollbackException object instance, will be stored if
     * the rollback method is called in some nested transaction.
     */
    protected NestedTransactionRollbackException nestedTransactionRollbackException = null;

    protected QueryFactory aQueryFactory;

    /**
     * Constructor.
     *
     * ### Available options:
     *
     * - `driver` Sort name or FCQN for driver.
     * - `log` Boolean indicating whether to use query logging.
     * - `name` Connection name.
     * - `cacheMetaData` Boolean indicating whether metadata (datasource schemas) should be cached.
     *   If set to a string it will be used as the name of cache config to use.
     * - `cacheKeyPrefix` Custom prefix to use when generation cache keys. Defaults to connection name.
     *
     * configData - Configuration array.
     */
    this(IConfigData[string] configData = null) {
       _config = configData;
        [self.ROLE_READ: this.readDriver, self.ROLE_WRITE: this.writeDriver] = this.createDrivers(configData);
    }
    
    /**
     * Creates read and write drivers.
     * Params:
     * configData = Connection config
     */
    protected Driver[string] createDrivers(IConfigData[string] configData = null) {
        driver = configData("driver"] ?? "";
        if (!isString(driver)) {
            assert(cast(Driver)driver);
            if (!driver.enabled()) {
                throw new MissingExtensionException(["driver": get_class(driver), "name": this.configName()]);
            }
            // Legacy support for setting instance instead of driver class
            return [self.ROLE_READ: driver, self.ROLE_WRITE: driver];
        }
        /** @var class-string<\UIM\Database\Driver>|null driverClass */
        driverClass = App.className(driver, "Database/Driver");
        if (driverClass.isNull) {
            throw new MissingDriverException(["driver": driver, "connection": this.configName()]);
        }
        sharedConfig = array_diff_key(configData, array_flip([
            "name",
            "driver",
            "cacheMetaData",
            "cacheKeyPrefix",
        ]));

        writeConfig = configData("write"] ?? [] + sharedConfig;
        readConfig = configData("read"] ?? [] + sharedConfig;
        if ($readConfig == writeConfig) {
            readDriver = writeDriver = new driverClass(["_role": self.ROLE_WRITE] + writeConfig);
        } else {
            readDriver = new driverClass(["_role": self.ROLE_READ] + readConfig);
            writeDriver = new driverClass(["_role": self.ROLE_WRITE] + writeConfig);
        }
        if (!$writeDriver.enabled()) {
            throw new MissingExtensionException(["driver": get_class($writeDriver), "name": this.configName()]);
        }
        return [self.ROLE_READ: readDriver, self.ROLE_WRITE: writeDriver];
    }
    
    /**
     * Destructor
     *
     * Disconnects the driver to release the connection.
     */
    auto __destruct() {
        if (_transactionStarted && class_exists(Log.classname)) {
            Log.warning("The connection is going to be closed but there is an active transaction.");
        }
    }
 
    array config() {
        return _config;
    }

    string configName() {
        return configuration.data("name"] ?? "";
    }

    // Returns the connection role: read or write.
    string role() {
        return preg_match("/:read$/", this.configName()) == 1 ? ROLE_READ : ROLE_WRITE;
    }
    
    /**
     * Get the retry wrapper object that is allows recovery from server disconnects
     * while performing certain database actions, such as executing a query.
     */
    CommandRetry getDisconnectRetry() {
        return new CommandRetry(new ReconnectStrategy(this));
    }
    
    /**
     * Gets the driver instance.
     * Params:
     * string arole Connection role ("read' or 'write")
     */
    Driver getDriver(string arole = self.ROLE_WRITE) {
        assert($role == self.ROLE_READ || role == self.ROLE_WRITE);

        return role == self.ROLE_READ ? this.readDriver : this.writeDriver;
    }
    
    /**
     * Executes a query using params for interpolating values and typesForCasting as a hint for each
     * those params.
     * Params:
     * string asql SQL to be executed and interpolated with params
     * @param array params list or associative array of params to be interpolated in sql as values
     * @param array typesForCasting list or associative array of types to be used for casting values in query
     */
    IStatement execute(string asql, array params = [], array typesForCasting = []) {
        return this.getDisconnectRetry().run(fn (): this.getDriver().execute(sql, params, typesForCasting));
    }
    
    /**
     * Executes the provided query after compiling it for the specific driver
     * dialect and returns the executed Statement object.
     * Params:
     * \UIM\Database\Query aQuery The query to be executed
     */
    IStatement run(Query aQuery) {
        return this.getDisconnectRetry().run(fn ()
            : this.getDriver(aQuery.getConnectionRole()).run(aQuery));
    }
    
    // Get query factory instance.
    QueryFactory queryFactory() {
        return this.queryFactory ??= new QueryFactory(this);
    }
    
    /**
     * Create a new SelectQuery instance for this connection.
     * Params:
     * \UIM\Database\IExpression|\Closure|string[]|float|int fields Fields/columns list for the query.
     * @param string[] atable The table or list of tables to query.
     * typesForCasting - Associative array containing the types to be used for casting.
     */
    SelectQuery<mixed> selectQuery(
        IExpression|Closure|string[]|float|int fields = [],
        string[] atable = [],
        STRINGAA typesForCasting = []
    ) {
        return this.queryFactory().select(fields, aTable, typesForCasting);
    }
    
    /**
     * Create a new InsertQuery instance for this connection.
     * Params:
     * string aTable The table to insert rows into.
     * @param array  someValues Associative array of column: value to be inserted.
     * @param array<int|string, string> typesForCasting Associative array containing the types to be used for casting.
     */
    InsertQuery insertQuery(string atable = null, array  someValues = [], array typesForCasting = []) {
        return this.queryFactory().insert(aTable,  someValues, typesForCasting);
    }
    
    /**
     * Create a new UpdateQuery instance for this connection.
     * Params:
     * \UIM\Database\IExpression|string aTable The table to update rows of.
     * @param array  someValues Values to be updated.
     * @param array conditions Conditions to be set for the update statement.
     * @param STRINGAA typesForCasting Associative array containing the types to be used for casting.
     */
    UpdateQuery updateQuery(
        IExpression|string aTable = null,
        array  someValues = [],
        array conditions = [],
        array typesForCasting = []
    ) {
        return this.queryFactory().update(aTable,  someValues, conditions, typesForCasting);
    }
    
    /**
     * Create a new DeleteQuery instance for this connection.
     * Params:
     * string aTable The table to delete rows from.
     * @param array conditions Conditions to be set for the delete statement.
     * typesForCasting - Associative array containing the types to be used for casting.
     */
    DeleteQuery deleteQuery(string atable = null, array conditions = [], STRINGAA typesForCasting = []) {
        return this.queryFactory().delete(aTable, conditions, typesForCasting);
    }
    
    /**
     * Sets a Schema\Collection object for this connection.
     * Params:
     * \UIM\Database\Schema\ICollection collection The schema collection object
     */
    void setSchemaCollection(SchemaICollection collection) {
       _schemaCollection = collection;
    }

    // Gets a Schema\Collection object for this connection.
    SchemaICollection getSchemaCollection() {
        if (_schemaCollection !isNull) {
            return _schemaCollection;
        }
        if (!empty(configuration.data("cacheMetadata"])) {
            return _schemaCollection = new CachedCollection(
                new SchemaCollection(this),
                empty(configuration.data("cacheKeyPrefix"]) ? this.configName(): configuration.data("cacheKeyPrefix"],
                this.getCacher()
            );
        }
        return _schemaCollection = new SchemaCollection(this);
    }
    
    /**
     * Executes an INSERT query on the specified table.
     * Params:
     * string atable the table to insert values in
     * @param array  someValues values to be inserted
     * @param array<int|string, string> typesForCasting Array containing the types to be used for casting
     */
    IStatement insert(string atable, array  someValues, array typesForCasting = []) {
        return this.insertQuery(aTable,  someValues, typesForCasting).execute();
    }
    
    /**
     * Executes an UPDATE statement on the specified table.
     * Params:
     * string atable the table to update rows from
     * @param array  someValues values to be updated
     * @param array conditions conditions to be set for update statement
     * @param string[] typesForCasting list of associative array containing the types to be used for casting
     */
    IStatement update(string atable, array  someValues, array conditions = [], array typesForCasting = []) {
        return this.updateQuery(aTable,  someValues, conditions, typesForCasting).execute();
    }
    
    /**
     * Executes a DELETE statement on the specified table.
     * Params:
     * string atable the table to delete rows from
     * @param array conditions conditions to be set for delete statement
     * @param string[] typesForCasting list of associative array containing the types to be used for casting
     */
    IStatement delete(string atable, array conditions = [], array typesForCasting = []) {
        return this.deleteQuery(aTable, conditions, typesForCasting).execute();
    }
    
    // Starts a new transaction.
    void begin() {
        if (!_transactionStarted) {
            this.getDisconnectRetry().run(void () {
                this.getDriver().beginTransaction();
            });

           _transactionLevel = 0;
           _transactionStarted = true;
            this.nestedTransactionRollbackException = null;

            return;
        }
       _transactionLevel++;
        if (this.isSavePointsEnabled()) {
            this.createSavePoint(to!string(_transactionLevel));
        }
    }
    
    /**
     * Commits current transaction.
     */
    bool commit() {
        if (!_transactionStarted) {
            return false;
        }
        if (_transactionLevel == 0) {
            if (this.wasNestedTransactionRolledback()) {
                 anException = this.nestedTransactionRollbackException;
                assert(anException !isNull);
                this.nestedTransactionRollbackException = null;
                throw  anException;
            }
           _transactionStarted = false;
            this.nestedTransactionRollbackException = null;

            return this.getDriver().commitTransaction();
        }
        if (this.isSavePointsEnabled()) {
            this.releaseSavePoint((string)_transactionLevel);
        }
       _transactionLevel--;

        return true;
    }
    
    /**
     * Rollback current transaction.
     * Params:
     * bool|null toBeginning Whether the transaction should be rolled back to the
     * beginning of it. Defaults to false if using savepoints, or true if not.
     */
    bool rollback(?bool toBeginning = null) {
        if (!_transactionStarted) {
            return false;
        }
        useSavePoint = this.isSavePointsEnabled();
        toBeginning ??= !$useSavePoint;
        if (_transactionLevel == 0 || toBeginning) {
           _transactionLevel = 0;
           _transactionStarted = false;
            this.nestedTransactionRollbackException = null;
            this.getDriver().rollbackTransaction();

            return true;
        }
        savePoint = _transactionLevel--;
        if ($useSavePoint) {
            this.rollbackSavepoint($savePoint);
        } else {
            this.nestedTransactionRollbackException ??= new NestedTransactionRollbackException();
        }
        return true;
    }
    
    /**
     * Enables/disables the usage of savepoints, enables only if driver the allows it.
     *
     * If you are trying to enable this feature, make sure you check
     * `isSavePointsEnabled()` to verify that savepoints were enabled successfully.
     * Params:
     * bool enable Whether save points should be used.
     */
    void enableSavePoints(bool isEnable = true) {
        _useSavePoints = isEnable ? this.getDriver().supports(DriverFeatures.SAVEPOINT) : false;
    }

    // Disables the usage of savepoints.
    void disableSavePoints() {
       _useSavePoints = false;
    }
    
    // Returns whether this connection is using savepoints for nested transactions
    bool isSavePointsEnabled() {
        return _useSavePoints;
    }

    /**
     * Creates a new save point for nested transactions.
     * Params:
     * string|int name Save point name or id
     */
    void createSavePoint(string|int name) {
        this.execute(this.getDriver().savePointSQL(name));
    }

    /**
     * Releases a save point by its name.
     * Params:
     * string|int name Save point name or id
     */
    void releaseSavePoint(string|int name) {
        sql = this.getDriver().releaseSavePointSQL(name);
        if (sql) {
            this.execute(sql);
        }
    }

    /**
     * Rollback a save point by its name.
     * Params:
     * string|int name Save point name or id
     */
    void rollbackSavepoint(string|int name) {
        this.execute(this.getDriver().rollbackSavePointSQL(name));
    }

    // Run driver specific SQL to disable foreign key checks.
    void disableForeignKeys() {
        this.getDisconnectRetry().run(function () {
            this.execute(this.getDriver().disableForeignKeySQL());
        });
    }

    // Run driver specific SQL to enable foreign key checks.
    void enableForeignKeys() {
        this.getDisconnectRetry().run(void () {
            this.execute(this.getDriver().enableForeignKeySQL());
        });
    }

    /**
     * Executes a callback inside a transaction, if any exception occurs
     * while executing the passed callback, the transaction will be rolled back
     * If the result of the callback is `false`, the transaction will
     * also be rolled back. Otherwise the transaction is committed after executing
     * the callback.
     *
     * The callback will receive the connection instance as its first argument.
     *
     * ### Example:
     *
     * ```
     * aConnection.transactional(function (aConnection) {
     *  aConnection.deleteQuery("users").execute();
     * });
     * ```
     * Params:
     * \Closure aCallback The callback to execute within a transaction.
     */
    Json transactional(Closure aCallback) {
        this.begin();

        try {
            result = aCallback(this);
        } catch (Throwable  anException) {
            this.rollback(false);
            throw  anException;
        }
        if (result == false) {
            this.rollback(false);

            return false;
        }
        try {
            this.commit();
        } catch (NestedTransactionRollbackException  anException) {
            this.rollback(false);
            throw  anException;
        }
        return result;
    }

    // Returns whether some nested transaction has been already rolled back.
    protected bool wasNestedTransactionRolledback() {
        return cast(NestedTransactionRollbackException)this.nestedTransactionRollbackException;
    }

    /**
     * Run an operation with constraints disabled.
     *
     * Constraints should be re-enabled after the callback succeeds/fails.
     *
     * ### Example:
     *
     * ```
     * aConnection.disableConstraints(function (aConnection) {
     *  aConnection.insertQuery("users").execute();
     * });
     * ```
     * Params:
     * \Closure aCallback Callback to run with constraints disabled
     */
    Json disableConstraints(Closure aCallback) {
        return this.getDisconnectRetry().run(function () use (aCallback) {
            this.disableForeignKeys();

            try {
                result = aCallback(this);
            } finally {
                this.enableForeignKeys();
            }
            return result;
        });
    }

    // Checks if a transaction is running.
    bool inTransaction() {
        return _transactionStarted;
    }

    /**
     * Enables or disables metadata caching for this connection
     *
     * Changing this setting will not modify existing schema collections objects.
     * Params:
     * string|bool cache Either boolean false to disable metadata caching, or
     *  true to use `_cake_model_` or the name of the cache config to use.
     */
    void cacheMetadata(string|bool cache) {
       _schemaCollection = null;
       configuration.data("cacheMetadata"] = cache;
        if (isString($cache)) {
            this.cacher = null;
        }
    }
 
    void setCacher(ICache cacher) {
        this.cacher = cacher;
    }
 
    ICache getCacher() {
        if (this.cacher !isNull) {
            return this.cacher;
        }
        configDataName = configuration.data("cacheMetadata"] ?? "_cake_model_";
        if (!isString(configDataName)) {
            configDataName = "_cake_model_";
        }
        if (!class_exists(Cache.classname)) {
            throw new UimException(
                'To use caching you must either set a cacher using Connection.setCacher()' .
                ' or require the UIM/cache package in your composer config.'
            );
        }
        return this.cacher = Cache.pool(configDataName);
    }

    // Returns an array that can be used to describe the internal state of this object.
    IData[string] debugInfo() {
        secrets = [
            "password": "*****",
            "username": "*****",
            "host": "*****",
            "database": "*****",
            "port": "*****",
        ];
        replace = array_intersect_key($secrets, _config);
        configData = replace + _config;

        if (configuration.hasKey("read")) {
            configData("read", array_intersect_key($secrets, configData("read")) + configData("read"));
        }
        if (configData.isSet("write")) {
            configData("write", array_intersect_key($secrets, configData("write")) + configData("write"));
        }
        return [
            "config": configData,
            "readDriver": this.readDriver,
            "writeDriver": this.writeDriver,
            "transactionLevel": _transactionLevel,
            "transactionStarted": _transactionStarted,
            "useSavePoints": _useSavePoints,
        ];
    }
}
