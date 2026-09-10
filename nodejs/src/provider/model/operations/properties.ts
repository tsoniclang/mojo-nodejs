import type { MojoProviderOperationDefinition, MojoTargetTypeRef } from "@tsonic/target-mojo/provider";
import { unitCarrier } from "../carriers.js";

export function constantValue(
  exportId: string,
  moduleName: string,
  targetName: string,
  resultType: MojoTargetTypeRef,
): MojoProviderOperationDefinition {
  return Object.freeze({
    exportId,
    operationKind: "property",
    target: Object.freeze({
      kind: "constant",
      modulePath: Object.freeze(["tsonic_node", moduleName]),
      name: targetName,
    }),
    resultType,
  });
}

export function functionValue(
  exportId: string,
  moduleName: string,
  targetName: string,
  resultType: MojoTargetTypeRef,
  raises = false,
): MojoProviderOperationDefinition {
  return Object.freeze({
    exportId,
    operationKind: "property",
    target: Object.freeze({
      kind: "function-read",
      modulePath: Object.freeze(["tsonic_node", moduleName]),
      name: targetName,
    }),
    resultType,
    ...(raises ? { raises: true } : {}),
  });
}

export function propertyRead(
  exportId: string,
  memberId: string,
  targetName: string,
  receiverType: MojoTargetTypeRef,
  resultType: MojoTargetTypeRef,
  access: "member" | "method" = "member",
): MojoProviderOperationDefinition {
  return Object.freeze({
    exportId,
    memberId,
    operationKind: "property",
    target: Object.freeze({
      kind: "property-read",
      access: Object.freeze({ kind: access, name: targetName }),
      receiver: "imm",
    }),
    receiverType,
    resultType,
  });
}

export function propertyWrite(
  exportId: string,
  memberId: string,
  targetName: string,
  receiverType: MojoTargetTypeRef,
  valueType: MojoTargetTypeRef,
  access: "member" | "method" = "member",
): MojoProviderOperationDefinition {
  return Object.freeze({
    exportId,
    memberId,
    operationKind: "property-set",
    target: Object.freeze({
      kind: "property-write",
      access: Object.freeze({ kind: access, name: targetName }),
      receiver: access === "method" ? "imm" : "mut",
      value: Object.freeze({
        convention: "imm",
        position: "positional-or-keyword",
      }),
    }),
    receiverType,
    parameterTypes: Object.freeze([valueType]),
    resultType: unitCarrier,
  });
}

export function staticPropertyRead(
  exportId: string,
  memberId: string,
  moduleName: string,
  targetName: string,
  resultType: MojoTargetTypeRef,
  raises = false,
): MojoProviderOperationDefinition {
  return Object.freeze({
    exportId,
    memberId,
    operationKind: "property",
    target: Object.freeze({
      kind: "function-read",
      modulePath: Object.freeze(["tsonic_node", moduleName]),
      name: targetName,
    }),
    resultType,
    ...(raises ? { raises: true } : {}),
  });
}

export function staticPropertyWrite(
  exportId: string,
  memberId: string,
  moduleName: string,
  targetName: string,
  valueType: MojoTargetTypeRef,
  raises = false,
): MojoProviderOperationDefinition {
  return Object.freeze({
    exportId,
    memberId,
    operationKind: "property-set",
    target: Object.freeze({
      kind: "function-write",
      modulePath: Object.freeze(["tsonic_node", moduleName]),
      name: targetName,
      value: Object.freeze({
        convention: "imm",
        position: "positional-or-keyword",
      }),
    }),
    parameterTypes: Object.freeze([valueType]),
    resultType: unitCarrier,
    ...(raises ? { raises: true } : {}),
  });
}

export function indexRead(
  exportId: string,
  memberId: string,
  signatureId: string,
  targetName: string,
  receiverType: MojoTargetTypeRef,
  indexType: MojoTargetTypeRef,
  resultType: MojoTargetTypeRef,
  raises = false,
): MojoProviderOperationDefinition {
  return Object.freeze({
    exportId,
    memberId,
    signatureId,
    operationKind: "indexer",
    target: Object.freeze({
      kind: "index-read",
      access: Object.freeze({ kind: "method", name: targetName }),
      receiver: "imm",
      index: Object.freeze({
        convention: "imm",
        position: "positional-or-keyword",
      }),
    }),
    receiverType,
    parameterTypes: Object.freeze([indexType]),
    resultType,
    ...(raises ? { raises: true } : {}),
  });
}
