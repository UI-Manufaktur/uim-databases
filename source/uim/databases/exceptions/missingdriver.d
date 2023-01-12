module uim.databases.exceptions.missingdriver;

@safe:
import uim.databases;

// Class MissingDriverException
class MissingDriverException : UIMException {

    protected _messageTemplate = "Could not find driver `%s` for connection `%s`.";
}
