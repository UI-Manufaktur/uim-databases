module uim.cake.databases;

import uim.cake;

@safe:

enum DriverFeatures: string {
    // Common Table Expressions (with clause) support.
    CTE = "cte",

    // Disabling constraints without being in transaction support.
    DISABLE_CONSTRAINT_WITHOUT_TRANSACTION = "disble-constarint-without-transaction",

    // Native JSON data type support.
    JSON = "json",

    // Transaction savepoint support.
    SAVEPOINT = "Savepoint",

    // Truncate with foreign keys attached support.
    TRUNCATE_WITH_CONSTRAINTS = "truncate-with-constraints",

    // Window auto support (all or partial clauses).
    WINDOW = "window"
}
