module uim.cake.databases.schemas;

import uim.cake;

@safe:

/**
 * Represents a single table in a database schema.
 *
 * Can either be populated using the reflection API`s
 * or by incrementally building an instance using
 * methods.
 *
 * Once created TableSchema instances can be added to
 * Schema\Collection objects. They can also be converted into SQL using the
 * createSql(), dropSql() and truncateSql() methods.
 */
class TableSchema : TableISchema, ISqlGenerator {
    // The name of the table
    protected string _table;

    // Columns in the table.
    protected array<string, array> _columns = [];

    // A map with columns to types
    protected STRINGAA _typeMap = [];

    /**
     * indexNames in the table.
     */
    protected array<string, array> _indexNames = [];

    /**
     * Constraints in the table.
     */
    protected IData[string][string] _constraints;

    /**
     * Options for the table.
     */
    protected IData[string] _options = [];

    /**
     * Whether the table is temporary
     */
    protected bool _temporary = false;

    /**
     * Column length when using a `tiny` column type
     */
    const int LENGTH_TINY = 255;

    /**
     * Column length when using a `medium` column type
     */
    const int LENGTH_MEDIUM = 16777215;

    /**
     * Column length when using a `long` column type
     */
    const int LENGTH_LONG = 4294967295;

    /**
     * Valid column length that can be used with text type columns
     *
     * @var array<string, int>
     */
    static array columnLengths = [
        'tiny": self.LENGTH_TINY,
        'medium": self.LENGTH_MEDIUM,
        'long": self.LENGTH_LONG,
    ];

    /**
     * The valid keys that can be used in a column
     * definition.
     */
    protected static IData[string] _columnKeys = [
        "type": null,
        "baseType": null,
        "length": null,
        "precision": null,
        "null": null,
        "default": null,
        "comment": null,
    ];

    // Additional type specific properties.
    protected static Json _columnExtras = [
        "string": [
            'collate": null,
        ],
        "char": [
            'collate": null,
        ],
        "text": [
            'collate": null,
        ],
        "tinyinteger": [
            "unsigned": null,
            "autoIncrement": null,
        ],
        "smallinteger": [
            'unsigned": null,
            'autoIncrement": null,
        ],
        "integer": [
            'unsigned": null,
            'autoIncrement": null,
        ],
        "biginteger": [
            'unsigned": null,
            'autoIncrement": null,
        ],
        'decimal": [
            'unsigned": null,
        ],
        'float": [
            'unsigned": null,
        ],
    ];

    /**
     * The valid keys that can be used in an index
     * definition.
     *
     * @var IData[string]
     */
    protected static array _indexKeys = [
        "type": null,
        "columns": [],
        "length": [],
        "references": [],
        "update": "restrict",
        "delete": "restrict",
    ];

    /**
     * Names of the valid index types.
     *
     * @var string[]
     */
    protected static array _validIndexTypes = [
        self.INDEX_INDEX,
        self.INDEX_FULLTEXT,
    ];

    /**
     * Names of the valid constraint types.
     *
     * @var string[]
     */
    protected static array _validConstraintTypes = [
        self.CONSTRAINT_PRIMARY,
        self.CONSTRAINT_UNIQUE,
        self.CONSTRAINT_FOREIGN,
    ];

    /**
     * Names of the valid foreign key actions.
     */
    protected static string[] _validForeignKeyActions = [
        self.ACTION_CASCADE,
        self.ACTION_SET_NULL,
        self.ACTION_SET_DEFAULT,
        self.ACTION_NO_ACTION,
        self.ACTION_RESTRICT,
    ];

    // Primary constraint type
    const string CONSTRAINT_PRIMARY = "primary";

    // Unique constraint type
    const string CONSTRAINT_UNIQUE = "unique";

    // Foreign constraint type
    const string CONSTRAINT_FOREIGN = "foreign";

    // Index - index type
    const string INDEX_INDEX = "index";

    // Fulltext index type
    const string INDEX_FULLTEXT = "fulltext";

    // Foreign key cascade action
    const string ACTION_CASCADE = "cascade";

    // Foreign key set null action
    const string ACTION_SET_NULL = "SetNull";

    // Foreign key no action
    const string ACTION_NO_ACTION = "noAction";

    // Foreign key restrict action
    const string ACTION_RESTRICT = "restrict";

    // Foreign key restrict default
    const string ACTION_SET_DEFAULT = "SetDefault";

    this(string tableName, string[][string] columns = null) {
       _table = tableName;
        columns.byKeyValue
            .each!(fieldDefinition => this.addColumn(fieldDefinition.key, fieldDefinition.value));
    }
 
    string name() {
        return _table;
    }
 
    void addColumn(string aName, attrs) {
        if (isString($attrs)) {
            attrs = ["type": attrs];
        }
        valid = _columnKeys;
        if (isSet(_columnExtras[$attrs["type"]])) {
            valid += _columnExtras[$attrs["type"]];
        }
        attrs = array_intersect_key($attrs, valid);
       _columns[$name] = attrs + valid;
       _typeMap[$name] = _columns[$name]["type"];
    }
 
    void removeColumn(string aName) {
        unset(_columns[$name], _typeMap[$name]);
    }
 
    array columns() {
        return array_keys(_columns);
    }
 
    array getColumn(string aName) {
        if (!isSet(_columns[$name])) {
            return null;
        }
        column = _columns[$name];
        unset($column["baseType"]);

        return column;
    }
 
    string getColumnType(string aName) {
        if (!_columns.isSet($name)) {
            return null;
        }
        return _columns[$name]["type"];
    }
 
    auto setColumnType(string aName, string atype) {
        if (!isSet(_columns[$name])) {
            return this;
        }
       _columns[$name]["type"] = type;
       _typeMap[$name] = type;

        unset(_columns[$name]["baseType"]);

        return this;
    }
 
    bool hasColumn(string aName) {
        return isSet(_columns[$name]);
    }
 
    string baseColumnType(string acolumn) {
        if (isSet(_columns[$column]["baseType"])) {
            return _columns[$column]["baseType"];
        }
        type = this.getColumnType($column);

        if ($type.isNull) {
            return null;
        }
        if (TypeFactory.getMap($type)) {
            type = TypeFactory.build($type).getBaseType();
        }
        return _columns[$column]["baseType"] = type;
    }
 
    array typeMap() {
        return _typeMap;
    }
 
    bool isNullable(string aName) {
        if (!isSet(_columns[$name])) {
            return true;
        }
        return _columns[$name]["null"] == true;
    }
 
    array defaultValues() {
        IData[string] defaults;
        foreach (_columns as name: someData) {
            if (!array_key_exists("default", someData)) {
                continue;
            }
            if (someData["default"].isNull && someData["null"] != true) {
                continue;
            }
            defaults[$name] = someData["default"];
        }
        return defaults;
    }
 
    auto addIndex(string aName, attrs) {
        if (isString($attrs)) {
            attrs = ["type": attrs];
        }
        attrs = array_intersect_key($attrs, _indexKeys);
        attrs += _indexKeys;
        unset($attrs["references"], attrs["update"], attrs["delete"]);

        if (!in_array($attrs["type"], _validIndexTypes, true)) {
            throw new DatabaseException(
                "Invalid index type `%s` in index `%s` in table `%s`."
                .format($attrs["type"],
                name,
               _table
            ));
        }
        attrs["columns"] = (array)$attrs["columns"];
        foreach ($attrs["columns"] as field) {
            if (isEmpty(_columns[field])) {
                message = 
                    "Columns used in index `%s` in table `%s` must be added to the Table schema first. " ~
                    "The column `%s` was not found."
                    .format($name, _table, field);
                throw new DatabaseException($message);
            }
        }
       _indexNames[$name] = attrs;

        return this;
    }
 
    array indexNames() {
        return array_keys(_indexNames);
    }
 
    auto getIndex(string indexName): array
    {
        if (!isSet(_indexNames[$name])) {
            return null;
        }
        return _indexNames[$name];
    }
 
    array getPrimaryKey() {
        _constraints.each!((someData) {
            if (someData["type"] == CONSTRAINT_PRIMARY) {
                return someData["columns"];
            }
        });
        return null;
    }
 
    auto addConstraint(string aName, attrs) {
        if (isString($attrs)) {
            attrs = ["type": attrs];
        }
        attrs = array_intersect_key($attrs, _indexKeys);
        attrs += _indexKeys;
        if (!in_array($attrs["type"], _validConstraintTypes, true)) {
            throw new DatabaseException(
                "Invalid constraint type `%s` in table `%s`."
                .format($attrs["type"], _table)
            );
        }
        if (isEmpty($attrs["columns"])) {
            throw new DatabaseException(
                "Constraints in table `%s` must have at least one column."
                .format(_table
            ));
        }
        attrs["columns"] = (array)$attrs["columns"];
        foreach ($attrs["columns"] as field) {
            if (isEmpty(_columns[field])) {
                message = "Columns used in constraints must be added to the Table schema first. ' ~
                    "The column `%s` was not found in table `%s`.".format(
                    field,
                   _table
                );
                throw new DatabaseException($message);
            }
        }
        if ($attrs["type"] == CONSTRAINT_FOREIGN) {
            attrs = _checkForeignKey($attrs);

            if (isSet(_constraints[$name])) {
               _constraints[$name]["columns"] = array_unique(chain(
                   _constraints[$name]["columns"],
                    attrs["columns"]
                ));

                if (isSet(_constraints[$name]["references"])) {
                   _constraints[$name]["references"][1] = array_unique(chain(
                        (array)_constraints[$name]["references"][1],
                        [$attrs["references"][1]]
                    ));
                }
                return this;
            }
        } else {
            unset($attrs["references"], attrs["update"], attrs["delete"]);
        }
       _constraints[$name] = attrs;

        return this;
    }
 
    void dropConstraint(string aName) {
        if (isSet(_constraints[$name])) {
            unset(_constraints[$name]);
        }
    }
    
    // Check whether a table has an autoIncrement column defined.
   bool hasAutoincrement() {
        foreach ($column; _columns) {
            if (isSet($column["autoIncrement"]) && column["autoIncrement"]) {
                return true;
            }
        }
        return false;
    }
    
    /**
     * Helper method to check/validate foreign keys.
     * Params:
     * IData[string] attrs Attributes to set.
     */
    protected IData[string] _checkForeignKey(array attrs) {
        if (count($attrs["references"]) < 2) {
            throw new DatabaseException("References must contain a table and column.");
        }
        if (!in_array($attrs["update"], _validForeignKeyActions)) {
            throw new DatabaseException(
                "Update action is invalid. Must be one of %s".format(
                join(",", _validForeignKeyActions)
            ));
        }
        if (!in_array($attrs["delete"], _validForeignKeyActions)) {
            throw new DatabaseException(
                "Delete action is invalid. Must be one of %s"
                .format(join(",", _validForeignKeyActions))
            );
        }
        return attrs;
    }
 
    array constraints() {
        return array_keys(_constraints);
    }
 
    array getConstraint(string aName) {
        return _constraints[$name] ?? null;
    }
 
    auto setOptions(IData[string] options = null) {
       _options = options + _options;

        return this;
    }
 
    array getOptions() {
        return _options;
    }
 
    auto setTemporary(bool temporary) {
       _temporary = temporary;

        return this;
    }
 
    bool isTemporary() {
        return _temporary;
    }
 
    array createSql(Connection aConnection) {
        dialect = aConnection.getDriver().schemaDialect();
        someColumns = constraints =  anIndexes = [];
        foreach (array_keys(_columns) as name) {
            someColumns ~= dialect.columnSql(this, name);
        }
        foreach (array_keys(_constraints) as name) {
            constraints ~= dialect.constraintSql(this, name);
        }
        foreach (array_keys(_indexNames) as name) {
             anIndexes ~= dialect.indexSql(this, name);
        }
        return dialect.createTableSql(this, someColumns, constraints,  anIndexes);
    }
 
    array dropSql(Connection aConnection) {
        dialect = aConnection.getDriver().schemaDialect();

        return dialect.dropTableSql(this);
    }
 
    array truncateSql(Connection aConnection) {
        dialect = aConnection.getDriver().schemaDialect();

        return dialect.truncateTableSql(this);
    }
 
    array addConstraintSql(Connection aConnection) {
        dialect = aConnection.getDriver().schemaDialect();

        return dialect.addConstraintSql(this);
    }
 
    array dropConstraintSql(Connection aConnection) {
        dialect = aConnection.getDriver().schemaDialect();

        return dialect.dropConstraintSql(this);
    }
    
    /**
     * Returns an array of the table schema.
     */
    IData[string] debugInfo() {
        return [
            'table": _table,
            'columns": _columns,
            'indexes": _indexNames,
            'constraints": _constraints,
            'options": _options,
            'typeMap": _typeMap,
            'temporary": _temporary,
        ];
    }
}
