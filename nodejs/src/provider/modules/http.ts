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
  httpIncomingMessageCarrier,
  httpRequestCallbackCarrier,
  httpServerCarrier,
  httpServerResponseCarrier,
  int32Carrier,
  int32Type,
  instanceCall,
  methodMember,
  overloadedMethodMember,
  propertyMember,
  propertyRead,
  propertyWrite,
  providerCallbackType,
  providerRef,
  stringType,
  nativeString,
  nodeProviderType,
  unitCarrier,
  voidType,
} from "../model.js";

const moduleSpecifier = "node:http";
const incomingId = `${moduleSpecifier}::IncomingMessage`;
const responseId = `${moduleSpecifier}::ServerResponse`;
const serverId = `${moduleSpecifier}::Server`;

export function httpModule(): MojoProviderModuleDefinition {
  const requestCallback = providerCallbackType(
    `${moduleSpecifier}::createServer(handler)`,
    "handler",
    [
      { name: "request", type: providerRef(moduleSpecifier, "IncomingMessage") },
      { name: "response", type: providerRef(moduleSpecifier, "ServerResponse") },
    ],
  );
  const listenCallback = (signatureId: string) => providerCallbackType(signatureId, "callback", []);
  return Object.freeze({
    moduleSpecifier,
    providerModuleId: "tsonic.mojo.node.http",
    imports: Object.freeze([Object.freeze({
      moduleSpecifier: "node:buffer",
      namedImports: Object.freeze([{ exportedName: "Buffer" }]),
    })]),
    exports: Object.freeze([
      Object.freeze({
        id: incomingId,
        name: "IncomingMessage",
        kind: "class",
        members: Object.freeze([
          propertyMember(incomingId, "method", stringType),
          propertyMember(incomingId, "url", stringType),
          methodMember(incomingId, "readAll", [], stringType),
          methodMember(incomingId, "readAllBuffer", [], providerRef("node:buffer", "Buffer")),
        ]),
      }),
      Object.freeze({
        id: responseId,
        name: "ServerResponse",
        kind: "class",
        members: Object.freeze([
          propertyMember(responseId, "statusCode", int32Type, { readonly: false }),
          methodMember(responseId, "setHeader", [
            { name: "name", type: stringType },
            { name: "value", type: stringType },
          ], voidType),
          methodMember(responseId, "writeHead", [
            { name: "statusCode", type: int32Type },
            { name: "statusMessage", type: stringType },
          ], voidType),
          methodMember(responseId, "write", [
            { name: "chunk", type: providerRef("node:buffer", "Buffer") },
          ], booleanType),
          overloadedMethodMember(responseId, "end", [
            { parameters: [], returnType: voidType, signatureSuffix: "" },
            { parameters: [{ name: "chunk", type: stringType }], returnType: voidType, signatureSuffix: "string" },
            {
              parameters: [{ name: "chunk", type: providerRef("node:buffer", "Buffer") }],
              returnType: voidType,
              signatureSuffix: "buffer",
            },
          ]),
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
                { name: "port", type: int32Type },
                {
                  name: "callback",
                  type: listenCallback(`${serverId}.listen(port,callback)`),
                },
              ],
              returnType: providerRef(moduleSpecifier, "Server"),
              signatureSuffix: "port,callback",
            },
            {
              parameters: [
                { name: "port", type: int32Type },
                { name: "hostname", type: stringType },
                {
                  name: "callback",
                  type: listenCallback(`${serverId}.listen(port,hostname,callback)`),
                },
              ],
              returnType: providerRef(moduleSpecifier, "Server"),
              signatureSuffix: "port,hostname,callback",
            },
          ]),
          methodMember(serverId, "close", [], voidType),
        ]),
      }),
      Object.freeze({
        id: `${moduleSpecifier}::createServer`,
        name: "createServer",
        kind: "function",
        signatures: Object.freeze([Object.freeze({
          id: `${moduleSpecifier}::createServer(handler)`,
          name: "createServer",
          parameters: Object.freeze([{ name: "handler", type: requestCallback }]),
          returnType: providerRef(moduleSpecifier, "Server"),
        })]),
      }),
    ]),
  });
}

export function httpTypes(): readonly MojoProviderTypeDefinition[] {
  return Object.freeze([
    nodeProviderType(incomingId, httpIncomingMessageCarrier, "implicitly-copyable"),
    nodeProviderType(responseId, httpServerResponseCarrier, "implicitly-copyable"),
    nodeProviderType(serverId, httpServerCarrier, "implicitly-copyable"),
  ]);
}

export function httpOperations(): readonly MojoProviderOperationDefinition[] {
  return Object.freeze([
    Object.freeze({
      exportId: `${moduleSpecifier}::createServer`,
      signatureId: `${moduleSpecifier}::createServer(handler)`,
      operationKind: "call",
      target: Object.freeze({
        kind: "function-call",
        modulePath: Object.freeze(["tsonic_node", "http"]),
        name: "create_server",
        arguments: Object.freeze([
          Object.freeze({ convention: "imm", position: "positional-or-keyword" }),
        ]),
      }),
      parameterTypes: Object.freeze([httpRequestCallbackCarrier]),
      resultType: httpServerCarrier,
    }),
    propertyRead(incomingId, `${incomingId}.method`, "method", httpIncomingMessageCarrier, nativeString),
    propertyRead(incomingId, `${incomingId}.url`, "url", httpIncomingMessageCarrier, nativeString),
    instanceCall(incomingId, `${incomingId}.readAll`, `${incomingId}.readAll()`, "read_all", httpIncomingMessageCarrier, [], nativeString, true),
    instanceCall(incomingId, `${incomingId}.readAllBuffer`, `${incomingId}.readAllBuffer()`, "read_all_buffer", httpIncomingMessageCarrier, [], bufferCarrier),
    propertyRead(responseId, `${responseId}.statusCode`, "status_code", httpServerResponseCarrier, int32Carrier, "method"),
    propertyWrite(responseId, `${responseId}.statusCode`, "set_status_code", httpServerResponseCarrier, int32Carrier, "method"),
    instanceCall(responseId, `${responseId}.setHeader`, `${responseId}.setHeader(name,value)`, "set_header", httpServerResponseCarrier, [nativeString, nativeString], unitCarrier, true),
    instanceCall(responseId, `${responseId}.writeHead`, `${responseId}.writeHead(statusCode,statusMessage)`, "write_head", httpServerResponseCarrier, [int32Carrier, nativeString], unitCarrier, true),
    instanceCall(responseId, `${responseId}.write`, `${responseId}.write(chunk)`, "write_buffer", httpServerResponseCarrier, [bufferCarrier], boolCarrier, true),
    instanceCall(responseId, `${responseId}.end`, `${responseId}.end()`, "end_empty", httpServerResponseCarrier, [], unitCarrier, true),
    instanceCall(responseId, `${responseId}.end`, `${responseId}.end(string)`, "end_string", httpServerResponseCarrier, [nativeString], unitCarrier, true),
    instanceCall(responseId, `${responseId}.end`, `${responseId}.end(buffer)`, "end_buffer", httpServerResponseCarrier, [bufferCarrier], unitCarrier, true),
    instanceCall(serverId, `${serverId}.listen`, `${serverId}.listen(port,callback)`, "listen_default_host", httpServerCarrier, [int32Carrier, emptyCallbackCarrier], httpServerCarrier, true),
    instanceCall(serverId, `${serverId}.listen`, `${serverId}.listen(port,hostname,callback)`, "listen", httpServerCarrier, [int32Carrier, nativeString, emptyCallbackCarrier], httpServerCarrier, true),
    instanceCall(serverId, `${serverId}.close`, `${serverId}.close()`, "close", httpServerCarrier, [], unitCarrier),
  ]);
}
