module uim.databases.Statement;

use PDO;

/**
 * Statement class meant to be used by an Sqlserver driver
 *
 * @internal
 */
class SqlserverStatement : PDOStatement
{
    /**
     * {@inheritDoc}
     *
     * The SQL Server PDO driver requires that binary parameters be bound with the SQLSRV_ENCODING_BINARY attribute.
     * This overrides the PDOStatement::bindValue method in order to bind binary columns using the required attribute.
     *
     * @param string|int $column name or param position to be bound
     * @param mixed aValue The value to bind to variable in query
     * @param string|int|null $type PDO type or name of configured Type class
     * @return void
     */
    function bindValue($column, DValue aValue, $type = "string"): void
    {
        if ($type == null) {
            $type = "string";
        }
        if (!is_int($type)) {
            [aValue, $type] = this.cast(DValue aValue, $type);
        }
        if ($type == PDO::PARAM_LOB) {
            /** @psalm-suppress UndefinedConstant */
            this._statement.bindParam($column, DValue aValue, $type, 0, PDO::SQLSRV_ENCODING_BINARY);
        } else {
            this._statement.bindValue($column, DValue aValue, $type);
        }
    }
}
