/*********************************************************************************************************
	Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        
	License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  
	Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      
**********************************************************************************************************/
module uim.databases.expressions;

// This defines the functions used for building window expressions.
interface IWindow {
    /**
     */
    const string PRECEDING = "PRECEDING";

    /**
     */
    const string FOLLOWING = "FOLLOWING";

    /**
     */
    const string RANGE = "RANGE";

    /**
     */
    const string ROWS = "ROWS";

    /**
     */
    const string GROUPS = "GROUPS";

    /**
     * Adds one or more partition expressions to the window.
     *
     * @param uim.databases.IDBAExpression|\Closure|array<uim.databases.IDBAExpression|string>|string $partitions Partition expressions
     * @return this
     */
    function partition($partitions);

    /**
     * Adds one or more order clauses to the window.
     *
     * @param uim.databases.IDBAExpression|\Closure|array<uim.databases.IDBAExpression|string>|string fields Order expressions
     * @return this
     */
    function order(fields);

    /**
     * Adds a simple range frame to the window.
     *
     * `$start`:
     *  - `0` - "CURRENT ROW"
     *  - `null` - "UNBOUNDED PRECEDING"
     *  - offset - "offset PRECEDING"
     *
     * `$end`:
     *  - `0` - "CURRENT ROW"
     *  - `null` - "UNBOUNDED FOLLOWING"
     *  - offset - "offset FOLLOWING"
     *
     * If you need to use "FOLLOWING" with frame start or
     * "PRECEDING" with frame end, use `frame()` instead.
     *
     * @param uim.databases.IDBAExpression|string|int|null $start Frame start
     * @param uim.databases.IDBAExpression|string|int|null $end Frame end
     *  If not passed in, only frame start SQL will be generated.
     * @return this
     */
    function range($start, $end = 0);

    /**
     * Adds a simple rows frame to the window.
     *
     * See `range()` for details.
     *
     * @param int|null $start Frame start
     * @param int|null $end Frame end
     *  If not passed in, only frame start SQL will be generated.
     * @return this
     */
    function rows(Nullable!int $start, Nullable!int $end = 0);

    /**
     * Adds a simple groups frame to the window.
     *
     * See `range()` for details.
     *
     * @param int|null $start Frame start
     * @param int|null $end Frame end
     *  If not passed in, only frame start SQL will be generated.
     * @return this
     */
    function groups(Nullable!int $start, Nullable!int $end = 0);

    /**
     * Adds a frame to the window.
     *
     * Use the `range()`, `rows()` or `groups()` helpers if you need simple
     * "BETWEEN offset PRECEDING and offset FOLLOWING" frames.
     *
     * You can specify any direction for both frame start and frame end.
     *
     * With both `$startOffset` and `$endOffset`:
     *  - `0` - "CURRENT ROW"
     *  - `null` - "UNBOUNDED"
     *
     * @param string type Frame type
     * @param uim.databases.IDBAExpression|string|int|null $startOffset Frame start offset
     * @param string $startDirection Frame start direction
     * @param uim.databases.IDBAExpression|string|int|null $endOffset Frame end offset
     * @param string $endDirection Frame end direction
     * @return this
     * @throws \InvalidArgumentException WHen offsets are negative.
     * @psalm-param self::RANGE|self::ROWS|self::GROUPS type
     * @psalm-param self::PRECEDING|self::FOLLOWING $startDirection
     * @psalm-param self::PRECEDING|self::FOLLOWING $endDirection
     */
    function frame(
        string type,
        $startOffset,
        string $startDirection,
        $endOffset,
        string $endDirection
    );

    /**
     * Adds current row frame exclusion.
     *
     * @return this
     */
    function excludeCurrent();

    /**
     * Adds group frame exclusion.
     *
     * @return this
     */
    function excludeGroup();

    /**
     * Adds ties frame exclusion.
     *
     * @return this
     */
    function excludeTies();
}
