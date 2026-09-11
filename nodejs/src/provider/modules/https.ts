import type {
  MojoProviderModuleDefinition,
  MojoProviderOperationDefinition,
  MojoProviderTypeDefinition,
} from "@tsonic/target-mojo/provider";
import {
  booleanType,
  boolCarrier,
  functionCall,
  httpRequestCallbackCarrier,
  httpsServerCarrier,
  instanceCall,
  nodeProviderType,
  propertyMember,
  propertyRead,
  providerCallbackType,
  providerRef,
  tlsServerOptionsCarrier,
  unitCarrier,
  voidType,
} from "../model.js";
import { httpClientExports, httpClientOperations, httpClientTypes } from "./http/client.js";
import { tlsServerFields, tlsOptionMembers, tlsOptionOperations } from "./tls/options.js";
import { listenOptionsImport, serverListenMember, serverListenOperations } from "./net/listen-contract.js";

const moduleSpecifier = "node:https";
const optionsId = `${moduleSpecifier}::ServerOptions`;
const serverId = `${moduleSpecifier}::Server`;

export function httpsModule(): MojoProviderModuleDefinition {
  const requestHandler = providerCallbackType(
    `${moduleSpecifier}::createServer(options,handler)`,
    "handler",
    [
      { name: "request", type: providerRef("node:http", "IncomingMessage") },
      { name: "response", type: providerRef("node:http", "ServerResponse") },
    ],
  );
  return Object.freeze({
    moduleSpecifier,
    providerModuleId: "tsonic.mojo.node.https",
    imports: Object.freeze([listenOptionsImport, Object.freeze({ moduleSpecifier: "node:buffer", namedImports: Object.freeze([{ exportedName: "Buffer" }]) }), Object.freeze({
      moduleSpecifier: "node:http",
      namedImports: Object.freeze([
        { exportedName: "IncomingMessage" },
        { exportedName: "ServerResponse" },
      ]),
    })]),
    exports: Object.freeze([
      ...httpClientExports("node:https"),
      Object.freeze({
        id: optionsId,
        name: "ServerOptions",
        kind: "interface",
        members: tlsOptionMembers(optionsId, tlsServerFields),
      }),
      Object.freeze({
        id: serverId,
        name: "Server",
        kind: "class",
        members: Object.freeze([
          serverListenMember(moduleSpecifier),
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
        id: `${moduleSpecifier}::createServer`, name: "createServer", kind: "function",
        signatures: Object.freeze([Object.freeze({
          id: `${moduleSpecifier}::createServer(options,handler)`, name: "createServer",
          parameters: Object.freeze([
            { name: "options", type: providerRef(moduleSpecifier, "ServerOptions") },
            { name: "handler", type: requestHandler },
          ]),
          returnType: providerRef(moduleSpecifier, "Server"),
        })]),
      }),
    ]),
  });
}

export function httpsTypes(): readonly MojoProviderTypeDefinition[] {
  return Object.freeze([
    nodeProviderType(optionsId, tlsServerOptionsCarrier, "copyable", {
      objectLiteralConstruction: true,
    }),
    nodeProviderType(serverId, httpsServerCarrier, "implicitly-copyable"),
    ...httpClientTypes("node:https"),
  ]);
}

export function httpsOperations(): readonly MojoProviderOperationDefinition[] {
  return Object.freeze([
    ...tlsOptionOperations(optionsId, tlsServerOptionsCarrier, tlsServerFields),
    ...httpClientOperations("node:https"),
    functionCall(`${moduleSpecifier}::createServer`, `${moduleSpecifier}::createServer(options,handler)`, "https", "create_server", [tlsServerOptionsCarrier, httpRequestCallbackCarrier], httpsServerCarrier, true),
    ...serverListenOperations(moduleSpecifier, httpsServerCarrier),
    instanceCall(serverId, `${serverId}.close`, `${serverId}.close()`, "close", httpsServerCarrier, [], unitCarrier, true, "mut"),
    instanceCall(serverId, `${serverId}.ref`, `${serverId}.ref()`, "ref", httpsServerCarrier, [], httpsServerCarrier, false, "mut"),
    instanceCall(serverId, `${serverId}.unref`, `${serverId}.unref()`, "unref", httpsServerCarrier, [], httpsServerCarrier, false, "mut"),
    propertyRead(serverId, `${serverId}.listening`, "listening", httpsServerCarrier, boolCarrier, "method"),
  ]);
}
