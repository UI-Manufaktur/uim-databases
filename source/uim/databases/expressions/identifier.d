/*********************************************************************************************************
*	Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        *
*	License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  *
*	Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      *
**********************************************************************************************************/
module uim.cake;

@safe:
import uim.cake;

/**
 * Represents a single identifier name in the database.
 *
 * Identifier values are unsafe with user supplied data.
 * Values will be quoted when identifier quoting is enabled.
 *
 * @see \Cake\Database\Query::identifier()
 */
class IdentifierExpression implements ExpressionInterface
{
    /**
     * Holds the identifier string
     *
     * @var string
     */
    protected $_identifier;

    /**
     * @var string|null
     */
    protected $collation;

    /**
     * Constructor
     *
     * @param string $identifier The identifier this expression represents
     * @param string|null $collation The identifier collation
     */
    function __construct(string $identifier, ?string $collation = null)
    {
        _identifier = $identifier;
        $this.collation = $collation;
    }

    /**
     * Sets the identifier this expression represents
     *
     * @param string $identifier The identifier
     * @return void
     */
    function setIdentifier(string $identifier): void
    {
        _identifier = $identifier;
    }

    /**
     * Returns the identifier this expression represents
     *
     * @return string
     */
    function getIdentifier(): string
    {
        return _identifier;
    }

    /**
     * Sets the collation.
     *
     * @param string $collation Identifier collation
     * @return void
     */
    function setCollation(string $collation): void
    {
        $this.collation = $collation;
    }

    /**
     * Returns the collation.
     *
     * @return string|null
     */
    function getCollation(): ?string
    {
        return $this.collation;
    }

    /**
     * @inheritDoc
     */
    function sql(ValueBinder $binder): string
    {
        $sql = _identifier;
        if ($this.collation) {
            $sql .=" COLLATE" . $this.collation;
        }

        return $sql;
    }

    /**
     * @inheritDoc
     */
    function traverse(Closure $callback)
    {
        return $this;
    }
}
