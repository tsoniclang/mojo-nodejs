import type {
  MojoProviderModuleDefinition,
  MojoProviderOperationDefinition,
} from "@tsonic/target-mojo/provider";
import {
  fnExport,
  functionCall,
  nativeString,
  overloadedFunctionExport,
  stringType,
} from "../model.js";

const moduleSpecifier = "node:path";

export function pathModule(): MojoProviderModuleDefinition {
  return Object.freeze({
    moduleSpecifier,
    providerModuleId: "tsonic.mojo.node.path",
    exports: Object.freeze([
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
    ]),
  });
}

export function pathOperations(): readonly MojoProviderOperationDefinition[] {
  return Object.freeze([
    functionCall(`${moduleSpecifier}::normalize`, `${moduleSpecifier}::normalize(path)`, "path", "normalize", [nativeString], nativeString),
    functionCall(`${moduleSpecifier}::isAbsolute`, `${moduleSpecifier}::isAbsolute(path)`, "path", "is_absolute", [nativeString], { kind: "source-primitive", name: "bool" }),
    functionCall(`${moduleSpecifier}::dirname`, `${moduleSpecifier}::dirname(path)`, "path", "dirname", [nativeString], nativeString),
    functionCall(`${moduleSpecifier}::extname`, `${moduleSpecifier}::extname(path)`, "path", "extname", [nativeString], nativeString),
    functionCall(`${moduleSpecifier}::basename`, `${moduleSpecifier}::basename(path)`, "path", "basename", [nativeString], nativeString),
    functionCall(`${moduleSpecifier}::basename`, `${moduleSpecifier}::basename(path,suffix)`, "path", "basename", [nativeString, nativeString], nativeString),
    functionCall(`${moduleSpecifier}::relative`, `${moduleSpecifier}::relative(from,to)`, "path", "relative", [nativeString, nativeString], nativeString, true),
  ]);
}
