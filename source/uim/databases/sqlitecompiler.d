module uim.databases;

@safe:
import uim.databases;

/**
 * Responsible for compiling a Query object into its SQL representation
 * for SQLite
 *
 * @internal
 */
class SqliteCompiler : QueryCompiler
{
    /**
     * SQLite does not support ORDER BY in UNION queries.
     *
     * @var bool
     */
    protected _orderedUnion = false;
}
