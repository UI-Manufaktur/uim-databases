/*********************************************************************************************************
	Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        
	License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  
	Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      
**********************************************************************************************************/
module uim.databases.compilers.sqlite.compiler;

@safe:
import uim.databases;

// Responsible for compiling a Query object into its SQL representation
class SqliteCompiler : QueryCompiler {
    // SQLite does not support ORDER BY in UNION queries.
    protected bool _orderedUnion = false;
}
