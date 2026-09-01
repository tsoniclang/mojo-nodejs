import type {
  MojoProviderModuleDefinition,
  MojoProviderOperationDefinition,
  MojoProviderTypeDefinition,
} from "@tsonic/target-mojo/provider";
import {
  fnExport,
  functionCall,
  legacyUrlCarrier,
  optionalBoolCarrier,
  optionalStringCarrier,
  propertyMember,
  propertyRead,
  providerRef,
  stringType,
} from "../model.js";

const moduleSpecifier = "node:url";
const urlId = `${moduleSpecifier}::Url`;
const stringQueryUrlId = `${moduleSpecifier}::UrlWithStringQuery`;
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

export function urlModule(): MojoProviderModuleDefinition {
  return Object.freeze({
    moduleSpecifier,
    providerModuleId: "tsonic.mojo.node.url",
    exports: Object.freeze([
      legacyUrlExport(urlId, "Url"),
      legacyUrlExport(stringQueryUrlId, "UrlWithStringQuery"),
      fnExport(
        moduleSpecifier,
        "parse",
        Object.freeze([{ name: "input", type: stringType }]),
        providerRef(moduleSpecifier, "UrlWithStringQuery"),
      ),
    ]),
  });
}

export function urlTypes(): readonly MojoProviderTypeDefinition[] {
  return Object.freeze([urlId, stringQueryUrlId].map((exportId) => Object.freeze({
    exportId,
    sourceGenericParameters: Object.freeze([]),
    targetType: legacyUrlCarrier,
  })));
}

export function urlOperations(): readonly MojoProviderOperationDefinition[] {
  return Object.freeze([
    functionCall(
      `${moduleSpecifier}::parse`,
      `${moduleSpecifier}::parse(input)`,
      "url",
      "parse_legacy",
      Object.freeze([Object.freeze({ kind: "native-string" as const })]),
      legacyUrlCarrier,
      true,
    ),
    ...[urlId, stringQueryUrlId].flatMap((exportId) => [
      propertyRead(exportId, `${exportId}.href`, "href", legacyUrlCarrier, optionalStringCarrier),
      ...stringProperties.map((name) => propertyRead(
        exportId,
        `${exportId}.${name}`,
        name,
        legacyUrlCarrier,
        optionalStringCarrier,
      )),
      propertyRead(exportId, `${exportId}.slashes`, "slashes", legacyUrlCarrier, optionalBoolCarrier),
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
      propertyMember(id, "href", nullableStringType),
      ...stringProperties.map((propertyName) => propertyMember(
        id,
        propertyName,
        nullableStringType,
      )),
      propertyMember(id, "slashes", nullableBooleanType),
    ]),
  });
}
