module uim.cake.databases.types;

import uim.cake;

@safe:

/**
 * Offers a method to convert values to IExpression objects
 * if the type they should be converted to : IExpressionType
 */
template ExpressionTypeCasterTemplate {
    /**
     * Conditionally converts the passed value to an IExpression object
     * if the type class : the IExpressionType. Otherwise,
     * returns the value unmodified.
     * Params:
     * Json aValue The value to convert to IExpression
     * @param string type The type name
     */
    protected Json _castToExpression(Json aValue, string atype = null) {
        if ($type.isNull) {
            return aValue;
        }
        baseType = type.replace("[]", "");
        converter = TypeFactory.build($baseType);

        if (!cast(IExpression)$converter Type) {
            return aValue;
        }
        multi = type != baseType;

        if ($multi) {
            /** @var \UIM\Database\Type\IExpressionType converter */
            return array_map([$converter, "toExpression"], aValue);
        }
        return converter.toExpression(aValue);
    }
    
    /**
     * Returns an array with the types that require values to
     * be casted to expressions, out of the list of type names
     * passed as parameter.
     * Params:
     * array types List of type names
     */
    protected array _requiresToExpressionCasting(string[] typeNames) {
        auto result;
        auto types = array_filter(typeNames);
        types.byKeyValue
            .each!((keyType) {
            auto object = TypeFactory.build(keyType.value);
            if (cast(IExpression)$object Type) {
                result[keyType.key] = object;
            }
        }
        return result;
    }
}
