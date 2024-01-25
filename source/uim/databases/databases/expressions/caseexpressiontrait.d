module uim.cake.databases.Expression;

import uim.cake;

@safe:

/**
 * Trait that holds shared functionality for case related expressions.
 *
 * @internal
 */
template CaseExpressionTemplate {
    /**
     * Infers the abstract type for the given value.
     * Params:
     * Json aValue The value for which to infer the type.
     */
    protected string inferType(Json aValue) {
        auto type = null;

        /** @psalm-suppress RedundantCondition */
        if (isString(aValue)) {
            type = "String";
        } else if (isInt(aValue)) {
            type = "integer";
        } else if (isFloat(aValue)) {
            type = "float";
        } else if (isBool(aValue)) {
            type = "boolean";
        } else if (cast(ChronosDate)aValue) {
            type = "date";
        } else if (cast(IDateTime)aValue) {
            type = "datetime";
        } else if (
            isObject(aValue) &&
            cast(Stringable)aValue
        ) {
            type = "String";
        } else if (
           _typeMap !isNull &&
            cast(IdentifierExpression)aValue 
        ) {
            type = _typeMap.type(aValue.getIdentifier());
        } else if (aValue  ITypedResult) {
            type = aValue.getReturnType();
        }
        return type;
    }
    
    /**
     * Compiles a nullable value to SQL.
     * Params:
     * \UIM\Database\ValueBinder aBinder The value binder to use.
     * @param \UIM\Database\IExpression|object|scalar|null aValue The value to compile.
     * @param string type The value type.
     */
    protected string compileNullableValue(ValueBinder aBinder, Json aValue, string atype = null) {
        if (
            type !isNull &&
            !(cast(IExpression)aValue )
        ) {
            aValue = _castToExpression(aValue, type);
        }
        if (aValue.isNull) {
            aValue = "NULL";
        } else if (cast(Query)aValue) {
            aValue = "(%s)".format(aValue.sql(aBinder));
        } else if (cast(IExpression)aValue) {
            aValue = aValue.sql(aBinder);
        } else {
            placeholder = aBinder.placeholder("c");
            aBinder.bind($placeholder, aValue, type);
            aValue = placeholder;
        }
        return aValue;
    }
}
