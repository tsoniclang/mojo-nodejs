import type {
  MojoProviderModuleDefinition,
  MojoProviderOperationDefinition,
  MojoProviderTypeDefinition,
} from "@tsonic/target-mojo/provider";
import {
  booleanType,
  boolCarrier,
  bufferCarrier,
  httpServerResponseCarrier,
  instanceCall,
  methodMember,
  nativeString,
  propertyMember,
  providerRef,
  readableCarrier,
  stringType,
  unitCarrier,
  undefinedType,
  writableCarrier,
} from "../model.js";

const moduleSpecifier = "node:stream";
const readableId = `${moduleSpecifier}::Readable`;
const writableId = `${moduleSpecifier}::Writable`;
const bufferType = providerRef("node:buffer", "Buffer");
const optionalBufferType = Object.freeze({ kind: "union" as const, types: Object.freeze([bufferType, undefinedType]) });

export function streamModule(): MojoProviderModuleDefinition {
  return Object.freeze({
    moduleSpecifier,
    providerModuleId: "tsonic.mojo.node.stream",
    imports: Object.freeze([
      Object.freeze({ moduleSpecifier: "node:buffer", namedImports: Object.freeze([{ exportedName: "Buffer" }]) }),
      Object.freeze({ moduleSpecifier: "node:http", namedImports: Object.freeze([{ exportedName: "ServerResponse" }]) }),
    ]),
    exports: Object.freeze([
      Object.freeze({
        id: readableId,
        name: "Readable",
        kind: "class",
        members: Object.freeze([
          methodMember(readableId, "read", [], optionalBufferType),
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
        ]),
      }),
      Object.freeze({
        id: writableId,
        name: "Writable",
        kind: "class",
        members: Object.freeze([
          Object.freeze({
            id: `${writableId}.write`, name: "write", kind: "method",
            signatures: Object.freeze([
              Object.freeze({ id: `${writableId}.write(buffer)`, name: "write", parameters: Object.freeze([{ name: "chunk", type: bufferType }]), returnType: booleanType }),
              Object.freeze({ id: `${writableId}.write(string)`, name: "write", parameters: Object.freeze([{ name: "chunk", type: stringType }]), returnType: booleanType }),
            ]),
          }),
          Object.freeze({
            id: `${writableId}.end`, name: "end", kind: "method",
            signatures: Object.freeze([
              Object.freeze({ id: `${writableId}.end()`, name: "end", parameters: Object.freeze([]), returnType: providerRef(moduleSpecifier, "Writable") }),
              Object.freeze({ id: `${writableId}.end(buffer)`, name: "end", parameters: Object.freeze([{ name: "chunk", type: bufferType }]), returnType: providerRef(moduleSpecifier, "Writable") }),
              Object.freeze({ id: `${writableId}.end(string)`, name: "end", parameters: Object.freeze([{ name: "chunk", type: stringType }]), returnType: providerRef(moduleSpecifier, "Writable") }),
            ]),
          }),
          methodMember(writableId, "cork", [], Object.freeze({ kind: "void" })),
          methodMember(writableId, "uncork", [], Object.freeze({ kind: "void" })),
        ]),
      }),
    ]),
  });
}

export function streamTypes(): readonly MojoProviderTypeDefinition[] {
  return Object.freeze([
    Object.freeze({ exportId: readableId, sourceGenericParameters: Object.freeze([]), targetType: readableCarrier }),
    Object.freeze({ exportId: writableId, sourceGenericParameters: Object.freeze([]), targetType: writableCarrier }),
  ]);
}

export function streamOperations(): readonly MojoProviderOperationDefinition[] {
  return Object.freeze([
    instanceCall(readableId, `${readableId}.read`, `${readableId}.read()`, "read", readableCarrier, [], Object.freeze({ kind: "optional", value: bufferCarrier }), true, "mut"),
    instanceCall(readableId, `${readableId}.pipe`, `${readableId}.pipe(writable)`, "pipe_to", readableCarrier, [writableCarrier], writableCarrier, true, "mut"),
    instanceCall(readableId, `${readableId}.pipe`, `${readableId}.pipe(serverResponse)`, "pipe_to_response", readableCarrier, [httpServerResponseCarrier], httpServerResponseCarrier, true, "mut"),
    instanceCall(readableId, `${readableId}.pause`, `${readableId}.pause()`, "pause", readableCarrier, [], readableCarrier, false, "mut"),
    instanceCall(readableId, `${readableId}.resume`, `${readableId}.resume()`, "resume", readableCarrier, [], readableCarrier, false, "mut"),
    instanceCall(readableId, `${readableId}.isPaused`, `${readableId}.isPaused()`, "is_paused", readableCarrier, [], boolCarrier),
    instanceCall(writableId, `${writableId}.write`, `${writableId}.write(buffer)`, "write_buffer", writableCarrier, [bufferCarrier], boolCarrier, true, "mut"),
    instanceCall(writableId, `${writableId}.write`, `${writableId}.write(string)`, "write_string", writableCarrier, [nativeString], boolCarrier, true, "mut"),
    instanceCall(writableId, `${writableId}.end`, `${writableId}.end()`, "end", writableCarrier, [], writableCarrier, true, "mut"),
    instanceCall(writableId, `${writableId}.end`, `${writableId}.end(buffer)`, "end_buffer", writableCarrier, [bufferCarrier], writableCarrier, true, "mut"),
    instanceCall(writableId, `${writableId}.end`, `${writableId}.end(string)`, "end_string", writableCarrier, [nativeString], writableCarrier, true, "mut"),
    instanceCall(writableId, `${writableId}.cork`, `${writableId}.cork()`, "cork", writableCarrier, [], unitCarrier, false, "mut"),
    instanceCall(writableId, `${writableId}.uncork`, `${writableId}.uncork()`, "uncork", writableCarrier, [], unitCarrier, true, "mut"),
  ]);
}
