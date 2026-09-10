import type { MojoProviderModuleDefinition, MojoProviderOperationDefinition, MojoProviderTypeDefinition } from "@tsonic/target-mojo/provider";
import { constantValue, functionValue, nativeString, propertyMember, propertyRead, providerRef, stringType, valueExport } from "../../model.js";
import { dialectId, dialectCarrier, pathRecordDeclarations, pathRecordOperations, pathRecordTypes } from "./records.js";
import { pathCallOperations, pathDialectMembers, pathFunctionDeclarations } from "./operations.js";

const moduleSpecifier = "node:path";
const dialectType = providerRef(moduleSpecifier, "PlatformPath");

export function pathModule(): MojoProviderModuleDefinition {
  return Object.freeze({
    moduleSpecifier, providerModuleId: "tsonic.mojo.node.path",
    exports: Object.freeze([
      ...pathRecordDeclarations(),
      Object.freeze({ id: dialectId, name: "PlatformPath", kind: "interface" as const, members: Object.freeze([
        ...pathDialectMembers(),
        propertyMember(dialectId, "sep", stringType), propertyMember(dialectId, "delimiter", stringType),
        propertyMember(dialectId, "posix", dialectType), propertyMember(dialectId, "win32", dialectType),
      ]) }),
      ...pathFunctionDeclarations(),
      valueExport(moduleSpecifier, "sep", stringType),
      valueExport(moduleSpecifier, "delimiter", stringType),
      valueExport(moduleSpecifier, "posix", dialectType),
      valueExport(moduleSpecifier, "win32", dialectType),
    ]),
  });
}

export function pathTypes(): readonly MojoProviderTypeDefinition[] {
  return Object.freeze(pathRecordTypes());
}

export function pathOperations(): readonly MojoProviderOperationDefinition[] {
  return Object.freeze([
    ...pathRecordOperations(), ...pathCallOperations(false), ...pathCallOperations(true),
    constantValue(`${moduleSpecifier}::sep`, "path", "separator", nativeString),
    constantValue(`${moduleSpecifier}::delimiter`, "path", "delimiter", nativeString),
    functionValue(`${moduleSpecifier}::posix`, "path", "posix_value", dialectCarrier),
    functionValue(`${moduleSpecifier}::win32`, "path", "win32_value", dialectCarrier),
    propertyRead(dialectId, `${dialectId}.sep`, "separator", dialectCarrier, nativeString, "method"),
    propertyRead(dialectId, `${dialectId}.delimiter`, "delimiter", dialectCarrier, nativeString, "method"),
    propertyRead(dialectId, `${dialectId}.posix`, "posix", dialectCarrier, dialectCarrier, "method"),
    propertyRead(dialectId, `${dialectId}.win32`, "win32", dialectCarrier, dialectCarrier, "method"),
  ]);
}
