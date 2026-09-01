import type {
  MojoProviderModuleDefinition,
  MojoProviderOperationDefinition,
  MojoTargetTypeRef,
} from "@tsonic/target-mojo/provider";
import {
  booleanType,
  boolCarrier,
  nativeString,
  stringType,
  targetTypeParameter,
  typeParameter,
  unitCarrier,
  voidType,
} from "../model.js";

const moduleSpecifier = "node:assert";
const defaultId = `${moduleSpecifier}::default`;
const okId = `${moduleSpecifier}::ok`;
const strictEqualId = `${moduleSpecifier}::strictEqual`;
const notStrictEqualId = `${moduleSpecifier}::notStrictEqual`;
const deepStrictEqualId = `${moduleSpecifier}::deepStrictEqual`;

export function assertModule(): MojoProviderModuleDefinition {
  return Object.freeze({
    moduleSpecifier,
    providerModuleId: "tsonic.mojo.node.assert",
    exports: Object.freeze([
      booleanAssertion(defaultId, "assert", "default"),
      booleanAssertion(okId, "ok"),
      equalityAssertion(strictEqualId, "strictEqual"),
      equalityAssertion(notStrictEqualId, "notStrictEqual"),
      equalityAssertion(deepStrictEqualId, "deepStrictEqual"),
    ]),
  });
}

export function assertOperations(): readonly MojoProviderOperationDefinition[] {
  return Object.freeze([
    ...booleanAssertionOperations(defaultId),
    ...booleanAssertionOperations(okId),
    ...equalityAssertionOperations(strictEqualId, "strict_equal", "strict_equal_with_message"),
    ...equalityAssertionOperations(notStrictEqualId, "not_strict_equal", "not_strict_equal_with_message"),
    ...equalityAssertionOperations(deepStrictEqualId, "strict_equal", "strict_equal_with_message"),
  ]);
}

function booleanAssertion(
  id: string,
  name: string,
  exportKind?: "default",
): MojoProviderModuleDefinition["exports"][number] {
  return Object.freeze({
    id,
    name,
    ...(exportKind === undefined ? {} : { exportKind }),
    kind: "function",
    signatures: Object.freeze([
      Object.freeze({
        id: `${id}(value)`,
        name,
        parameters: Object.freeze([{ name: "value", type: booleanType }]),
        returnType: voidType,
      }),
      Object.freeze({
        id: `${id}(value,message)`,
        name,
        parameters: Object.freeze([
          { name: "value", type: booleanType },
          { name: "message", type: stringType },
        ]),
        returnType: voidType,
      }),
    ]),
  });
}

function equalityAssertion(
  id: string,
  name: string,
): MojoProviderModuleDefinition["exports"][number] {
  const parameter = typeParameter("T");
  return Object.freeze({
    id,
    name,
    kind: "function",
    signatures: Object.freeze([
      Object.freeze({
        id: `${id}(actual,expected)`,
        name,
        typeParameters: Object.freeze([{ name: "T" }]),
        parameters: Object.freeze([
          { name: "actual", type: parameter },
          { name: "expected", type: parameter },
        ]),
        returnType: voidType,
      }),
      Object.freeze({
        id: `${id}(actual,expected,message)`,
        name,
        typeParameters: Object.freeze([{ name: "T" }]),
        parameters: Object.freeze([
          { name: "actual", type: parameter },
          { name: "expected", type: parameter },
          { name: "message", type: stringType },
        ]),
        returnType: voidType,
      }),
    ]),
  });
}

function booleanAssertionOperations(id: string): readonly MojoProviderOperationDefinition[] {
  return Object.freeze([
    callOperation(id, `${id}(value)`, "ok", [boolCarrier]),
    callOperation(id, `${id}(value,message)`, "ok_with_message", [boolCarrier, nativeString]),
  ]);
}

function equalityAssertionOperations(
  id: string,
  withoutMessage: string,
  withMessage: string,
): readonly MojoProviderOperationDefinition[] {
  const parameter = targetTypeParameter("T");
  return Object.freeze([
    callOperation(id, `${id}(actual,expected)`, withoutMessage, [parameter, parameter], true),
    callOperation(id, `${id}(actual,expected,message)`, withMessage, [parameter, parameter, nativeString], true),
  ]);
}

function callOperation(
  exportId: string,
  signatureId: string,
  targetName: string,
  parameterTypes: readonly MojoTargetTypeRef[],
  generic = false,
): MojoProviderOperationDefinition {
  return Object.freeze({
    exportId,
    signatureId,
    operationKind: "call",
    target: Object.freeze({
      kind: "function-call",
      modulePath: Object.freeze(["tsonic_node", "assertions"]),
      name: targetName,
      ...(generic
        ? {
            genericParameters: Object.freeze([Object.freeze({
              kind: "type" as const,
              name: "T",
              position: "inferred" as const,
              variadic: false,
              constraints: Object.freeze([]),
            })]),
          }
        : {}),
      arguments: Object.freeze(parameterTypes.map(() => Object.freeze({
        convention: "imm" as const,
        position: "positional-or-keyword" as const,
      }))),
    }),
    parameterTypes: Object.freeze([...parameterTypes]),
    resultType: unitCarrier,
    raises: true,
  });
}
