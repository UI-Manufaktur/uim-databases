/*********************************************************************************************************
*	Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        *
*	License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  *
*	Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      *
**********************************************************************************************************/
module uim.cake;

@safe:
import uim.cake;
/**
 * An expression object that represents an expression with only a single operand.
 */
class UnaryExpression : ExpressionInterface
{
    /**
     * Indicates that the operation is in pre-order
     *
     * @var int
     */
    public const PREFIX = 0;

    /**
     * Indicates that the operation is in post-order
     *
     * @var int
     */
    public const POSTFIX = 1;

    /**
     * The operator this unary expression represents
     *
     * @var string
     */
    protected $_operator;

    /**
     * Holds the value which the unary expression operates
     *
     * @var mixed
     */
    protected $_value;

    /**
     * Where to place the operator
     *
     * @var int
     */
    protected $position;

    /**
     * Constructor
     *
     * @param string $operator The operator to used for the expression
     * @param mixed $value the value to use as the operand for the expression
     * @param int $position either UnaryExpression::PREFIX or UnaryExpression::POSTFIX
     */
    function __construct(string $operator, $value, $position = self::PREFIX)
    {
        _operator = $operator;
        _value = $value;
        $this.position = $position;
    }

    /**
     * @inheritDoc
     */
    function sql(ValueBinder $binder): string
    {
        $operand = _value;
        if ($operand instanceof ExpressionInterface) {
            $operand = $operand.sql($binder);
        }

        if ($this.position === self::POSTFIX) {
            return"(" . $operand .")" . _operator;
        }

        return _operator ." (" . $operand .")";
    }

    /**
     * @inheritDoc
     */
    function traverse(Closure $callback)
    {
        if (_value instanceof ExpressionInterface) {
            $callback(_value);
            _value.traverse($callback);
        }

        return $this;
    }

    /**
     * Perform a deep clone of the inner expression.
     *
     * @return void
     */
    function __clone()
    {
        if (_value instanceof ExpressionInterface) {
            _value = clone _value;
        }
    }
}
