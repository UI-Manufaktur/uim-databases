module source.uim.databases.classes.queries.delete;

import uim.databases;

@safe:

// This class is used to generate DELETE queries for the relational database.
class DeleteQuery : Query {
    mixin(QueryThis!("DeleteQuery"));

    override bool initialize(IData[string] initData = null) {
		if (!super.initialize(initData)) { return false; }

    // List of SQL parts that will be used to build this query.
    _parts = [
        "comment": null,
        "with": [],
        "delete": true,
        "modifier": [],
        "from": [],
        "join": [],
        "where": null,
        "order": null,
        "limit": null,
        "epilog": null,
    ];

return true;
    }
    // Type of this query.
    protected string _type = self.TYPE_DELETE;

    /**
     * Create a delete query.
     *
     * Can be combined with from(), where() and other methods to
     * create delete queries with specific conditions.
     */
    void delete(string tableName = null) {
       _isDirty();
        if (!tableName.isNull) {
            this.from(tableName);
        }
    }
}
