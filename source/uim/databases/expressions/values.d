/*********************************************************************************************************
*	Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        *
*	License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  *
*	Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      *
**********************************************************************************************************/
module uim.cake;

@safe:
import uim.cake;

/**
 * An expression object to contain values being inserted.
 *
 * Helps generate SQL with the correct number of placeholders and bind
 * values correctly into the statement.
 */
class ValuesExpression : IDTBExpression
{
    use ExpressionTypeCasterTrait;
    use TypeMapTrait;

    /**
     * Array of values to insert.
     *
     * @var array
     */
    protected $_values = [];

    /**
     * List of columns to ensure are part of the insert.
     *
     * @var array
     */
    protected $_columns = [];

    /**
     * The Query object to use as a values expression
     *
     * @var \Cake\Database\Query|null
     */
    protected $_query;

    /**
     * Whether values have been casted to expressions
     * already.
     *
     * @var bool
     */
    protected $_castedExpressions = false;

    /**
     * Constructor
     *
     * @param array $columns The list of columns that are going to be part of the values.
     * @param uim.databases\TypeMap $typeMap A dictionary of column . type names
     */
    this(array $columns, TypeMap $typeMap)
    {
        _columns = $columns;
        $this.setTypeMap($typeMap);
    }

    /**
     * Add a row of data to be inserted.
     *
     * @param uim.databases\Query|array someValues Array of data to append into the insert, or
     *   a query for doing INSERT INTO .. SELECT style commands
     * @return void
     * @throws \Cake\Database\Exception\DatabaseException When mixing array + Query data types.
     */
    function add(someValues): void
    {
        if (
            (
                count(_values) &&
                someValues instanceof Query
            ) ||
            (
                _query &&
                is_array(someValues)
            )
        ) {
            throw new DatabaseException(
               "You cannot mix subqueries and array values in inserts."
            );
        }
        if (someValues instanceof Query) {
            $this.setQuery(someValues);

            return;
        }
        _values[] = someValues;
        _castedExpressions = false;
    }

    /**
     * Sets the columns to be inserted.
     *
     * @param array $columns Array with columns to be inserted.
     * @return $this
     */
    function setColumns(array $columns)
    {
        _columns = $columns;
        _castedExpressions = false;

        return $this;
    }

    /**
     * Gets the columns to be inserted.
     *
     * @return array
     */
    function getColumns(): array
    {
        return _columns;
    }

    /**
     * Get the bare column names.
     *
     * Because column names could be identifier quoted, we
     * need to strip the identifiers off of the columns.
     *
     * @return array
     */
    protected function _columnNames(): array
    {
        $columns = [];
        foreach (_columns as $col) {
            if (is_string($col)) {
                $col = trim($col,"`[]"");
            }
            $columns[] = $col;
        }

        return $columns;
    }

    /**
     * Sets the values to be inserted.
     *
     * @param array someValues Array with values to be inserted.
     * @return $this
     */
    function setValues(array someValues)
    {
        _values = someValues;
        _castedExpressions = false;

        return $this;
    }

    /**
     * Gets the values to be inserted.
     *
     * @return array
     */
    function getValues(): array
    {
        if (!_castedExpressions) {
            _processExpressions();
        }

        return _values;
    }

    /**
     * Sets the query object to be used as the values expression to be evaluated
     * to insert records in the table.
     *
     * @param uim.databases\Query $query The query to set
     * @return $this
     */
    function setQuery(Query $query)
    {
        _query = $query;

        return $this;
    }

    /**
     * Gets the query object to be used as the values expression to be evaluated
     * to insert records in the table.
     *
     * @return \Cake\Database\Query|null
     */
    function getQuery(): ?Query
    {
        return _query;
    }


    string sql(ValueBinder aValueBinder)
    {
        if (empty(_values) && empty(_query)) {
            return"";
        }

        if (!_castedExpressions) {
            _processExpressions();
        }

        $columns = _columnNames();
        $defaults = array_fill_keys($columns, null);
        $placeholders = [];

        $types = [];
        $typeMap = $this.getTypeMap();
        foreach ($defaults as $col: $v) {
            $types[$col] = $typeMap.type($col);
        }

        foreach (_values as $row) {
            $row += $defaults;
            $rowPlaceholders = [];

            foreach ($columns as $column) {
                aValue = $row[$column];

                if (aValue instanceof IDTBExpression) {
                    $rowPlaceholders[] ="(" . aValue.sql($binder) .")";
                    continue;
                }

                $placeholder = $binder.placeholder("c");
                $rowPlaceholders[] = $placeholder;
                $binder.bind($placeholder, DValue aValue, $types[$column]);
            }

            $placeholders[] = implode(",", $rowPlaceholders);
        }

        $query = $this.getQuery();
        if ($query) {
            return"" . $query.sql($binder);
        }

        return sprintf(" VALUES (%s)", implode("), (", $placeholders));
    }


    O traverse(this O)(Closure $callback)
    {
        if (_query) {
            return $this;
        }

        if (!_castedExpressions) {
            _processExpressions();
        }

        foreach (_values as $v) {
            if ($v instanceof IDTBExpression) {
                $v.traverse($callback);
            }
            if (!is_array($v)) {
                continue;
            }
            foreach ($v as $field) {
                if ($field instanceof IDTBExpression) {
                    $callback($field);
                    $field.traverse($callback);
                }
            }
        }

        return $this;
    }

    /**
     * Converts values that need to be casted to expressions
     *
     * @return void
     */
    protected function _processExpressions(): void
    {
        $types = [];
        $typeMap = $this.getTypeMap();

        $columns = _columnNames();
        foreach ($columns as $c) {
            if (!is_string($c) && !isInt($c)) {
                continue;
            }
            $types[$c] = $typeMap.type($c);
        }

        $types = _requiresToExpressionCasting($types);

        if (empty($types)) {
            return;
        }

        foreach (_values as $row: someValues) {
            foreach ($types as $col: $type) {
                /** @var \Cake\Database\Type\ExpressionTypeInterface $type */
                _values[$row][$col] = $type.toExpression(someValues[$col]);
            }
        }
        _castedExpressions = true;
    }
}
