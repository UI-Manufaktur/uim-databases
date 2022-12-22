/*********************************************************************************************************
*	Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        *
*	License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  *
*	Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      *
**********************************************************************************************************/
module uim.cake;

@safe:
import uim.cake;

/**
 * This class represents a function call string in a SQL statement. Calls can be
 * constructed by passing the name of the function and a list of params.
 * For security reasons, all params passed are quoted by default unless
 * explicitly told otherwise.
 */
class FunctionExpression extends QueryExpression : IDTBTypedResult
{
    use ExpressionTypeCasterTrait;
    use TypedResultTrait;

    /**
     * The name of the function to be constructed when generating the SQL string
     *
     * @var string
     */
    protected $_name;

    /**
     * Constructor. Takes a name for the function to be invoked and a list of params
     * to be passed into the function. Optionally you can pass a list of types to
     * be used for each bound param.
     *
     * By default, all params that are passed will be quoted. If you wish to use
     * literal arguments, you need to explicitly hint this function.
     *
     * ### Examples:
     *
     * `$f = new FunctionExpression("CONCAT", ["CakePHP"," rules"]);`
     *
     * Previous line will generate `CONCAT("CakePHP"," rules")`
     *
     * `$f = new FunctionExpression("CONCAT", ["name":"literal"," rules"]);`
     *
     * Will produce `CONCAT(name," rules")`
     *
     * @param string $name the name of the function to be constructed
     * @param array $params list of arguments to be passed to the function
     * If associative the key would be used as argument when value is"literal"
     * @param array<string, string>|array<string|null> $types Associative array of types to be associated with the
     * passed arguments
     * @param string $returnType The return type of this expression
     */
    this(string $name, array $params = [], array $types = [], string $returnType ="string")
    {
        _name = $name;
        _returnType = $returnType;
        parent::__construct($params, $types,",");
    }

    /**
     * Sets the name of the SQL function to be invoke in this expression.
     *
     * @param string $name The name of the function
     * @return $this
     */
    function setName(string $name)
    {
        _name = $name;

        return $this;
    }

    /**
     * Gets the name of the SQL function to be invoke in this expression.
     *
     * @return string
     */
    string getName()
    {
        return _name;
    }

    /**
     * Adds one or more arguments for the function call.
     *
     * @param array $conditions list of arguments to be passed to the function
     * If associative the key would be used as argument when value is"literal"
     * @param array<string, string> $types Associative array of types to be associated with the
     * passed arguments
     * @param bool $prepend Whether to prepend or append to the list of arguments
     * @see \Cake\Database\Expression\FunctionExpression::__construct() for more details.
     * @return $this
     * @psalm-suppress MoreSpecificImplementedParamType
     */
    function add($conditions, array $types = [], bool $prepend = false)
    {
        $put = $prepend ?"array_unshift" :"array_push";
        $typeMap = $this.getTypeMap().setTypes($types);
        foreach ($conditions as $k: $p) {
            if ($p =="literal") {
                $put(_conditions, $k);
                continue;
            }

            if ($p =="identifier") {
                $put(_conditions, new IdentifierExpression($k));
                continue;
            }

            $type = $typeMap.type($k);

            if ($type !is null && !$p instanceof IDTBExpression) {
                $p = _castToExpression($p, $type);
            }

            if ($p instanceof IDTBExpression) {
                $put(_conditions, $p);
                continue;
            }

            $put(_conditions, ["value": $p,"type": $type]);
        }

        return $this;
    }


    string sql(ValueBinder aValueBinder) {
        $parts = [];
        foreach (_conditions as $condition) {
            if ($condition instanceof Query) {
                $condition = sprintf("(%s)", $condition.sql($binder));
            } elseif ($condition instanceof IDTBExpression) {
                $condition = $condition.sql($binder);
            } elseif (is_array($condition)) {
                $p = $binder.placeholder("param");
                $binder.bind($p, $condition["value"], $condition["type"]);
                $condition = $p;
            }
            $parts[] = $condition;
        }

        return _name . sprintf("(%s)", implode(
            _conjunction ."",
            $parts
        ));
    }

    /**
     * The name of the function is in itself an expression to generate, thus
     * always adding 1 to the amount of expressions stored in this object.
     *
     * @return int
     */
    function count(): int
    {
        return 1 + count(_conditions);
    }
}
