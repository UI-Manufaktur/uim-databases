/*********************************************************************************************************
	Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        
	License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  
	Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      
**********************************************************************************************************/
module uim.databases.exceptions;

import uim.core.exceptions.UIMException;

/**
 * Exception for the database package.
 */
class DatabaseException : UIMException {
}

// phpcs:disable
class_exists("Cake\databases.exceptions");
// phpcs:enable
