module uim.databases.Statement;

@safe:
import uim.databases;


/**
 * Wraps a statement in a callback that allows row results
 * to be modified when being fetched.
 *
 * This is used by CakePHP to eagerly load association data.
 */
class CallbackStatement : StatementDecorator
{
    /**
     * A callback function to be applied to results.
     *
     * @var callable
     */
    protected _callback;

    /**
     * Constructor
     *
     * @param uim.databases.StatementInterface statement The statement to decorate.
     * @param uim.databases.IDBADriver aDriver The driver instance used by the statement.
     * @param callable callback The callback to apply to results before they are returned.
     */
    public this(StatementInterface statement, IDBADriver aDriver, callable callback)
    {
        parent::__construct(statement, driver);
        this._callback = callback;
    }

    /**
     * Fetch a row from the statement.
     *
     * The result will be processed by the callback when it is not `false`.
     *
     * @param string|int type Either "num" or "assoc" to indicate the result format you would like.
     * @return array|false
     */
    function fetch(type = parent::FETCH_TYPE_NUM)
    {
        callback = this._callback;
        aRow = this._statement.fetch(type);

        return aRow == false ? aRow : callback(aRow);
    }

    /**
     * {@inheritDoc}
     *
     * Each row in the result will be processed by the callback when it is not `false.
     */
    function fetchAll(type = parent::FETCH_TYPE_NUM)
    {
        results = this._statement.fetchAll(type);

        return results != false ? array_map(this._callback, results) : false;
    }
}
