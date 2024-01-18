module uim.databases.Statement;

import uim.cake;

@safe:

class Statement : IStatement {
    protected const array<string, int> MODE_NAME_MAP = [
        self.FETCH_TYPE_ASSOC: PDO.FETCH_ASSOC,
        self.FETCH_TYPE_NUM: PDO.FETCH_NUM,
        self.FETCH_TYPE_OBJ: PDO.FETCH_OBJ,
    ];

    protected Driver _driver;

    protected PDOStatement $statement;

    protected FieldTypeConverter $typeConverter;

    // Cached bound parameters used for logging
    protected Json $params = [];

    /**
     * @param \PDOStatement $statement PDO statement
     * @param \UIM\Database\Driver $driver Database driver
     * @param \UIM\Database\TypeMap|null $typeMap Results type map
     */
    this(
        PDOStatement $statement,
        Driver $driver,
        ?TypeMap $typeMap = null,
    ) {
       _driver = $driver;
        this.statement = $statement;
        this.typeConverter = $typeMap !isNull ? new FieldTypeConverter($typeMap, $driver): null;
    }
    void bind(array $params, array $types) {
        if (isEmpty($params)) {
            return;
        }
        $anonymousParams = isInt(key($params));
         anOffset = 1;
        foreach ($params as  anIndex: aValue) {
            $type = $types[anIndex] ?? null;
            if ($anonymousParams) {
                /** @psalm-suppress InvalidOperand */
                 anIndex +=  anOffset;
            }
            /** @psalm-suppress PossiblyInvalidArgument */
            this.bindValue(anIndex, aValue, $type);
        }
    }
 
    void bindValue(string|int $column, Json aValue, string|int $type = "string") {
        $type ??= "string";
        if (!isInt($type)) {
            [aValue, $type] = this.castType(aValue, $type);
        }
        this.params[$column] = aValue;
        this.performBind($column, aValue, $type);
    }
    
    /**
     * Converts a give value to a suitable database value based on type and
     * return relevant internal statement type.
     * Params:
     * @param \UIM\Database\IType|string|int $type The type name or type instance to use.
     */
    protected array castType(Json valueToCast, string typeName = "String") {
        IType type;
        if (isString()) {
            type = TypeFactory.build(typeName);
        }
        return castType(Value, type = "String");
    }
    protected array castType(Json valueToCast, IType|string|int $type = "String") {
        if (cast(IType)$type) {
            valueToCast = $type.toDatabase(valueToCast, _driver);
            $type = $type.toStatement(valueToCast, _driver);
        }
        return [valueToCast, $type];
    }
 
    array getBoundParams() {
        return this.params;
    }
    
    protected void performBind(string|int $column, Json aValue, int $type) {
        this.statement.bindValue($column, aValue, $type);
    }
 
    bool execute(array $params = null) {
        return this.statement.execute($params);
    }
 
    Json fetch(string|int $mode = PDO.FETCH_NUM) {
        $mode = this.convertMode($mode);
        $row = this.statement.fetch($mode);
        if ($row == false) {
            return false;
        }
        if (this.typeConverter !isNull) {
            return (this.typeConverter)($row);
        }
        return $row;
    }
 
    array fetchAssoc() {
        return this.fetch(PDO.FETCH_ASSOC) ?: [];
    }
 
    Json fetchColumn(int $position) {
        $row = this.fetch(PDO.FETCH_NUM);
        if ($row && isSet($row[$position])) {
            return $row[$position];
        }
        return false;
    }
 
    array fetchAll(string|int $mode = PDO.FETCH_NUM) {
        $mode = this.convertMode($mode);
        $rows = this.statement.fetchAll($mode);

        if (this.typeConverter !isNull) {
            return array_map(this.typeConverter, $rows);
        }
        return $rows;
    }
    
    /**
     * Converts mode name to PDO constant.
     * Params:
     * string|int $mode Mode name or PDO constant
     */
    protected int convertMode(string|int $mode) {
        if (isInt($mode)) {
            // We don`t try to validate the PDO constants
            return $mode;
        }
        return MODE_NAME_MAP[$mode]
            ??
            throw new InvalidArgumentException("Invalid fetch mode requested. Expected \'assoc\", \'num\' or \'obj\'.");
    }
 
    void closeCursor() {
        this.statement.closeCursor();
    }
 
    int rowCount() {
        return this.statement.rowCount();
    }
 
    int columnCount() {
        return this.statement.columnCount();
    }
 
    string errorCode() {
        return this.statement.errorCode() ?: "";
    }
 
    array errorInfo() {
        return this.statement.errorInfo();
    }
 
    string|int lastInsertId(string atable = null, string acolumn = null) {
        if ($column && this.columnCount()) {
            $row = this.fetch(FETCH_TYPE_ASSOC);

            if ($row && isSet($row[$column])) {
                return $row[$column];
            }
        }
        return _driver.lastInsertId(aTable);
    }
    
    /**
     * Returns prepared query string stored in PDOStatement.
     */
    string queryString() {
        return this.statement.queryString;
    }
}
