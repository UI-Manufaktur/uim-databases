/*********************************************************************************************************
	Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        
	License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  
	Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      
**********************************************************************************************************/
module uim.databases.expressions;

/**
 * Contains the field property with a getter and a setter for it
 */
trait FieldTrait
{
    /**
     * The field name or expression to be used in the left hand side of the operator
     *
     * @var DDBIDBAExpression|array|string
     */
    protected _field;

    /**
     * Sets the field name
     *
     * @param uim.databases.IDBAExpression|array|string $field The field to compare with.
     */
    void setField($field) {
        _field = $field;
    }

    /**
     * Returns the field name
     *
     * @return uim.databases.IDBAExpression|array|string
     */
    function getField() {
        return _field;
    }
}
