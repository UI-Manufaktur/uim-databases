module uim.cake.databases.Expression;

import uim.cake.databases.IExpression;
import uim.cake.databases.ValueBinder;
use Closure;
use RuntimeException;

/**
 * An expression that represents a common table expression definition.
 */
class CommonTableExpression : IExpression
{
    /**
     * The CTE name.
     *
     * @var DDBExpression\IdentifierExpression
     */
    protected $name;

    /**
     * The field names to use for the CTE.
     *
     * @var array<uim.cake.databases.Expression\IdentifierExpression>
     */
    protected $fields = null;

    /**
     * The CTE query definition.
     *
     * @var DDBIExpression|null
     */
    protected $query;

    /**
     * Whether the CTE is materialized or not materialized.
     *
     */
    protected Nullable!string materialized = null;

    /**
     * Whether the CTE is recursive.
     */
    protected bool $recursive = false;

    /**
     * Constructor.
     *
     * @param string aName The CTE name.
     * @param uim.cake.databases.IExpression|\Closure $query CTE query
     */
    this(string aName = "", $query = null) {
        this.name = new IdentifierExpression($name);
        if ($query) {
            this.query($query);
        }
    }

    /**
     * Sets the name of this CTE.
     *
     * This is the named you used to reference the expression
     * in select, insert, etc queries.
     *
     * @param string aName The CTE name.
     * @return this
     */
    function name(string aName) {
        this.name = new IdentifierExpression($name);

        return this;
    }

    /**
     * Sets the query for this CTE.
     *
     * @param uim.cake.databases.IExpression|\Closure $query CTE query
     * @return this
     */
    function query($query) {
        if ($query instanceof Closure) {
            $query = $query();
            if (!($query instanceof IExpression)) {
                throw new RuntimeException(
                    "You must return an `IExpression` from a Closure passed to `query()`."
                );
            }
        }
        this.query = $query;

        return this;
    }

    /**
     * Adds one or more fields (arguments) to the CTE.
     *
     * @param uim.cake.databases.Expression\IdentifierExpression|array<uim.cake.databases.Expression\IdentifierExpression>|array<string>|string $fields Field names
     * @return this
     */
    function field($fields) {
        $fields = (array)$fields;
        foreach ($fields as &$field) {
            if (!($field instanceof IdentifierExpression)) {
                $field = new IdentifierExpression($field);
            }
        }
        this.fields = array_merge(this.fields, $fields);

        return this;
    }

    /**
     * Sets this CTE as materialized.
     *
     * @return this
     */
    function materialized() {
        this.materialized = "MATERIALIZED";

        return this;
    }

    /**
     * Sets this CTE as not materialized.
     *
     * @return this
     */
    function notMaterialized() {
        this.materialized = "NOT MATERIALIZED";

        return this;
    }

    /**
     * Gets whether this CTE is recursive.
     */
    bool isRecursive() {
        return this.recursive;
    }

    /**
     * Sets this CTE as recursive.
     *
     * @return this
     */
    function recursive() {
        this.recursive = true;

        return this;
    }


    string sql(ValueBinder aBinder) {
        $fields = "";
        if (this.fields) {
            $expressions = array_map(function (IdentifierExpression $e) use ($binder) {
                return $e.sql($binder);
            }, this.fields);
            $fields = sprintf("(%s)", implode(", ", $expressions));
        }

        $suffix = this.materialized ? this.materialized ~ " " : "";

        return sprintf(
            "%s%s AS %s(%s)",
            this.name.sql($binder),
            $fields,
            $suffix,
            this.query ? this.query.sql($binder) : ""
        );
    }


    O traverse(this O)(Closure $callback) {
        $callback(this.name);
        foreach (this.fields as $field) {
            $callback($field);
            $field.traverse($callback);
        }

        if (this.query) {
            $callback(this.query);
            this.query.traverse($callback);
        }

        return this;
    }

    /**
     * Clones the inner expression objects.
     */
    void __clone() {
        this.name = clone this.name;
        if (this.query) {
            this.query = clone this.query;
        }

        foreach (this.fields as $key: $field) {
            this.fields[$key] = clone $field;
        }
    }
}
