module uim.databases.Expression;

/**
 * Describes a getter and a setter for the a field property. Useful for expressions
 * that contain an identifier to compare against.
 */
interface FieldInterface
{
    /**
     * Sets the field name
     *
     * @param uim.databases.IDBAExpression|array|string $field The field to compare with.
     */
    void setField($field);

    /**
     * Returns the field name
     *
     * @return uim.databases.IDBAExpression|array|string
     */
    function getField();
}
