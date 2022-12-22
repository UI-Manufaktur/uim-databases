module uim.databases.drivers.registry;

@safe:
import uim.databases;

class DDTBDriverRegistry : DRegistry(IDTBDriver) { 
  static DDTBDriverRegistry driverRegistry;
}
auto DTBDriverRegistry() { // Singleton
  if (driverRegistry is null) {
    driverRegistry = new DDTBDriverRegistry;
  }
  return driverRegistry;
}