module uim.cake.databases.types.base;

import uim.cake;

@safe:

/*

/**
 * Base type class.
 */
abstract class BaseType : IType {
    /**
     * Identifier name for this type
     */
    protected string _name = null;

    // aTypeName The name identifying this type
    this(string aTypeName = null) {
       _name = aTypeName;
    }
 
    @property string name() {
        return _name;
    }
 
    string getBaseType() {
        return _name;
    }
 
    int toStatement(Json aValue, Driver $driver) {
        if (aValue.isNull) {
            return PDO.PARAM_NULL;
        }
        return PDO.PARAM_STR;
    }
 
    Json newId() {
        return null;
    }
}
