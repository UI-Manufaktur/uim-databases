/*********************************************************************************************************
*	Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        *
*	License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  *
*	Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      *
**********************************************************************************************************/
module uim.cake;

@safe:
import uim.cake;

/**
 * This represents a SQL window expression used by aggregate and window functions.
 */
class WindowExpression : ExpressionInterface, WindowInterface
{
    /**
     * @var \Cake\Database\Expression\IdentifierExpression
     */
    protected $name;

    /**
     * @var array<\Cake\Database\ExpressionInterface>
     */
    protected $partitions = [];

    /**
     * @var \Cake\Database\Expression\OrderByExpression|null
     */
    protected $order;

    /**
     * @var array|null
     */
    protected $frame;

    /**
     * @var string|null
     */
    protected $exclusion;

    /**
     * @param string $name Window name
     */
    function __construct(string $name ="")
    {
        $this.name = new IdentifierExpression($name);
    }

    /**
     * Return whether is only a named window expression.
     *
     * These window expressions only specify a named window and do not
     * specify their own partitions, frame or order.
     *
     * @return bool
     */
    function isNamedOnly(): bool
    {
        return $this.name.getIdentifier() && (!$this.partitions && !$this.frame && !$this.order);
    }

    /**
     * Sets the window name.
     *
     * @param string $name Window name
     * @return $this
     */
    function name(string $name)
    {
        $this.name = new IdentifierExpression($name);

        return $this;
    }


    function partition($partitions)
    {
        if (!$partitions) {
            return $this;
        }

        if ($partitions instanceof Closure) {
            $partitions = $partitions(new QueryExpression([], [],""));
        }

        if (!is_array($partitions)) {
            $partitions = [$partitions];
        }

        foreach ($partitions as &$partition) {
            if (is_string($partition)) {
                $partition = new IdentifierExpression($partition);
            }
        }

        $this.partitions = array_merge($this.partitions, $partitions);

        return $this;
    }


    function order($fields)
    {
        if (!$fields) {
            return $this;
        }

        if ($this.order =is null) {
            $this.order = new OrderByExpression();
        }

        if ($fields instanceof Closure) {
            $fields = $fields(new QueryExpression([], [],""));
        }

        $this.order.add($fields);

        return $this;
    }


    function range($start, $end = 0)
    {
        return $this.frame(self::RANGE, $start, self::PRECEDING, $end, self::FOLLOWING);
    }


    function rows(?int $start, ?int $end = 0)
    {
        return $this.frame(self::ROWS, $start, self::PRECEDING, $end, self::FOLLOWING);
    }


    function groups(?int $start, ?int $end = 0)
    {
        return $this.frame(self::GROUPS, $start, self::PRECEDING, $end, self::FOLLOWING);
    }


    function frame(
        string $type,
        $startOffset,
        string $startDirection,
        $endOffset,
        string $endDirection
    ) {
        $this.frame = [
           "type": $type,
           "start": [
               "offset": $startOffset,
               "direction": $startDirection,
            ],
           "end": [
               "offset": $endOffset,
               "direction": $endDirection,
            ],
        ];

        return $this;
    }


    function excludeCurrent()
    {
        $this.exclusion ="CURRENT ROW";

        return $this;
    }


    function excludeGroup()
    {
        $this.exclusion ="GROUP";

        return $this;
    }


    function excludeTies()
    {
        $this.exclusion ="TIES";

        return $this;
    }


    string sql(ValueBinder $binder)
    {
        $clauses = [];
        if ($this.name.getIdentifier()) {
            $clauses[] = $this.name.sql($binder);
        }

        if ($this.partitions) {
            $expressions = [];
            foreach ($this.partitions as $partition) {
                $expressions[] = $partition.sql($binder);
            }

            $clauses[] ="PARTITION BY" . implode(",", $expressions);
        }

        if ($this.order) {
            $clauses[] = $this.order.sql($binder);
        }

        if ($this.frame) {
            $start = $this.buildOffsetSql(
                $binder,
                $this.frame["start"]["offset"],
                $this.frame["start"]["direction"]
            );
            $end = $this.buildOffsetSql(
                $binder,
                $this.frame["end"]["offset"],
                $this.frame["end"]["direction"]
            );

            $frameSql = sprintf("%s BETWEEN %s AND %s", $this.frame["type"], $start, $end);

            if ($this.exclusion !is null) {
                $frameSql .=" EXCLUDE" . $this.exclusion;
            }

            $clauses[] = $frameSql;
        }

        return implode("", $clauses);
    }


    function traverse(Closure $callback)
    {
        $callback($this.name);
        foreach ($this.partitions as $partition) {
            $callback($partition);
            $partition.traverse($callback);
        }

        if ($this.order) {
            $callback($this.order);
            $this.order.traverse($callback);
        }

        if ($this.frame !is null) {
            $offset = $this.frame["start"]["offset"];
            if ($offset instanceof ExpressionInterface) {
                $callback($offset);
                $offset.traverse($callback);
            }
            $offset = $this.frame["end"]["offset"] ?? null;
            if ($offset instanceof ExpressionInterface) {
                $callback($offset);
                $offset.traverse($callback);
            }
        }

        return $this;
    }

    /**
     * Builds frame offset sql.
     *
     * @param \Cake\Database\ValueBinder $binder Value binder
     * @param \Cake\Database\ExpressionInterface|string|int|null $offset Frame offset
     * @param string $direction Frame offset direction
     * @return string
     */
    protected string buildOffsetSql(ValueBinder $binder, $offset, string $direction)
    {
        if ($offset === 0) {
            return"CURRENT ROW";
        }

        if ($offset instanceof ExpressionInterface) {
            $offset = $offset.sql($binder);
        }

        return sprintf(
           "%s %s",
            $offset ??"UNBOUNDED",
            $direction
        );
    }

    /**
     * Clone this object and its subtree of expressions.
     *
     * @return void
     */
    function __clone()
    {
        $this.name = clone $this.name;
        foreach ($this.partitions as $i: $partition) {
            $this.partitions[$i] = clone $partition;
        }
        if ($this.order !is null) {
            $this.order = clone $this.order;
        }
    }
}
