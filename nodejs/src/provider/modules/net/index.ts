import { mojoOptionalTargetType } from "@tsonic/target-mojo/provider";
import type {
  MojoProviderModuleDefinition,
  MojoProviderOperationDefinition,
  MojoProviderTypeDefinition,
} from "@tsonic/target-mojo/provider";
import {
  booleanType,
  boolCarrier,
  bufferCarrier,
  emptyCallbackCarrier,
  float64Carrier,
  functionCall,
  instanceCall,
  methodMember,
  nativeString,
  nodeProviderType,
  netConnectionCallbackCarrier,
  netServerCarrier,
  netSocketCarrier,
  numberType,
  overloadedFunctionExport,
  overloadedMethodMember,
  propertyMember,
  propertyRead,
  providerCallbackType,
  providerRef,
  stringType,
} from "../../model.js";
import { networkEventMembers, networkEventOperations } from "./events.js";
import {
  addressCarrier, addressType, connectionOptionsCarrier, connectionOptionsType,
  networkRecordExports, networkRecordTypes, networkRecordOperations,
  serverOptionsCarrier, serverOptionsType,
} from "./records.js";

const moduleSpecifier = "node:net";
const socketId = `${moduleSpecifier}::Socket`;
const serverId = `${moduleSpecifier}::Server`;
const bufferType = providerRef("node:buffer", "Buffer");
const nullableBufferType = Object.freeze({ kind: "union" as const, types: Object.freeze([bufferType, Object.freeze({ kind: "null" as const })]) });
const nullableAddressType = Object.freeze({ kind: "union" as const, types: Object.freeze([addressType, Object.freeze({ kind: "null" as const })]) });

export function netModule(): MojoProviderModuleDefinition {
  const emptyCallback = (id: string) => providerCallbackType(id, "callback", []);
  return Object.freeze({
    moduleSpecifier,
    providerModuleId: "tsonic.mojo.node.net",
    imports: Object.freeze([Object.freeze({
      moduleSpecifier: "node:buffer",
      namedImports: Object.freeze([{ exportedName: "Buffer" }]),
    })]),
    exports: Object.freeze([
      ...networkRecordExports,
      Object.freeze({
        id: socketId,
        name: "Socket",
        kind: "class",
        members: Object.freeze([
          ...networkEventMembers("Socket"),
          methodMember(socketId, "address", [], nullableAddressType),
          methodMember(socketId, "isPaused", [], booleanType),
          overloadedMethodMember(socketId, "write", [
            { parameters: [{ name: "data", type: bufferType }], returnType: booleanType, signatureSuffix: "buffer" },
            { parameters: [{ name: "data", type: stringType }], returnType: booleanType, signatureSuffix: "string" },
          ]),
          methodMember(socketId, "read", [], nullableBufferType),
          overloadedMethodMember(socketId, "end", [
            { parameters: [], returnType: providerRef(moduleSpecifier, "Socket"), signatureSuffix: "" },
            { parameters: [{ name: "data", type: bufferType }], returnType: providerRef(moduleSpecifier, "Socket"), signatureSuffix: "buffer" },
            { parameters: [{ name: "data", type: stringType }], returnType: providerRef(moduleSpecifier, "Socket"), signatureSuffix: "string" },
          ]),
          ...(["destroy", "ref", "unref", "pause", "resume"] as const).map((name) =>
            methodMember(socketId, name, [], providerRef(moduleSpecifier, "Socket"))),
          overloadedMethodMember(socketId, "setNoDelay", [
            { parameters: [], returnType: providerRef(moduleSpecifier, "Socket"), signatureSuffix: "" },
            { parameters: [{ name: "value", type: booleanType }], returnType: providerRef(moduleSpecifier, "Socket"), signatureSuffix: "value" },
          ]),
          overloadedMethodMember(socketId, "setTimeout", [
            { parameters: [{ name: "timeout", type: numberType }], returnType: providerRef(moduleSpecifier, "Socket"), signatureSuffix: "timeout" },
            { parameters: [{ name: "timeout", type: numberType }, { name: "callback", type: emptyCallback(`${socketId}.setTimeout(timeout,callback)`) }], returnType: providerRef(moduleSpecifier, "Socket"), signatureSuffix: "timeout,callback" },
          ]),
          propertyMember(socketId, "bytesRead", numberType),
          propertyMember(socketId, "bytesWritten", numberType),
          propertyMember(socketId, "destroyed", booleanType),
          propertyMember(socketId, "pending", booleanType),
        ]),
      }),
      Object.freeze({
        id: serverId,
        name: "Server",
        kind: "class",
        members: Object.freeze([
          ...networkEventMembers("Server"),
          methodMember(serverId, "address", [], nullableAddressType),
          overloadedMethodMember(serverId, "listen", [
            { parameters: [{ name: "port", type: numberType }], returnType: providerRef(moduleSpecifier, "Server"), signatureSuffix: "port" },
            { parameters: [{ name: "port", type: numberType }, { name: "host", type: stringType }], returnType: providerRef(moduleSpecifier, "Server"), signatureSuffix: "port,host" },
            { parameters: [{ name: "port", type: numberType }, { name: "callback", type: emptyCallback(`${serverId}.listen(port,callback)`) }], returnType: providerRef(moduleSpecifier, "Server"), signatureSuffix: "port,callback" },
            { parameters: [{ name: "port", type: numberType }, { name: "host", type: stringType }, { name: "callback", type: emptyCallback(`${serverId}.listen(port,host,callback)`) }], returnType: providerRef(moduleSpecifier, "Server"), signatureSuffix: "port,host,callback" },
          ]),
          methodMember(serverId, "close", [], providerRef(moduleSpecifier, "Server")),
          methodMember(serverId, "ref", [], providerRef(moduleSpecifier, "Server")),
          methodMember(serverId, "unref", [], providerRef(moduleSpecifier, "Server")),
          propertyMember(serverId, "listening", booleanType),
        ]),
      }),
      overloadedFunctionExport(moduleSpecifier, "createConnection", [
        { parameters: [{ name: "options", type: connectionOptionsType }], returnType: providerRef(moduleSpecifier, "Socket"), signatureSuffix: "options" },
        { parameters: [{ name: "options", type: connectionOptionsType }, { name: "callback", type: emptyCallback(`${moduleSpecifier}::createConnection(options,callback)`) }], returnType: providerRef(moduleSpecifier, "Socket"), signatureSuffix: "options,callback" },
        { parameters: [{ name: "port", type: numberType }], returnType: providerRef(moduleSpecifier, "Socket"), signatureSuffix: "port" },
        { parameters: [{ name: "port", type: numberType }, { name: "host", type: stringType }], returnType: providerRef(moduleSpecifier, "Socket"), signatureSuffix: "port,host" },
        { parameters: [{ name: "port", type: numberType }, { name: "callback", type: emptyCallback(`${moduleSpecifier}::createConnection(port,callback)`) }], returnType: providerRef(moduleSpecifier, "Socket"), signatureSuffix: "port,callback" },
        { parameters: [{ name: "port", type: numberType }, { name: "host", type: stringType }, { name: "callback", type: emptyCallback(`${moduleSpecifier}::createConnection(port,host,callback)`) }], returnType: providerRef(moduleSpecifier, "Socket"), signatureSuffix: "port,host,callback" },
      ]),
      overloadedFunctionExport(moduleSpecifier, "createServer", [
        { parameters: [{ name: "options", type: serverOptionsType }], returnType: providerRef(moduleSpecifier, "Server"), signatureSuffix: "options" },
        { parameters: [{ name: "options", type: serverOptionsType }, { name: "callback", type: providerCallbackType(`${moduleSpecifier}::createServer(options,callback)`, "callback", [{ name: "socket", type: providerRef(moduleSpecifier, "Socket") }]) }], returnType: providerRef(moduleSpecifier, "Server"), signatureSuffix: "options,callback" },
        { parameters: [], returnType: providerRef(moduleSpecifier, "Server"), signatureSuffix: "" },
        { parameters: [{ name: "callback", type: providerCallbackType(`${moduleSpecifier}::createServer(callback)`, "callback", [{ name: "socket", type: providerRef(moduleSpecifier, "Socket") }]) }], returnType: providerRef(moduleSpecifier, "Server"), signatureSuffix: "callback" },
      ]),
      ...(["isIP", "isIPv4", "isIPv6"] as const).map((name) => Object.freeze({
        id: `${moduleSpecifier}::${name}`,
        name,
        kind: "function" as const,
        signatures: Object.freeze([Object.freeze({
          id: `${moduleSpecifier}::${name}(input)`,
          name,
          parameters: Object.freeze([{ name: "input", type: stringType }]),
          returnType: name === "isIP" ? numberType : booleanType,
        })]),
      })),
    ]),
  });
}

export function netTypes(): readonly MojoProviderTypeDefinition[] {
  return Object.freeze([
    ...networkRecordTypes,
    nodeProviderType(socketId, netSocketCarrier, "implicitly-copyable"),
    nodeProviderType(serverId, netServerCarrier, "implicitly-copyable"),
  ]);
}

export function netOperations(): readonly MojoProviderOperationDefinition[] {
  const rows: MojoProviderOperationDefinition[] = [
    ...networkRecordOperations,
    ...networkEventOperations("Socket", netSocketCarrier),
    ...networkEventOperations("Server", netServerCarrier),
    instanceCall(socketId, `${socketId}.address`, `${socketId}.address()`, "address", netSocketCarrier, [], mojoOptionalTargetType(addressCarrier), true),
    instanceCall(serverId, `${serverId}.address`, `${serverId}.address()`, "address", netServerCarrier, [], mojoOptionalTargetType(addressCarrier), true),
    instanceCall(socketId, `${socketId}.isPaused`, `${socketId}.isPaused()`, "is_paused", netSocketCarrier, [], boolCarrier),
    instanceCall(socketId, `${socketId}.setTimeout`, `${socketId}.setTimeout(timeout,callback)`, "set_timeout_callback", netSocketCarrier, [float64Carrier, emptyCallbackCarrier], netSocketCarrier, true, "mut"),
    ...connectionOperations(),
    functionCall(`${moduleSpecifier}::createServer`, `${moduleSpecifier}::createServer()`, "net", "create_server", [], netServerCarrier),
    functionCall(`${moduleSpecifier}::createServer`, `${moduleSpecifier}::createServer(callback)`, "net", "create_server_callback", [netConnectionCallbackCarrier], netServerCarrier, true),
    functionCall(`${moduleSpecifier}::createServer`, `${moduleSpecifier}::createServer(options)`, "net", "create_server_options", [serverOptionsCarrier], netServerCarrier),
    functionCall(`${moduleSpecifier}::createServer`, `${moduleSpecifier}::createServer(options,callback)`, "net", "create_server_options_callback", [serverOptionsCarrier, netConnectionCallbackCarrier], netServerCarrier, true),
    functionCall(`${moduleSpecifier}::isIP`, `${moduleSpecifier}::isIP(input)`, "net", "is_ip", [nativeString], float64Carrier),
    functionCall(`${moduleSpecifier}::isIPv4`, `${moduleSpecifier}::isIPv4(input)`, "net", "is_ipv4", [nativeString], boolCarrier),
    functionCall(`${moduleSpecifier}::isIPv6`, `${moduleSpecifier}::isIPv6(input)`, "net", "is_ipv6", [nativeString], boolCarrier),
    instanceCall(socketId, `${socketId}.write`, `${socketId}.write(buffer)`, "write_buffer", netSocketCarrier, [bufferCarrier], boolCarrier, true, "mut"),
    instanceCall(socketId, `${socketId}.write`, `${socketId}.write(string)`, "write_string", netSocketCarrier, [nativeString], boolCarrier, true, "mut"),
    instanceCall(socketId, `${socketId}.read`, `${socketId}.read()`, "read", netSocketCarrier, [], mojoOptionalTargetType(bufferCarrier), false, "mut"),
    instanceCall(socketId, `${socketId}.end`, `${socketId}.end()`, "end", netSocketCarrier, [], netSocketCarrier, true, "mut"),
    instanceCall(socketId, `${socketId}.end`, `${socketId}.end(buffer)`, "end_buffer", netSocketCarrier, [bufferCarrier], netSocketCarrier, true, "mut"),
    instanceCall(socketId, `${socketId}.end`, `${socketId}.end(string)`, "end_string", netSocketCarrier, [nativeString], netSocketCarrier, true, "mut"),
    instanceCall(socketId, `${socketId}.destroy`, `${socketId}.destroy()`, "destroy", netSocketCarrier, [], netSocketCarrier, false, "mut"),
    ...(["ref", "unref", "pause", "resume"] as const).map((name) =>
      instanceCall(socketId, `${socketId}.${name}`, `${socketId}.${name}()`, name, netSocketCarrier, [], netSocketCarrier, false, "mut")),
    instanceCall(socketId, `${socketId}.setNoDelay`, `${socketId}.setNoDelay(value)`, "set_no_delay", netSocketCarrier, [boolCarrier], netSocketCarrier, true, "mut"),
    instanceCall(socketId, `${socketId}.setNoDelay`, `${socketId}.setNoDelay()`, "set_no_delay", netSocketCarrier, [], netSocketCarrier, true, "mut"),
    instanceCall(socketId, `${socketId}.setTimeout`, `${socketId}.setTimeout(timeout)`, "set_timeout", netSocketCarrier, [float64Carrier], netSocketCarrier, true, "mut"),
    propertyRead(socketId, `${socketId}.bytesRead`, "bytes_read", netSocketCarrier, float64Carrier, "method"),
    propertyRead(socketId, `${socketId}.bytesWritten`, "bytes_written", netSocketCarrier, float64Carrier, "method"),
    propertyRead(socketId, `${socketId}.destroyed`, "destroyed", netSocketCarrier, boolCarrier, "method"),
    propertyRead(socketId, `${socketId}.pending`, "pending", netSocketCarrier, boolCarrier, "method"),
    instanceCall(serverId, `${serverId}.close`, `${serverId}.close()`, "close", netServerCarrier, [], netServerCarrier, true, "mut"),
    instanceCall(serverId, `${serverId}.ref`, `${serverId}.ref()`, "ref", netServerCarrier, [], netServerCarrier, false, "mut"),
    instanceCall(serverId, `${serverId}.unref`, `${serverId}.unref()`, "unref", netServerCarrier, [], netServerCarrier, false, "mut"),
    propertyRead(serverId, `${serverId}.listening`, "listening", netServerCarrier, boolCarrier, "method"),
  ];
  for (const [signature, target, parameters] of [
    ["port", "listen_port", [float64Carrier]],
    ["port,host", "listen_port_host", [float64Carrier, nativeString]],
    ["port,callback", "listen_port_callback", [float64Carrier, emptyCallbackCarrier]],
    ["port,host,callback", "listen_port_host_callback", [float64Carrier, nativeString, emptyCallbackCarrier]],
  ] as const) {
    rows.push(instanceCall(serverId, `${serverId}.listen`, `${serverId}.listen(${signature})`, target, netServerCarrier, parameters, netServerCarrier, true, "mut"));
  }
  return Object.freeze(rows);
}

function connectionOperations(): readonly MojoProviderOperationDefinition[] {
  return Object.freeze(([
    ["options", "create_connection_options", [connectionOptionsCarrier]],
    ["options,callback", "create_connection_options_callback", [connectionOptionsCarrier, emptyCallbackCarrier]],
    ["port", "create_connection", [float64Carrier]],
    ["port,host", "create_connection_host", [float64Carrier, nativeString]],
    ["port,callback", "create_connection_callback", [float64Carrier, emptyCallbackCarrier]],
    ["port,host,callback", "create_connection_host_callback", [float64Carrier, nativeString, emptyCallbackCarrier]],
  ] as const).map(([signature, target, parameters]) =>
    functionCall(`${moduleSpecifier}::createConnection`, `${moduleSpecifier}::createConnection(${signature})`, "net", target, parameters, netSocketCarrier, true)));
}
