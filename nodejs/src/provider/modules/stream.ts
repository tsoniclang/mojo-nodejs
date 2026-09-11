import type {
  MojoProviderModuleDefinition,
  MojoProviderOperationDefinition,
  MojoProviderTypeDefinition,
} from "@tsonic/target-mojo/provider";
import { writableCallMembers, writableCallOperations } from "./stream/writable-calls.js";
import { writableEventMembers, writableEventOperations } from "./stream/writable-events.js";
import { writableLifecycleMembers, writableLifecycleOperations } from "./stream/writable-lifecycle.js";
import { readableReadMember, readableReadOperations } from "./stream/readable-calls.js";
import { readableEventMembers, readableEventOperations } from "./stream/readable-events.js";
import { duplexExport, duplexOperations, duplexType } from "./stream/duplex.js";
import {
  booleanType,
  boolCarrier,
  httpServerResponseCarrier,
  instanceCall,
  methodMember,
  nativeString,
  nodeProviderType,
  propertyMember,
  propertyRead,
  providerRef,
  readableCarrier,
  stringType,
  writableCarrier,
} from "../model.js";

const moduleSpecifier = "node:stream";
const readableId = `${moduleSpecifier}::Readable`;
const writableId = `${moduleSpecifier}::Writable`;

export function streamModule(): MojoProviderModuleDefinition {
  return Object.freeze({
    moduleSpecifier,
    providerModuleId: "tsonic.mojo.node.stream",
    imports: Object.freeze([
      Object.freeze({ moduleSpecifier: "node:buffer", namedImports: Object.freeze([{ exportedName: "Buffer" }]) }),
      Object.freeze({ moduleSpecifier: "node:http", namedImports: Object.freeze([{ exportedName: "ServerResponse" }]) }),
    ]),
    exports: Object.freeze([
      duplexExport,
      Object.freeze({
        id: readableId,
        name: "Readable",
        kind: "class",
        members: Object.freeze([
          readableReadMember(readableId),
          ...readableEventMembers(moduleSpecifier, "Readable"),
          methodMember(readableId, "setEncoding", [{ name: "encoding", type: stringType }], providerRef(moduleSpecifier, "Readable")),
          Object.freeze({
            id: `${readableId}.pipe`, name: "pipe", kind: "method",
            signatures: Object.freeze([
              Object.freeze({ id: `${readableId}.pipe(writable)`, name: "pipe", parameters: Object.freeze([{ name: "destination", type: providerRef(moduleSpecifier, "Writable") }]), returnType: providerRef(moduleSpecifier, "Writable") }),
              Object.freeze({ id: `${readableId}.pipe(serverResponse)`, name: "pipe", parameters: Object.freeze([{ name: "destination", type: providerRef("node:http", "ServerResponse") }]), returnType: providerRef("node:http", "ServerResponse") }),
            ]),
          }),
          methodMember(readableId, "pause", [], providerRef(moduleSpecifier, "Readable")),
          methodMember(readableId, "resume", [], providerRef(moduleSpecifier, "Readable")),
          methodMember(readableId, "isPaused", [], booleanType),
          propertyMember(readableId, "readable", booleanType),
          propertyMember(readableId, "readableEnded", booleanType),
        ]),
      }),
      Object.freeze({
        id: writableId,
        name: "Writable",
        kind: "class",
        members: Object.freeze([
          ...writableCallMembers(writableId, providerRef(moduleSpecifier, "Writable")),
          ...writableEventMembers(moduleSpecifier, "Writable"),
          ...writableLifecycleMembers(writableId, providerRef(moduleSpecifier, "Writable")),
        ]),
      }),
    ]),
  });
}

export function streamTypes(): readonly MojoProviderTypeDefinition[] {
  return Object.freeze([
    nodeProviderType(readableId, readableCarrier, "implicitly-copyable"),
    duplexType,
    nodeProviderType(writableId, writableCarrier, "implicitly-copyable"),
  ]);
}

export function streamOperations(): readonly MojoProviderOperationDefinition[] {
  return Object.freeze([
    ...readableReadOperations(readableId, readableCarrier),
    ...duplexOperations,
    ...readableEventOperations(moduleSpecifier, "Readable", readableCarrier),
    instanceCall(readableId, `${readableId}.setEncoding`, `${readableId}.setEncoding(encoding)`, "set_encoding", readableCarrier, [nativeString], readableCarrier, true, "mut"),
    instanceCall(readableId, `${readableId}.pipe`, `${readableId}.pipe(writable)`, "pipe_to", readableCarrier, [writableCarrier], writableCarrier, true, "mut"),
    instanceCall(readableId, `${readableId}.pipe`, `${readableId}.pipe(serverResponse)`, "pipe_to_response", readableCarrier, [httpServerResponseCarrier], httpServerResponseCarrier, true, "mut"),
    instanceCall(readableId, `${readableId}.pause`, `${readableId}.pause()`, "pause", readableCarrier, [], readableCarrier, true, "mut"),
    instanceCall(readableId, `${readableId}.resume`, `${readableId}.resume()`, "resume", readableCarrier, [], readableCarrier, true, "mut"),
    instanceCall(readableId, `${readableId}.isPaused`, `${readableId}.isPaused()`, "is_paused", readableCarrier, [], boolCarrier),
    ...writableCallOperations(writableId, writableCarrier),
    ...writableEventOperations(moduleSpecifier, "Writable", writableCarrier),
    ...writableLifecycleOperations(writableId, writableCarrier),
    ...([
      [readableId, readableCarrier, "readable", "readable"],
      [readableId, readableCarrier, "readableEnded", "readable_ended"],
    ] as const).map(([id, carrier, name, target]) =>
      propertyRead(id, `${id}.${name}`, target, carrier, boolCarrier, "method")),
  ]);
}
