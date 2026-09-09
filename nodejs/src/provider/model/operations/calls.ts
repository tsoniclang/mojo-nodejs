import type { MojoProviderOperationDefinition, MojoTargetTypeRef } from "@tsonic/target-mojo/provider";

export function functionCall(
  exportId: string,
  signatureId: string,
  moduleName: string | readonly string[],
  targetName: string,
  parameterTypes: readonly MojoTargetTypeRef[],
  resultType: MojoTargetTypeRef,
  raises = false,
): MojoProviderOperationDefinition {
  return Object.freeze({
    exportId,
    signatureId,
    operationKind: "call",
    target: Object.freeze({
      kind: "function-call",
      modulePath: Object.freeze(["tsonic_node", ...(typeof moduleName === "string" ? [moduleName] : moduleName)]),
      name: targetName,
      arguments: Object.freeze(parameterTypes.map(() => Object.freeze({
        convention: "imm" as const,
        position: "positional-or-keyword" as const,
      }))),
    }),
    parameterTypes: Object.freeze([...parameterTypes]),
    resultType,
    ...(raises ? { raises: true } : {}),
  });
}

export function staticCall(
  exportId: string,
  memberId: string,
  signatureId: string,
  moduleName: string,
  targetName: string,
  parameterTypes: readonly MojoTargetTypeRef[],
  resultType: MojoTargetTypeRef,
  raises = false,
): MojoProviderOperationDefinition {
  return Object.freeze({
    ...functionCall(exportId, signatureId, moduleName, targetName, parameterTypes, resultType, raises),
    memberId,
  });
}

export function variadicFunctionCall(
  exportId: string,
  signatureId: string,
  moduleName: string,
  targetName: string,
  parameterType: MojoTargetTypeRef,
  resultType: MojoTargetTypeRef,
  raises = false,
): MojoProviderOperationDefinition {
  return Object.freeze({
    exportId,
    signatureId,
    operationKind: "call",
    target: Object.freeze({
      kind: "function-call",
      modulePath: Object.freeze(["tsonic_node", moduleName]),
      name: targetName,
      arguments: Object.freeze([Object.freeze({
        convention: "imm",
        position: "positional-or-keyword",
        variadic: true,
        restPacking: "list",
      })]),
    }),
    parameterTypes: Object.freeze([parameterType]),
    resultType,
    ...(raises ? { raises: true } : {}),
  });
}

export function instanceCall(
  exportId: string,
  memberId: string,
  signatureId: string,
  targetName: string,
  receiverType: MojoTargetTypeRef,
  parameterTypes: readonly MojoTargetTypeRef[],
  resultType: MojoTargetTypeRef,
  raises = false,
  receiver: "imm" | "mut" | "var" | "ref" | "deinit" = "imm",
): MojoProviderOperationDefinition {
  return Object.freeze({
    exportId,
    memberId,
    signatureId,
    operationKind: "call",
    target: Object.freeze({
      kind: "instance-call",
      name: targetName,
      receiver,
      arguments: Object.freeze(parameterTypes.map(() => Object.freeze({
        convention: "imm" as const,
        position: "positional-or-keyword" as const,
      }))),
    }),
    receiverType,
    parameterTypes: Object.freeze([...parameterTypes]),
    resultType,
    ...(raises ? { raises: true } : {}),
  });
}
