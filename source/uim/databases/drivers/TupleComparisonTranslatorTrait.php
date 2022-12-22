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
 * @since         3.0.0
 * @license       https://opensource.org/licenses/mit-license.php MIT License
 */
namespace Cake\Database\Driver;

use Cake\Database\Expression\IdentifierExpression;
use Cake\Database\Expression\QueryExpression;
use Cake\Database\Expression\TupleComparison;
use Cake\Database\Query;
use RuntimeException;

/**
 * Provides a translator method for tuple comparisons
 *
 * @internal
 */
trait TupleComparisonTranslatorTrait
{
    /**
     * Receives a TupleExpression and changes it so that it conforms to this
     * SQL dialect.
     *
     * It transforms expressions looking like "(a, b) IN ((c, d), (e, f))" into an
     * equivalent expression of the form "((a = c) AND (b = d)) OR ((a = e) AND (b = f))".
     *
     * It can also transform transform expressions where the right hand side is a query
     * selecting the same amount of columns as the elements in the left hand side of
     * the expression:
     *
     * (a, b) IN (SELECT c, d FROM a_table) is transformed into
     *
     * 1 = (SELECT 1 FROM a_table WHERE (a = c) AND (b = d))
     *
     * @param \Cake\Database\Expression\TupleComparison $expression The expression to transform
     * @param \Cake\Database\Query $query The query to update.
     * @return void
     */
    protected function _transformTupleComparison(TupleComparison $expression, Query $query): void
    {
        $fields = $expression->getField();

        if (!is_array($fields)) {
            return;
        }

        $operator = strtoupper($expression->getOperator());
        if (!in_array($operator, ["IN", "="])) {
            throw new RuntimeException(
                sprintf(
                    "Tuple comparison transform only supports the `IN` and `=` operators, `%s` given.",
                    $operator
                )
            );
        }

        aValue = $expression->getValue();
        $true = new QueryExpression("1");

        if (aValue instanceof Query) {
            $selected = array_values(aValue->clause("select"));
            foreach ($fields as $i : $field) {
                aValue->andWhere([$field : new IdentifierExpression($selected[$i])]);
            }
            aValue->select($true, true);
            $expression->setField($true);
            $expression->setOperator("=");

            return;
        }

        $type = $expression->getType();
        if ($type) {
            /** @var array<string, string> $typeMap */
            $typeMap = array_combine($fields, $type) ?: [];
        } else {
            $typeMap = [];
        }

        $surrogate = $query->getConnection()
            ->newQuery()
            ->select($true);

        if (!is_array(current(aValue))) {
            aValue = [aValue];
        }

        $conditions = ["OR" : []];
        foreach (aValue as $tuple) {
            $item = [];
            foreach (array_values($tuple) as $i : aValue2) {
                $item[] = [$fields[$i] : aValue2];
            }
            $conditions["OR"][] = $item;
        }
        $surrogate->where($conditions, $typeMap);

        $expression->setField($true);
        $expression->setValue($surrogate);
        $expression->setOperator("=");
    }
}
