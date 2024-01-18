module uim.databases.Expression;

import uim.cake;

@safe:

/*
/**
 * String expression with collation.
 */
class StringExpression : IExpression {
    protected string astring;

    protected string aCollation;

    /**
     * @param string astring String value
     * @param string aCollation String collation
     */
    this(string astring, string aCollation) {
        this.string = $string;
        this.collation = aCollation;
    }
    
    // Sets the string collation.
    void collation(string aCollation) {
        this.collation = aCollation;
    }
    
    // Returns the string collation.
    string collation() {
        return this.collation;
    }
 
    string sql(ValueBinder aBinder) {
        $placeholder = aBinder.placeholder("c");
        aBinder.bind($placeholder, this.string, "string");

        return $placeholder ~ " COLLATE " ~ this.collation;
    }
 
    void traverse(Closure aCallback) {
    }
}
