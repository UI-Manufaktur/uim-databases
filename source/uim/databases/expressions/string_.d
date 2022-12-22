/*********************************************************************************************************
*	Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        *
*	License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  *
*	Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      *
**********************************************************************************************************/
module uim.cake.expressions.string_;

@safe:
import uim.cake;

/**
 * String expression with collation.
 */
class StringExpression : ExpressionInterface
{
    /**
     * @var string
     */
    protected $string;

    /**
     * @var string
     */
    protected $collation;

    /**
     * @param string $string String value
     * @param string $collation String collation
     */
    function __construct(string $string, string $collation)
    {
        $this.string = $string;
        $this.collation = $collation;
    }

    /**
     * Sets the string collation.
     *
     * @param string $collation String collation
     * @return void
     */
    function setCollation(string $collation): void
    {
        $this.collation = $collation;
    }

    /**
     * Returns the string collation.
     *
     * @return string
     */
    string getCollation()
    {
        return $this.collation;
    }


    string sql(ValueBinder $binder)
    {
        $placeholder = $binder.placeholder("c");
        $binder.bind($placeholder, $this.string,"string");

        return $placeholder ." COLLATE" . $this.collation;
    }


    function traverse(Closure $callback)
    {
        return $this;
    }
}
