module uim.databases.typedresults.interface_;

// Represents an expression that is known to return a specific type
interface IDTBTypedResult
{
    /**
     * Return the abstract type this expression will return
     */
    string getReturnType();

    /**
     * Set the return type of the expression
     *
     * @param string myType The type name to use.
     * @return this
     */
    auto setReturnType(string myType);
}
