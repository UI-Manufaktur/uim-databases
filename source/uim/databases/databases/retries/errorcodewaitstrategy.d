module uim.cake.databases.Retry;

import uim.cake;

@safe:

/*


/**
 * : retry strategy based on db error codes and wait interval.
 *
 * @internal
 */
class ErrorCodeWaitStrategy : IRetryStrategy {
    protected int[] errorCodes;

    protected int retryInterval;

    /**
     * @param array<int> errorCodes DB-specific error codes that allow retrying
     * @param int retryInterval Seconds to wait before allowing next retry, 0 for no wait.
     */
    this(array errorCodes, int retryInterval) {
        this.errorCodes = errorCodes;
        this.retryInterval = retryInterval;
    }
 
    bool shouldRetry(Exception exception, int retryCount) {
        if (
            cast(PDOException)$exception &&
            exception.errorInfo &&
            in_array($exception.errorInfo[1], this.errorCodes)
        ) {
            if (this.retryInterval > 0) {
                sleep(this.retryInterval);
            }
            return true;
        }
        return false;
    }
}
