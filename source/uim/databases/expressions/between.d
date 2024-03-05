/*********************************************************************************************************
	Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        
	License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  
	Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      
**********************************************************************************************************/
module uim.databases.expressions;

@safe:
import uim.databases;

use Closure;

/**
 * An expression object that represents a SQL BETWEEN snippet
 */
class BetweenExpression : IDBAExpression, FieldInterface
{
    use ExpressionTypeCasterTrait;
    use FieldTrait;

    /**
     * The first value in the expression
     *
     * @var mixed
     */
    protected _from;

    /**
     * The second value in the expression
     *
     * @var mixed
     */
    protected _to;

    /**
     * The data type for the from and to arguments
     *
     * @var mixed
     */
    protected _type;

    /**
     * Constructor
     *
     * @param uim.databases.IDBAExpression|string field The field name to compare for values inbetween the range.
     * @param mixed from The initial value of the range.
     * @param mixed to The ending value in the comparison range.
     * @param string|null type The data type name to bind the values with.
     */
    this(field, from, to, type = null) {
        if (type != null) {
            from = _castToExpression(from, type);
            to = _castToExpression(to, type);
        }

        _field = field;
        _from = from;
        _to = to;
        _type = type;
    }


    string sql(ValueBinder aBinder) {
        parts = [
            "from": _from,
            "to": _to,
        ];

        /** @var DDBIDBAExpression|string field */
        field = _field;
        if (field instanceof IDBAExpression) {
            field = field.sql( binder);
        }

        foreach (parts as name: part) {
            if (part instanceof IDBAExpression) {
                parts[name] = part.sql( binder);
                continue;
            }
            parts[name] = _bindValue(part,  binder, _type);
        }

        return sprintf("%s BETWEEN %s AND %s", field, parts["from"], parts["to"]);
    }


    O traverse(this O)(Closure callback) {
        foreach ([_field, _from, _to] as part) {
            if (part instanceof IDBAExpression) {
                callback(part);
            }
        }

        return this;
    }

    /**
     * Registers a value in the placeholder generator and returns the generated placeholder
     *
     * @param mixed value The value to bind
     * @param uim.databases.ValueBinder aBinder The value binder to use
     * @param string type The type of value
     * @return string generated placeholder
     */
    protected string _bindValue(value,  binder, type) {
        placeholder =  binder.placeholder("c");
         binder.bind(placeholder, value, type);

        return placeholder;
    }

    /**
     * Do a deep clone of this expression.
     */
    void __clone() {
        foreach (["_field", "_from", "_to"] as part) {
            if (this.{part} instanceof IDBAExpression) {
                this.{part} = clone this.{part};
            }
        }
    }
}
