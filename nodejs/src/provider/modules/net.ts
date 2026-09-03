import type {
  MojoProviderModuleDefinition,
  MojoProviderOperationDefinition,
  MojoProviderTypeDefinition,
  MojoTargetTypeRef,
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
  unitCarrier,
  voidType,
} from "../model.js";

const moduleSpecifier = "node:net";
const socketId = `${moduleSpecifier}::Socket`;
const serverId = `${moduleSpecifier}::Server`;
const bufferType = providerRef("node:buffer", "Buffer");

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
      Object.freeze({
        id: socketId,
        name: "Socket",
        kind: "class",
        members: Object.freeze([
          overloadedMethodMember(socketId, "write", [
            { parameters: [{ name: "data", type: bufferType }], returnType: booleanType, signatureSuffix: "buffer" },
            { parameters: [{ name: "data", type: stringType }], returnType: booleanType, signatureSuffix: "string" },
          ]),
          methodMember(socketId, "read", [], bufferType),
          overloadedMethodMember(socketId, "end", [
            { parameters: [], returnType: voidType, signatureSuffix: "" },
            { parameters: [{ name: "data", type: bufferType }], returnType: voidType, signatureSuffix: "buffer" },
            { parameters: [{ name: "data", type: stringType }], returnType: voidType, signatureSuffix: "string" },
          ]),
          ...(["destroy", "ref", "unref", "pause", "resume"] as const).map((name) =>
            methodMember(socketId, name, [], name === "destroy" ? voidType : providerRef(moduleSpecifier, "Socket"))),
          methodMember(socketId, "setNoDelay", [{ name: "value", type: booleanType }], providerRef(moduleSpecifier, "Socket")),
          methodMember(socketId, "setTimeout", [{ name: "timeout", type: numberType }], providerRef(moduleSpecifier, "Socket")),
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
          overloadedMethodMember(serverId, "listen", [
            { parameters: [{ name: "port", type: numberType }], returnType: providerRef(moduleSpecifier, "Server"), signatureSuffix: "port" },
            { parameters: [{ name: "port", type: numberType }, { name: "host", type: stringType }], returnType: providerRef(moduleSpecifier, "Server"), signatureSuffix: "port,host" },
            { parameters: [{ name: "port", type: numberType }, { name: "callback", type: emptyCallback(`${serverId}.listen(port,callback)`) }], returnType: providerRef(moduleSpecifier, "Server"), signatureSuffix: "port,callback" },
            { parameters: [{ name: "port", type: numberType }, { name: "host", type: stringType }, { name: "callback", type: emptyCallback(`${serverId}.listen(port,host,callback)`) }], returnType: providerRef(moduleSpecifier, "Server"), signatureSuffix: "port,host,callback" },
          ]),
          methodMember(serverId, "close", [], voidType),
          methodMember(serverId, "ref", [], providerRef(moduleSpecifier, "Server")),
          methodMember(serverId, "unref", [], providerRef(moduleSpecifier, "Server")),
          propertyMember(serverId, "listening", booleanType),
        ]),
      }),
      overloadedFunctionExport(moduleSpecifier, "createConnection", [
        { parameters: [{ name: "port", type: numberType }], returnType: providerRef(moduleSpecifier, "Socket"), signatureSuffix: "port" },
        { parameters: [{ name: "port", type: numberType }, { name: "host", type: stringType }], returnType: providerRef(moduleSpecifier, "Socket"), signatureSuffix: "port,host" },
        { parameters: [{ name: "port", type: numberType }, { name: "callback", type: emptyCallback(`${moduleSpecifier}::createConnection(port,callback)`) }], returnType: providerRef(moduleSpecifier, "Socket"), signatureSuffix: "port,callback" },
        { parameters: [{ name: "port", type: numberType }, { name: "host", type: stringType }, { name: "callback", type: emptyCallback(`${moduleSpecifier}::createConnection(port,host,callback)`) }], returnType: providerRef(moduleSpecifier, "Socket"), signatureSuffix: "port,host,callback" },
      ]),
      overloadedFunctionExport(moduleSpecifier, "createServer", [
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
    Object.freeze({ exportId: socketId, sourceGenericParameters: Object.freeze([]), targetType: netSocketCarrier }),
    Object.freeze({ exportId: serverId, sourceGenericParameters: Object.freeze([]), targetType: netServerCarrier }),
  ]);
}

export function netOperations(): readonly MojoProviderOperationDefinition[] {
  const rows: MojoProviderOperationDefinition[] = [
    ...connectionOperations(),
    functionCall(`${moduleSpecifier}::createServer`, `${moduleSpecifier}::createServer()`, "net", "create_server", [], netServerCarrier),
    functionCall(`${moduleSpecifier}::createServer`, `${moduleSpecifier}::createServer(callback)`, "net", "create_server_callback", [netConnectionCallbackCarrier], netServerCarrier),
    functionCall(`${moduleSpecifier}::isIP`, `${moduleSpecifier}::isIP(input)`, "net", "is_ip", [nativeString], float64Carrier),
    functionCall(`${moduleSpecifier}::isIPv4`, `${moduleSpecifier}::isIPv4(input)`, "net", "is_ipv4", [nativeString], boolCarrier),
    functionCall(`${moduleSpecifier}::isIPv6`, `${moduleSpecifier}::isIPv6(input)`, "net", "is_ipv6", [nativeString], boolCarrier),
    instanceCall(socketId, `${socketId}.write`, `${socketId}.write(buffer)`, "write_buffer", netSocketCarrier, [bufferCarrier], boolCarrier, true, "mut"),
    instanceCall(socketId, `${socketId}.write`, `${socketId}.write(string)`, "write_string", netSocketCarrier, [nativeString], boolCarrier, true, "mut"),
    instanceCall(socketId, `${socketId}.read`, `${socketId}.read()`, "read", netSocketCarrier, [], bufferCarrier, true, "mut"),
    instanceCall(socketId, `${socketId}.end`, `${socketId}.end()`, "end", netSocketCarrier, [], unitCarrier, true, "mut"),
    instanceCall(socketId, `${socketId}.end`, `${socketId}.end(buffer)`, "end_buffer", netSocketCarrier, [bufferCarrier], unitCarrier, true, "mut"),
    instanceCall(socketId, `${socketId}.end`, `${socketId}.end(string)`, "end_string", netSocketCarrier, [nativeString], unitCarrier, true, "mut"),
    instanceCall(socketId, `${socketId}.destroy`, `${socketId}.destroy()`, "destroy", netSocketCarrier, [], unitCarrier, false, "mut"),
    ...(["ref", "unref", "pause", "resume"] as const).map((name) =>
      instanceCall(socketId, `${socketId}.${name}`, `${socketId}.${name}()`, name, netSocketCarrier, [], netSocketCarrier, false, "mut")),
    instanceCall(socketId, `${socketId}.setNoDelay`, `${socketId}.setNoDelay(value)`, "set_no_delay", netSocketCarrier, [boolCarrier], netSocketCarrier, true, "mut"),
    instanceCall(socketId, `${socketId}.setTimeout`, `${socketId}.setTimeout(timeout)`, "set_timeout", netSocketCarrier, [float64Carrier], netSocketCarrier, true, "mut"),
    propertyRead(socketId, `${socketId}.bytesRead`, "bytes_read", netSocketCarrier, float64Carrier, "method"),
    propertyRead(socketId, `${socketId}.bytesWritten`, "bytes_written", netSocketCarrier, float64Carrier, "method"),
    propertyRead(socketId, `${socketId}.destroyed`, "destroyed", netSocketCarrier, boolCarrier, "method"),
    propertyRead(socketId, `${socketId}.pending`, "pending", netSocketCarrier, boolCarrier, "method"),
    instanceCall(serverId, `${serverId}.close`, `${serverId}.close()`, "close", netServerCarrier, [], unitCarrier, false, "mut"),
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
    ["port", "create_connection", [float64Carrier]],
    ["port,host", "create_connection_host", [float64Carrier, nativeString]],
    ["port,callback", "create_connection_callback", [float64Carrier, emptyCallbackCarrier]],
    ["port,host,callback", "create_connection_host_callback", [float64Carrier, nativeString, emptyCallbackCarrier]],
  ] as const).map(([signature, target, parameters]) =>
    functionCall(`${moduleSpecifier}::createConnection`, `${moduleSpecifier}::createConnection(${signature})`, "net", target, parameters, netSocketCarrier, true)));
}
