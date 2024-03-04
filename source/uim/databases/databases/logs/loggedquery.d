module uim.cake.databases.Log;

import uim.cake;

@safe:

/**
 * Contains a query string, the params used to executed it, time taken to do it
 * and the number of rows found or affected by its execution.
 */
class LoggedQuery : JsonSerializable, Stringable {
    // Driver executing the query
    protected Driver driver = null;

    // Query string that was executed
    protected string aquery = "";

    // Number of milliseconds this query took to complete
    protected float took = 0;

    // Associative array with the params bound to the query string
    protected array params = [];

    // Number of rows affected or returned by the query execution
    protected int numRows = 0;

    // The exception that was thrown by the execution of this query
    protected Exception error = null;

    // Helper auto used to replace query placeholders by the real params used to execute the query
    protected string interpolate() {
        params = array_map(function (p) {
            if (p.isNull) {
                return "NULL";
            }
            if (isBool(p)) {
                if (cast(Sqlserver)this.driver ) {
                    return p ? "1" : "0";
                }
                return p ? "TRUE" : "FALSE";
            }
            if (isString(p)) {
                // Likely binary data like a blob or binary uuid.
                // pattern matches ascii control chars.
                if (preg_replace("/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/u", "", p) != p) {
                    p = bin2hex(p);
                }
                replacements = [
                    "$": "\\$",
                    "\\": "\\\\\\\\",
                    "\'": "\"\"",
                ];

                p = strtr(p, replacements);

                return "'p'";
            }
            return p;
        }, this.params);

        aLimit = isInt(key(params)) ? 1 : -1;
        auto someKeys = params.byKeyValue
            .map!(keyParam => isString(keyParam.key) ? "/:"~keyParam.key~"\b/" : "/[?]/")
            .array;

        return to!string(preg_replace(someKeys, params, this.query, aLimit));
    }
    
    // Get the logging context data for a query.
    IData[string] getContext() {
        return [
            "query": this.query,
            "numRows": this.numRows,
            "took": this.took,
            "role": this.driver 
                ? this.driver.getRole()
                : "",
        ];
    }
    
    // Set logging context for this query.
    void setContext(IData[string] loggingContext) {
        loggingContext.byKeyValue
            each!(kv => this.{kv.key} = kv.value);
    }
    
    // Returns data that will be serialized as JSON
    IData[string] jsonSerialize() {
        error = this.error;
        if (error !isNull) {
            error = [
                "class": error.classname,
                "message": error.getMessage(),
                "code": error.getCode(),
            ];
        }
        return [
            "query": this.query,
            "numRows": this.numRows,
            "params": this.params,
            "took": this.took,
            "error": error,
        ];
    }
    
    // Returns the string representation of this logged query
    override string toString() {
        sql = this.query;
        if (!empty(this.params)) {
            sql = this.interpolate();
        }
        return sql;
    }
}
