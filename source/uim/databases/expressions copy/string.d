module uim.databases.Expression;

import uim.databases.IDBAExpression;
import uim.databases.ValueBinder;
use Closure;

/**
 * String expression with collation.
 */
class StringExpression : IDBAExpression
{
    /**
     */
    protected string $string;

    /**
     */
    protected string $collation;

    /**
     * @param string $string String value
     * @param string $collation String collation
     */
    this(string $string, string $collation) {
        this.string = $string;
        this.collation = $collation;
    }

    /**
     * Sets the string collation.
     *
     * @param string $collation String collation
     */
    void setCollation(string $collation) {
        this.collation = $collation;
    }

    /**
     * Returns the string collation.
     */
    string getCollation() {
        return this.collation;
    }


    string sql(ValueBinder aBinder) {
        $placeholder = $binder.placeholder("c");
        $binder.bind($placeholder, this.string, "string");

        return $placeholder ~ " COLLATE " ~ this.collation;
    }


    O traverse(this O)(Closure $callback) {
        return this;
    }
}
