module uim.databases.classes.compilers.sqlite;

import uim.databases;

@safe:
// Responsible for compiling a Query object into its SQL representation for SQLite
class SqliteCompiler : QueryCompiler {
  // SQLite does not support ORDER BY in UNION queries.
  protected bool _orderedUnion = false;
}
