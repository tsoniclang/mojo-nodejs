import type { ProviderTypeExpression } from "./types.js";

export const stringType = Object.freeze({ kind: "string" as const });

export const numberType = Object.freeze({ kind: "number" as const });

export const booleanType = Object.freeze({ kind: "boolean" as const });

export const voidType = Object.freeze({ kind: "void" as const });

export const undefinedType = Object.freeze({ kind: "undefined" as const });
export const nullType = Object.freeze({ kind: "literal" as const, value: null });

export const int32Type = Object.freeze({ kind: "source-primitive" as const, name: "int32" as const });

export const stringArrayType = Object.freeze({ kind: "array" as const, elementType: stringType });

export const numberArrayType = Object.freeze({ kind: "array" as const, elementType: numberType });

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

export function sourcePromise(
  value: ProviderTypeExpression,
): ProviderTypeExpression {
  return Object.freeze({
    kind: "source-global",
    name: "Promise",
    typeArguments: Object.freeze([value]),
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
