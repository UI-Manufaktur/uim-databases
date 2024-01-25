module uim.cake.databases;

import uim.cake;

@safe:
// Responsible for compiling a Query object into its SQL representation for SQLite
class SqliteCompiler : QueryCompiler {
  	override bool initialize(IConfigData[string] configData = null) {
		if (!super.initialize(configData)) { return false; }
		
		return true;
	}

  // SQLite does not support ORDER BY in UNION queries.
  protected bool _orderedUnion = false;
}
