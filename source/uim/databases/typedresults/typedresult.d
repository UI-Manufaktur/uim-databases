module uim.databases.typedresults;

@safe:
import uim.databases.typedresults;

class DDBATypedResult {
  // The type name this expression will return when executed
  protected string _returnType = "string";

  // Gets the type of the value this object will generate.
  string returnType() {
    return _returnType;
  }

  // Sets the type of the value this object will generate.
  // string myType The name of the type that is to be returned
  auto returnType(string newType) {
    _returnType = newType;
    return cast(O)this;
  }
}
