import { mojoNamedTargetType, mojoOptionalTargetType, mojoUnionTargetType } from "@tsonic/target-mojo/provider";
import type { MojoProviderModuleDefinition, MojoProviderOperationDefinition, MojoProviderTypeDefinition, MojoTargetTypeRef } from "@tsonic/target-mojo/provider";
import {
  booleanType, boolCarrier, bufferCarrier, float64Carrier, functionCall, httpResponseCallbackCarrier,
  instanceCall, methodMember, nativeString, nodeProviderType, numberType, optionalBoolCarrier,
  optionalFloat64Carrier, optionalStringCarrier, overloadedFunctionExport, overloadedMethodMember,
  propertyMember, propertyRead, propertyWrite, providerCallbackType, providerRef,
  stringArrayType, stringListCarrier, stringType, unitCarrier, voidType,
} from "../../model.js";

type SourceType = Parameters<typeof propertyMember>[2];
type ModuleSpecifier = "node:http" | "node:https";
type OptionField = readonly [source: string, native: string, type: SourceType, target: MojoTargetTypeRef];
const clientCarrier = mojoNamedTargetType("tsonic.mojo.node.http.ClientRequest", ["tsonic_node", "http"], "ClientRequest");
const optionsCarrier = mojoNamedTargetType("tsonic.mojo.node.http.RequestOptions", ["tsonic_node", "http"], "RequestOptions");
const certificateType = Object.freeze({ kind: "union" as const, types: Object.freeze([stringType, providerRef("node:buffer", "Buffer")]) });
const authoritiesType = Object.freeze({ kind: "union" as const, types: Object.freeze([stringType, providerRef("node:buffer", "Buffer"), stringArrayType]) });
const commonFields: readonly OptionField[] = Object.freeze([
  ["hostname", "hostname", stringType, optionalStringCarrier],
  ["path", "path", stringType, optionalStringCarrier],
  ["method", "method", stringType, optionalStringCarrier],
  ["protocol", "protocol", stringType, optionalStringCarrier],
  ["port", "port", numberType, optionalFloat64Carrier],
  ["timeout", "timeout", numberType, optionalFloat64Carrier],
]);
const tlsFields: readonly OptionField[] = Object.freeze([
  ["ca", "ca", authoritiesType, mojoOptionalTargetType(mojoUnionTargetType([nativeString, bufferCarrier, stringListCarrier]))],
  ["cert", "cert", certificateType, mojoOptionalTargetType(mojoUnionTargetType([nativeString, bufferCarrier]))],
  ["key", "key", certificateType, mojoOptionalTargetType(mojoUnionTargetType([nativeString, bufferCarrier]))],
  ["pfx", "pfx", providerRef("node:buffer", "Buffer"), mojoOptionalTargetType(bufferCarrier)],
  ["passphrase", "passphrase", stringType, optionalStringCarrier],
  ["minVersion", "min_version", stringType, optionalStringCarrier],
  ["maxVersion", "max_version", stringType, optionalStringCarrier],
  ["rejectUnauthorized", "reject_unauthorized", booleanType, optionalBoolCarrier],
]);
const fields = (module: ModuleSpecifier) => module === "node:http" ? commonFields : [...commonFields, ...tlsFields];

export function httpClientExports(module: ModuleSpecifier): MojoProviderModuleDefinition["exports"] {
  const clientId = `${module}::ClientRequest`;
  const optionsId = `${module}::RequestOptions`;
  const clientType = providerRef(module, "ClientRequest");
  return Object.freeze([
    Object.freeze({ id: optionsId, name: "RequestOptions", kind: "interface", members: Object.freeze(fields(module).map(([name, , type]) => propertyMember(optionsId, name, type, { optional: true, readonly: false }))) }),
    Object.freeze({ id: clientId, name: "ClientRequest", kind: "class", members: Object.freeze([
      overloadedMethodMember(clientId, "write", [
        { parameters: [{ name: "chunk", type: stringType }], returnType: booleanType, signatureSuffix: "string" },
        { parameters: [{ name: "chunk", type: providerRef("node:buffer", "Buffer") }], returnType: booleanType, signatureSuffix: "buffer" },
      ]),
      overloadedMethodMember(clientId, "end", [
        { parameters: [], returnType: clientType },
        { parameters: [{ name: "chunk", type: stringType }], returnType: clientType, signatureSuffix: "string" },
        { parameters: [{ name: "chunk", type: providerRef("node:buffer", "Buffer") }], returnType: clientType, signatureSuffix: "buffer" },
      ]),
      methodMember(clientId, "setHeader", [{ name: "name", type: stringType }, { name: "value", type: stringType }], voidType),
      methodMember(clientId, "removeHeader", [{ name: "name", type: stringType }], voidType),
      methodMember(clientId, "destroy", [], clientType),
      ...["path", "method", "host", "protocol"].map((name) => propertyMember(clientId, name, stringType)),
    ]) }),
    ...(["request", "get"] as const).map((name) => overloadedFunctionExport(module, name,
      (["url", "options"] as const).flatMap((kind) => {
        const parameter = Object.freeze({ name: kind, type: kind === "url" ? stringType : providerRef(module, "RequestOptions") });
        return [
          { parameters: [parameter], returnType: clientType },
          { parameters: [parameter, { name: "callback", type: providerCallbackType(`${module}::${name}(${kind},callback)`, "callback", [{ name: "response", type: providerRef("node:http", "IncomingMessage") }]) }], returnType: clientType },
        ];
      }))),
  ]);
}

export function httpClientTypes(module: ModuleSpecifier): readonly MojoProviderTypeDefinition[] {
  return Object.freeze([
    nodeProviderType(`${module}::ClientRequest`, clientCarrier, "implicitly-copyable"),
    nodeProviderType(`${module}::RequestOptions`, optionsCarrier, "copyable", { objectLiteralConstruction: true }),
  ]);
}

export function httpClientOperations(module: ModuleSpecifier): readonly MojoProviderOperationDefinition[] {
  const clientId = `${module}::ClientRequest`;
  const optionsId = `${module}::RequestOptions`;
  const nativeModule = module === "node:http" ? "http" : "https";
  const operations: MojoProviderOperationDefinition[] = [];
  for (const [name, target, result, parameters, suffix] of [
    ["write", "write_string", boolCarrier, [nativeString], "string"],
    ["write", "write_buffer", boolCarrier, [bufferCarrier], "buffer"],
    ["end", "end", clientCarrier, [], ""],
    ["end", "end_string", clientCarrier, [nativeString], "string"],
    ["end", "end_buffer", clientCarrier, [bufferCarrier], "buffer"],
    ["setHeader", "set_header", unitCarrier, [nativeString, nativeString], "name,value"],
    ["removeHeader", "remove_header", unitCarrier, [nativeString], "name"],
    ["destroy", "destroy", clientCarrier, [], ""],
  ] as const) operations.push(instanceCall(clientId, `${clientId}.${name}`, `${clientId}.${name}(${suffix})`, target, clientCarrier, parameters, result, name !== "destroy"));
  for (const name of ["path", "method", "host", "protocol"]) {
    operations.push(Object.freeze({ ...propertyRead(clientId, `${clientId}.${name}`, name, clientCarrier, nativeString, "method"), ...(name !== "method" ? { raises: true } : {}) }));
  }
  for (const [source, target, , carrier] of fields(module)) {
    operations.push(propertyRead(optionsId, `${optionsId}.${source}`, target, optionsCarrier, carrier), propertyWrite(optionsId, `${optionsId}.${source}`, target, optionsCarrier, carrier));
  }
  for (const name of ["request", "get"]) {
    for (const [kind, carrier] of [["url", nativeString], ["options", optionsCarrier]] as const) {
      operations.push(functionCall(`${module}::${name}`, `${module}::${name}(${kind})`, nativeModule, name, [carrier], clientCarrier, true));
      operations.push(functionCall(`${module}::${name}`, `${module}::${name}(${kind},callback)`, nativeModule, name, [carrier, mojoOptionalTargetType(httpResponseCallbackCarrier)], clientCarrier, true));
    }
  }
  return Object.freeze(operations);
}
