module uim.databases.exceptions.missingextension;

@safe:
import uim.databases;

/**
 * Class MissingExtensionException
 */
class MissingExtensionException : UIMException {

    // phpcs:ignore Generic.Files.LineLength
    protected _messageTemplate = "Database driver %s cannot be used due to a missing PHP extension or unmet dependency. Requested by connection '%s'";
}
