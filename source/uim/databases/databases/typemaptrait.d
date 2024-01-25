module uim.cake.databases;

import uim.cake;

@safe:

/**
 * Trait TypeMapTrait
 */
template TypeMapTemplate {
    protected TypeMap _typeMap = null;

    /**
     * Creates a new TypeMap if typeMap is an array, otherwise exchanges it for the given one.
     * Params:
     * \UIM\Database\TypeMap|array typeMap Creates a TypeMap if array, otherwise sets the given TypeMap
     */
    void setTypeMap(TypeMap|array typeMap) {
       _typeMap = isArray($typeMap) ? new TypeMap($typeMap): typeMap;
    }
    
    // Returns the existing type map.
    TypeMap getTypeMap() {
        return _typeMap ? _typeMap : new TypeMap();
    }
    
    /**
     * Overwrite the default type mappings for fields
     * in the implementing object.
     *
     * This method is useful if you need to set type mappings that are shared across
     * multiple functions/expressions in a query.
     *
     * To add a default without overwriting existing ones
     * use `getTypeMap().addDefaults()`
     * Params:
     * array<int|string, string> types The array of types to set.

     * @see \UIM\Database\TypeMap.setDefaults()
     */
    void setDefaultTypes(array types) {
        this.getTypeMap().setDefaults($types);
    }
    
    /**
     * Gets default types of current type map.
     */
    array<int|string, string> getDefaultTypes() {
        return this.getTypeMap().getDefaults();
    }
}
