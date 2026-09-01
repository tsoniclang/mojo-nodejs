import type {
  MojoProviderModuleDefinition,
  MojoProviderOperationDefinition,
  MojoProviderTypeDefinition,
} from "@tsonic/target-mojo/provider";
import {
  booleanType,
  boolCarrier,
  bufferCarrier,
  fnExport,
  functionCall,
  instanceCall,
  nativeString,
  numberType,
  overloadedMethodMember,
  propertyMember,
  propertyRead,
  providerRef,
  stringType,
  textDecoderCarrier,
} from "../model.js";

const moduleSpecifier = "node:util";
const textDecoderId = `${moduleSpecifier}::TextDecoder`;

export function utilModule(): MojoProviderModuleDefinition {
  return Object.freeze({
    moduleSpecifier,
    providerModuleId: "tsonic.mojo.node.util",
    imports: Object.freeze([Object.freeze({
      moduleSpecifier: "node:buffer",
      namedImports: Object.freeze([{ exportedName: "Buffer" }]),
    })]),
    exports: Object.freeze([
      Object.freeze({
        id: textDecoderId,
        name: "TextDecoder",
        kind: "class",
        members: Object.freeze([
          Object.freeze({
            id: `${textDecoderId}.constructor`,
            name: "constructor",
            kind: "constructor",
            signatures: Object.freeze([
              Object.freeze({
                id: `${textDecoderId}.constructor()`,
                name: "constructor",
                parameters: Object.freeze([]),
                returnType: Object.freeze({ kind: "void" }),
              }),
              Object.freeze({
                id: `${textDecoderId}.constructor(encoding)`,
                name: "constructor",
                parameters: Object.freeze([{ name: "encoding", type: stringType }]),
                returnType: Object.freeze({ kind: "void" }),
              }),
            ]),
          }),
          overloadedMethodMember(textDecoderId, "decode", [
            { parameters: [], returnType: stringType, signatureSuffix: "" },
            {
              parameters: [{ name: "input", type: providerRef("node:buffer", "Buffer") }],
              returnType: stringType,
              signatureSuffix: "input",
            },
          ]),
          propertyMember(textDecoderId, "encoding", stringType),
          propertyMember(textDecoderId, "fatal", booleanType),
          propertyMember(textDecoderId, "ignoreBOM", booleanType),
        ]),
      }),
      fnExport(moduleSpecifier, "stripVTControlCharacters", [{ name: "value", type: stringType }], stringType),
      fnExport(moduleSpecifier, "toUSVString", [{ name: "value", type: stringType }], stringType),
      fnExport(moduleSpecifier, "styleText", [
        { name: "style", type: stringType },
        { name: "text", type: stringType },
      ], stringType),
      fnExport(moduleSpecifier, "getSystemErrorName", [{ name: "code", type: numberType }], stringType),
      fnExport(moduleSpecifier, "getSystemErrorMessage", [{ name: "code", type: numberType }], stringType),
      fnExport(moduleSpecifier, "inspect", [{ name: "value", type: Object.freeze({ kind: "any" }) }], stringType),
      fnExport(moduleSpecifier, "format", [Object.freeze({
        name: "values",
        type: Object.freeze({ kind: "array", elementType: Object.freeze({ kind: "any" }) }),
        rest: true,
      })], stringType),
    ]),
  });
}

export function utilTypes(): readonly MojoProviderTypeDefinition[] {
  return Object.freeze([Object.freeze({
    exportId: textDecoderId,
    sourceGenericParameters: Object.freeze([]),
    targetType: textDecoderCarrier,
  })]);
}

export function utilOperations(): readonly MojoProviderOperationDefinition[] {
  return Object.freeze([
    constructorOperation(`${textDecoderId}.constructor()`, "text_decoder_new", [], textDecoderCarrier),
    constructorOperation(`${textDecoderId}.constructor(encoding)`, "text_decoder_new_encoding", [nativeString], textDecoderCarrier, true),
    instanceCall(textDecoderId, `${textDecoderId}.decode`, `${textDecoderId}.decode()`, "decode_empty", textDecoderCarrier, [], nativeString),
    instanceCall(textDecoderId, `${textDecoderId}.decode`, `${textDecoderId}.decode(input)`, "decode", textDecoderCarrier, [bufferCarrier], nativeString, true),
    propertyRead(textDecoderId, `${textDecoderId}.encoding`, "encoding", textDecoderCarrier, nativeString, "method"),
    propertyRead(textDecoderId, `${textDecoderId}.fatal`, "fatal", textDecoderCarrier, boolCarrier, "method"),
    propertyRead(textDecoderId, `${textDecoderId}.ignoreBOM`, "ignore_bom", textDecoderCarrier, boolCarrier, "method"),
    functionCall(`${moduleSpecifier}::stripVTControlCharacters`, `${moduleSpecifier}::stripVTControlCharacters(value)`, "util", "strip_vt_control_characters", [nativeString], nativeString),
    functionCall(`${moduleSpecifier}::toUSVString`, `${moduleSpecifier}::toUSVString(value)`, "util", "to_usv_string", [nativeString], nativeString),
    functionCall(`${moduleSpecifier}::styleText`, `${moduleSpecifier}::styleText(style,text)`, "util", "style_text", [nativeString, nativeString], nativeString, true),
  ]);
}

function constructorOperation(
  signatureId: string,
  name: string,
  parameterTypes: readonly import("@tsonic/target-mojo/provider").MojoTargetTypeRef[],
  resultType: import("@tsonic/target-mojo/provider").MojoTargetTypeRef,
  raises = false,
): MojoProviderOperationDefinition {
  return Object.freeze({
    exportId: textDecoderId,
    memberId: `${textDecoderId}.constructor`,
    signatureId,
    operationKind: "constructor",
    target: Object.freeze({
      kind: "function-call",
      modulePath: Object.freeze(["tsonic_node", "util"]),
      name,
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
