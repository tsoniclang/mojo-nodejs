import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { createMojoProviderPackage } from "@tsonic/target-mojo/provider";
import type { MojoProviderPackageImplementation } from "@tsonic/target-mojo/provider";
import { assertModule, assertOperations } from "./modules/assert.js";
import { bufferModule, bufferOperations, bufferTypes } from "./modules/buffer.js";
import {
  childProcessModule,
  childProcessOperations,
  childProcessTypes,
} from "./modules/child-process.js";
import { cryptoModule, cryptoOperations, cryptoTypes } from "./modules/crypto.js";
import {
  filesystemModule,
  filesystemOperations,
  filesystemTypes,
} from "./modules/filesystem.js";
import {
  filesystemPromisesModule,
  filesystemPromisesOperations,
} from "./modules/filesystem-promises.js";
import { httpModule, httpOperations, httpTypes } from "./modules/http.js";
import { osModule, osOperations } from "./modules/os.js";
import { pathModule, pathOperations } from "./modules/path.js";
import {
  processModule,
  processOperations,
  processTypes,
} from "./modules/process.js";
import { utilModule, utilOperations, utilTypes } from "./modules/util.js";
import { urlModule, urlOperations, urlTypes } from "./modules/url.js";
import { timersModule, timersOperations, timersTypes } from "./modules/timers.js";

const packageRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..");

export function createMojoNodejsProviderPackage(): MojoProviderPackageImplementation {
  return createMojoProviderPackage({
    id: "@tsonic/mojo-nodejs",
    displayName: "Node.js for Mojo",
    version: "0.0.1",
    moduleAliases: Object.freeze([
      { moduleSpecifier: "assert", canonicalModuleSpecifier: "node:assert" },
      { moduleSpecifier: "assert/strict", canonicalModuleSpecifier: "node:assert" },
      { moduleSpecifier: "node:assert/strict", canonicalModuleSpecifier: "node:assert" },
      { moduleSpecifier: "buffer", canonicalModuleSpecifier: "node:buffer" },
      { moduleSpecifier: "child_process", canonicalModuleSpecifier: "node:child_process" },
      { moduleSpecifier: "crypto", canonicalModuleSpecifier: "node:crypto" },
      { moduleSpecifier: "fs", canonicalModuleSpecifier: "node:fs" },
      { moduleSpecifier: "fs/promises", canonicalModuleSpecifier: "node:fs/promises" },
      { moduleSpecifier: "http", canonicalModuleSpecifier: "node:http" },
      { moduleSpecifier: "os", canonicalModuleSpecifier: "node:os" },
      { moduleSpecifier: "path", canonicalModuleSpecifier: "node:path" },
      { moduleSpecifier: "process", canonicalModuleSpecifier: "node:process" },
      { moduleSpecifier: "timers", canonicalModuleSpecifier: "node:timers" },
      { moduleSpecifier: "util", canonicalModuleSpecifier: "node:util" },
      { moduleSpecifier: "url", canonicalModuleSpecifier: "node:url" },
    ]),
    modules: Object.freeze([
      assertModule(),
      bufferModule(),
      childProcessModule(),
      cryptoModule(),
      filesystemModule(),
      filesystemPromisesModule(),
      httpModule(),
      osModule(),
      pathModule(),
      processModule(),
      timersModule(),
      utilModule(),
      urlModule(),
    ]),
    types: Object.freeze([
      ...bufferTypes(),
      ...childProcessTypes(),
      ...cryptoTypes(),
      ...filesystemTypes(),
      ...httpTypes(),
      ...processTypes(),
      ...timersTypes(),
      ...utilTypes(),
      ...urlTypes(),
    ]),
    operations: Object.freeze([
      ...assertOperations(),
      ...bufferOperations(),
      ...childProcessOperations(),
      ...cryptoOperations(),
      ...filesystemOperations(),
      ...filesystemPromisesOperations(),
      ...httpOperations(),
      ...osOperations(),
      ...pathOperations(),
      ...processOperations(),
      ...timersOperations(),
      ...utilOperations(),
      ...urlOperations(),
    ]),
    binaryEpilogues: Object.freeze([
      Object.freeze({
        id: "node-event-loop",
        modulePath: Object.freeze(["tsonic_node", "event_loop"]),
        name: "run_event_loop",
        raises: true,
      }),
      Object.freeze({
        id: "node-process-exit-code",
        modulePath: Object.freeze(["tsonic_node", "process"]),
        name: "apply_exit_code",
      }),
    ]),
    runtimePackages: Object.freeze([Object.freeze({
      packageName: "tsonic_node",
      packagePath: resolve(packageRoot, "mojo"),
    })]),
  });
}
