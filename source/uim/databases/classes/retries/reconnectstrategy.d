module uim.databases.Retry;

import uim.cake;

@safe:

/*

/**
 * Makes sure the connection to the database is alive before authorizing
 * the retry of an action.
 *
 * @internal
 */
class ReconnectStrategy : IRetryStrategy {
    /**
     * The list of error strings to match when looking for a disconnection error.
     *
     * This is a static variable to enable opcache to inline the values.
     */
    protected static string[] $causes = [
        "gone away",
        "Lost connection",
        "Transaction() on null",
        "closed the connection unexpectedly",
        "closed unexpectedly",
        "deadlock avoided",
        "decryption failed or bad record mac",
        "is dead or not enabled",
        "no connection to the server",
        "query_wait_timeout",
        "reset by peer",
        "terminate due to client_idle_limit",
        "while sending",
        "writing data to the connection",
    ];

    // The connection to check for validity
    protected Connection _connection;

    /**
     * Creates the ReconnectStrategy object by storing a reference to the
     * passed connection. This reference will be used to automatically
     * reconnect to the server in case of failure.
     * Params:
     * \UIM\Database\Connection aConnection The connection to check
     */
    this(Connection aConnection) {
       _connection = aConnection;
    }
    
    /**
     * Checks whether the exception was caused by a lost connection,
     * and returns true if it was able to successfully reconnect.
     */
    bool shouldRetry(Exception $exception, int $retryCount) {
        auto $message = $exception.getMessage();

        foreach ($cause; $causes) {
            if ($message.has($cause)) {
                return this.reconnect();
            }
        }
        return false;
    }
    
    /**
     * Tries to re-establish the connection to the server, if it is safe to do so
     */
    protected bool reconnect() {
        if (this.connection.inTransaction()) {
            // It is not safe to blindly reconnect in the middle of a transaction
            return false;
        }
        try {
            // Make sure we free any resources associated with the old connection
            this.connection.getDriver().disconnect();
        } catch (Exception) {
        }
        try {
            this.connection.getDriver().connect();
            this.connection.getDriver().log(
                'connection={connection} [RECONNECT]",
                ["connection": this.connection.configName()]
            );

            return true;
        } catch (Exception) {
            // If there was an error connecting again, don`t report it back,
            // let the retry handler do it.
            return false;
        }
    }
}
