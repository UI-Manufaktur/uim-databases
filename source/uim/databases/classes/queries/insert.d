module source.uim.databases.classes.queries.insert;

import uim.databases;

@safe:

/*
use InvalidArgumentException; */

// This class is used to generate INSERT queries for the relational database.
class InsertQuery : Query {
    mixin(QueryThis!("InsertQuery"));

    override bool initialize(IData[string] initData = null) {
		if (!super.initialize(initData)) { return false; }

    _parts = [
        "comment": null,
        "with": [],
        "insert": [],
        "modifier": [],
        "values": [],
        "epilog": null,
    ];

return true;
    }
    // Type of this query.
    protected string _type = self.TYPE_INSERT;


    /**
     * Create an insert query.
     *
     * Note calling this method will reset any data previously set
     * with Query.values().
     * Params:
     * array columnsToInsert The columns to insert into.
     * @param array<int|string, string> types A map between columns & their datatypes.
     */
    void insert(array columnsToInsert, array types = []) {
        if (isEmpty(columnsToInsert)) {
            throw new InvalidArgumentException("At least 1 column is required to perform an insert.");
        }
       _isDirty();
       _parts["insert"][1] = columnsToInsert;
        if (!_parts["values"]) {
           _parts["values"] = new ValuesExpression(columnsToInsert, this.getTypeMap().setTypes(types));
        } else {
           _parts["values"].setColumns(columnsToInsert);
        }
    }
    
    /**
     * Set the table name for insert queries.
     */
    void into(string tableName) {
       _isDirty();
       _parts["insert"][0] = tableName;
    }
    
    /**
     * Set the values for an insert query.
     *
     * Multi inserts can be performed by calling values() more than one time,
     * or by providing an array of value sets. Additionally someData can be a Query
     * instance to insert data from another SELECT statement.
     * Params:
     * \UIM\Database\Expression\ValuesExpression|\UIM\Database\Query|array data The data to insert.

     * @throws \UIM\Database\Exception\DatabaseException if you try to set values before declaring columns.
     *  Or if you try to set values on non-insert queries.
     */
    void values(ValuesExpression|Query|array data) {
        if (isEmpty(_parts["insert"])) {
            throw new DatabaseException(
                'You cannot add values before defining columns to use.'
            );
        }
       _isDirty();
        if (cast(ValuesExpression)someData) {
           _parts["values"] = someData;

            return;
        }
       _parts["values"].add(someData);
    }
}
