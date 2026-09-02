import type {
  MojoProviderModuleDefinition,
  MojoProviderOperationDefinition,
  MojoProviderTypeDefinition,
} from "@tsonic/target-mojo/provider";
import {
  bufferCarrier,
  nativeString,
  optionalInt32Carrier,
  propertyMember,
  propertyRead,
  providerRef,
  spawnSyncResultCarrier,
  stringArrayType,
  stringListCarrier,
  stringType,
} from "../model.js";

const moduleSpecifier = "node:child_process";
const resultId = `${moduleSpecifier}::SpawnSyncReturns`;

export function childProcessModule(): MojoProviderModuleDefinition {
  return Object.freeze({
    moduleSpecifier,
    providerModuleId: "tsonic.mojo.node.child-process",
    imports: Object.freeze([Object.freeze({
      moduleSpecifier: "node:buffer",
      namedImports: Object.freeze([{ exportedName: "Buffer" }]),
    })]),
    exports: Object.freeze([
      Object.freeze({
        id: resultId,
        name: "SpawnSyncReturns",
        kind: "interface",
        typeParameters: Object.freeze([{ name: "Output" }]),
        members: Object.freeze([
          propertyMember(resultId, "stdout", Object.freeze({ kind: "type-parameter", name: "Output" })),
          propertyMember(resultId, "stderr", Object.freeze({ kind: "type-parameter", name: "Output" })),
          propertyMember(resultId, "status", Object.freeze({
            kind: "union",
            types: Object.freeze([
              Object.freeze({ kind: "number" }),
              Object.freeze({ kind: "literal", value: null }),
            ]),
          })),
        ]),
      }),
      Object.freeze({
        id: `${moduleSpecifier}::spawnSync`,
        name: "spawnSync",
        kind: "function",
        signatures: Object.freeze([Object.freeze({
          id: `${moduleSpecifier}::spawnSync(command,args)`,
          name: "spawnSync",
          parameters: Object.freeze([
            Object.freeze({ name: "command", type: stringType }),
            Object.freeze({ name: "args", type: stringArrayType }),
          ]),
          returnType: providerRef(moduleSpecifier, "SpawnSyncReturns", [
            providerRef("node:buffer", "Buffer"),
          ]),
        })]),
      }),
    ]),
  });
}

export function childProcessTypes(): readonly MojoProviderTypeDefinition[] {
  return Object.freeze([Object.freeze({
    exportId: resultId,
    sourceGenericParameters: Object.freeze([Object.freeze({
      targetName: "Output",
      targetKind: "type",
      variadic: false,
    })]),
    targetType: spawnSyncResultCarrier,
  })]);
}

export function childProcessOperations(): readonly MojoProviderOperationDefinition[] {
  return Object.freeze([
    Object.freeze({
      exportId: `${moduleSpecifier}::spawnSync`,
      signatureId: `${moduleSpecifier}::spawnSync(command,args)`,
      operationKind: "call",
      target: Object.freeze({
        kind: "function-call",
        modulePath: Object.freeze(["tsonic_node", "child_process"]),
        name: "spawn_sync",
        arguments: Object.freeze([
          Object.freeze({ convention: "imm", position: "positional-or-keyword" }),
          Object.freeze({ convention: "imm", position: "positional-or-keyword" }),
        ]),
      }),
      parameterTypes: Object.freeze([nativeString, stringListCarrier]),
      resultType: spawnSyncResultCarrier,
      raises: true,
    }),
    propertyRead(resultId, `${resultId}.stdout`, "stdout", spawnSyncResultCarrier, bufferCarrier),
    propertyRead(resultId, `${resultId}.stderr`, "stderr", spawnSyncResultCarrier, bufferCarrier),
    propertyRead(resultId, `${resultId}.status`, "status", spawnSyncResultCarrier, optionalInt32Carrier),
  ]);
}
