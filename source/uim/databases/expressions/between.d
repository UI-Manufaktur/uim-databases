module uim.databases.expressions.expression;

@safe:
import uim.databases;

/**
 * An expression object that represents a SQL BETWEEN snippet
 */
class BetweenExpression : IExpression, IField {
    use ExpressionTypeCasterTrait;
    use FieldTrait;

    // The first value in the expression
    // @var mixed
    protected DValue _fromValue;

    // The second value in the expression
    // @var mixed
    protected _to;

    // The data type for the from and to arguments
    // @var mixed
    protected _valueDatatype;

    /**
     * Constructor
     *
     * @param \Cake\Database\ExpressionInterface|string $field The field name to compare for values inbetween the range.
     * @param mixed $from The initial value of the range.
     * @param mixed $to The ending value in the comparison range.
     * @param string|null $type The data type name to bind the values with.
     */
    this($field, aFromValue, aToValue, $aValueDatatype = null) {
        if (aValueDatatype !is null) {
            fromValue = _castToExpression($from, $type);
            toValue = _castToExpression($to, $type);
        }

        _field = $field;
        _from = $from;
        _to = $to;
        _type = $type;
    }

    /**
     * @inheritDoc
     */
    public function sql(ValueBinder $binder): string
    {
        $parts = [
            'from' => _from,
            'to' => _to,
        ];

        /** @var \Cake\Database\ExpressionInterface|string $field */
        $field = _field;
        if ($field instanceof ExpressionInterface) {
            $field = $field->sql($binder);
        }

        foreach ($parts as $name => $part) {
            if ($part instanceof ExpressionInterface) {
                $parts[$name] = $part->sql($binder);
                continue;
            }
            $parts[$name] = _bindValue($part, $binder, _type);
        }

        return sprintf('%s BETWEEN %s AND %s', $field, $parts['from'], $parts['to']);
    }

    /**
     * @inheritDoc
     */
    public function traverse(Closure $callback)
    {
        foreach ([_field, _from, _to] as $part) {
            if ($part instanceof ExpressionInterface) {
                $callback($part);
            }
        }

        return $this;
    }

    /**
     * Registers a value in the placeholder generator and returns the generated placeholder
     *
     * @param mixed $value The value to bind
     * @param \Cake\Database\ValueBinder $binder The value binder to use
     * @param string $type The type of $value
     * @return string generated placeholder
     */
    protected function _bindValue($value, $binder, $type): string
    {
        $placeholder = $binder->placeholder('c');
        $binder->bind($placeholder, $value, $type);

        return $placeholder;
    }

    /**
     * Do a deep clone of this expression.
     *
     * @return void
     */
    public function __clone()
    {
        foreach (['_field', '_from', '_to'] as $part) {
            if ($this->{$part} instanceof ExpressionInterface) {
                $this->{$part} = clone $this->{$part};
            }
        }
    }
}
