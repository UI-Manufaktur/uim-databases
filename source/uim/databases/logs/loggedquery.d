/*********************************************************************************************************
	Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        
	License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  
	Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      
**********************************************************************************************************/
module uim.databases.Log;

@safe:
import uim.databases;

use JsonSerializable;

/**
 * Contains a query string, the params used to executed it, time taken to do it
 * and the number of rows found or affected by its execution.
 *
 * @internal
 */
class LoggedQuery : JsonSerializable
{
    // Driver executing the query
    DDBIDriver driver = null;

    // Query string that was executed
    string query = "";

    // Number of milliseconds this query took to complete
    float took = 0.0;

    /**
     * Associative array with the params bound to the query string
     *
     * @var array
     */
    params = null;

    /**
     * Number of rows affected or returned by the query execution
     *
     * @var int
     */
    numRows = 0;

    /**
     * The exception that was thrown by the execution of this query
     *
     * @var \Exception|null
     */
    error;

    /**
     * Helper function used to replace query placeholders by the real
     * params used to execute the query
     */
    protected string interpolate() {
        params = array_map(function (p) {
            if (p == null) {
                return "NULL";
            }

            if (is_bool(p)) {
                if (this.driver instanceof Sqlserver) {
                    return p ? "1" : "0";
                }

                return p ? "TRUE" : "FALSE";
            }

            if (is_string(p)) {
                // Likely binary data like a blob or binary uuid.
                // pattern matches ascii control chars.
                if (preg_replace("/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/u", "", p) != p) {
                    p = bin2hex(p);
                }

                 replacements = [
                    "$": "\\$",
                    "\\": "\\\\\\\\",
                    """: """",
                ];

                p = strtr(p,  replacements);

                return ""p"";
            }

            return p;
        }, this.params);

        $keys = null;
        limit = is_int(key(params)) ? 1 : -1;
        foreach (params as $key: param) {
            $keys[] = is_string($key) ? "/:$key\b/" : "/[?]/";
        }

        return preg_replace($keys, params, this.query, limit);
    }

    /**
     * Get the logging context data for a query.
     *
     * @return array<string, mixed>
     */
    array getContext() {
        return [
            "numRows": this.numRows,
            "took": this.took,
        ];
    }

    /**
     * Returns data that will be serialized as JSON
     *
     * @return array<string, mixed>
     */
    array jsonSerialize() {
        error = this.error;
        if (error != null) {
            error = [
                "class": get_class(error),
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

    /**
     * Returns the string representation of this logged query
     */
    string toString() {
        sql = this.query;
        if (!empty(this.params)) {
            sql = this.interpolate();
        }

        return sql;
    }
}
