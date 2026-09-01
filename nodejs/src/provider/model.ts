import {
  mojoCallableTargetType,
  mojoListTargetType,
  mojoNamedTargetType,
  mojoOptionalTargetType,
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
export const undefinedType = Object.freeze({ kind: "undefined" as const });
export const int32Type = Object.freeze({ kind: "source-primitive" as const, name: "int32" as const });
export const stringArrayType = Object.freeze({ kind: "array" as const, elementType: stringType });
export const numberArrayType = Object.freeze({ kind: "array" as const, elementType: numberType });
export const nativeString = mojoStringTargetType();
export const boolCarrier = mojoPrimitiveTargetType("bool");
export const nativeIntCarrier = mojoPrimitiveTargetType("native-int");
export const float64Carrier = mojoPrimitiveTargetType("float64");
export const int32Carrier = mojoPrimitiveTargetType("int32");
export const uint8Carrier = mojoPrimitiveTargetType("uint8");
export const unitCarrier = mojoUnitTargetType();
export const stringListCarrier = mojoListTargetType(nativeString);
export const numberListCarrier = mojoListTargetType(float64Carrier);
export const optionalInt32Carrier = mojoOptionalTargetType(int32Carrier);
export const optionalBoolCarrier = mojoOptionalTargetType(boolCarrier);
export const optionalFloat64Carrier = mojoOptionalTargetType(float64Carrier);
export const optionalStringCarrier = mojoOptionalTargetType(nativeString);
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

export const readdirOptionsCarrier = mojoNamedTargetType(
  "tsonic.mojo.node.ReaddirOptions",
  ["tsonic_node", "filesystem"],
  "ReaddirOptions",
);

export const direntCarrier = mojoNamedTargetType(
  "tsonic.mojo.node.Dirent",
  ["tsonic_node", "filesystem"],
  "Dirent",
);
export const direntListCarrier = mojoListTargetType(direntCarrier);

export const pathPartsCarrier = mojoNamedTargetType(
  "tsonic.mojo.node.PathParts",
  ["tsonic_node", "path"],
  "PathParts",
);

export const processWriteStreamCarrier = mojoNamedTargetType(
  "tsonic.mojo.node.ProcessWriteStream",
  ["tsonic_node", "process"],
  "ProcessWriteStream",
);

export const processEnvCarrier = mojoNamedTargetType(
  "tsonic.mojo.node.ProcessEnv",
  ["tsonic_node", "process"],
  "ProcessEnv",
);

export const processMemoryUsageCarrier = mojoNamedTargetType(
  "tsonic.mojo.node.MemoryUsage",
  ["tsonic_node", "process"],
  "MemoryUsage",
);

export const spawnSyncResultCarrier = mojoNamedTargetType(
  "tsonic.mojo.node.SpawnSyncResult",
  ["tsonic_node", "child_process"],
  "SpawnSyncResult",
);

export const textDecoderCarrier = mojoNamedTargetType(
  "tsonic.mojo.node.TextDecoder",
  ["tsonic_node", "util"],
  "TextDecoder",
);

export const legacyUrlCarrier = mojoNamedTargetType(
  "tsonic.mojo.node.LegacyUrl",
  ["tsonic_node", "url"],
  "LegacyUrl",
);

export const hashCarrier = mojoNamedTargetType(
  "tsonic.mojo.node.Hash",
  ["tsonic_node", "crypto"],
  "Hash",
);

export const timeoutCarrier = mojoNamedTargetType(
  "tsonic.mojo.node.Timeout",
  ["tsonic_node", "timers"],
  "Timeout",
);

export const httpIncomingMessageCarrier = mojoNamedTargetType(
  "tsonic.mojo.node.HttpIncomingMessage",
  ["tsonic_node", "http"],
  "IncomingMessage",
);

export const httpServerResponseCarrier = mojoNamedTargetType(
  "tsonic.mojo.node.HttpServerResponse",
  ["tsonic_node", "http"],
  "ServerResponse",
);

export const httpServerCarrier = mojoNamedTargetType(
  "tsonic.mojo.node.HttpServer",
  ["tsonic_node", "http"],
  "Server",
);

export const emptyCallbackCarrier = mojoCallableTargetType([], unitCarrier, true);
export const httpRequestCallbackCarrier = mojoCallableTargetType(
  [httpIncomingMessageCarrier, httpServerResponseCarrier].map((type) => Object.freeze({
    convention: "var" as const,
    passing: "plain" as const,
    type,
  })),
  unitCarrier,
  true,
);

export function providerRef(
  moduleSpecifier: string,
  exportName: string,
  typeArguments: readonly ProviderTypeExpression[] = [],
): ProviderTypeExpression {
  return Object.freeze({
    kind: "provider-ref",
    moduleSpecifier,
    exportName,
    ...(typeArguments.length === 0 ? {} : { typeArguments: Object.freeze([...typeArguments]) }),
  });
}

export function providerCallbackType(
  signatureId: string,
  parameterName: string,
  parameters: readonly { readonly name: string; readonly type: ProviderTypeExpression }[],
): ProviderTypeExpression {
  return Object.freeze({
    kind: "function",
    id: `${signatureId}::parameter:${parameterName}`,
    parameters: Object.freeze(parameters.map((parameter) => Object.freeze({ ...parameter }))),
    returnType: voidType,
  });
}

export function typeParameter(name: string): ProviderTypeExpression {
  return Object.freeze({ kind: "type-parameter", name });
}

export function targetTypeParameter(name: string): MojoTargetTypeRef {
  return Object.freeze({ kind: "type-parameter", name });
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
  options?: { readonly static?: boolean; readonly signatureSuffix?: string },
): ProviderMemberDeclaration {
  const id = `${ownerId}.${name}`;
  return Object.freeze({
    id,
    name,
    kind: "method",
    ...(options?.static === true ? { static: true } : {}),
    signatures: Object.freeze([Object.freeze({
      id: `${id}(${options?.signatureSuffix ?? parameters.map((parameter) => parameter.name).join(",")})`,
      name,
      parameters: Object.freeze([...parameters]),
      returnType,
    })]),
  });
}

export function overloadedMethodMember(
  ownerId: string,
  name: string,
  overloads: readonly {
    readonly parameters: readonly ProviderParameterDeclaration[];
    readonly returnType: ProviderTypeExpression;
    readonly signatureSuffix?: string;
  }[],
  options?: { readonly static?: boolean },
): ProviderMemberDeclaration {
  const id = `${ownerId}.${name}`;
  return Object.freeze({
    id,
    name,
    kind: "method",
    ...(options?.static === true ? { static: true } : {}),
    signatures: Object.freeze(overloads.map((overload) => Object.freeze({
      id: `${id}(${overload.signatureSuffix ?? overload.parameters.map((parameter) => parameter.name).join(",")})`,
      name,
      parameters: Object.freeze(overload.parameters.map((parameter) => Object.freeze({ ...parameter }))),
      returnType: overload.returnType,
    }))),
  });
}

export function propertyMember(
  ownerId: string,
  name: string,
  type: ProviderTypeExpression,
  options?: { readonly readonly?: boolean; readonly static?: boolean; readonly optional?: boolean },
): ProviderMemberDeclaration {
  return Object.freeze({
    id: `${ownerId}.${name}`,
    name,
    kind: "property",
    ...(options?.readonly === false ? {} : { readonly: true }),
    ...(options?.static === true ? { static: true } : {}),
    ...(options?.optional === true ? { optional: true } : {}),
    type,
  });
}

export function constructorMember(
  ownerId: string,
  parameters: readonly ProviderParameterDeclaration[],
): ProviderMemberDeclaration {
  const id = `${ownerId}.constructor`;
  return Object.freeze({
    id,
    name: "constructor",
    kind: "constructor",
    signatures: Object.freeze([Object.freeze({
      id: `${id}(${parameters.map((parameter) => parameter.name).join(",")})`,
      name: "constructor",
      parameters: Object.freeze(parameters.map((parameter) => Object.freeze({ ...parameter }))),
      returnType: voidType,
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
): MojoProviderOperationDefinition {
  return Object.freeze({
    exportId,
    memberId,
    operationKind: "property-set",
    target: Object.freeze({
      kind: "property-write",
      access: Object.freeze({ kind: "member", name: targetName }),
      receiver: "mut",
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
