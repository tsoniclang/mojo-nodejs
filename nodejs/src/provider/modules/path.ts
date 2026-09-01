import type {
  MojoProviderModuleDefinition,
  MojoProviderOperationDefinition,
} from "@tsonic/target-mojo/provider";
import {
  fnExport,
  functionCall,
  constantValue,
  nativeString,
  overloadedFunctionExport,
  stringType,
  valueExport,
  variadicFunctionCall,
} from "../model.js";

const moduleSpecifier = "node:path";

export function pathModule(): MojoProviderModuleDefinition {
  return Object.freeze({
    moduleSpecifier,
    providerModuleId: "tsonic.mojo.node.path",
    exports: Object.freeze([
      fnExport(moduleSpecifier, "join", [{ name: "paths", type: stringType, rest: true }], stringType),
      fnExport(moduleSpecifier, "resolve", [{ name: "paths", type: stringType, rest: true }], stringType),
      fnExport(moduleSpecifier, "normalize", [{ name: "path", type: stringType }], stringType),
      fnExport(moduleSpecifier, "isAbsolute", [{ name: "path", type: stringType }], { kind: "boolean" }),
      fnExport(moduleSpecifier, "dirname", [{ name: "path", type: stringType }], stringType),
      fnExport(moduleSpecifier, "extname", [{ name: "path", type: stringType }], stringType),
      overloadedFunctionExport(moduleSpecifier, "basename", [
        {
          parameters: [{ name: "path", type: stringType }],
          returnType: stringType,
        },
        {
          parameters: [
            { name: "path", type: stringType },
            { name: "suffix", type: stringType },
          ],
          returnType: stringType,
        },
      ]),
      fnExport(moduleSpecifier, "relative", [
        { name: "from", type: stringType },
        { name: "to", type: stringType },
      ], stringType),
      valueExport(moduleSpecifier, "sep", stringType),
    ]),
  });
}

export function pathOperations(): readonly MojoProviderOperationDefinition[] {
  return Object.freeze([
    variadicFunctionCall(`${moduleSpecifier}::join`, `${moduleSpecifier}::join(paths)`, "path", "join", nativeString, nativeString),
    variadicFunctionCall(`${moduleSpecifier}::resolve`, `${moduleSpecifier}::resolve(paths)`, "path", "resolve", nativeString, nativeString, true),
    functionCall(`${moduleSpecifier}::normalize`, `${moduleSpecifier}::normalize(path)`, "path", "normalize", [nativeString], nativeString),
    functionCall(`${moduleSpecifier}::isAbsolute`, `${moduleSpecifier}::isAbsolute(path)`, "path", "is_absolute", [nativeString], { kind: "source-primitive", name: "bool" }),
    functionCall(`${moduleSpecifier}::dirname`, `${moduleSpecifier}::dirname(path)`, "path", "dirname", [nativeString], nativeString),
    functionCall(`${moduleSpecifier}::extname`, `${moduleSpecifier}::extname(path)`, "path", "extname", [nativeString], nativeString),
    functionCall(`${moduleSpecifier}::basename`, `${moduleSpecifier}::basename(path)`, "path", "basename", [nativeString], nativeString),
    functionCall(`${moduleSpecifier}::basename`, `${moduleSpecifier}::basename(path,suffix)`, "path", "basename", [nativeString, nativeString], nativeString),
    functionCall(`${moduleSpecifier}::relative`, `${moduleSpecifier}::relative(from,to)`, "path", "relative", [nativeString, nativeString], nativeString, true),
    constantValue(`${moduleSpecifier}::sep`, "path", "separator", nativeString),
  ]);
}
