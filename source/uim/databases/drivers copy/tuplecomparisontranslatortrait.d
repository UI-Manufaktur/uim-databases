module uim.cake.databases.drivers;

import uim.cake.databases.expressions.IdentifierExpression;
import uim.cake.databases.expressions.QueryExpression;
import uim.cake.databases.expressions.TupleComparison;
import uim.cake.databases.Query;
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
     * @param uim.cake.databases.Expression\TupleComparison $expression The expression to transform
     * @param uim.cake.databases.Query $query The query to update.
     */
    protected void _transformTupleComparison(TupleComparison $expression, Query $query) {
        $fields = $expression.getField();

        if (!is_array($fields)) {
            return;
        }

        $operator = strtoupper($expression.getOperator());
        if (!hasAllValues($operator, ["IN", "="])) {
            throw new RuntimeException(
                sprintf(
                    "Tuple comparison transform only supports the `IN` and `=` operators, `%s` given.",
                    $operator
                )
            );
        }

        $value = $expression.getValue();
        $true = new QueryExpression("1");

        if ($value instanceof Query) {
            $selected = array_values($value.clause("select"));
            foreach ($fields as $i: $field) {
                $value.andWhere([$field: new IdentifierExpression($selected[$i])]);
            }
            $value.select($true, true);
            $expression.setField($true);
            $expression.setOperator("=");

            return;
        }

        $type = $expression.getType();
        if ($type) {
            /** @var array<string, string> $typeMap */
            $typeMap = array_combine($fields, $type) ?: [];
        } else {
            $typeMap = null;
        }

        $surrogate = $query.getConnection()
            .newQuery()
            .select($true);

        if (!is_array(current($value))) {
            $value = [$value];
        }

        $conditions = ["OR": []];
        foreach ($value as $tuple) {
            $item = null;
            foreach (array_values($tuple) as $i: $value2) {
                $item[] = [$fields[$i]: $value2];
            }
            $conditions["OR"][] = $item;
        }
        $surrogate.where($conditions, $typeMap);

        $expression.setField($true);
        $expression.setValue($surrogate);
        $expression.setOperator("=");
    }
}
