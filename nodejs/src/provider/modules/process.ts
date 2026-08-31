import type {
  MojoProviderModuleDefinition,
  MojoProviderOperationDefinition,
} from "@tsonic/target-mojo/provider";
import {
  fnExport,
  functionCall,
  nativeIntCarrier,
  nativeString,
  numberType,
  stringType,
  unitCarrier,
  voidType,
} from "../model.js";

const moduleSpecifier = "node:process";

export function processModule(): MojoProviderModuleDefinition {
  return Object.freeze({
    moduleSpecifier,
    providerModuleId: "tsonic.mojo.node.process",
    exports: Object.freeze([
      fnExport(moduleSpecifier, "cwd", [], stringType),
      fnExport(moduleSpecifier, "chdir", [{ name: "directory", type: stringType }], voidType),
      fnExport(moduleSpecifier, "exit", [{ name: "code", type: numberType }], voidType),
    ]),
  });
}

export function processOperations(): readonly MojoProviderOperationDefinition[] {
  return Object.freeze([
    functionCall(`${moduleSpecifier}::cwd`, `${moduleSpecifier}::cwd()`, "process", "current_directory", [], nativeString, true),
    functionCall(`${moduleSpecifier}::chdir`, `${moduleSpecifier}::chdir(directory)`, "process", "change_directory", [nativeString], unitCarrier, true),
    functionCall(`${moduleSpecifier}::exit`, `${moduleSpecifier}::exit(code)`, "process", "exit", [nativeIntCarrier], unitCarrier),
  ]);
}
