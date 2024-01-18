module uim.cake.databases;

import uim.cake;

@safe:
// Responsible for compiling a Query object into its SQL representation for SQLite
class SqliteCompiler : QueryCompiler {
  // SQLite does not support ORDER BY in UNION queries.
  protected bool _orderedUnion = false;
}
