import type {
  MojoProviderModuleDefinition,
  MojoProviderOperationDefinition,
  MojoProviderTypeDefinition,
} from "@tsonic/target-mojo/provider";
import {
  bufferCarrier,
  fnExport,
  functionCall,
  hashCarrier,
  instanceCall,
  methodMember,
  nativeString,
  nodeProviderType,
  providerRef,
  stringType,
} from "../model.js";

const moduleSpecifier = "node:crypto";
const hashId = `${moduleSpecifier}::Hash`;

export function cryptoModule(): MojoProviderModuleDefinition {
  return Object.freeze({
    moduleSpecifier,
    providerModuleId: "tsonic.mojo.node.crypto",
    imports: Object.freeze([Object.freeze({
      moduleSpecifier: "node:buffer",
      namedImports: Object.freeze([{ exportedName: "Buffer" }]),
    })]),
    exports: Object.freeze([
      Object.freeze({
        id: hashId,
        name: "Hash",
        kind: "interface",
        members: Object.freeze([
          Object.freeze({
            id: `${hashId}.update`,
            name: "update",
            kind: "method",
            signatures: Object.freeze([
              Object.freeze({
                id: `${hashId}.update(buffer)`,
                name: "update",
                parameters: Object.freeze([{ name: "data", type: providerRef("node:buffer", "Buffer") }]),
                returnType: providerRef(moduleSpecifier, "Hash"),
              }),
              Object.freeze({
                id: `${hashId}.update(string)`,
                name: "update",
                parameters: Object.freeze([{ name: "data", type: stringType }]),
                returnType: providerRef(moduleSpecifier, "Hash"),
              }),
            ]),
          }),
          methodMember(hashId, "digest", [{ name: "encoding", type: stringType }], stringType),
        ]),
      }),
      fnExport(moduleSpecifier, "createHash", [{ name: "algorithm", type: stringType }], providerRef(moduleSpecifier, "Hash")),
    ]),
  });
}

export function cryptoTypes(): readonly MojoProviderTypeDefinition[] {
  return Object.freeze([
    nodeProviderType(hashId, hashCarrier, "implicitly-copyable"),
  ]);
}

export function cryptoOperations(): readonly MojoProviderOperationDefinition[] {
  return Object.freeze([
    functionCall(
      `${moduleSpecifier}::createHash`,
      `${moduleSpecifier}::createHash(algorithm)`,
      "crypto",
      "create_hash",
      [nativeString],
      hashCarrier,
      true,
    ),
    instanceCall(
      hashId,
      `${hashId}.update`,
      `${hashId}.update(buffer)`,
      "update_buffer",
      hashCarrier,
      [bufferCarrier],
      hashCarrier,
      true,
    ),
    instanceCall(
      hashId,
      `${hashId}.update`,
      `${hashId}.update(string)`,
      "update_string",
      hashCarrier,
      [nativeString],
      hashCarrier,
      true,
    ),
    instanceCall(
      hashId,
      `${hashId}.digest`,
      `${hashId}.digest(encoding)`,
      "digest",
      hashCarrier,
      [nativeString],
      nativeString,
      true,
    ),
  ]);
}
