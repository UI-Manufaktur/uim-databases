/*********************************************************************************************************
	Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        
	License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  
	Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      
**********************************************************************************************************/
module uim.databases.expressions;

import uim.Chronos\Date;
import uim.Chronos\MutableDate;
import uim.databases.IDBAExpression;
import uim.databases.Query;
import uim.databases.ITypedResult;
import uim.databases.ValueBinder;
use DateTimeInterface;

/**
 * Trait that holds shared functionality for case related expressions.
 *
 * @property uim.databases.TypeMap _typeMap The type map to use when using an array of conditions for the `WHEN`
 *  value.
 * @internal
 */
trait CaseExpressionTrait
{
    /**
     * Infers the abstract type for the given value.
     *
     * @param mixed $value The value for which to infer the type.
     * @return string|null The abstract type, or `null` if it could not be inferred.
     */
    protected Nullable!string inferType($value) {
        type = null;

        if (is_string($value)) {
            type = "string";
        } elseif (is_int($value)) {
            type = "integer";
        } elseif (is_float($value)) {
            type = "float";
        } elseif (is_bool($value)) {
            type = "boolean";
        } elseif (
            $value instanceof Date ||
            $value instanceof MutableDate
        ) {
            type = "date";
        } elseif ($value instanceof DateTimeInterface) {
            type = "datetime";
        } elseif (
            is_object($value) &&
            method_exists($value, "__toString")
        ) {
            type = "string";
        } elseif (
            _typeMap != null &&
            $value instanceof IdentifierExpression
        ) {
            type = _typeMap.type($value.getIdentifier());
        } elseif ($value instanceof ITypedResult) {
            type = $value.getReturnType();
        }

        return type;
    }

    /**
     * Compiles a nullable value to SQL.
     *
     * @param uim.databases.ValueBinder aBinder The value binder to use.
     * @param uim.databases.IDBAExpression|object|scalar|null $value The value to compile.
     * @param string|null type The value type.
     */
    protected string compileNullableValue(ValueBinder aBinder, $value, Nullable!string type = null) {
        if (
            type != null &&
            !($value instanceof IDBAExpression)
        ) {
            $value = _castToExpression($value, type);
        }

        if ($value == null) {
            $value = "NULL";
        } elseif ($value instanceof Query) {
            $value = sprintf("(%s)", $value.sql($binder));
        } elseif ($value instanceof IDBAExpression) {
            $value = $value.sql($binder);
        } else {
            $placeholder = $binder.placeholder("c");
            $binder.bind($placeholder, $value, type);
            $value = $placeholder;
        }

        return $value;
    }
}
