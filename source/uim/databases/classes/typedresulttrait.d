module uim.cake.databases;
/**
 * : the ITypedResult
 */
trait TypedResultTrait {
    // The type name this expression will return when executed
    protected string _returnType = "string";

    // Gets the type of the value this object will generate.
    string getReturnType() {
        return _returnType;
    }
    
    // Sets the type of the value this object will generate.
    void setReturnType(string typeName) {
       _returnType = typeName;
    }
}
