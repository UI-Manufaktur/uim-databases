/*********************************************************************************************************
	Copyright: © 2015-2023 Ozan Nurettin Süel (Sicherheitsschmiede)                                        
	License: Subject to the terms of the Apache 2.0 license, as written in the included LICENSE.txt file.  
	Authors: Ozan Nurettin Süel (Sicherheitsschmiede)                                                      
**********************************************************************************************************/
module uim.databases.expressions;

import uim.databases.IDBAExpression;
import uim.databases.ValueBinder;
use Closure;

/**
 * Represents a single identifier name in the database.
 *
 * Identifier values are unsafe with user supplied data.
 * Values will be quoted when identifier quoting is enabled.
 *
 * @see uim.databases.Query::identifier()
 */
class IdentifierExpression : IDBAExpression
{
    /**
     * Holds the identifier string
     */
    protected string _identifier;

    /**
     */
    protected Nullable!string collation;

    /**
     * Constructor
     *
     * @param string identifier The identifier this expression represents
     * @param string|null collation The identifier collation
     */
    this(string identifier, Nullable!string collation = null) {
        _identifier = identifier;
        this.collation = collation;
    }

    /**
     * Sets the identifier this expression represents
     *
     * @param string identifier The identifier
     */
    void setIdentifier(string identifier) {
        _identifier = identifier;
    }

    /**
     * Returns the identifier this expression represents
     */
    string getIdentifier() {
        return _identifier;
    }

    /**
     * Sets the collation.
     *
     * @param string collation Identifier collation
     */
    void setCollation(string collation) {
        this.collation = collation;
    }

    /**
     * Returns the collation.
     *
     */
    Nullable!string getCollation() {
        return this.collation;
    }


    string sql(ValueBinder aBinder) {
        sql = _identifier;
        if (this.collation) {
            sql ~= " COLLATE " ~ this.collation;
        }

        return sql;
    }


    O traverse(this O)(Closure callback) {
        return this;
    }
}
