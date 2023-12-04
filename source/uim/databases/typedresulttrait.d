module uim.databases;

@safe:
import uim.databases;

/**
 * : the TypedResultInterface
 */
trait TypedResultTrait
{
    /**
     * The type name this expression will return when executed
     *
     * @var string
     */
    protected _returnType = "string";

    /**
     * Gets the type of the value this object will generate.
     */
    string  getReturnType(): string
    {
        return _returnType;
    }

    /**
     * Sets the type of the value this object will generate.
     *
     * @param string $type The name of the type that is to be returned
     * @return this
     */
    function setReturnType(string $type)
    {
        _returnType = $type;

        return this;
    }
}
