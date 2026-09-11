import type {
  MojoProviderModuleDefinition,
  MojoProviderOperationDefinition,
  MojoProviderTypeDefinition,
  MojoTargetTypeRef,
} from "@tsonic/target-mojo/provider";
import { mojoOptionalTargetType, mojoUnionTargetType } from "@tsonic/target-mojo/provider";
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
  nullType,
  overloadedMethodMember,
  methodMember,
  propertyMember,
  propertyRead,
  providerCallbackType,
  providerRef,
  stringType,
  tlsConnectOptionsCarrier,
  tlsServerCarrier,
  tlsServerOptionsCarrier,
  tlsSocketCallbackCarrier,
  tlsSocketCarrier,
  undefinedType,
} from "../../model.js";
import { addressCarrier, addressType } from "../net/records.js";
import { tlsEventMembers, tlsEventOperations } from "./events.js";
import { listenOptionsImport, serverListenMember, serverListenOperations } from "../net/listen-contract.js";
import { tlsConnectionFields, tlsServerFields, tlsOptionDeclaration, tlsOptionOperations } from "./options.js";

const moduleSpecifier = "node:tls";
const connectOptionsId = `${moduleSpecifier}::ConnectionOptions`;
const serverOptionsId = `${moduleSpecifier}::TlsOptions`;
const socketId = `${moduleSpecifier}::TLSSocket`;
const serverId = `${moduleSpecifier}::Server`;
const bufferType = providerRef("node:buffer", "Buffer");
const optionalBufferType = Object.freeze({
  kind: "union" as const,
  types: Object.freeze([bufferType, nullType]),
});
const optionalStringType = Object.freeze({
  kind: "union" as const,
  types: Object.freeze([stringType, undefinedType]),
});
const negotiatedStringType = Object.freeze({ kind: "union" as const, types: Object.freeze([stringType, { kind: "literal" as const, value: false }]) });
const negotiatedStringCarrier = mojoUnionTargetType([nativeString, boolCarrier]);

export function tlsModule(): MojoProviderModuleDefinition {
  return Object.freeze({
    moduleSpecifier,
    providerModuleId: "tsonic.mojo.node.tls",
    imports: Object.freeze([Object.freeze({
      moduleSpecifier: "node:buffer",
      namedImports: Object.freeze([{ exportedName: "Buffer" }]),
    }), Object.freeze({
      moduleSpecifier: "node:net",
      namedImports: Object.freeze([{ exportedName: "AddressInfo" }, ...listenOptionsImport.namedImports]),
    })]),
    exports: Object.freeze([
      tlsOptionDeclaration(connectOptionsId, "ConnectionOptions", tlsConnectionFields),
      tlsOptionDeclaration(serverOptionsId, "TlsOptions", tlsServerFields),
      Object.freeze({
        id: socketId,
        name: "TLSSocket",
        kind: "class",
        members: Object.freeze([
          ...tlsEventMembers("TLSSocket"),
          methodMember(socketId, "isPaused", [], booleanType),
          overloadedMethodMember(socketId, "write", [
            { parameters: [{ name: "value", type: bufferType }], returnType: booleanType, signatureSuffix: "buffer" },
            { parameters: [{ name: "value", type: stringType }], returnType: booleanType, signatureSuffix: "string" },
          ]),
          Object.freeze({
            id: `${socketId}.read`, name: "read", kind: "method",
            signatures: Object.freeze([Object.freeze({ id: `${socketId}.read()`, name: "read", parameters: Object.freeze([]), returnType: optionalBufferType })]),
          }),
          overloadedMethodMember(socketId, "end", [
            { parameters: [], returnType: providerRef(moduleSpecifier, "TLSSocket"), signatureSuffix: "" },
            { parameters: [{ name: "data", type: bufferType }], returnType: providerRef(moduleSpecifier, "TLSSocket"), signatureSuffix: "buffer" },
            { parameters: [{ name: "data", type: stringType }], returnType: providerRef(moduleSpecifier, "TLSSocket"), signatureSuffix: "string" },
          ]),
          overloadedMethodMember(socketId, "setNoDelay", [
            { parameters: [], returnType: providerRef(moduleSpecifier, "TLSSocket"), signatureSuffix: "" },
            { parameters: [{ name: "value", type: booleanType }], returnType: providerRef(moduleSpecifier, "TLSSocket"), signatureSuffix: "value" },
          ]),
          overloadedMethodMember(socketId, "setTimeout", [
            { parameters: [{ name: "timeout", type: numberType }], returnType: providerRef(moduleSpecifier, "TLSSocket"), signatureSuffix: "timeout" },
            { parameters: [{ name: "timeout", type: numberType }, { name: "callback", type: providerCallbackType(`${socketId}.setTimeout(timeout,callback)`, "callback", []) }], returnType: providerRef(moduleSpecifier, "TLSSocket"), signatureSuffix: "timeout,callback" },
          ]),
          ...(["ref", "unref", "pause", "resume", "destroy"] as const).map((name) => Object.freeze({
            id: `${socketId}.${name}`,
            name,
            kind: "method" as const,
            signatures: Object.freeze([Object.freeze({
              id: `${socketId}.${name}()`,
              name,
              parameters: Object.freeze([]),
              returnType: providerRef(moduleSpecifier, "TLSSocket"),
            })]),
          })),
          propertyMember(socketId, "authorized", booleanType),
          propertyMember(socketId, "authorizationError", optionalStringType),
          propertyMember(socketId, "encrypted", booleanType),
          propertyMember(socketId, "servername", { kind: "union", types: [negotiatedStringType, nullType] }),
          propertyMember(socketId, "alpnProtocol", negotiatedStringType),
          propertyMember(socketId, "bytesRead", numberType),
          propertyMember(socketId, "bytesWritten", numberType),
          propertyMember(socketId, "destroyed", booleanType),
        ]),
      }),
      Object.freeze({
        id: serverId,
        name: "Server",
        kind: "class",
        members: Object.freeze([
          ...tlsEventMembers("Server"),
          methodMember(serverId, "address", [], { kind: "union", types: [addressType, nullType] }),
          serverListenMember(moduleSpecifier),
          ...(["close", "ref", "unref"] as const).map((name) => Object.freeze({
            id: `${serverId}.${name}`,
            name,
            kind: "method" as const,
            signatures: Object.freeze([Object.freeze({
              id: `${serverId}.${name}()`,
              name,
              parameters: Object.freeze([]),
              returnType: providerRef(moduleSpecifier, "Server"),
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
          id: `${moduleSpecifier}::createServer(options)`,
          name: "createServer",
          parameters: Object.freeze([{ name: "options", type: providerRef(moduleSpecifier, "TlsOptions") }]),
          returnType: providerRef(moduleSpecifier, "Server"),
        }), Object.freeze({
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
    ...tlsEventOperations("TLSSocket", tlsSocketCarrier),
    ...tlsEventOperations("Server", tlsServerCarrier),
    ...tlsOptionOperations(connectOptionsId, tlsConnectOptionsCarrier, tlsConnectionFields),
    ...tlsOptionOperations(serverOptionsId, tlsServerOptionsCarrier, tlsServerFields),
    functionCall(`${moduleSpecifier}::connect`, `${moduleSpecifier}::connect(options)`, "tls", "connect", [tlsConnectOptionsCarrier], tlsSocketCarrier, true),
    functionCall(`${moduleSpecifier}::connect`, `${moduleSpecifier}::connect(options,callback)`, "tls", "connect_callback", [tlsConnectOptionsCarrier, emptyCallbackCarrier], tlsSocketCarrier, true),
    functionCall(`${moduleSpecifier}::createServer`, `${moduleSpecifier}::createServer(options,callback)`, "tls", "create_server", [tlsServerOptionsCarrier, tlsSocketCallbackCarrier], tlsServerCarrier, true),
    socketCall("write", "buffer", "write_buffer", [bufferCarrier], boolCarrier, true),
    socketCall("write", "string", "write_string", [nativeString], boolCarrier, true),
    socketCall("read", undefined, "read", [], mojoOptionalTargetType(bufferCarrier), true),
    socketCall("end", undefined, "end", [], tlsSocketCarrier, true),
    socketCall("end", "buffer", "end_buffer", [bufferCarrier], tlsSocketCarrier, true),
    socketCall("end", "string", "end_string", [nativeString], tlsSocketCarrier, true),
    socketCall("setNoDelay", undefined, "set_no_delay", [], tlsSocketCarrier, true),
    socketCall("setNoDelay", "value", "set_no_delay", [boolCarrier], tlsSocketCarrier, true),
    socketCall("setTimeout", "timeout", "set_timeout", [float64Carrier], tlsSocketCarrier, true),
    socketCall("setTimeout", "timeout,callback", "set_timeout_callback", [float64Carrier, emptyCallbackCarrier], tlsSocketCarrier, true),
    socketCall("isPaused", undefined, "is_paused", [], boolCarrier),
    ...["pause", "resume", "destroy"].map((name) => socketCall(name, undefined, name, [], tlsSocketCarrier)),
    socketCall("ref", undefined, "ref", [], tlsSocketCarrier),
    socketCall("unref", undefined, "unref", [], tlsSocketCarrier),
    ...socketProperty("authorized", "authorized", boolCarrier),
    ...socketProperty("authorizationError", "authorization_error", mojoOptionalTargetType(nativeString)),
    ...socketProperty("encrypted", "encrypted", boolCarrier),
    ...socketProperty("servername", "servername_value", mojoOptionalTargetType(negotiatedStringCarrier)),
    ...socketProperty("alpnProtocol", "alpn_protocol", negotiatedStringCarrier),
    ...socketProperty("bytesRead", "bytes_read", float64Carrier),
    ...socketProperty("bytesWritten", "bytes_written", float64Carrier),
    ...socketProperty("destroyed", "closed", boolCarrier),
    functionCall(`${moduleSpecifier}::createServer`, `${moduleSpecifier}::createServer(options)`, "tls", "create_server", [tlsServerOptionsCarrier], tlsServerCarrier, true),
    instanceCall(serverId, `${serverId}.address`, `${serverId}.address()`, "address", tlsServerCarrier, [], mojoOptionalTargetType(addressCarrier), true),
    ...serverListenOperations(moduleSpecifier, tlsServerCarrier),
    instanceCall(serverId, `${serverId}.close`, `${serverId}.close()`, "close", tlsServerCarrier, [], tlsServerCarrier, true, "mut"),
    instanceCall(serverId, `${serverId}.ref`, `${serverId}.ref()`, "ref", tlsServerCarrier, [], tlsServerCarrier, false, "mut"),
    instanceCall(serverId, `${serverId}.unref`, `${serverId}.unref()`, "unref", tlsServerCarrier, [], tlsServerCarrier, false, "mut"),
    propertyRead(serverId, `${serverId}.listening`, "listening", tlsServerCarrier, boolCarrier, "method"),
  ];
  return Object.freeze(rows);
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
