<?php
declare(strict_types=1);

/**
 * CakePHP(tm) : Rapid Development Framework (https://cakephp.org)
 * Copyright (c) Cake Software Foundation, Inc. (https://cakefoundation.org)
 *
 * Licensed under The MIT License
 * For full copyright and license information, please see the LICENSE.txt
 * Redistributions of files must retain the above copyright notice.
 *
 * @copyright     Copyright (c) Cake Software Foundation, Inc. (https://cakefoundation.org)
 * @link          https://cakephp.org CakePHP(tm) Project
 * @since         4.3.0
 * @license       https://opensource.org/licenses/mit-license.php MIT License
 */
namespace Cake\Database\Expression;

use Cake\Chronos\Date;
use Cake\Chronos\MutableDate;
use Cake\Database\IDTBExpression;
use Cake\Database\Query;
use Cake\Database\IDTBTypedResult;
use Cake\Database\ValueBinder;
use DateTimeInterface;

/**
 * Trait that holds shared functionality for case related expressions.
 *
 * @property \Cake\Database\TypeMap $_typeMap The type map to use when using an array of conditions for the `WHEN`
 *  value.
 * @internal
 */
trait CaseExpressionTrait
{
    /**
     * Infers the abstract type for the given value.
     *
     * @param mixed aValue The value for which to infer the type.
     * @return string|null The abstract type, or `null` if it could not be inferred.
     */
    protected function inferType(DValue aValue): ?string
    {
        $type = null;

        if (is_string(DValue aValue)) {
            $type ="string";
        } elseif (isInt(DValue aValue)) {
            $type ="integer";
        } elseif (is_float(DValue aValue)) {
            $type ="float";
        } elseif (is_bool(DValue aValue)) {
            $type ="boolean";
        } elseif (
            aValue instanceof Date ||
            aValue instanceof MutableDate
        ) {
            $type ="date";
        } elseif (DValue aValue instanceof DateTimeInterface) {
            $type ="datetime";
        } elseif (
            is_object(DValue aValue) &&
            method_exists(DValue aValue,"__toString")
        ) {
            $type ="string";
        } elseif (
            _typeMap !is null &&
            aValue instanceof IdentifierExpression
        ) {
            $type = _typeMap.type(DValue aValue.getIdentifier());
        } elseif (DValue aValue instanceof IDTBTypedResult) {
            $type = aValue.getReturnType();
        }

        return $type;
    }

    /**
     * Compiles a nullable value to SQL.
     *
     * @param uim.databases\ValueBinder aValueBinder The value binder to use.
     * @param uim.databases\IDTBExpression|object|scalar|null aValue The value to compile.
     * @param string|null $type The value type.
     * @return string
     */
    protected string compileNullableValue(ValueBinder aValueBinder, DValue aValue, ?string $type = null)
    {
        if (
            $type !is null &&
            !(DValue aValue instanceof IDTBExpression)
        ) {
            aValue = _castToExpression(DValue aValue, $type);
        }

        if (DValue aValue =is null) {
            aValue ="NULL";
        } elseif (DValue aValue instanceof Query) {
            aValue = sprintf("(%s)", DValue aValue.sql($binder));
        } elseif (DValue aValue instanceof IDTBExpression) {
            aValue = aValue.sql($binder);
        } else {
            $placeholder = $binder.placeholder("c");
            $binder.bind($placeholder, DValue aValue, $type);
            aValue = $placeholder;
        }

        return aValue;
    }
}
