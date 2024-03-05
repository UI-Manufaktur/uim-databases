module uim.databases.Retry;

import uim.databases;

@safe:

// Retry strategy based on db error codes and wait interval.
class ErrorCodeWaitStrategy : IRetryStrategy {
    protected int[] errorCodes;

    protected int  retryInterval;

    /**
     * @param array<int> errorCodes DB-specific error codes that allow retrying
     * @param int  retryInterval Seconds to wait before allowing next retry, 0 for no wait.
     */
    this(array<int> errorCodes, int retryWait) {
        _errorCodes = errorCodes;
        _retryWait =  retryWait;
    }
 
    bool shouldRetry(Exception exception, int  retryCount) {
        if (
            cast(PDOException)exception && exception.errorInfo && in_array(exception.errorInfo[1], this.errorCodes)
        ) {
            if (this.retryInterval > 0) {
                sleep(this.retryInterval);
            }
            return true;
        }
        return false;
    }
}
