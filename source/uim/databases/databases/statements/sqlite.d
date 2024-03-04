module source.uim.cake.databases.statements.sqlite;

import uim.cake;

@safe:

// Statement class meant to be used by an Sqlite driver
class SqliteStatement : Statement {
    protected  int affectedRows = null;

    bool execute(array myparams = null) {
        this.affectedRows = null;

        return super.execute(params);
    }

    size_t rowCount() {
        if (!this.affectedRows.isNull) {
            return this.affectedRows;
        }
        if (
            this.statement.queryString &&
            preg_match("/^(?:DELETE|UPDATE|INSERT)/i", this.statement.queryString)
            ) {
            auto changes = _driver.prepare("SELECT CHANGES()");
            changes.execute();
            
            auto row = changes.fetch();
            this.affectedRows = row ? (int)$row[0] : 0;
        } else {
            this.affectedRows = super.rowCount();
        }
        return this.affectedRows;
    }
}
