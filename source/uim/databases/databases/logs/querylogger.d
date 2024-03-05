module uim.cake.databases.logs.queryloggers;

import uim.cake;

@safe:

/**
 * This class is a bridge used to write LoggedQuery objects into a real log.
 * by default this class use the built-in UIM Log class to accomplish this
 */
class QueryLogger : BaseLog {

  this(IData[string] configData = null) {
    _defaultConfig["scopes"] = ["queriesLog", "cake.database.queries"];
    _defaultConfig["connection"] = "";

    super(configData);
  }

  void log( level, string | Stringable$message, array mycontext = []) {
    context += [
      "scope": this.scopes() ? : ["queriesLog", "cake.database.queries"],
      "connection": _configData.isSet("connection"),
      "query": null,
    ];

    if (cast(LoggedQuery)context["query"]) {
      context = context["query"].getContext() + context;
      string message = "connection={connection} role={role} duration={took} rows={numRows} " ~ message;
    }

    Log.write("debug", to!string($message), context);
  }
}
