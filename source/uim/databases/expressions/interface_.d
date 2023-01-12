module uim.databases.expressions.interface_;

@safe:
import uim.databases;

// An interface used by Expression objects.
interface IDBAExpression {
  // Converts the Node into a SQL string fragment.
  // uim.Database\ValueBinder aValueBinder Parameter binder
  string sql(DDTBValueBinder newValueBinder);

  /**
    * Iterates over each part of the expression recursively for every
    * level of the expressions tree and executes the $callback callable
    * passing as first parameter the instance of the expression currently
    * being iterated.
    *
    * @param \Closure $callback The callable to apply to all nodes.
    * @return this
    */
  // O traverse(this O)(Closure $callback);
}
