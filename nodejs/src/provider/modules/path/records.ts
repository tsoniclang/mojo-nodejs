import { mojoNamedTargetType } from "@tsonic/target-mojo/provider";
import { nativeString, optionalStringCarrier, nodeProviderType, propertyMember, propertyRead, propertyWrite, stringType } from "../../model.js";

export const parsedId = "node:path::ParsedPath";
export const inputId = "node:path::FormatInputPathObject";
export const dialectId = "node:path::PlatformPath";
export const parsedCarrier = mojoNamedTargetType("tsonic.mojo.node.path.PathParts", ["tsonic_node", "path"], "PathParts");
export const inputCarrier = mojoNamedTargetType("tsonic.mojo.node.path.PathInput", ["tsonic_node", "path"], "PathInput");
export const dialectCarrier = mojoNamedTargetType("tsonic.mojo.node.path.PathDialect", ["tsonic_node", "path"], "PathDialect");

const fields = [
  ["root", "root"], ["dir", "directory"], ["base", "base"], ["name", "name"], ["ext", "extension"],
] as const;

export function pathRecordDeclarations() {
  return [parsedId, inputId].map((id) => Object.freeze({
    id, name: id === parsedId ? "ParsedPath" : "FormatInputPathObject", kind: "interface" as const,
    members: Object.freeze(fields.map(([name]) => propertyMember(id, name, stringType, { readonly: false, optional: id === inputId }))),
  }));
}

export function pathRecordTypes() {
  return [
    nodeProviderType(parsedId, parsedCarrier, "copyable", { objectLiteralConstruction: true }),
    nodeProviderType(inputId, inputCarrier, "copyable", { objectLiteralConstruction: true }),
    nodeProviderType(dialectId, dialectCarrier, "implicitly-copyable"),
  ];
}

export function pathRecordOperations() {
  return [parsedId, inputId].flatMap((id) => fields.flatMap(([name, targetName]) => {
    const receiver = id === parsedId ? parsedCarrier : inputCarrier;
    const value = id === parsedId ? nativeString : optionalStringCarrier;
    return [propertyRead(id, `${id}.${name}`, targetName, receiver, value),
      propertyWrite(id, `${id}.${name}`, targetName, receiver, value)];
  }));
}
