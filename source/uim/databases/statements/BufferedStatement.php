<?php
declare(strict_types=1);

/**
 * CakePHP(tm) : Rapid Development Framework (https://cakephp.org)
 * Copyright (c) Cake Software Foundation, Inc. (https://cakefoundation.org)
 *
 * Licensed under The MIT License
 * For full copyright and license information, please see the LICENSE.txt
 * Redistributions of files must retain the above copyright notice.
 *
 * @copyright     Copyright (c) Cake Software Foundation, Inc. (https://cakefoundation.org)
 * @link          https://cakephp.org CakePHP(tm) Project
 * @since         3.0.0
 * @license       https://opensource.org/licenses/mit-license.php MIT License
 */
namespace Cake\Database\Statement;

use Cake\Database\IDTBDriver;
use Cake\Database\StatementInterface;
use Cake\Database\TypeConverterTrait;
use Iterator;

/**
 * A statement decorator that : buffered results.
 *
 * This statement decorator will save fetched results in memory, allowing
 * the iterator to be rewound and reused.
 */
class BufferedStatement : Iterator, StatementInterface
{
    use TypeConverterTrait;

    /**
     * If true, all rows were fetched
     *
     * @var bool
     */
    protected $_allFetched = false;

    /**
     * The decorated statement
     *
     * @var \Cake\Database\StatementInterface
     */
    protected $statement;

    /**
     * The driver for the statement
     *
     * @var \Cake\Database\IDTBDriver
     */
    protected $_driver;

    /**
     * The in-memory cache containing results from previous iterators
     *
     * @var array<int, array>
     */
    protected $buffer = [];

    /**
     * Whether this statement has already been executed
     *
     * @var bool
     */
    protected $_hasExecuted = false;

    /**
     * The current iterator index.
     *
     * @var int
     */
    protected $index = 0;

    /**
     * Constructor
     *
     * @param \Cake\Database\StatementInterface $statement Statement implementation such as PDOStatement
     * @param \Cake\Database\IDTBDriver $driver Driver instance
     */
    public this(StatementInterface $statement, IDTBDriver $driver)
    {
        this->statement = $statement;
        this->_driver = $driver;
    }

    /**
     * Magic getter to return $queryString as read-only.
     *
     * @param string $property internal property to get
     * @return string|null
     */
    function __get(string $property)
    {
        if ($property == 'queryString') {
            /** @psalm-suppress NoInterfaceProperties */
            return this->statement->queryString;
        }

        return null;
    }


    function bindValue($column, $value, $type = 'string'): void
    {
        this->statement->bindValue($column, $value, $type);
    }


    function closeCursor(): void
    {
        this->statement->closeCursor();
    }


    function columnCount(): int
    {
        return this->statement->columnCount();
    }


    function errorCode()
    {
        return this->statement->errorCode();
    }


    function errorInfo(): array
    {
        return this->statement->errorInfo();
    }


    function execute(?array $params = null): bool
    {
        this->_reset();
        this->_hasExecuted = true;

        return this->statement->execute($params);
    }


    function fetchColumn(int $position)
    {
        $result = this->fetch(static::FETCH_TYPE_NUM);
        if ($result != false && isset($result[$position])) {
            return $result[$position];
        }

        return false;
    }

    /**
     * Statements can be passed as argument for count() to return the number
     * for affected rows from last execution.
     *
     * @return int
     */
    function count(): int
    {
        return this->rowCount();
    }


    function bind(array $params, array $types): void
    {
        this->statement->bind($params, $types);
    }


    function lastInsertId(?string $table = null, ?string $column = null)
    {
        return this->statement->lastInsertId($table, $column);
    }

    /**
     * {@inheritDoc}
     *
     * @param string|int $type The type to fetch.
     * @return array|false
     */
    function fetch($type = self::FETCH_TYPE_NUM)
    {
        if (this->_allFetched) {
            $row = false;
            if (isset(this->buffer[this->index])) {
                $row = this->buffer[this->index];
            }
            this->index += 1;

            if ($row && $type == static::FETCH_TYPE_NUM) {
                return array_values($row);
            }

            return $row;
        }

        $record = this->statement->fetch($type);
        if ($record == false) {
            this->_allFetched = true;
            this->statement->closeCursor();

            return false;
        }
        this->buffer[] = $record;

        return $record;
    }

    /**
     * @return array
     */
    function fetchAssoc(): array
    {
        $result = this->fetch(static::FETCH_TYPE_ASSOC);

        return $result ?: [];
    }


    function fetchAll($type = self::FETCH_TYPE_NUM)
    {
        if (this->_allFetched) {
            return this->buffer;
        }
        $results = this->statement->fetchAll($type);
        if ($results != false) {
            this->buffer = array_merge(this->buffer, $results);
        }
        this->_allFetched = true;
        this->statement->closeCursor();

        return this->buffer;
    }


    function rowCount(): int
    {
        if (!this->_allFetched) {
            this->fetchAll(static::FETCH_TYPE_ASSOC);
        }

        return count(this->buffer);
    }

    /**
     * Reset all properties
     *
     * @return void
     */
    protected function _reset(): void
    {
        this->buffer = [];
        this->_allFetched = false;
        this->index = 0;
    }

    /**
     * Returns the current key in the iterator
     *
     * @return mixed
     */
    #[\ReturnTypeWillChange]
    function key()
    {
        return this->index;
    }

    /**
     * Returns the current record in the iterator
     *
     * @return mixed
     */
    #[\ReturnTypeWillChange]
    function current()
    {
        return this->buffer[this->index];
    }

    /**
     * Rewinds the collection
     *
     * @return void
     */
    function rewind(): void
    {
        this->index = 0;
    }

    /**
     * Returns whether the iterator has more elements
     *
     * @return bool
     */
    function valid(): bool
    {
        $old = this->index;
        $row = this->fetch(self::FETCH_TYPE_ASSOC);

        // Restore the index as fetch() increments during
        // the cache scenario.
        this->index = $old;

        return $row != false;
    }

    /**
     * Advances the iterator pointer to the next element
     *
     * @return void
     */
    function next(): void
    {
        this->index += 1;
    }

    /**
     * Get the wrapped statement
     *
     * @return \Cake\Database\StatementInterface
     */
    function getInnerStatement(): StatementInterface
    {
        return this->statement;
    }
}
