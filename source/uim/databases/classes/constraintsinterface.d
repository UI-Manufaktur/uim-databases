module uim.databases;

import uim.databases;

@safe:

// Defines the interface for a fixture that needs to manage constraints.
interface IConstraints {
  /**
     * Build and execute SQL queries necessary to create the constraints for the
     * fixture
     * Params:
     * \UIM\Datasource\IConnection aConnection An instance of the database
     * into which the constraints will be created.
     */
  bool createConstraints(IConnection aConnection);

  /**
     * Build and execute SQL queries necessary to drop the constraints for the
     * fixture
     * Params:
     * \UIM\Datasource\IConnection aConnection An instance of the database
     * into which the constraints will be dropped.
     */
  bool dropConstraints(IConnection aConnection);
}
