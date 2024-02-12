module uim.databases.Statement;

@safe:
import uim.databases;

/**
 * Statement class meant to be used by an Sqlite driver
 *
 * @internal
 */
class SqliteStatement : StatementDecorator
{
    use BufferResultsTrait;


    function execute(?array params = null): bool
    {
        if (this._statement instanceof BufferedStatement) {
            this._statement = this._statement.getInnerStatement();
        }

        if (this._bufferResults) {
            this._statement = new BufferedStatement(this._statement, this._driver);
        }

        return this._statement.execute(params);
    }

    /**
     * Returns the number of rows returned of affected by last execution
     *
     * @return int
     */
    function rowCount(): int
    {
        /** @psalm-suppress NoInterfaceProperties */
        if (
            this._statement.queryString &&
            preg_match("/^(?:DELETE|UPDATE|INSERT)/i", this._statement.queryString)
        ) {
            changes = this._driver.prepare("SELECT CHANGES()");
            changes.execute();
            aRow = changes.fetch();
            changes.closeCursor();

            if (!aRow) {
                return 0;
            }

            return (int)aRow[0];
        }

        return parent::rowCount();
    }
}
