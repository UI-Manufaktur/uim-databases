module uim.cake.databases;

/**
 * Represents a database statement. Concrete implementations
 * can either use PDOStatement or a native driver
 *
 * @property-read string myQueryString
 */
interface IStatement
{
    /**
     * Used to designate that numeric indexes be returned in a result when calling fetch methods
     */
    public const string FETCH_TYPE_NUM = "num";

    /**
     * Used to designate that an associated array be returned in a result when calling fetch methods
     */
    public const string FETCH_TYPE_ASSOC = "assoc";

    /**
     * Used to designate that a stdClass object be returned in a result when calling fetch methods
     */
    public const string FETCH_TYPE_OBJ = "obj";

    /**
     * Assign a value to a positional or named variable in prepared query. If using
     * positional variables you need to start with index one, if using named params then
     * just use the name in any order.
     *
     * It is not allowed to combine positional and named variables in the same statement
     *
     * ### Examples:
     *
     * ```
     * $statement.bindValue(1, "a title");
     * $statement.bindValue("active", true, "boolean");
     * $statement.bindValue(5, new \DateTime(), "date");
     * ```
     *
     * @param string|int $column name or param position to be bound
     * @param mixed myValue The value to bind to variable in query
     * @param string|int|null myType name of configured Type class, or PDO type constant.
     */
    void bindValue($column, myValue, myType = "string");

    /**
     * Closes a cursor in the database, freeing up any resources and memory
     * allocated to it. In most cases you don"t need to call this method, as it is
     * automatically called after fetching all results from the result set.
     */
    void closeCursor();

    /**
     * Returns the number of columns this statement"s results will contain
     *
     * ### Example:
     *
     * ```
     *  $statement = myConnection.prepare("SELECT id, title from articles");
     *  $statement.execute();
     *  echo $statement.columnCount(); // outputs 2
     * ```
     */
    int columnCount();

    /**
     * Returns the error code for the last error that occurred when executing this statement
     *
     * @return string|int
     */
    function errorCode();

    /**
     * Returns the error information for the last error that occurred when executing
     * this statement
     */
    array errorInfo();

    /**
     * Executes the statement by sending the SQL query to the database. It can optionally
     * take an array or arguments to be bound to the query variables. Please note
     * that binding parameters from this method will not perform any custom type conversion
     * as it would normally happen when calling `bindValue`
     *
     * @param array|null myParams list of values to be bound to query
     * @return bool true on success, false otherwise
     */
    bool execute(?array myParams = null);

    /**
     * Returns the next row for the result set after executing this statement.
     * Rows can be fetched to contain columns as names or positions. If no
     * rows are left in result set, this method will return false
     *
     * ### Example:
     *
     * ```
     *  $statement = myConnection.prepare("SELECT id, title from articles");
     *  $statement.execute();
     *  print_r($statement.fetch("assoc")); // will show ["id":1, "title":"a title"]
     * ```
     *
     * @param string|int myType "num" for positional columns, assoc for named columns, or PDO fetch mode constants.
     * @return mixed Result array containing columns and values or false if no results
     * are left
     */
    function fetch(myType = "num");

    /**
     * Returns an array with all rows resulting from executing this statement
     *
     * ### Example:
     *
     * ```
     *  $statement = myConnection.prepare("SELECT id, title from articles");
     *  $statement.execute();
     *  print_r($statement.fetchAll("assoc")); // will show [0: ["id":1, "title":"a title"]]
     * ```
     *
     * @param string|int myType num for fetching columns as positional keys or assoc for column names as keys
     * @return array|false list of all results from database for this statement or false on failure.
     */
    function fetchAll(myType = "num");

    /**
     * Returns the value of the result at position.
     *
     * @param int $position The numeric position of the column to retrieve in the result
     * @return mixed Returns the specific value of the column designated at $position
     */
    function fetchColumn(int $position);

    /**
     * Returns the number of rows affected by this SQL statement
     *
     * ### Example:
     *
     * ```
     *  $statement = myConnection.prepare("SELECT id, title from articles");
     *  $statement.execute();
     *  print_r($statement.rowCount()); // will show 1
     * ```
     */
    int rowCount();

    /**
     * Statements can be passed as argument for count()
     * to return the number for affected rows from last execution
     */
    int count();

    /**
     * Binds a set of values to statement object with corresponding type
     *
     * @param array myParams list of values to be bound
     * @param array myTypes list of types to be used, keys should match those in myParams
     */
    void bind(array myParams, array myTypes);

    /**
     * Returns the latest primary inserted using this statement
     *
     * @param string|null myTable table name or sequence to get last insert value from
     * @param string|null $column the name of the column representing the primary key
     * @return string|int
     */
    function lastInsertId(Nullable!string myTable = null, Nullable!string column = null);
}
