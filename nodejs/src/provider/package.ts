import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { createMojoProviderPackage } from "@tsonic/target-mojo/provider";
import type { MojoProviderPackageImplementation } from "@tsonic/target-mojo/provider";
import { bufferModule, bufferTypes } from "./modules/buffer.js";
import {
  filesystemModule,
  filesystemOperations,
  filesystemTypes,
} from "./modules/filesystem.js";
import { osModule, osOperations } from "./modules/os.js";
import { pathModule, pathOperations } from "./modules/path.js";
import { processModule, processOperations } from "./modules/process.js";

const packageRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..");

export function createMojoNodejsProviderPackage(): MojoProviderPackageImplementation {
  return createMojoProviderPackage({
    id: "@tsonic/mojo-nodejs",
    displayName: "Node.js for Mojo",
    version: "0.0.1",
    moduleAliases: Object.freeze([
      { moduleSpecifier: "buffer", canonicalModuleSpecifier: "node:buffer" },
      { moduleSpecifier: "fs", canonicalModuleSpecifier: "node:fs" },
      { moduleSpecifier: "os", canonicalModuleSpecifier: "node:os" },
      { moduleSpecifier: "path", canonicalModuleSpecifier: "node:path" },
      { moduleSpecifier: "process", canonicalModuleSpecifier: "node:process" },
    ]),
    modules: Object.freeze([
      bufferModule(),
      filesystemModule(),
      osModule(),
      pathModule(),
      processModule(),
    ]),
    types: Object.freeze([...bufferTypes(), ...filesystemTypes()]),
    operations: Object.freeze([
      ...filesystemOperations(),
      ...osOperations(),
      ...pathOperations(),
      ...processOperations(),
    ]),
    runtimePackages: Object.freeze([Object.freeze({
      packageName: "tsonic_node",
      packagePath: resolve(packageRoot, "mojo"),
    })]),
  });
}
