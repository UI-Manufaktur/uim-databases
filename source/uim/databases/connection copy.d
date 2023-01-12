/*********************************************************************************************************
	Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        
	License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  
	Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      
**********************************************************************************************************/
module uim.cake.databases;

@safe:
import uim.cake;

// Represents a connection with a database server.
class Connection : IConnection {
    use TypeConverterTrait;

    /**
     * Contains the configuration params for this connection.
     *
     * @var array<string, mixed>
     */
    protected _config;

    /**
     * Driver object, responsible for creating the real connection
     * and provide specific SQL dialect.
     *
     * @var DDBIDriver
     */
    protected _driver;

    /**
     * Contains how many nested transactions have been started.
     */
    protected int _transactionLevel = 0;

    /**
     * Whether a transaction is active in this connection.
     */
    protected bool _transactionStarted = false;

    /**
     * Whether this connection can and should use savepoints for nested
     * transactions.
     */
    protected bool _useSavePoints = false;

    /**
     * Whether to log queries generated during this connection.
     */
    protected bool _logQueries = false;

    /**
     * Logger object instance.
     *
     * @var \Psr\logs.LoggerInterface|null
     */
    protected _logger;

    /**
     * Cacher object instance.
     *
     * @var \Psr\SimpleCache\ICache|null
     */
    protected $cacher;

    /**
     * The schema collection object
     *
     * @var DDBSchema\ICollection|null
     */
    protected _schemaCollection;

    /**
     * NestedTransactionRollbackException object instance, will be stored if
     * the rollback method is called in some nested transaction.
     *
     * @var DDBexceptions.NestedTransactionRollbackException|null
     */
    protected $nestedTransactionRollbackException;

    /**
     * Constructor.
     *
     * ### Available options:
     *
     * - `driver` Sort name or FCQN for driver.
     * - `log` Boolean indicating whether to use query logging.
     * - `name` Connection name.
     * - `cacheMetaData` Boolean indicating whether metadata (datasource schemas) should be cached.
     *    If set to a string it will be used as the name of cache config to use.
     * - `cacheKeyPrefix` Custom prefix to use when generation cache keys. Defaults to connection name.
     *
     * @param array<string, mixed> aConfig Configuration array.
     */
    this(Json aConfig) {
        _config = aConfig;

        $driverConfig = array_diff_key(aConfig, array_flip([
            'name',
            'driver',
            'log',
            'cacheMetaData',
            'cacheKeyPrefix',
        ]));
        _driver = this.createDriver(aConfig['driver'] ?? '', $driverConfig);

        if (!empty(aConfig['log'])) {
            this.enableQueryLogging((bool)aConfig['log']);
        }
    }

    /**
     * Destructor
     *
     * Disconnects the driver to release the connection.
     */
    function __destruct() {
        if (_transactionStarted && class_exists(Log::class)) {
            Log::warning('The connection is going to be closed but there is an active transaction.');
        }
    }


    array config() {
        return _config;
    }


    string configName() {
        return _config['name'] ?? '';
    }

    /**
     * Sets the driver instance. If a string is passed it will be treated
     * as a class name and will be instantiated.
     *
     * @param uim.cake.databases.IDriver|string $driver The driver instance to use.
     * @param array<string, mixed> aConfig Config for a new driver.
     * @throws uim.cake.databases.exceptions.MissingDriverException When a driver class is missing.
     * @throws uim.cake.databases.exceptions.MissingExtensionException When a driver's PHP extension is missing.
     * @return this
     * @deprecated 4.4.0 Setting the driver is deprecated. Use the connection config instead.
     */
    function setDriver($driver, aConfig = null) {
        deprecationWarning('Setting the driver is deprecated. Use the connection config instead.');

        _driver = this.createDriver($driver, aConfig);

        return this;
    }

    /**
     * Creates driver from name, class name or instance.
     *
     * @param uim.cake.databases.IDriver|string aName Driver name, class name or instance.
     * @param Json aConfig Driver config if $name is not an instance.
     * @return uim.cake.databases.IDriver
     * @throws uim.cake.databases.exceptions.MissingDriverException When a driver class is missing.
     * @throws uim.cake.databases.exceptions.MissingExtensionException When a driver's PHP extension is missing.
     */
    protected function createDriver($name, Json aConfig): IDriver
    {
        $driver = $name;
        if (is_string($driver)) {
            /** @psalm-var class-string<uim.cake.databases.IDriver>|null $className */
            $className = App::className($driver, 'Database/Driver');
            if ($className == null) {
                throw new MissingDriverException(['driver': $driver, 'connection': this.configName()]);
            }
            $driver = new $className(aConfig);
        }

        if (!$driver.enabled()) {
            throw new MissingExtensionException(['driver': get_class($driver), 'name': this.configName()]);
        }

        return $driver;
    }

    /**
     * Get the retry wrapper object that is allows recovery from server disconnects
     * while performing certain database actions, such as executing a query.
     *
     * @return uim.cake.Core\Retry\CommandRetry The retry wrapper
     */
    function getDisconnectRetry(): CommandRetry
    {
        return new CommandRetry(new ReconnectStrategy(this));
    }

    /**
     * Gets the driver instance.
     *
     * @return uim.cake.databases.IDriver
     */
    function getDriver(): IDriver
    {
        return _driver;
    }

    /**
     * Connects to the configured database.
     *
     * @throws uim.cake.databases.exceptions.MissingConnectionException If database connection could not be established.
     * @return bool true, if the connection was already established or the attempt was successful.
     */
    bool connect() {
        try {
            return _driver.connect();
        } catch (MissingConnectionException $e) {
            throw $e;
        } catch (Throwable $e) {
            throw new MissingConnectionException(
                [
                    'driver': App::shortName(get_class(_driver), 'Database/Driver'),
                    'reason': $e.getMessage(),
                ],
                null,
                $e
            );
        }
    }

    /**
     * Disconnects from database server.
     */
    void disconnect() {
        _driver.disconnect();
    }

    /**
     * Returns whether connection to database server was already established.
     */
    bool isConnected() {
        return _driver.isConnected();
    }

    /**
     * Prepares a SQL statement to be executed.
     *
     * @param uim.cake.databases.Query|string $query The SQL to convert into a prepared statement.
     * @return uim.cake.databases.IStatement
     */
    function prepare($query): IStatement
    {
        return this.getDisconnectRetry().run(function () use ($query) {
            $statement = _driver.prepare($query);

            if (_logQueries) {
                $statement = _newLogger($statement);
            }

            return $statement;
        });
    }

    /**
     * Executes a query using $params for interpolating values and $types as a hint for each
     * those params.
     *
     * @param string $sql SQL to be executed and interpolated with $params
     * @param array $params list or associative array of params to be interpolated in $sql as values
     * @param array $types list or associative array of types to be used for casting values in query
     * @return uim.cake.databases.IStatement executed statement
     */
    function execute(string $sql, array $params = null, array $types = null): IStatement
    {
        return this.getDisconnectRetry().run(function () use ($sql, $params, $types) {
            $statement = this.prepare($sql);
            if (!empty($params)) {
                $statement.bind($params, $types);
            }
            $statement.execute();

            return $statement;
        });
    }

    /**
     * Compiles a Query object into a SQL string according to the dialect for this
     * connection's driver
     *
     * @param uim.cake.databases.Query $query The query to be compiled
     * @param uim.cake.databases.ValueBinder aBinder Value binder
     */
    string compileQuery(Query $query, ValueBinder aBinder) {
        return this.getDriver().compileQuery($query, $binder)[1];
    }

    /**
     * Executes the provided query after compiling it for the specific driver
     * dialect and returns the executed Statement object.
     *
     * @param uim.cake.databases.Query $query The query to be executed
     * @return uim.cake.databases.IStatement executed statement
     */
    function run(Query $query): IStatement
    {
        return this.getDisconnectRetry().run(function () use ($query) {
            $statement = this.prepare($query);
            $query.getValueBinder().attachTo($statement);
            $statement.execute();

            return $statement;
        });
    }

    /**
     * Executes a SQL statement and returns the Statement object as result.
     *
     * @param string $sql The SQL query to execute.
     * @return uim.cake.databases.IStatement
     */
    function query(string $sql): IStatement
    {
        return this.getDisconnectRetry().run(function () use ($sql) {
            $statement = this.prepare($sql);
            $statement.execute();

            return $statement;
        });
    }

    /**
     * Create a new Query instance for this connection.
     *
     * @return uim.cake.databases.Query
     */
    function newQuery(): Query
    {
        return new Query(this);
    }

    /**
     * Sets a Schema\Collection object for this connection.
     *
     * @param uim.cake.databases.Schema\ICollection $collection The schema collection object
     * @return this
     */
    function setSchemaCollection(SchemaICollection $collection) {
        _schemaCollection = $collection;

        return this;
    }

    /**
     * Gets a Schema\Collection object for this connection.
     *
     * @return uim.cake.databases.Schema\ICollection
     */
    function getSchemaCollection(): SchemaICollection
    {
        if (_schemaCollection != null) {
            return _schemaCollection;
        }

        if (!empty(_config['cacheMetadata'])) {
            return _schemaCollection = new CachedCollection(
                new SchemaCollection(this),
                empty(_config['cacheKeyPrefix']) ? this.configName() : _config['cacheKeyPrefix'],
                this.getCacher()
            );
        }

        return _schemaCollection = new SchemaCollection(this);
    }

    /**
     * Executes an INSERT query on the specified table.
     *
     * @param string $table the table to insert values in
     * @param array $values values to be inserted
     * @param array<int|string, string> $types Array containing the types to be used for casting
     * @return uim.cake.databases.IStatement
     */
    function insert(string $table, array $values, array $types = null): IStatement
    {
        return this.getDisconnectRetry().run(function () use ($table, $values, $types) {
            $columns = array_keys($values);

            return this.newQuery().insert($columns, $types)
                .into($table)
                .values($values)
                .execute();
        });
    }

    /**
     * Executes an UPDATE statement on the specified table.
     *
     * @param string $table the table to update rows from
     * @param array $values values to be updated
     * @param array $conditions conditions to be set for update statement
     * @param array<string> $types list of associative array containing the types to be used for casting
     * @return uim.cake.databases.IStatement
     */
    function update(string $table, array $values, array $conditions = null, array $types = null): IStatement
    {
        return this.getDisconnectRetry().run(function () use ($table, $values, $conditions, $types) {
            return this.newQuery().update($table)
                .set($values, $types)
                .where($conditions, $types)
                .execute();
        });
    }

    /**
     * Executes a DELETE statement on the specified table.
     *
     * @param string $table the table to delete rows from
     * @param array $conditions conditions to be set for delete statement
     * @param array<string> $types list of associative array containing the types to be used for casting
     * @return uim.cake.databases.IStatement
     */
    function delete(string $table, array $conditions = null, array $types = null): IStatement
    {
        return this.getDisconnectRetry().run(function () use ($table, $conditions, $types) {
            return this.newQuery().delete($table)
                .where($conditions, $types)
                .execute();
        });
    }

    /**
     * Starts a new transaction.
     */
    void begin() {
        if (!_transactionStarted) {
            if (_logQueries) {
                this.log('BEGIN');
            }

            this.getDisconnectRetry().run(void () {
                _driver.beginTransaction();
            });

            _transactionLevel = 0;
            _transactionStarted = true;
            this.nestedTransactionRollbackException = null;

            return;
        }

        _transactionLevel++;
        if (this.isSavePointsEnabled()) {
            this.createSavePoint((string)_transactionLevel);
        }
    }

    /**
     * Commits current transaction.
     *
     * @return bool true on success, false otherwise
     */
    bool commit() {
        if (!_transactionStarted) {
            return false;
        }

        if (_transactionLevel == 0) {
            if (this.wasNestedTransactionRolledback()) {
                /** @var DDBexceptions.NestedTransactionRollbackException $e */
                $e = this.nestedTransactionRollbackException;
                this.nestedTransactionRollbackException = null;
                throw $e;
            }

            _transactionStarted = false;
            this.nestedTransactionRollbackException = null;
            if (_logQueries) {
                this.log('COMMIT');
            }

            return _driver.commitTransaction();
        }
        if (this.isSavePointsEnabled()) {
            this.releaseSavePoint((string)_transactionLevel);
        }

        _transactionLevel--;

        return true;
    }

    /**
     * Rollback current transaction.
     *
     * @param bool|null $toBeginning Whether the transaction should be rolled back to the
     * beginning of it. Defaults to false if using savepoints, or true if not.
     */
    bool rollback(?bool $toBeginning = null) {
        if (!_transactionStarted) {
            return false;
        }

        $useSavePoint = this.isSavePointsEnabled();
        if ($toBeginning == null) {
            $toBeginning = !$useSavePoint;
        }
        if (_transactionLevel == 0 || $toBeginning) {
            _transactionLevel = 0;
            _transactionStarted = false;
            this.nestedTransactionRollbackException = null;
            if (_logQueries) {
                this.log('ROLLBACK');
            }
            _driver.rollbackTransaction();

            return true;
        }

        $savePoint = _transactionLevel--;
        if ($useSavePoint) {
            this.rollbackSavepoint($savePoint);
        } elseif (this.nestedTransactionRollbackException == null) {
            this.nestedTransactionRollbackException = new NestedTransactionRollbackException();
        }

        return true;
    }

    /**
     * Enables/disables the usage of savepoints, enables only if driver the allows it.
     *
     * If you are trying to enable this feature, make sure you check
     * `isSavePointsEnabled()` to verify that savepoints were enabled successfully.
     *
     * @param bool $enable Whether save points should be used.
     * @return this
     */
    function enableSavePoints(bool $enable = true) {
        if ($enable == false) {
            _useSavePoints = false;
        } else {
            _useSavePoints = _driver.supports(IDriver::FEATURE_SAVEPOINT);
        }

        return this;
    }

    /**
     * Disables the usage of savepoints.
     *
     * @return this
     */
    function disableSavePoints() {
        _useSavePoints = false;

        return this;
    }

    /**
     * Returns whether this connection is using savepoints for nested transactions
     *
     * @return bool true if enabled, false otherwise
     */
    bool isSavePointsEnabled() {
        return _useSavePoints;
    }

    /**
     * Creates a new save point for nested transactions.
     *
     * @param string|int $name Save point name or id
     */
    void createSavePoint($name) {
        this.execute(_driver.savePointSQL($name)).closeCursor();
    }

    /**
     * Releases a save point by its name.
     *
     * @param string|int $name Save point name or id
     */
    void releaseSavePoint($name) {
        $sql = _driver.releaseSavePointSQL($name);
        if ($sql) {
            this.execute($sql).closeCursor();
        }
    }

    /**
     * Rollback a save point by its name.
     *
     * @param string|int $name Save point name or id
     */
    void rollbackSavepoint($name) {
        this.execute(_driver.rollbackSavePointSQL($name)).closeCursor();
    }

    /**
     * Run driver specific SQL to disable foreign key checks.
     */
    void disableForeignKeys() {
        this.getDisconnectRetry().run(void () {
            this.execute(_driver.disableForeignKeySQL()).closeCursor();
        });
    }

    /**
     * Run driver specific SQL to enable foreign key checks.
     */
    void enableForeignKeys() {
        this.getDisconnectRetry().run(void () {
            this.execute(_driver.enableForeignKeySQL()).closeCursor();
        });
    }

    /**
     * Returns whether the driver supports adding or dropping constraints
     * to already created tables.
     *
     * @return bool true if driver supports dynamic constraints
     * @deprecated 4.3.0 Fixtures no longer dynamically drop and create constraints.
     */
    bool supportsDynamicConstraints() {
        return _driver.supportsDynamicConstraints();
    }


    function transactional(callable $callback) {
        this.begin();

        try {
            $result = $callback(this);
        } catch (Throwable $e) {
            this.rollback(false);
            throw $e;
        }

        if ($result == false) {
            this.rollback(false);

            return false;
        }

        try {
            this.commit();
        } catch (NestedTransactionRollbackException $e) {
            this.rollback(false);
            throw $e;
        }

        return $result;
    }

    /**
     * Returns whether some nested transaction has been already rolled back.
     */
    protected bool wasNestedTransactionRolledback() {
        return this.nestedTransactionRollbackException instanceof NestedTransactionRollbackException;
    }


    function disableConstraints(callable $callback) {
        return this.getDisconnectRetry().run(function () use ($callback) {
            this.disableForeignKeys();

            try {
                $result = $callback(this);
            } finally {
                this.enableForeignKeys();
            }

            return $result;
        });
    }

    /**
     * Checks if a transaction is running.
     *
     * @return bool True if a transaction is running else false.
     */
    bool inTransaction() {
        return _transactionStarted;
    }

    /**
     * Quotes value to be used safely in database query.
     *
     * This uses `PDO::quote()` and requires `supportsQuoting()` to work.
     *
     * @param mixed $value The value to quote.
     * @param uim.cake.databases.TypeInterface|string|int $type Type to be used for determining kind of quoting to perform
     * @return string Quoted value
     */
    string quote($value, $type = 'string') {
        [$value, $type] = this.cast($value, $type);

        return _driver.quote($value, $type);
    }

    /**
     * Checks if using `quote()` is supported.
     *
     * This is not required to use `quoteIdentifier()`.
     */
    bool supportsQuoting() {
        return _driver.supports(IDriver::FEATURE_QUOTE);
    }

    /**
     * Quotes a database identifier (a column name, table name, etc..) to
     * be used safely in queries without the risk of using reserved words.
     *
     * This does not require `supportsQuoting()` to work.
     *
     * @param string $identifier The identifier to quote.
     */
    string quoteIdentifier(string $identifier) {
        return _driver.quoteIdentifier($identifier);
    }

    /**
     * Enables or disables metadata caching for this connection
     *
     * Changing this setting will not modify existing schema collections objects.
     *
     * @param string|bool $cache Either boolean false to disable metadata caching, or
     *   true to use `_cake_model_` or the name of the cache config to use.
     */
    void cacheMetadata($cache) {
        _schemaCollection = null;
        _config['cacheMetadata'] = $cache;
        if (is_string($cache)) {
            this.cacher = null;
        }
    }


    function setCacher(ICache $cacher) {
        this.cacher = $cacher;

        return this;
    }


    function getCacher(): ICache
    {
        if (this.cacher != null) {
            return this.cacher;
        }

        $configName = _config['cacheMetadata'] ?? '_cake_model_';
        if (!is_string($configName)) {
            $configName = '_cake_model_';
        }

        if (!class_exists(Cache::class)) {
            throw new RuntimeException(
                'To use caching you must either set a cacher using Connection::setCacher()' .
                ' or require the cakephp/cache package in your composer config.'
            );
        }

        return this.cacher = Cache::pool($configName);
    }

    /**
     * Enable/disable query logging
     *
     * @param bool $enable Enable/disable query logging
     * @return this
     */
    function enableQueryLogging(bool $enable = true) {
        _logQueries = $enable;

        return this;
    }

    /**
     * Disable query logging
     *
     * @return this
     */
    function disableQueryLogging() {
        _logQueries = false;

        return this;
    }

    /**
     * Check if query logging is enabled.
     */
    bool isQueryLoggingEnabled() {
        return _logQueries;
    }

    /**
     * Sets a logger
     *
     * @param \Psr\logs.LoggerInterface $logger Logger object
     * @return this
     * @psalm-suppress ImplementedReturnTypeMismatch
     */
    function setLogger(LoggerInterface $logger) {
        _logger = $logger;

        return this;
    }

    /**
     * Gets the logger object
     *
     * @return \Psr\logs.LoggerInterface logger instance
     */
    function getLogger(): LoggerInterface
    {
        if (_logger != null) {
            return _logger;
        }

        if (!class_exists(BaseLog::class)) {
            throw new RuntimeException(
                'For logging you must either set a logger using Connection::setLogger()' .
                ' or require the cakephp/log package in your composer config.'
            );
        }

        return _logger = new QueryLogger(['connection': this.configName()]);
    }

    /**
     * Logs a Query string using the configured logger object.
     *
     * @param string $sql string to be logged
     */
    void log(string $sql) {
        $query = new LoggedQuery();
        $query.query = $sql;
        this.getLogger().debug((string)$query, ['query': $query]);
    }

    /**
     * Returns a new statement object that will log the activity
     * for the passed original statement instance.
     *
     * @param uim.cake.databases.IStatement $statement the instance to be decorated
     * @return uim.cake.databases.logs.LoggingStatement
     */
    protected function _newLogger(IStatement $statement): LoggingStatement
    {
        $log = new LoggingStatement($statement, _driver);
        $log.setLogger(this.getLogger());

        return $log;
    }

    /**
     * Returns an array that can be used to describe the internal state of this
     * object.
     *
     * @return array<string, mixed>
     */
    array __debugInfo() {
        $secrets = [
            'password': '*****',
            'username': '*****',
            'host': '*****',
            'database': '*****',
            'port': '*****',
        ];
        $replace = array_intersect_key($secrets, _config);
        aConfig = $replace + _config;

        return [
            'config': aConfig,
            'driver': _driver,
            'transactionLevel': _transactionLevel,
            'transactionStarted': _transactionStarted,
            'useSavePoints': _useSavePoints,
            'logQueries': _logQueries,
            'logger': _logger,
        ];
    }
}
