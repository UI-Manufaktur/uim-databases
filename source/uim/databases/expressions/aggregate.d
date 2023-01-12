/*********************************************************************************************************
*	Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        *
*	License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  *
*	Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      *
**********************************************************************************************************/
module uim.expressions.aggregate;

@safe:
import uim.cake;

/**
 * This represents an SQL aggregate function expression in an SQL statement.
 * Calls can be constructed by passing the name of the function and a list of params.
 * For security reasons, all params passed are quoted by default unless
 * explicitly told otherwise.
 */
class AggregateExpression : FunctionExpression : IWindow
{
    /**
     * @var \Cake\Database\Expression\QueryExpression
     */
    protected $filter;

    /**
     * @var \Cake\Database\Expression\WindowExpression
     */
    protected $window;

    /**
     * Adds conditions to the FILTER clause. The conditions are the same format as
     * `Query.where()`.
     *
     * @param uim.databases\IDTBExpression|\Closure|array|string $conditions The conditions to filter on.
     * @param array<string, string> $types Associative array of type names used to bind values to query
     * @return $this
     * @see \Cake\Database\Query.where()
     */
    function filter($conditions, array $types = [])
    {
        if ($this.filter =is null) {
            $this.filter = new QueryExpression();
        }

        if ($conditions instanceof Closure) {
            $conditions = $conditions(new QueryExpression());
        }

        $this.filter.add($conditions, someTypes);

        return $this;
    }

    /**
     * Adds an empty `OVER()` window expression or a named window epression.
     *
     * @param string|null $name Window name
     * @return $this
     */
    function over(?string $name = null)
    {
        if ($this.window =is null) {
            $this.window = new WindowExpression();
        }
        if ($name) {
            // Set name manually in case this was chained from FunctionsBuilder wrapper
            $this.window.name($name);
        }

        return $this;
    }


    function partition($partitions)
    {
        $this.over();
        $this.window.partition($partitions);

        return $this;
    }


    function order($fields)
    {
        $this.over();
        $this.window.order($fields);

        return $this;
    }


    function range($start, $end = 0)
    {
        $this.over();
        $this.window.range($start, $end);

        return $this;
    }


    function rows(?int $start, ?int $end = 0)
    {
        $this.over();
        $this.window.rows($start, $end);

        return $this;
    }


    function groups(?int $start, ?int $end = 0)
    {
        $this.over();
        $this.window.groups($start, $end);

        return $this;
    }


    function frame(
        string $type,
        $startOffset,
        string $startDirection,
        $endOffset,
        string $endDirection
    ) {
        $this.over();
        $this.window.frame($type, $startOffset, $startDirection, $endOffset, $endDirection);

        return $this;
    }


    function excludeCurrent()
    {
        $this.over();
        $this.window.excludeCurrent();

        return $this;
    }


    function excludeGroup()
    {
        $this.over();
        $this.window.excludeGroup();

        return $this;
    }


    function excludeTies()
    {
        $this.over();
        $this.window.excludeTies();

        return $this;
    }


    string sql(ValueBinder aValueBinder)
    {
        mySql = parent.sql($binder);
        if ($this.filter !is null) {
            mySql ~=" FILTER (WHERE" . $this.filter.sql($binder) .")";
        }
        if ($this.window !is null) {
            if ($this.window.isNamedOnly()) {
                mySql ~=" OVER" . $this.window.sql($binder);
            } else {
                mySql ~=" OVER (" . $this.window.sql($binder) .")";
            }
        }

        return mySql;
    }


    O traverse(this O)(Closure $callback)
    {
        parent.traverse($callback);
        if ($this.filter !is null) {
            $callback($this.filter);
            $this.filter.traverse($callback);
        }
        if ($this.window !is null) {
            $callback($this.window);
            $this.window.traverse($callback);
        }

        return $this;
    }


    function count(): int
    {
        $count = parent.count();
        if ($this.window !is null) {
            $count = $count + 1;
        }

        return $count;
    }

    /**
     * Clone this object and its subtree of expressions.
     *
     * @return void
     */
    function __clone()
    {
        parent.__clone();
        if ($this.filter !is null) {
            $this.filter = clone $this.filter;
        }
        if ($this.window !is null) {
            $this.window = clone $this.window;
        }
    }
}
