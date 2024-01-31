/*********************************************************************************************************
	Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        
	License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  
	Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      
**********************************************************************************************************/
module uim.databases.Retry;

/**
 * : retry strategy based on db error codes and wait interval.
 *
 * @internal
 */
class ErrorCodeWaitStrategy : RetryStrategyInterface
{
    /**
     * @var array<int>
     */
    protected $errorCodes;

    /**
     */
    protected int $retryInterval;

    /**
     * @param array<int> $errorCodes DB-specific error codes that allow retrying
     * @param int $retryInterval Seconds to wait before allowing next retry, 0 for no wait.
     */
    this(array $errorCodes, int $retryInterval) {
        this.errorCodes = $errorCodes;
        this.retryInterval = $retryInterval;
    }


    bool shouldRetry(Exception $exception, int $retryCount) {
        if (
            $exception instanceof PDOException &&
            $exception.errorInfo &&
            hasAllValues($exception.errorInfo[1], this.errorCodes)
        ) {
            if (this.retryInterval > 0) {
                sleep(this.retryInterval);
            }

            return true;
        }

        return false;
    }
}
