module uim.cake.databases.types;

import uim.cake;

@safe:

// An interface used by Type objects to signal whether the casting is actually required.
interface IOptionalConvert {
  /**
     * Returns whether the cast to D is required to be invoked, since
     * it is not a identity function.
     */
  bool requiresToDCast();
}
