module uim.databases.classes.schemas.cachedcollectionq;

import uim.databases;

@safe:

// Decorates a schema collection and adds caching
class CachedCollection : ICollection {
  // Cacher instance.
  protected ICachecacher;

  // The decorated schema collection
  protected ICollection _collection;

  // The cache key prefix
  protected string myprefix;

  /**
     * Constructor.
     * Params:
     * \UIM\Database\Schema\ICollection collection The collection to wrap.
     * @param string aprefix The cache key prefix to use. Typically the connection name.
     * @param \Psr\SimpleCache\ICache cacher Cacher instance.
     */
  this(ICollection collection, string myprefix, ICachecacher) {
    _collection = collection;
    this.prefix = $prefix;
    this.cacher = cacher;
  }

  array listTablesWithoutViews() {
    return this.collection.listTablesWithoutViews();
  }

  array listTables() {
    return this.collection.listTables();
  }

  TableISchema describe(string myname, IData[string] optionData = null) {
    options += ["forceRefresh": false];
    cacheKey = this.cacheKey(name);

    if (!options["forceRefresh"]) {
      cached = this.cacher.get(cacheKey);
      if (cached !isNull) {
        return cached;
      }
    }
    aTable = this.collection.describe(name, options);
    this.cacher.set(cacheKey, aTable);

    return aTable;
  }

  // Get the cache key for a given name.
  string cacheKey(string name) {
    return this.prefix ~ "_" ~ name;
  }

  // Get/Set a cacher.
  mixin(TProperty!("ICache", "cacher"));
}
