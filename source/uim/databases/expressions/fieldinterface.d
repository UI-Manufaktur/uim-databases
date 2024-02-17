/*********************************************************************************************************
	Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        
	License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  
	Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      
**********************************************************************************************************/
module uim.databases.expressions;

/**
 * Describes a getter and a setter for the a field property. Useful for expressions
 * that contain an identifier to compare against.
 */
interface FieldInterface
{
    /**
     * Sets the field name
     *
     * @param uim.databases.IDBAExpression|array|string field The field to compare with.
     */
    void setField(field);

    /**
     * Returns the field name
     *
     * @return uim.databases.IDBAExpression|array|string
     */
    function getField();
}
