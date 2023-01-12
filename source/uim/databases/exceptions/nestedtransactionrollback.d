/*********************************************************************************************************
	Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        
	License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  
	Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      
**********************************************************************************************************/
module uim.databases.exceptions.nestedtransactionrollback;

@safe:
import uim.databases;

use Throwable;

/**
 * Class NestedTransactionRollbackException
 */
class NestedTransactionRollbackException : UIMException {
    /**
     * Constructor
     *
     * @param string|null $message If no message is given a default meesage will be used.
     * @param int|null $code Status code, defaults to 500.
     * @param \Throwable|null $previous the previous exception.
     */
    this(Nullable!string $message = null, Nullable!int $code = 500, ?Throwable $previous = null) {
        if ($message == null) {
            $message = "Cannot commit transaction - rollback() has been already called in the nested transaction";
        }
        super(($message, $code, $previous);
    }
}
