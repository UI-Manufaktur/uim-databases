module uim.databases.compilers.sqlite.compiler;

@safe:
import uim.databases;

// Responsible for compiling a Query object into its SQL representation
class SqliteCompiler : QueryCompiler {
    // SQLite does not support ORDER BY in UNION queries.
    protected bool _orderedUnion = false;
}
