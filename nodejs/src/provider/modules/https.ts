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
  emptyCallbackCarrier,
  float64Carrier,
  functionCall,
  httpRequestCallbackCarrier,
  httpResponseCallbackCarrier,
  httpsClientRequestCarrier,
  httpsServerCarrier,
  instanceCall,
  nativeString,
  propertyMember,
  propertyRead,
  propertyWrite,
  providerCallbackType,
  providerRef,
  stringArrayType,
  stringListCarrier,
  stringType,
  tlsServerOptionsCarrier,
  unitCarrier,
  voidType,
} from "../model.js";

const moduleSpecifier = "node:https";
const optionsId = `${moduleSpecifier}::ServerOptions`;
const serverId = `${moduleSpecifier}::Server`;
const clientRequestId = `${moduleSpecifier}::ClientRequest`;

export function httpsModule(): MojoProviderModuleDefinition {
  const requestHandler = providerCallbackType(
    `${moduleSpecifier}::createServer(options,handler)`,
    "handler",
    [
      { name: "request", type: providerRef("node:http", "IncomingMessage") },
      { name: "response", type: providerRef("node:http", "ServerResponse") },
    ],
  );
  const responseCallback = (signatureId: string) => providerCallbackType(
    signatureId,
    "callback",
    [{ name: "response", type: providerRef("node:http", "IncomingMessage") }],
  );
  return Object.freeze({
    moduleSpecifier,
    providerModuleId: "tsonic.mojo.node.https",
    imports: Object.freeze([Object.freeze({
      moduleSpecifier: "node:http",
      namedImports: Object.freeze([
        { exportedName: "IncomingMessage" },
        { exportedName: "ServerResponse" },
      ]),
    })]),
    exports: Object.freeze([
      Object.freeze({
        id: optionsId,
        name: "ServerOptions",
        kind: "interface",
        members: Object.freeze([
          propertyMember(optionsId, "key", stringType, { readonly: false, optional: true }),
          propertyMember(optionsId, "cert", stringType, { readonly: false, optional: true }),
          propertyMember(optionsId, "ca", stringArrayType, { readonly: false, optional: true }),
          propertyMember(optionsId, "ALPNProtocols", stringArrayType, { readonly: false, optional: true }),
          propertyMember(optionsId, "requestCert", booleanType, { readonly: false, optional: true }),
          propertyMember(optionsId, "rejectUnauthorized", booleanType, { readonly: false, optional: true }),
        ]),
      }),
      Object.freeze({
        id: serverId,
        name: "Server",
        kind: "class",
        members: Object.freeze([
          Object.freeze({
            id: `${serverId}.listen`,
            name: "listen",
            kind: "method",
            signatures: Object.freeze([
              Object.freeze({
                id: `${serverId}.listen(port,callback)`,
                name: "listen",
                parameters: Object.freeze([
                  { name: "port", type: Object.freeze({ kind: "number" }) },
                  { name: "callback", type: providerCallbackType(`${serverId}.listen(port,callback)`, "callback", []) },
                ]),
                returnType: providerRef(moduleSpecifier, "Server"),
              }),
              Object.freeze({
                id: `${serverId}.listen(port,host,callback)`,
                name: "listen",
                parameters: Object.freeze([
                  { name: "port", type: Object.freeze({ kind: "number" }) },
                  { name: "host", type: stringType },
                  { name: "callback", type: providerCallbackType(`${serverId}.listen(port,host,callback)`, "callback", []) },
                ]),
                returnType: providerRef(moduleSpecifier, "Server"),
              }),
            ]),
          }),
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
        id: clientRequestId,
        name: "ClientRequest",
        kind: "class",
        members: Object.freeze([
          Object.freeze({
            id: `${clientRequestId}.write`, name: "write", kind: "method",
            signatures: Object.freeze([Object.freeze({
              id: `${clientRequestId}.write(chunk)`, name: "write",
              parameters: Object.freeze([{ name: "chunk", type: stringType }]),
              returnType: booleanType,
            })]),
          }),
          Object.freeze({
            id: `${clientRequestId}.end`, name: "end", kind: "method",
            signatures: Object.freeze([Object.freeze({
              id: `${clientRequestId}.end()`, name: "end",
              parameters: Object.freeze([]), returnType: voidType,
            })]),
          }),
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
      ...(["request", "get"] as const).map((name) => {
        const signatureId = `${moduleSpecifier}::${name}(url,callback)`;
        return Object.freeze({
          id: `${moduleSpecifier}::${name}`, name, kind: "function" as const,
          signatures: Object.freeze([Object.freeze({
            id: signatureId, name,
            parameters: Object.freeze([
              { name: "url", type: stringType },
              { name: "callback", type: responseCallback(signatureId) },
            ]),
            returnType: providerRef(moduleSpecifier, "ClientRequest"),
          })]),
        });
      }),
    ]),
  });
}

export function httpsTypes(): readonly MojoProviderTypeDefinition[] {
  return Object.freeze([
    Object.freeze({
      exportId: optionsId,
      sourceGenericParameters: Object.freeze([]),
      targetType: tlsServerOptionsCarrier,
      objectLiteralConstruction: Object.freeze({ kind: "struct-default" }),
    }),
    providerType(serverId, httpsServerCarrier),
    providerType(clientRequestId, httpsClientRequestCarrier),
  ]);
}

export function httpsOperations(): readonly MojoProviderOperationDefinition[] {
  return Object.freeze([
    ...optionRows(),
    functionCall(`${moduleSpecifier}::createServer`, `${moduleSpecifier}::createServer(options,handler)`, "https", "create_server", [tlsServerOptionsCarrier, httpRequestCallbackCarrier], httpsServerCarrier, true),
    functionCall(`${moduleSpecifier}::request`, `${moduleSpecifier}::request(url,callback)`, "https", "request", [nativeString, httpResponseCallbackCarrier], httpsClientRequestCarrier, true),
    functionCall(`${moduleSpecifier}::get`, `${moduleSpecifier}::get(url,callback)`, "https", "get", [nativeString, httpResponseCallbackCarrier], httpsClientRequestCarrier, true),
    instanceCall(clientRequestId, `${clientRequestId}.write`, `${clientRequestId}.write(chunk)`, "write_string", httpsClientRequestCarrier, [nativeString], boolCarrier, true, "mut"),
    instanceCall(clientRequestId, `${clientRequestId}.end`, `${clientRequestId}.end()`, "end", httpsClientRequestCarrier, [], unitCarrier, true, "mut"),
    instanceCall(serverId, `${serverId}.listen`, `${serverId}.listen(port,callback)`, "listen_default_host", httpsServerCarrier, [float64Carrier, emptyCallbackCarrier], httpsServerCarrier, true, "mut"),
    instanceCall(serverId, `${serverId}.listen`, `${serverId}.listen(port,host,callback)`, "listen", httpsServerCarrier, [float64Carrier, nativeString, emptyCallbackCarrier], httpsServerCarrier, true, "mut"),
    instanceCall(serverId, `${serverId}.close`, `${serverId}.close()`, "close", httpsServerCarrier, [], unitCarrier, false, "mut"),
    instanceCall(serverId, `${serverId}.ref`, `${serverId}.ref()`, "ref", httpsServerCarrier, [], httpsServerCarrier, false, "mut"),
    instanceCall(serverId, `${serverId}.unref`, `${serverId}.unref()`, "unref", httpsServerCarrier, [], httpsServerCarrier, false, "mut"),
    propertyRead(serverId, `${serverId}.listening`, "listening", httpsServerCarrier, boolCarrier, "method"),
  ]);
}

function providerType(exportId: string, targetType: MojoTargetTypeRef): MojoProviderTypeDefinition {
  return Object.freeze({ exportId, sourceGenericParameters: Object.freeze([]), targetType });
}

function optionRows(): readonly MojoProviderOperationDefinition[] {
  return Object.freeze(([
    ["key", "key", mojoOptionalTargetType(nativeString)],
    ["cert", "cert", mojoOptionalTargetType(nativeString)],
    ["ca", "ca", mojoOptionalTargetType(stringListCarrier)],
    ["ALPNProtocols", "alpn_protocols", mojoOptionalTargetType(stringListCarrier)],
    ["requestCert", "request_cert", mojoOptionalTargetType(boolCarrier)],
    ["rejectUnauthorized", "reject_unauthorized", mojoOptionalTargetType(boolCarrier)],
  ] as const).flatMap(([sourceName, targetName, type]) => [
    propertyRead(optionsId, `${optionsId}.${sourceName}`, targetName, tlsServerOptionsCarrier, type),
    propertyWrite(optionsId, `${optionsId}.${sourceName}`, targetName, tlsServerOptionsCarrier, type),
  ]));
}
