module uim.cake.databases.Expression;

import uim.cake.databases.exceptions.DatabaseException;
import uim.cake.databases.IExpression;
import uim.cake.databases.Query;
import uim.cake.databases.types.ExpressionTypeCasterTrait;
import uim.cake.databases.TypeMap;
import uim.cake.databases.TypeMapTrait;
import uim.cake.databases.ValueBinder;
use Closure;

/**
 * An expression object to contain values being inserted.
 *
 * Helps generate SQL with the correct number of placeholders and bind
 * values correctly into the statement.
 */
class ValuesExpression : IExpression {
    use ExpressionTypeCasterTrait;
    use TypeMapTrait;

    /**
     * Array of values to insert.
     *
     * @var array
     */
    protected _values = null;

    /**
     * List of columns to ensure are part of the insert.
     *
     * @var array
     */
    protected _columns = null;

    /**
     * The Query object to use as a values expression
     *
     * @var DDBQuery|null
     */
    protected _query;

    /**
     * Whether values have been casted to expressions
     * already.
     */
    protected bool _castedExpressions = false;

    /**
     * Constructor
     *
     * @param array $columns The list of columns that are going to be part of the values.
     * @param uim.cake.databases.TypeMap $typeMap A dictionary of column . type names
     */
    this(array $columns, TypeMap $typeMap) {
        _columns = $columns;
        this.setTypeMap($typeMap);
    }

    /**
     * Add a row of data to be inserted.
     *
     * @param uim.cake.databases.Query|array $values Array of data to append into the insert, or
     *   a query for doing INSERT INTO .. SELECT style commands
     * @return void
     * @throws uim.cake.databases.exceptions.DatabaseException When mixing array + Query data types.
     */
    void add($values) {
        if (
            (
                count(_values) &&
                $values instanceof Query
            ) ||
            (
                _query &&
                is_array($values)
            )
        ) {
            throw new DatabaseException(
                "You cannot mix subqueries and array values in inserts."
            );
        }
        if ($values instanceof Query) {
            this.setQuery($values);

            return;
        }
        _values[] = $values;
        _castedExpressions = false;
    }

    /**
     * Sets the columns to be inserted.
     *
     * @param array $columns Array with columns to be inserted.
     * @return this
     */
    function setColumns(array $columns) {
        _columns = $columns;
        _castedExpressions = false;

        return this;
    }

    /**
     * Gets the columns to be inserted.
     */
    array getColumns() {
        return _columns;
    }

    /**
     * Get the bare column names.
     *
     * Because column names could be identifier quoted, we
     * need to strip the identifiers off of the columns.
     *
     */
    protected array _columnNames() {
        $columns = null;
        foreach (_columns as $col) {
            if (is_string($col)) {
                $col = trim($col, "`[]"");
            }
            $columns[] = $col;
        }

        return $columns;
    }

    /**
     * Sets the values to be inserted.
     *
     * @param array $values Array with values to be inserted.
     * @return this
     */
    function setValues(array $values) {
        _values = $values;
        _castedExpressions = false;

        return this;
    }

    /**
     * Gets the values to be inserted.
     */
    array getValues() {
        if (!_castedExpressions) {
            _processExpressions();
        }

        return _values;
    }

    /**
     * Sets the query object to be used as the values expression to be evaluated
     * to insert records in the table.
     *
     * @param uim.cake.databases.Query $query The query to set
     * @return this
     */
    function setQuery(Query $query) {
        _query = $query;

        return this;
    }

    /**
     * Gets the query object to be used as the values expression to be evaluated
     * to insert records in the table.
     *
     * @return uim.cake.databases.Query|null
     */
    function getQuery(): ?Query
    {
        return _query;
    }


    string sql(ValueBinder aBinder) {
        if (empty(_values) && empty(_query)) {
            return "";
        }

        if (!_castedExpressions) {
            _processExpressions();
        }

        $columns = _columnNames();
        $defaults = array_fill_keys($columns, null);
        $placeholders = null;

        $types = null;
        $typeMap = this.getTypeMap();
        foreach ($defaults as $col: $v) {
            $types[$col] = $typeMap.type($col);
        }

        foreach (_values as $row) {
            $row += $defaults;
            $rowPlaceholders = null;

            foreach ($columns as $column) {
                $value = $row[$column];

                if ($value instanceof IExpression) {
                    $rowPlaceholders[] = "(" ~ $value.sql($binder) ~ ")";
                    continue;
                }

                $placeholder = $binder.placeholder("c");
                $rowPlaceholders[] = $placeholder;
                $binder.bind($placeholder, $value, $types[$column]);
            }

            $placeholders[] = implode(", ", $rowPlaceholders);
        }

        $query = this.getQuery();
        if ($query) {
            return " " ~ $query.sql($binder);
        }

        return sprintf(" VALUES (%s)", implode("), (", $placeholders));
    }


    O traverse(this O)(Closure $callback) {
        if (_query) {
            return this;
        }

        if (!_castedExpressions) {
            _processExpressions();
        }

        foreach (_values as $v) {
            if ($v instanceof IExpression) {
                $v.traverse($callback);
            }
            if (!is_array($v)) {
                continue;
            }
            foreach ($v as $field) {
                if ($field instanceof IExpression) {
                    $callback($field);
                    $field.traverse($callback);
                }
            }
        }

        return this;
    }

    /**
     * Converts values that need to be casted to expressions
     */
    protected void _processExpressions() {
        $types = null;
        $typeMap = this.getTypeMap();

        $columns = _columnNames();
        foreach ($columns as $c) {
            if (!is_string($c) && !is_int($c)) {
                continue;
            }
            $types[$c] = $typeMap.type($c);
        }

        $types = _requiresToExpressionCasting($types);

        if (empty($types)) {
            return;
        }

        foreach (_values as $row: $values) {
            foreach ($types as $col: $type) {
                /** @var DDBtypes.ExpressionTypeInterface $type */
                _values[$row][$col] = $type.toExpression($values[$col]);
            }
        }
        _castedExpressions = true;
    }
}
