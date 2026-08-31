import type { MojoProviderPackageImplementation } from "@tsonic/target-mojo/provider";
import { createMojoNodejsProviderPackage } from "./provider/package.js";

export type MojoNodejsCapabilityPlugin = MojoProviderPackageImplementation;

export function createMojoNodejsCapability(): MojoNodejsCapabilityPlugin {
  return createMojoNodejsProviderPackage();
}
