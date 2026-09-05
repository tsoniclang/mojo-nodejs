import type {
  MojoProviderModuleDefinition,
  MojoProviderOperationDefinition,
  MojoProviderTypeDefinition,
  MojoTargetTypeRef,
} from "@tsonic/target-mojo/provider";
import { mojoOptionalTargetType } from "@tsonic/target-mojo/provider";
import {
  booleanType,
  boolCarrier,
  bufferCarrier,
  emptyCallbackCarrier,
  float64Carrier,
  functionCall,
  instanceCall,
  nativeString,
  nodeProviderType,
  numberType,
  overloadedMethodMember,
  propertyMember,
  propertyRead,
  propertyWrite,
  providerCallbackType,
  providerRef,
  stringArrayType,
  stringListCarrier,
  stringType,
  tlsConnectOptionsCarrier,
  tlsServerCarrier,
  tlsServerOptionsCarrier,
  tlsSocketCallbackCarrier,
  tlsSocketCarrier,
  undefinedType,
  unitCarrier,
  voidType,
} from "../model.js";

const moduleSpecifier = "node:tls";
const connectOptionsId = `${moduleSpecifier}::ConnectionOptions`;
const serverOptionsId = `${moduleSpecifier}::TlsOptions`;
const socketId = `${moduleSpecifier}::TLSSocket`;
const serverId = `${moduleSpecifier}::Server`;
const bufferType = providerRef("node:buffer", "Buffer");
const optionalBufferType = Object.freeze({
  kind: "union" as const,
  types: Object.freeze([bufferType, undefinedType]),
});
const optionalStringType = Object.freeze({
  kind: "union" as const,
  types: Object.freeze([stringType, undefinedType]),
});

export function tlsModule(): MojoProviderModuleDefinition {
  return Object.freeze({
    moduleSpecifier,
    providerModuleId: "tsonic.mojo.node.tls",
    imports: Object.freeze([Object.freeze({
      moduleSpecifier: "node:buffer",
      namedImports: Object.freeze([{ exportedName: "Buffer" }]),
    })]),
    exports: Object.freeze([
      optionsDeclaration(connectOptionsId, "ConnectionOptions", [
        ["host", stringType],
        ["servername", stringType],
        ["port", numberType],
        ["ALPNProtocols", stringArrayType],
        ["rejectUnauthorized", booleanType],
        ["ca", stringArrayType],
        ["timeout", numberType],
      ]),
      optionsDeclaration(serverOptionsId, "TlsOptions", [
        ["key", stringType],
        ["cert", stringType],
        ["ca", stringArrayType],
        ["ALPNProtocols", stringArrayType],
        ["requestCert", booleanType],
        ["rejectUnauthorized", booleanType],
      ]),
      Object.freeze({
        id: socketId,
        name: "TLSSocket",
        kind: "class",
        members: Object.freeze([
          overloadedMethodMember(socketId, "write", [
            { parameters: [{ name: "value", type: bufferType }], returnType: booleanType, signatureSuffix: "buffer" },
            { parameters: [{ name: "value", type: stringType }], returnType: booleanType, signatureSuffix: "string" },
          ]),
          Object.freeze({
            id: `${socketId}.read`, name: "read", kind: "method",
            signatures: Object.freeze([Object.freeze({ id: `${socketId}.read()`, name: "read", parameters: Object.freeze([]), returnType: optionalBufferType })]),
          }),
          ...(["end", "ref", "unref"] as const).map((name) => Object.freeze({
            id: `${socketId}.${name}`,
            name,
            kind: "method" as const,
            signatures: Object.freeze([Object.freeze({
              id: `${socketId}.${name}()`,
              name,
              parameters: Object.freeze([]),
              returnType: name === "end" ? voidType : providerRef(moduleSpecifier, "TLSSocket"),
            })]),
          })),
          propertyMember(socketId, "authorized", booleanType),
          propertyMember(socketId, "authorizationError", optionalStringType),
          propertyMember(socketId, "encrypted", booleanType),
          propertyMember(socketId, "servername", stringType),
          propertyMember(socketId, "alpnProtocol", optionalStringType),
          propertyMember(socketId, "bytesRead", numberType),
          propertyMember(socketId, "bytesWritten", numberType),
        ]),
      }),
      Object.freeze({
        id: serverId,
        name: "Server",
        kind: "class",
        members: Object.freeze([
          overloadedMethodMember(serverId, "listen", [
            {
              parameters: [
                { name: "port", type: numberType },
                { name: "callback", type: providerCallbackType(`${serverId}.listen(port,callback)`, "callback", []) },
              ],
              returnType: providerRef(moduleSpecifier, "Server"),
              signatureSuffix: "port,callback",
            },
            {
              parameters: [
                { name: "port", type: numberType },
                { name: "host", type: stringType },
                { name: "callback", type: providerCallbackType(`${serverId}.listen(port,host,callback)`, "callback", []) },
              ],
              returnType: providerRef(moduleSpecifier, "Server"),
              signatureSuffix: "port,host,callback",
            },
          ]),
          ...(["close", "ref", "unref"] as const).map((name) => Object.freeze({
            id: `${serverId}.${name}`,
            name,
            kind: "method" as const,
            signatures: Object.freeze([Object.freeze({
              id: `${serverId}.${name}()`,
              name,
              parameters: Object.freeze([]),
              returnType: name === "close" ? voidType : providerRef(moduleSpecifier, "Server"),
            })]),
          })),
          propertyMember(serverId, "listening", booleanType),
        ]),
      }),
      Object.freeze({
        id: `${moduleSpecifier}::connect`,
        name: "connect",
        kind: "function",
        signatures: Object.freeze([
          Object.freeze({
            id: `${moduleSpecifier}::connect(options)`,
            name: "connect",
            parameters: Object.freeze([{ name: "options", type: providerRef(moduleSpecifier, "ConnectionOptions") }]),
            returnType: providerRef(moduleSpecifier, "TLSSocket"),
          }),
          Object.freeze({
            id: `${moduleSpecifier}::connect(options,callback)`,
            name: "connect",
            parameters: Object.freeze([
              { name: "options", type: providerRef(moduleSpecifier, "ConnectionOptions") },
              { name: "callback", type: providerCallbackType(`${moduleSpecifier}::connect(options,callback)`, "callback", []) },
            ]),
            returnType: providerRef(moduleSpecifier, "TLSSocket"),
          }),
        ]),
      }),
      Object.freeze({
        id: `${moduleSpecifier}::createServer`,
        name: "createServer",
        kind: "function",
        signatures: Object.freeze([Object.freeze({
          id: `${moduleSpecifier}::createServer(options,callback)`,
          name: "createServer",
          parameters: Object.freeze([
            { name: "options", type: providerRef(moduleSpecifier, "TlsOptions") },
            { name: "callback", type: providerCallbackType(`${moduleSpecifier}::createServer(options,callback)`, "callback", [{ name: "socket", type: providerRef(moduleSpecifier, "TLSSocket") }]) },
          ]),
          returnType: providerRef(moduleSpecifier, "Server"),
        })]),
      }),
    ]),
  });
}

export function tlsTypes(): readonly MojoProviderTypeDefinition[] {
  return Object.freeze([
    nodeProviderType(connectOptionsId, tlsConnectOptionsCarrier, "copyable", {
      objectLiteralConstruction: true,
    }),
    nodeProviderType(serverOptionsId, tlsServerOptionsCarrier, "copyable", {
      objectLiteralConstruction: true,
    }),
    nodeProviderType(socketId, tlsSocketCarrier, "implicitly-copyable"),
    nodeProviderType(serverId, tlsServerCarrier, "implicitly-copyable"),
  ]);
}

export function tlsOperations(): readonly MojoProviderOperationDefinition[] {
  const rows: MojoProviderOperationDefinition[] = [
    ...options(connectOptionsId, tlsConnectOptionsCarrier, [
      ["host", "host", mojoOptionalTargetType(nativeString)],
      ["servername", "servername", mojoOptionalTargetType(nativeString)],
      ["port", "port", mojoOptionalTargetType(float64Carrier)],
      ["ALPNProtocols", "alpn_protocols", mojoOptionalTargetType(stringListCarrier)],
      ["rejectUnauthorized", "reject_unauthorized", mojoOptionalTargetType(boolCarrier)],
      ["ca", "ca", mojoOptionalTargetType(stringListCarrier)],
      ["timeout", "timeout", mojoOptionalTargetType(float64Carrier)],
    ]),
    ...options(serverOptionsId, tlsServerOptionsCarrier, [
      ["key", "key", mojoOptionalTargetType(nativeString)],
      ["cert", "cert", mojoOptionalTargetType(nativeString)],
      ["ca", "ca", mojoOptionalTargetType(stringListCarrier)],
      ["ALPNProtocols", "alpn_protocols", mojoOptionalTargetType(stringListCarrier)],
      ["requestCert", "request_cert", mojoOptionalTargetType(boolCarrier)],
      ["rejectUnauthorized", "reject_unauthorized", mojoOptionalTargetType(boolCarrier)],
    ]),
    functionCall(`${moduleSpecifier}::connect`, `${moduleSpecifier}::connect(options)`, "tls", "connect", [tlsConnectOptionsCarrier], tlsSocketCarrier, true),
    functionCall(`${moduleSpecifier}::connect`, `${moduleSpecifier}::connect(options,callback)`, "tls", "connect_callback", [tlsConnectOptionsCarrier, emptyCallbackCarrier], tlsSocketCarrier, true),
    functionCall(`${moduleSpecifier}::createServer`, `${moduleSpecifier}::createServer(options,callback)`, "tls", "create_server", [tlsServerOptionsCarrier, tlsSocketCallbackCarrier], tlsServerCarrier, true),
    socketCall("write", "buffer", "write_buffer", [bufferCarrier], boolCarrier, true),
    socketCall("write", "string", "write_string", [nativeString], boolCarrier, true),
    socketCall("read", undefined, "read", [], mojoOptionalTargetType(bufferCarrier), true),
    socketCall("end", undefined, "end", [], unitCarrier, true),
    socketCall("ref", undefined, "ref", [], tlsSocketCarrier),
    socketCall("unref", undefined, "unref", [], tlsSocketCarrier),
    ...socketProperty("authorized", "authorized", boolCarrier),
    ...socketProperty("authorizationError", "authorization_error", mojoOptionalTargetType(nativeString)),
    ...socketProperty("encrypted", "encrypted", boolCarrier),
    ...socketProperty("servername", "servername_value", nativeString),
    ...socketProperty("alpnProtocol", "alpn_protocol", mojoOptionalTargetType(nativeString)),
    ...socketProperty("bytesRead", "bytes_read", float64Carrier),
    ...socketProperty("bytesWritten", "bytes_written", float64Carrier),
    instanceCall(serverId, `${serverId}.listen`, `${serverId}.listen(port,callback)`, "listen_default_host", tlsServerCarrier, [float64Carrier, emptyCallbackCarrier], tlsServerCarrier, true, "mut"),
    instanceCall(serverId, `${serverId}.listen`, `${serverId}.listen(port,host,callback)`, "listen", tlsServerCarrier, [float64Carrier, nativeString, emptyCallbackCarrier], tlsServerCarrier, true, "mut"),
    instanceCall(serverId, `${serverId}.close`, `${serverId}.close()`, "close", tlsServerCarrier, [], unitCarrier, false, "mut"),
    instanceCall(serverId, `${serverId}.ref`, `${serverId}.ref()`, "ref", tlsServerCarrier, [], tlsServerCarrier, false, "mut"),
    instanceCall(serverId, `${serverId}.unref`, `${serverId}.unref()`, "unref", tlsServerCarrier, [], tlsServerCarrier, false, "mut"),
    propertyRead(serverId, `${serverId}.listening`, "listening", tlsServerCarrier, boolCarrier, "method"),
  ];
  return Object.freeze(rows);
}

function optionsDeclaration(
  id: string,
  name: string,
  fields: readonly (readonly [string, Parameters<typeof propertyMember>[2]])[],
) {
  return Object.freeze({
    id,
    name,
    kind: "interface" as const,
    members: Object.freeze(fields.map(([field, type]) => propertyMember(id, field, type, {
      readonly: false,
      optional: true,
    }))),
  });
}

function options(
  exportId: string,
  receiverType: MojoTargetTypeRef,
  fields: readonly (readonly [string, string, MojoTargetTypeRef])[],
): readonly MojoProviderOperationDefinition[] {
  return Object.freeze(fields.flatMap(([sourceName, targetName, type]) => [
    propertyRead(exportId, `${exportId}.${sourceName}`, targetName, receiverType, type),
    propertyWrite(exportId, `${exportId}.${sourceName}`, targetName, receiverType, type),
  ]));
}

function socketCall(
  member: string,
  signature: string | undefined,
  targetName: string,
  parameters: readonly MojoTargetTypeRef[],
  resultType: MojoTargetTypeRef,
  raises = false,
): MojoProviderOperationDefinition {
  return instanceCall(
    socketId,
    `${socketId}.${member}`,
    `${socketId}.${member}(${signature ?? ""})`,
    targetName,
    tlsSocketCarrier,
    parameters,
    resultType,
    raises,
    "mut",
  );
}

function socketProperty(
  member: string,
  targetName: string,
  resultType: MojoTargetTypeRef,
): readonly MojoProviderOperationDefinition[] {
  return Object.freeze([
    propertyRead(socketId, `${socketId}.${member}`, targetName, tlsSocketCarrier, resultType, "method"),
  ]);
}
