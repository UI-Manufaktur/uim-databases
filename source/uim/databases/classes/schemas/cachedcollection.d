module uim.databases.schemas;

import uim.cake;

@safe:

// Decorates a schema collection and adds caching
class CachedCollection : ICollection {
  // Cacher instance.
  protected ICache$cacher;

  // The decorated schema collection
  protected ICollection$collection;

  // The cache key prefix
  protected string myprefix;

  /**
     * Constructor.
     * Params:
     * \UIM\Database\Schema\ICollection $collection The collection to wrap.
     * @param string aprefix The cache key prefix to use. Typically the connection name.
     * @param \Psr\SimpleCache\ICache $cacher Cacher instance.
     */
  this(ICollection$collection, string myprefix, ICache$cacher) {
    this.collection = $collection;
    this.prefix = $prefix;
    this.cacher = $cacher;
  }

  array listTablesWithoutViews() {
    return this.collection.listTablesWithoutViews();
  }

  array listTables() {
    return this.collection.listTables();
  }

  TableISchema describe(string myname, Json[string] optionData = null) {
    $options += ["forceRefresh": false];
    $cacheKey = this.cacheKey($name);

    if (!$options["forceRefresh"]) {
      $cached = this.cacher.get($cacheKey);
      if ($cached !isNull) {
        return $cached;
      }
    }
    aTable = this.collection.describe($name, $options);
    this.cacher.set($cacheKey, aTable);

    return aTable;
  }

  /**
     * Get the cache key for a given name.
     * Params:
     * string aName The name to get a cache key for.
     */
  string cacheKey(string myname) {
    return this.prefix ~ "_" ~ $name;
  }

  // Get/Set a cacher.
  mixin(TProperty!("ICache", "cacher"));
}
