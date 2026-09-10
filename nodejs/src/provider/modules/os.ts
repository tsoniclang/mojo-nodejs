import type {
  MojoProviderModuleDefinition,
  MojoProviderOperationDefinition,
} from "@tsonic/target-mojo/provider";
import { float64Carrier, fnExport, functionCall, functionValue, nativeString, numberArrayType, numberListCarrier, numberType, stringType, valueExport } from "../model.js";

const moduleSpecifier = "node:os";

const functions = Object.freeze([
  ["platform", "platform", false],
  ["arch", "arch", false],
  ["eol", "end_of_line", false],
  ["hostname", "host_name", true],
  ["tmpdir", "temp_directory", true],
  ["homedir", "home_directory", true],
  ["endianness", "endianness", false],
  ["machine", "machine", true],
  ["release", "release", true],
  ["type", "system_type", true],
  ["version", "version", true],
] as const);

const numericFunctions = Object.freeze([
  ["availableParallelism", "available_parallelism", false],
  ["freemem", "free_memory", false],
  ["totalmem", "total_memory", false],
  ["uptime", "uptime", true],
] as const);

export function osModule(): MojoProviderModuleDefinition {
  return Object.freeze({
    moduleSpecifier,
    providerModuleId: "tsonic.mojo.node.os",
    exports: Object.freeze([
      ...functions.map(([name]) => fnExport(moduleSpecifier, name, [], stringType)),
      ...numericFunctions.map(([name]) => fnExport(moduleSpecifier, name, [], numberType)),
      fnExport(moduleSpecifier, "loadavg", [], numberArrayType),
      valueExport(moduleSpecifier, "EOL", stringType),
      valueExport(moduleSpecifier, "devNull", stringType),
    ]),
  });
}

export function osOperations(): readonly MojoProviderOperationDefinition[] {
  return Object.freeze([...functions.map(([name, targetName, raises]) => functionCall(
    `${moduleSpecifier}::${name}`,
    `${moduleSpecifier}::${name}()`,
    "os_info",
    targetName,
    [],
    nativeString,
    raises,
  )), ...numericFunctions.map(([name, targetName, raises]) => functionCall(
    `${moduleSpecifier}::${name}`, `${moduleSpecifier}::${name}()`, "os_info", targetName, [], float64Carrier, raises,
  )),
    functionCall(`${moduleSpecifier}::loadavg`, `${moduleSpecifier}::loadavg()`, "os_info", "load_average", [], numberListCarrier),
    functionValue(`${moduleSpecifier}::EOL`, "os_info", "end_of_line", nativeString),
    functionValue(`${moduleSpecifier}::devNull`, "os_info", "dev_null", nativeString),
  ]);
}
