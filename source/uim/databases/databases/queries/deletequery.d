module uim.cake.databases.Query;

import uim.cake;

@safe:

// This class is used to generate DELETE queries for the relational database.
class DeleteQuery : Query {
    // Type of this query.
    protected string _type = self.TYPE_DELETE;

    // List of SQL parts that will be used to build this query.
    protected IData[string] _parts = [
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

    /**
     * Create a delete query.
     *
     * Can be combined with from(), where() and other methods to
     * create delete queries with specific conditions.
     * Params:
     * string aTable The table to use when deleting.
     */
    void delete(string atable = null) {
       _isDirty();
        if (!aTable.isNull) {
            this.from(aTable);
        }
    }
}
