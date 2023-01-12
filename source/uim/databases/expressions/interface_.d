/*********************************************************************************************************
	Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        
	License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  
	Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      
**********************************************************************************************************/
module uim.databases.expressions.interface_;

@safe:
import uim.databases;

// An interface used by Expression objects.
interface IDBAExpression {
  // Converts the Node into a SQL string fragment.
  string sql(DDBAValueBinder newValueBinder);

  /**
    * Iterates over each part of the expression recursively for every level of the expressions tree and executes the $callback callable
    * passing as first parameter the instance of the expression currently being iterated.
    *
    * aCallback - The callable to apply to all nodes.
    */
  IDBAExpression traverse(this O)(Closure aCallback);
}
