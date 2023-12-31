/*********************************************************************************************************
	Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        
	License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  
	Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      
**********************************************************************************************************/
module uim.databases.exceptions.missingextension;

@safe:
import uim.databases;

/**
 * Class MissingExtensionException
 */
class MissingExtensionException : DatabaseException {

    // phpcs:ignore Generic.Files.LineLength
    protected _messageTemplate = "Database driver %s cannot be used due to a missing PHP extension or unmet dependency. Requested by connection '%s'";
}
