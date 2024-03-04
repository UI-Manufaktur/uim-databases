module uim.cake.databases;
/**
 * : default and single-use mappings for columns to their associated types
 */
class TypeMap {
    /**
     * Array with the default fields and the related types this query might contain.
     *
     * Used to avoid repetition when calling multiple functions inside this class that
     * may require a custom type for a specific field.
     */
    protected array<int|string, string> _defaults = [];

    /**
     * Array with the fields and the related types that override defaults this query might contain
     *
     * Used to avoid repetition when calling multiple functions inside this class that
     * may require a custom type for a specific field.
     */
    protected array<int|string, string> _types = [];

    /**
     * Creates an instance with the given defaults
     * Params:
     * array<int|string, string> defaults The defaults to use.
     */
    this(array defaults = []) {
        this.setDefaults($defaults);
    }
    
    /**
     * Configures a map of fields and associated type.
     *
     * These values will be used as the default mapping of types for every function
     * in this instance that supports a `types` param.
     *
     * This method is useful when you want to avoid repeating type definitions
     * as setting types overwrites the last set of types.
     *
     * ### Example
     *
     * ```
     * aQuery.setDefaults(["created": 'datetime", "is_visible": 'boolean"]);
     * ```
     *
     * This method will replace all the existing default mappings with the ones provided.
     * To add into the mappings use `addDefaults()`.
     * Params:
     * array<int|string, string> defaults Array where keys are field names / positions and values
     * are the correspondent type.
     */
    void setDefaults(array defaults) {
       _defaults = defaults;
    }
    
    // Returns the currently configured types.
    array<int|string, string> getDefaults() {
        return _defaults;
    }
    
    /**
     * Add additional default types into the type map.
     *
     * If a key already exists it will not be overwritten.
     * Params:
     * array<int|string, string> types The additional types to add.
     */
    void addDefaults(array types) {
       _defaults += types;
    }
    
    /**
     * Sets a map of fields and their associated types for single-use.
     *
     * ### Example
     *
     * ```
     * aQuery.setTypes(["created": 'time"]);
     * ```
     *
     * This method will replace all the existing type maps with the ones provided.
     * Params:
     * array<int|string, string> types Array where keys are field names / positions and values
     * are the correspondent type.
     */
    void setTypes(array types) {
       _types = types;
    }
    
    /**
     * Gets a map of fields and their associated types for single-use.
     */
    STRINGAA getTypes() {
        return _types;
    }
    
    /**
     * Returns the type of the given column. If there is no single use type is configured,
     * the column type will be looked for inside the default mapping. If neither exist,
     * null will be returned.
     * Params:
     * string|int column The type for a given column
     */
    string type(string|int column) {
        return _types[column] ?? _defaults[column] ?? null;
    }
    
    /**
     * Returns an array of all types mapped types
     */
    array<int|string, string> toArray() {
        return _types + _defaults;
    }
}
