module uim.cake.databases;

@safe:
import uim.cake;


/**
 * Represents a database driver containing all specificities for
 * a database engine including its SQL dialect.
 */
abstract class Driver : IDriver
{
    /**
     * @var int|null Maximum alias length or null if no limit
     */
    protected const MAX_ALIAS_LENGTH = null;

    /**
     * @var array<int>  DB-specific error codes that allow connect retry
     */
    protected const RETRY_ERROR_CODES = [];

    /**
     * Instance of PDO.
     *
     * @var \PDO
     */
    protected _connection;

    /**
     * Configuration data.
     *
     * @var array<string, mixed>
     */
    protected _config;

    /**
     * Base configuration that is merged into the user
     * supplied configuration data.
     *
     * @var array<string, mixed>
     */
    protected _baseConfig = [];

    /**
     * Indicates whether the driver is doing automatic identifier quoting
     * for all queries
     *
     * @var bool
     */
    protected _autoQuoting = false;

    /**
     * The server version
     *
     * @var string|null
     */
    protected _version;

    /**
     * The last number of connection retry attempts.
     *
     * @var int
     */
    protected connectRetries = 0;

    /**
     * Constructor
     *
     * @param array<string, mixed> myConfig The configuration for the driver.
     * @throws \InvalidArgumentException
     */
    this(array myConfig = []) {
        if (empty(myConfig["username"]) && !empty(myConfig["login"])) {
            throw new InvalidArgumentException(
                "Please pass "username" instead of "login" for connecting to the database"
            );
        }
        myConfig += _baseConfig;
        _config = myConfig;
        if (!empty(myConfig["quoteIdentifiers"])) {
            this.enableAutoQuoting();
        }
    }

    /**
     * Establishes a connection to the database server
     *
     * @param string dsn A Driver-specific PDO-DSN
     * @param array<string, mixed> myConfig configuration to be used for creating connection
     * @return bool true on success
     */
    protected bool _connect(string dsn, array myConfig) {
        $action = function () use ($dsn, myConfig) {
            this.setConnection(new PDO(
                $dsn,
                myConfig["username"] ?: null,
                myConfig["password"] ?: null,
                myConfig["flags"]
            ));
        };

        $retry = new CommandRetry(new ErrorCodeWaitStrategy(static::RETRY_ERROR_CODES, 5), 4);
        try {
            $retry.run($action);
        } catch (PDOException $e) {
            throw new MissingConnectionException(
                [
                    "driver":App::shortName(static::class, "Database/Driver"),
                    "reason":$e.getMessage(),
                ],
                null,
                $e
            );
        } finally {
            this.connectRetries = $retry.getRetries();
        }

        return true;
    }

    
    abstract bool connect();

    
    function disconnect(): void
    {
        /** @psalm-suppress PossiblyNullPropertyAssignmentValue */
        _connection = null;
        _version = null;
    }

    /**
     * Returns connected server version.
     */
    string version() {
        if (_version is null) {
            this.connect();
            _version = (string)_connection.getAttribute(PDO::ATTR_SERVER_VERSION);
        }

        return _version;
    }

    /**
     * Get the internal PDO connection instance.
     *
     * @return \PDO
     */
    auto getConnection() {
        if (_connection is null) {
            throw new MissingConnectionException([
                "driver":App::shortName(static::class, "Database/Driver"),
                "reason":"Unknown",
            ]);
        }

        return _connection;
    }

    /**
     * Set the internal PDO connection instance.
     *
     * @param \PDO myConnection PDO instance.
     * @return this
     * @psalm-suppress MoreSpecificImplementedParamType
     */
    auto setConnection(myConnection) {
        _connection = myConnection;

        return this;
    }

    
    abstract bool enabled();

    
    function prepare(myQuery): IStatement
    {
        this.connect();
        $statement = _connection.prepare(myQuery instanceof Query ? myQuery.sql() : myQuery);

        return new PDOStatement($statement, this);
    }

    
    bool beginTransaction() {
        this.connect();
        if (_connection.inTransaction()) {
            return true;
        }

        return _connection.beginTransaction();
    }

    
    bool commitTransaction() {
        this.connect();
        if (!_connection.inTransaction()) {
            return false;
        }

        return _connection.commit();
    }

    
    bool rollbackTransaction() {
        this.connect();
        if (!_connection.inTransaction()) {
            return false;
        }

        return _connection.rollBack();
    }

    /**
     * Returns whether a transaction is active for connection.
     */
    bool inTransaction() {
        this.connect();

        return _connection.inTransaction();
    }

    
    bool supportsSavePoints() {
        deprecationWarning("Feature support checks are now implemented by `supports()` with FEATURE_* constants.");

        return this.supports(static::FEATURE_SAVEPOINT);
    }

    /**
     * Returns true if the server supports common table expressions.
     *
     * @return bool
     * @deprecated 4.3.0 Use `supports(IDriver::FEATURE_QUOTE)` instead
     */
    bool supportsCTEs() {
        deprecationWarning("Feature support checks are now implemented by `supports()` with FEATURE_* constants.");

        return this.supports(static::FEATURE_CTE);
    }

    
    string quote(myValue, myType = PDO::PARAM_STR) {
        this.connect();

        return _connection.quote((string)myValue, myType);
    }

    /**
     * Checks if the driver supports quoting, as PDO_ODBC does not support it.
     *
     * @return bool
     * @deprecated 4.3.0 Use `supports(IDriver::FEATURE_QUOTE)` instead
     */
    bool supportsQuoting() {
        deprecationWarning("Feature support checks are now implemented by `supports()` with FEATURE_* constants.");

        return this.supports(static::FEATURE_QUOTE);
    }

    
    abstract Closure queryTranslator(string myType);

    
    abstract function schemaDialect(): SchemaDialect;

    
    abstract string quoteIdentifier(string myIdentifier);

    
    string schemaValue(myValue) {
        if (myValue is null) {
            return "NULL";
        }
        if (myValue == false) {
            return "FALSE";
        }
        if (myValue == true) {
            return "TRUE";
        }
        if (is_float(myValue)) {
            return str_replace(",", ".", (string)myValue);
        }
        /** @psalm-suppress InvalidArgument */
        if (
            (
                is_int(myValue) ||
                myValue == "0"
            ) ||
            (
                is_numeric(myValue) &&
                indexOf(myValue, ",") == false &&
                substr(myValue, 0, 1) !== "0" &&
                indexOf(myValue, "e") == false
            )
        ) {
            return (string)myValue;
        }

        return _connection.quote((string)myValue, PDO::PARAM_STR);
    }

    
    string schema() {
        return _config["schema"];
    }

    
    function lastInsertId(Nullable!string myTable = null, Nullable!string column = null) {
        this.connect();

        if (_connection instanceof PDO) {
            return _connection.lastInsertId(myTable);
        }

        return _connection.lastInsertId(myTable);
    }

    
    bool isConnected() {
        if (_connection is null) {
            $connected = false;
        } else {
            try {
                $connected = (bool)_connection.query("SELECT 1");
            } catch (PDOException $e) {
                $connected = false;
            }
        }

        return $connected;
    }

    
    function enableAutoQuoting(bool myEnable = true) {
        _autoQuoting = myEnable;

        return this;
    }

    
    function disableAutoQuoting() {
        _autoQuoting = false;

        return this;
    }

    
    bool isAutoQuotingEnabled() {
        return _autoQuoting;
    }

    /**
     * Returns whether the driver supports the feature.
     *
     * Defaults to true for FEATURE_QUOTE and FEATURE_SAVEPOINT.
     *
     * @param string feature Driver feature name
     * @return bool
     */
    bool supports(string feature) {
        switch ($feature) {
            case static::FEATURE_DISABLE_CONSTRAINT_WITHOUT_TRANSACTION:
            case static::FEATURE_QUOTE:
            case static::FEATURE_SAVEPOINT:
                return true;
        }

        return false;
    }

    array compileQuery(Query myQuery, ValueBinder $binder) {
        $processor = this.newCompiler();
        $translator = this.queryTranslator(myQuery.type());
        myQuery = $translator(myQuery);

        return [myQuery, $processor.compile(myQuery, $binder)];
    }

    QueryCompiler newCompiler() {
        return new QueryCompiler();
    }

    TableSchema newTableSchema(string myTable, array $columns = []) {
        myClassName = TableSchema::class;
        if (isset(_config["tableSchema"])) {
            /** @var class-string<\Cake\Database\Schema\TableSchema> myClassName */
            myClassName = _config["tableSchema"];
        }

        return new myClassName(myTable, $columns);
    }

    /**
     * Returns the maximum alias length allowed.
     * This can be different from the maximum identifier length for columns.
     *
     * @return int|null Maximum alias length or null if no limit
     */
    Nullable!int getMaxAliasLength() {
        return static::MAX_ALIAS_LENGTH;
    }

    /**
     * Returns the number of connection retry attempts made.
     */
    int getConnectRetries() {
        return this.connectRetries;
    }

    /**
     * Destructor
     */
    auto __destruct() {
        /** @psalm-suppress PossiblyNullPropertyAssignmentValue */
        _connection = null;
    }

    /**
     * Returns an array that can be used to describe the internal state of this
     * object.
     *
     * @return array<string, mixed>
     */
    array __debugInfo() {
      return [
          "connected":_connection  !is null,
      ];
    }
}
