import type {
  MojoProviderModuleDefinition,
  MojoProviderOperationDefinition,
  MojoProviderTypeDefinition,
} from "@tsonic/target-mojo/provider";
import { mojoNamedTargetType } from "@tsonic/target-mojo/provider";
import {
  fnExport,
  functionCall,
  constantValue,
  nativeString,
  optionalStringCarrier,
  nodeProviderType,
  propertyMember,
  propertyRead,
  propertyWrite,
  providerRef,
  overloadedFunctionExport,
  stringArrayType,
  stringType,
  valueExport,
  variadicFunctionCall,
} from "../model.js";

const moduleSpecifier = "node:path";
const parsedId = `${moduleSpecifier}::ParsedPath`;
const inputId = `${moduleSpecifier}::FormatInputPathObject`;
const parsedCarrier = mojoNamedTargetType("tsonic.mojo.node.path.PathParts", ["tsonic_node", "path"], "PathParts");
const inputCarrier = mojoNamedTargetType("tsonic.mojo.node.path.PathInput", ["tsonic_node", "path"], "PathInput");
const fields = Object.freeze([
  ["root", "root"], ["dir", "directory"], ["base", "base"], ["name", "name"], ["ext", "extension"],
] as const);

export function pathModule(): MojoProviderModuleDefinition {
  return Object.freeze({
    moduleSpecifier,
    providerModuleId: "tsonic.mojo.node.path",
    exports: Object.freeze([
      ...[parsedId, inputId].map((id) => Object.freeze({
        id,
        name: id === parsedId ? "ParsedPath" : "FormatInputPathObject",
        kind: "interface" as const,
        members: Object.freeze(fields.map(([name]) => propertyMember(id, name, stringType, { readonly: false, optional: id === inputId }))),
      })),
      fnExport(moduleSpecifier, "parse", [{ name: "path", type: stringType }], providerRef(moduleSpecifier, "ParsedPath")),
      overloadedFunctionExport(moduleSpecifier, "format", [
        { signatureSuffix: "parsed", parameters: [{ name: "pathObject", type: providerRef(moduleSpecifier, "ParsedPath") }], returnType: stringType },
        { signatureSuffix: "input", parameters: [{ name: "pathObject", type: providerRef(moduleSpecifier, "FormatInputPathObject") }], returnType: stringType },
      ]),
      fnExport(moduleSpecifier, "join", [{ name: "paths", type: stringArrayType, rest: true }], stringType),
      fnExport(moduleSpecifier, "resolve", [{ name: "paths", type: stringArrayType, rest: true }], stringType),
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
      valueExport(moduleSpecifier, "delimiter", stringType),
    ]),
  });
}

export function pathTypes(): readonly MojoProviderTypeDefinition[] {
  return Object.freeze([
    nodeProviderType(parsedId, parsedCarrier, "copyable", { objectLiteralConstruction: true }),
    nodeProviderType(inputId, inputCarrier, "copyable", { objectLiteralConstruction: true }),
  ]);
}

export function pathOperations(): readonly MojoProviderOperationDefinition[] {
  return Object.freeze([
    functionCall(`${moduleSpecifier}::parse`, `${moduleSpecifier}::parse(path)`, "path", "parse", [nativeString], parsedCarrier),
    functionCall(`${moduleSpecifier}::format`, `${moduleSpecifier}::format(parsed)`, "path", "format_path", [parsedCarrier], nativeString),
    functionCall(`${moduleSpecifier}::format`, `${moduleSpecifier}::format(input)`, "path", "format_path", [inputCarrier], nativeString),
    ...[parsedId, inputId].flatMap((id) => fields.flatMap(([name, targetName]) => {
      const receiver = id === parsedId ? parsedCarrier : inputCarrier;
      const value = id === parsedId ? nativeString : optionalStringCarrier;
      return [propertyRead(id, `${id}.${name}`, targetName, receiver, value),
        propertyWrite(id, `${id}.${name}`, targetName, receiver, value)];
    })),
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
    constantValue(`${moduleSpecifier}::delimiter`, "path", "delimiter", nativeString),
  ]);
}
