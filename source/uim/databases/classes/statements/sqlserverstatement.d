module uim.databases.Statement;

import uim.cake;

@safe:

// Statement class meant to be used by an Sqlserver driver
class SqlserverStatement : Statement {

  protected void performBind(string | int $column, Json aValue, int$type) {
    if ($type == PDO.PARAM_LOB) {
      this.statement.bindParam($column, aValue, $type, 0, PDO.SQLSRV_ENCODING_BINARY);
    } else {
      super.performBind($column, aValue, $type);
    }
  }
}
