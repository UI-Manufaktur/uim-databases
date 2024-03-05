module uim.cake.databases.expressions.unary;

import uim.cake;

@safe:

/* */
// An expression object that represents an expression with only a single operand.
class UnaryExpression : UimExpression {
    // Indicates that the operation is in pre-order
    const int PREFIX = 0;

    // Indicates that the operation is in post-order
    const int POSTFIX = 1;

    // The operator this unary expression represents
    protected string _operator;

    // Holds the value which the unary expression operates
    protected Json _value;

    // Where to place the operator
    protected int position;

    /**
     * Constructor
     * Params:
     * string aoperator The operator to used for the expression
     * @param Json aValue the value to use as the operand for the expression
     * @param int position either UnaryExpression.PREFIX or UnaryExpression.POSTFIX
     */
    this(string aoperator, Json aValue, int position = self.PREFIX) {
       _operator = operator;
       _value = aValue;
        this.position = position;
    }
    
    string sql(ValueBinder aBinder) {
        operand = _value;
        if (cast(IExpression) operand ) {
            operand = operand.sql(aBinder);
        }
        if (this.position == self.POSTFIX) {
            return "(" ~ operand ~ ") " ~ _operator;
        }
        return _operator ~ " (" ~ operand ~ ")";
    }
 
    void traverse(Closure aCallback) {
        if (cast(IExpression)_value ) {
            aCallback(_value);
           _value.traverse(aCallback);
        }
    }
    
    // Perform a deep clone of the inner expression.
    void __clone() {
        if (cast(IExpression)_value ) {
           _value = clone _value;
        }
    }
}
