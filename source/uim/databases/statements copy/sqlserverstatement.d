module uim.cake.databases.Statement;

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
     * @param mixed $value The value to bind to variable in query
     * @param string|int|null $type PDO type or name of configured Type class
     */
    void bindValue($column, $value, $type = "string") {
        if ($type == null) {
            $type = "string";
        }
        if (!is_int($type)) {
            [$value, $type] = this.cast($value, $type);
        }
        if ($type == PDO::PARAM_LOB) {
            /** @psalm-suppress UndefinedConstant */
            _statement.bindParam($column, $value, $type, 0, PDO::SQLSRV_ENCODING_BINARY);
        } else {
            _statement.bindValue($column, $value, $type);
        }
    }
}
