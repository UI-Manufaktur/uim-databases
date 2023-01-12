module uim.databases.schemas;

use Psr\SimpleCache\CacheInterface;

/**
 * Decorates a schema collection and adds caching
 */
class CachedCollection : CollectionInterface
{
    /**
     * Cacher instance.
     *
     * @var \Psr\SimpleCache\CacheInterface
     */
    protected $cacher;

    /**
     * The decorated schema collection
     *
     * @var \Cake\Database\Schema\CollectionInterface
     */
    protected $collection;

    /**
     * The cache key prefix
     *
     * @var string
     */
    protected $prefix;

    /**
     * Constructor.
     *
     * @param \Cake\Database\Schema\CollectionInterface $collection The collection to wrap.
     * @param string $prefix The cache key prefix to use. Typically the connection name.
     * @param \Psr\SimpleCache\CacheInterface $cacher Cacher instance.
     */
    public this(CollectionInterface $collection, string $prefix, CacheInterface $cacher)
    {
        this.collection = $collection;
        this.prefix = $prefix;
        this.cacher = $cacher;
    }


    function listTablesWithoutViews(): array
    {
        return this.collection.listTablesWithoutViews();
    }


    function listTables(): array
    {
        return this.collection.listTables();
    }


    function describe(string $name, array $options = []): ITableSchema
    {
        $options += ["forceRefresh" : false];
        $cacheKey = this.cacheKey($name);

        if (!$options["forceRefresh"]) {
            $cached = this.cacher.get($cacheKey);
            if ($cached != null) {
                return $cached;
            }
        }

        $table = this.collection.describe($name, $options);
        this.cacher.set($cacheKey, $table);

        return $table;
    }

    /**
     * Get the cache key for a given name.
     *
     * @param string $name The name to get a cache key for.
     * @return string The cache key.
     */
    function cacheKey(string $name): string
    {
        return this.prefix . "_" . $name;
    }

    /**
     * Set a cacher.
     *
     * @param \Psr\SimpleCache\CacheInterface $cacher Cacher object
     * @return this
     */
    function setCacher(CacheInterface $cacher)
    {
        this.cacher = $cacher;

        return this;
    }

    /**
     * Get a cacher.
     *
     * @return \Psr\SimpleCache\CacheInterface $cacher Cacher object
     */
    function getCacher(): CacheInterface
    {
        return this.cacher;
    }
}
