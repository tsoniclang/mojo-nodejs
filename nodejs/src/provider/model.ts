import {
  mojoListTargetType,
  mojoNamedTargetType,
  mojoPrimitiveTargetType,
  mojoStringTargetType,
  mojoUnitTargetType,
} from "@tsonic/target-mojo/provider";
import type {
  MojoProviderModuleDefinition,
  MojoProviderOperationDefinition,
  MojoTargetTypeRef,
} from "@tsonic/target-mojo/provider";

type ProviderExportDeclaration = MojoProviderModuleDefinition["exports"][number];
type ProviderSignatureDeclaration = NonNullable<ProviderExportDeclaration["signatures"]>[number];
type ProviderParameterDeclaration = ProviderSignatureDeclaration["parameters"][number];
type ProviderTypeExpression = ProviderParameterDeclaration["type"];
type ProviderMemberDeclaration = NonNullable<ProviderExportDeclaration["members"]>[number];

export const stringType = Object.freeze({ kind: "string" as const });
export const numberType = Object.freeze({ kind: "number" as const });
export const booleanType = Object.freeze({ kind: "boolean" as const });
export const voidType = Object.freeze({ kind: "void" as const });
export const nativeString = mojoStringTargetType();
export const boolCarrier = mojoPrimitiveTargetType("bool");
export const nativeIntCarrier = mojoPrimitiveTargetType("native-int");
export const float64Carrier = mojoPrimitiveTargetType("float64");
export const int32Carrier = mojoPrimitiveTargetType("int32");
export const uint8Carrier = mojoPrimitiveTargetType("uint8");
export const unitCarrier = mojoUnitTargetType();
export const stringListCarrier = mojoListTargetType(nativeString);
export const bufferCarrier = mojoNamedTargetType(
  "tsonic.mojo.node.Buffer",
  ["tsonic_node", "buffer"],
  "Buffer",
);
export const statsCarrier = mojoNamedTargetType(
  "tsonic.mojo.node.Stats",
  ["tsonic_node", "filesystem"],
  "Stats",
);

export const mkdirOptionsCarrier = mojoNamedTargetType(
  "tsonic.mojo.node.MkdirOptions",
  ["tsonic_node", "filesystem"],
  "MkdirOptions",
);

export const rmOptionsCarrier = mojoNamedTargetType(
  "tsonic.mojo.node.RmOptions",
  ["tsonic_node", "filesystem"],
  "RmOptions",
);

export function providerRef(
  moduleSpecifier: string,
  exportName: string,
): ProviderTypeExpression {
  return Object.freeze({ kind: "provider-ref", moduleSpecifier, exportName });
}

export function fnExport(
  moduleSpecifier: string,
  name: string,
  parameters: readonly ProviderParameterDeclaration[],
  returnType: ProviderTypeExpression,
  signatureSuffix = parameters.map((parameter) => parameter.name).join(","),
): ProviderExportDeclaration {
  return overloadedFunctionExport(moduleSpecifier, name, [{
    parameters,
    returnType,
    signatureSuffix,
  }]);
}

export function overloadedFunctionExport(
  moduleSpecifier: string,
  name: string,
  overloads: readonly {
    readonly parameters: readonly ProviderParameterDeclaration[];
    readonly returnType: ProviderTypeExpression;
    readonly signatureSuffix?: string;
  }[],
): ProviderExportDeclaration {
  const id = `${moduleSpecifier}::${name}`;
  return Object.freeze({
    id,
    name,
    kind: "function",
    signatures: Object.freeze(overloads.map((overload) => Object.freeze({
      id: `${id}(${overload.signatureSuffix ?? overload.parameters.map((parameter) => parameter.name).join(",")})`,
      name,
      parameters: Object.freeze(overload.parameters.map((parameter) => Object.freeze({ ...parameter }))),
      returnType: overload.returnType,
    }))),
  });
}

export function methodMember(
  ownerId: string,
  name: string,
  parameters: readonly ProviderParameterDeclaration[],
  returnType: ProviderTypeExpression,
): ProviderMemberDeclaration {
  const id = `${ownerId}.${name}`;
  return Object.freeze({
    id,
    name,
    kind: "method",
    signatures: Object.freeze([Object.freeze({
      id: `${id}(${parameters.map((parameter) => parameter.name).join(",")})`,
      name,
      parameters: Object.freeze([...parameters]),
      returnType,
    })]),
  });
}

export function functionCall(
  exportId: string,
  signatureId: string,
  moduleName: string,
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
      modulePath: Object.freeze(["tsonic_node", moduleName]),
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
      })]),
    }),
    parameterTypes: Object.freeze([parameterType]),
    resultType,
    ...(raises ? { raises: true } : {}),
  });
}

export function valueExport(
  moduleSpecifier: string,
  name: string,
  type: ProviderTypeExpression,
): ProviderExportDeclaration {
  return Object.freeze({
    id: `${moduleSpecifier}::${name}`,
    name,
    kind: "value",
    type,
  });
}

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

export function instanceCall(
  exportId: string,
  memberId: string,
  signatureId: string,
  targetName: string,
  receiverType: MojoTargetTypeRef,
  parameterTypes: readonly MojoTargetTypeRef[],
  resultType: MojoTargetTypeRef,
  raises = false,
): MojoProviderOperationDefinition {
  return Object.freeze({
    exportId,
    memberId,
    signatureId,
    operationKind: "call",
    target: Object.freeze({
      kind: "instance-call",
      name: targetName,
      receiver: "imm",
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
