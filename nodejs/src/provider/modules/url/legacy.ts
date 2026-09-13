import type {
  MojoProviderModuleDefinition,
  MojoProviderOperationDefinition,
  MojoProviderTypeDefinition,
} from "@tsonic/target-mojo/provider";
import {
  fnExport,
  functionCall,
  legacyUrlCarrier,
  nodeProviderType,
  optionalBoolCarrier,
  optionalStringCarrier,
  overloadedFunctionExport,
  propertyMember,
  propertyRead,
  propertyWrite,
  providerRef,
  stringType,
} from "../../model.js";

const moduleSpecifier = "node:url";
const urlId = `${moduleSpecifier}::Url`;
const stringQueryUrlId = `${moduleSpecifier}::UrlWithStringQuery`;
const objectId = `${moduleSpecifier}::UrlObject`;
const nullableStringType = Object.freeze({
  kind: "union" as const,
  types: Object.freeze([
    stringType,
    Object.freeze({ kind: "literal" as const, value: null }),
  ]),
});
const nullableBooleanType = Object.freeze({
  kind: "union" as const,
  types: Object.freeze([
    Object.freeze({ kind: "boolean" as const }),
    Object.freeze({ kind: "literal" as const, value: null }),
  ]),
});
const stringProperties = Object.freeze([
  "protocol",
  "auth",
  "host",
  "hostname",
  "port",
  "pathname",
  "search",
  "query",
  "hash",
  "path",
]);

export function legacyUrlModule(): MojoProviderModuleDefinition {
  return Object.freeze({
    moduleSpecifier,
    providerModuleId: "tsonic.mojo.node.url",
    exports: Object.freeze([
      legacyUrlExport(urlId, "Url"),
      legacyUrlExport(stringQueryUrlId, "UrlWithStringQuery"),
      Object.freeze({ ...legacyUrlExport(objectId, "UrlObject"), members: Object.freeze([
        ...["href", ...stringProperties].map((name) => propertyMember(objectId, name, nullableStringType, { optional: true, readonly: false })),
        propertyMember(objectId, "slashes", nullableBooleanType, { optional: true, readonly: false }),
      ]) }),
      overloadedFunctionExport(moduleSpecifier, "format", [
        { signatureSuffix: "object", parameters: [{ name: "value", type: providerRef(moduleSpecifier, "UrlObject") }], returnType: stringType },
        { signatureSuffix: "string", parameters: [{ name: "value", type: stringType }], returnType: stringType },
        { signatureSuffix: "URL", parameters: [{ name: "value", type: providerRef(moduleSpecifier, "URL") }], returnType: stringType },
      ]),
      fnExport(
        moduleSpecifier,
        "parse",
        Object.freeze([{ name: "input", type: stringType }]),
        providerRef(moduleSpecifier, "UrlWithStringQuery"),
      ),
      fnExport(moduleSpecifier, "resolve", [{ name: "from", type: stringType }, { name: "to", type: stringType }], stringType),
    ]),
  });
}

export function legacyUrlTypes(): readonly MojoProviderTypeDefinition[] {
  return Object.freeze([
    ...[urlId, stringQueryUrlId].map((exportId) => nodeProviderType(exportId, legacyUrlCarrier, "copyable")),
    nodeProviderType(objectId, legacyUrlCarrier, "copyable", { objectLiteralConstruction: true }),
  ]);
}

export function legacyUrlOperations(): readonly MojoProviderOperationDefinition[] {
  return Object.freeze([
    functionCall(`${moduleSpecifier}::resolve`, `${moduleSpecifier}::resolve(from,to)`, "url", "resolve", [{ kind: "native-string" }, { kind: "native-string" }], { kind: "native-string" }, true),
    functionCall(
      `${moduleSpecifier}::parse`,
      `${moduleSpecifier}::parse(input)`,
      "url",
      "parse_legacy",
      Object.freeze([Object.freeze({ kind: "native-string" as const })]),
      legacyUrlCarrier,
      true,
    ),
    functionCall(`${moduleSpecifier}::format`, `${moduleSpecifier}::format(object)`, "url", "format_url", [legacyUrlCarrier], { kind: "native-string" }, true),
    functionCall(`${moduleSpecifier}::format`, `${moduleSpecifier}::format(string)`, "url", "format_url", [{ kind: "native-string" }], { kind: "native-string" }, true),
    ...[urlId, stringQueryUrlId, objectId].flatMap((exportId) => [
      ...["href", ...stringProperties].flatMap((name) => [
        propertyRead(exportId, `${exportId}.${name}`, name, legacyUrlCarrier, optionalStringCarrier),
        propertyWrite(exportId, `${exportId}.${name}`, name, legacyUrlCarrier, optionalStringCarrier),
      ]),
      propertyRead(exportId, `${exportId}.slashes`, "slashes", legacyUrlCarrier, optionalBoolCarrier),
      propertyWrite(exportId, `${exportId}.slashes`, "slashes", legacyUrlCarrier, optionalBoolCarrier),
    ]),
  ]);
}

function legacyUrlExport(
  id: string,
  name: string,
): MojoProviderModuleDefinition["exports"][number] {
  return Object.freeze({
    id,
    name,
    kind: "interface",
    members: Object.freeze([
      propertyMember(id, "href", nullableStringType, { readonly: false }),
      ...stringProperties.map((propertyName) => propertyMember(
        id,
        propertyName,
        nullableStringType,
        { readonly: false },
      )),
      propertyMember(id, "slashes", nullableBooleanType, { readonly: false }),
    ]),
  });
}
