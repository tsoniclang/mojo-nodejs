import type {
  MojoProviderModuleDefinition,
  MojoProviderOperationDefinition,
} from "@tsonic/target-mojo/provider";
import { fnExport, functionCall, nativeString, stringType } from "../model.js";

const moduleSpecifier = "node:os";

const functions = Object.freeze([
  ["platform", "platform", false],
  ["arch", "arch", false],
  ["hostname", "host_name", true],
  ["tmpdir", "temp_directory", true],
  ["homedir", "home_directory", true],
] as const);

export function osModule(): MojoProviderModuleDefinition {
  return Object.freeze({
    moduleSpecifier,
    providerModuleId: "tsonic.mojo.node.os",
    exports: Object.freeze(functions.map(([name]) => fnExport(moduleSpecifier, name, [], stringType))),
  });
}

export function osOperations(): readonly MojoProviderOperationDefinition[] {
  return Object.freeze(functions.map(([name, targetName, raises]) => functionCall(
    `${moduleSpecifier}::${name}`,
    `${moduleSpecifier}::${name}()`,
    "os_info",
    targetName,
    [],
    nativeString,
    raises,
  )));
}
