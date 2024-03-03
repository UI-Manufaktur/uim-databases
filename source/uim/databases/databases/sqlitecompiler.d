module uim.cake.databases;

import uim.cake;

@safe:
// Responsible for compiling a Query object into its SQL representation for SQLite
class SqliteCompiler : QueryCompiler {
  	override bool initialize(IData[string] initData = null) {
		if (!super.initialize(initData)) { return false; }
		
		return true;
	}

  // SQLite does not support ORDER BY in UNION queries.
  protected bool _orderedUnion = false;
}
