module uim.databases.drivers.registry;

@safe:
import uim.databases;

class DDBADriverRegistry : DRegistry(IDBADriver) { 
  static DDBADriverRegistry driverRegistry;
}
auto DBADriverRegistry() { // Singleton
  if (driverRegistry is null) {
    driverRegistry = new DDBADriverRegistry;
  }
  return driverRegistry;
}