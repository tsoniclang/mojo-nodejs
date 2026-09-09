import type { ProviderExportDeclaration, ProviderMemberDeclaration, ProviderParameterDeclaration, ProviderTypeExpression } from "./types.js";
import { voidType } from "./source-types.js";

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
