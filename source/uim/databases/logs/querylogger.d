/*********************************************************************************************************
	Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        
	License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  
	Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      
**********************************************************************************************************/
module uim.databases.Log;

import uim.logs.Engine\BaseLog;
import uim.logs.Log;

/**
 * This class is a bridge used to write LoggedQuery objects into a real log.
 * by default this class use the built-in UIM Log class to accomplish this
 *
 * @internal
 */
class QueryLogger : BaseLog
{
    /**
     * Constructor.
     *
     * @param array<string, mixed> aConfig Configuration array
     */
    this(Json aConfig = null) {
        _defaultConfig["scopes"] = ["queriesLog"];
        _defaultConfig["connection"] = "";

        super((aConfig);
    }


    function log( level, $message, array context = null) {
        context["scope"] = this.scopes() ?: ["queriesLog"];
        context["connection"] = this.getConfig("connection");

        if (context["query"] instanceof LoggedQuery) {
            context = context["query"].getContext() + context;
            $message = "connection={connection} duration={took} rows={numRows} " ~ $message;
        }
        Log::write("debug", $message, context);
    }
}
