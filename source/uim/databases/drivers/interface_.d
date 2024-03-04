module uim.databases.drivers.interface_;

@safe:
import uim.databases;

/**
 * Interface for database driver.
 *
 * @method int|null getMaxAliasLength() Returns the maximum alias length allowed.
 * @method int getConnectRetries() Returns the number of connection retry attempts made.
 * @method bool supports(string feature) Checks whether a feature is supported by the driver.
 * @method bool inTransaction() Returns whether a transaction is active.
 */
interface IDBADriver {











    
}
