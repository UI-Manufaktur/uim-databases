/*********************************************************************************************************
	Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        
	License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  
	Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      
**********************************************************************************************************/
module uim.databases.Statement;

@safe:
import uim.databases;

use PDO;
use PDOStatement as Statement;

/**
 * Decorator for \PDOStatement class mainly used for converting human readable
 * fetch modes into PDO constants.
 */
class PDOStatement : StatementDecorator
{
    /**
     * PDOStatement instance
     *
     * @var \PDOStatement
     */
    protected _statement;

    /**
     * Constructor
     *
     * @param \PDOStatement statement Original statement to be decorated.
     * @param uim.databases.IDBADriver aDriver Driver instance.
     */
    public this(Statement statement, IDBADriver aDriver)
    {
        this._statement = statement;
        this._driver = driver;
    }

    /**
     * Magic getter to return PDOStatement::queryString as read-only.
     *
     * @param string property internal property to get
     * @return string|null
     */
    function __get(string property)
    {
        if (property == "queryString" && isset(this._statement.queryString)) {
            /** @psalm-suppress NoInterfaceProperties */
            return this._statement.queryString;
        }

        return null;
    }

    /**
     * Assign a value to a positional or named variable in prepared query. If using
     * positional variables you need to start with index one, if using named params then
     * just use the name in any order.
     *
     * You can pass PDO compatible constants for binding values with a type or optionally
     * any type name registered in the Type class. Any value will be converted to the valid type
     * representation if needed.
     *
     * It is not allowed to combine positional and named variables in the same statement
     *
     * ### Examples:
     *
     * ```
     * statement.bindValue(1, "a title");
     * statement.bindValue(2, 5, PDO::INT);
     * statement.bindValue("active", true, "boolean");
     * statement.bindValue(5, new \DateTime(), "date");
     * ```
     *
     * @param string|int column name or param position to be bound
     * @param mixed aValue The value to bind to variable in query
     * @param string|int|null type PDO type or name of configured Type class
     * @return void
     */
    function bindValue(column, DValue aValue, type = "string"): void
    {
        if (type == null) {
            type = "string";
        }
        if (!is_int(type)) {
            [aValue, type] = this.cast(DValue aValue, type);
        }
        this._statement.bindValue(column, DValue aValue, type);
    }

    /**
     * Returns the next row for the result set after executing this statement.
     * Rows can be fetched to contain columns as names or positions. If no
     * rows are left in result set, this method will return false
     *
     * ### Example:
     *
     * ```
     *  statement = connection.prepare("SELECT id, title from articles");
     *  statement.execute();
     *  print_r(statement.fetch("assoc")); // will show ["id" : 1, "title" : "a title"]
     * ```
     *
     * @param string|int type "num" for positional columns, assoc for named columns
     * @return mixed Result array containing columns and values or false if no results
     * are left
     */
    function fetch(type = parent::FETCH_TYPE_NUM)
    {
        if (type == static::FETCH_TYPE_NUM) {
            return this._statement.fetch(PDO::FETCH_NUM);
        }
        if (type == static::FETCH_TYPE_ASSOC) {
            return this._statement.fetch(PDO::FETCH_ASSOC);
        }
        if (type == static::FETCH_TYPE_OBJ) {
            return this._statement.fetch(PDO::FETCH_OBJ);
        }

        if (!is_int(type)) {
            throw new CakeException(sprintf(
                "Fetch type for PDOStatement must be an integer, found `%s` instead",
                getTypeName(type)
            ));
        }

        return this._statement.fetch(type);
    }

    /**
     * Returns an array with all rows resulting from executing this statement
     *
     * ### Example:
     *
     * ```
     *  statement = connection.prepare("SELECT id, title from articles");
     *  statement.execute();
     *  print_r(statement.fetchAll("assoc")); // will show [0 : ["id" : 1, "title" : "a title"]]
     * ```
     *
     * @param string|int type num for fetching columns as positional keys or assoc for column names as keys
     * @return array|false list of all results from database for this statement, false on failure
     * @psalm-assert string type
     */
    function fetchAll(type = parent::FETCH_TYPE_NUM)
    {
        if (type == static::FETCH_TYPE_NUM) {
            return this._statement.fetchAll(PDO::FETCH_NUM);
        }
        if (type == static::FETCH_TYPE_ASSOC) {
            return this._statement.fetchAll(PDO::FETCH_ASSOC);
        }
        if (type == static::FETCH_TYPE_OBJ) {
            return this._statement.fetchAll(PDO::FETCH_OBJ);
        }

        if (!is_int(type)) {
            throw new CakeException(sprintf(
                "Fetch type for PDOStatement must be an integer, found `%s` instead",
                getTypeName(type)
            ));
        }

        return this._statement.fetchAll(type);
    }
}
