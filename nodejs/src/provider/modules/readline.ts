import type {
  MojoProviderModuleDefinition,
  MojoProviderOperationDefinition,
  MojoProviderTypeDefinition,
  MojoTargetTypeRef,
} from "@tsonic/target-mojo/provider";
import {
  booleanType,
  boolCarrier,
  float64Carrier,
  functionCall,
  methodMember,
  nativeString,
  propertyMember,
  propertyRead,
  providerCallbackType,
  providerRef,
  readableCarrier,
  readlineInterfaceCarrier,
  readlineOptionsCarrier,
  readlineQuestionCallbackCarrier,
  stringType,
  unitCarrier,
  voidType,
  writableCarrier,
} from "../model.js";

const moduleSpecifier = "node:readline";
const optionsId = `${moduleSpecifier}::ReadLineOptions`;
const interfaceId = `${moduleSpecifier}::Interface`;

export function readlineModule(): MojoProviderModuleDefinition {
  const callback = providerCallbackType(
    `${interfaceId}.question(query,callback)`,
    "callback",
    [{ name: "answer", type: stringType }],
  );
  return Object.freeze({
    moduleSpecifier,
    providerModuleId: "tsonic.mojo.node.readline",
    imports: Object.freeze([Object.freeze({
      moduleSpecifier: "node:stream",
      namedImports: Object.freeze([
        { exportedName: "Readable" },
        { exportedName: "Writable" },
      ]),
    })]),
    exports: Object.freeze([
      Object.freeze({
        id: optionsId,
        name: "ReadLineOptions",
        kind: "interface",
        members: Object.freeze([
          propertyMember(optionsId, "input", providerRef("node:stream", "Readable"), { readonly: false }),
          propertyMember(optionsId, "output", providerRef("node:stream", "Writable"), { readonly: false, optional: true }),
          propertyMember(optionsId, "terminal", booleanType, { readonly: false, optional: true }),
          propertyMember(optionsId, "prompt", stringType, { readonly: false, optional: true }),
        ]),
      }),
      Object.freeze({
        id: interfaceId,
        name: "Interface",
        kind: "class",
        members: Object.freeze([
          methodMember(interfaceId, "question", [
            { name: "query", type: stringType },
            { name: "callback", type: callback },
          ], voidType),
          methodMember(interfaceId, "write", [{ name: "text", type: stringType }], voidType),
          methodMember(interfaceId, "pause", [], providerRef(moduleSpecifier, "Interface")),
          methodMember(interfaceId, "resume", [], providerRef(moduleSpecifier, "Interface")),
          methodMember(interfaceId, "isPaused", [], booleanType),
          methodMember(interfaceId, "close", [], voidType),
          methodMember(interfaceId, "setPrompt", [{ name: "prompt", type: stringType }], voidType),
          methodMember(interfaceId, "getPrompt", [], stringType),
          methodMember(interfaceId, "prompt", [], voidType),
          propertyMember(interfaceId, "line", stringType),
          propertyMember(interfaceId, "cursor", Object.freeze({ kind: "number" })),
          propertyMember(interfaceId, "terminal", booleanType),
        ]),
      }),
      Object.freeze({
        id: `${moduleSpecifier}::createInterface`,
        name: "createInterface",
        kind: "function",
        signatures: Object.freeze([Object.freeze({
          id: `${moduleSpecifier}::createInterface(options)`,
          name: "createInterface",
          parameters: Object.freeze([
            { name: "options", type: providerRef(moduleSpecifier, "ReadLineOptions") },
          ]),
          returnType: providerRef(moduleSpecifier, "Interface"),
        })]),
      }),
    ]),
  });
}

export function readlineTypes(): readonly MojoProviderTypeDefinition[] {
  return Object.freeze([
    Object.freeze({
      exportId: optionsId,
      sourceGenericParameters: Object.freeze([]),
      targetType: readlineOptionsCarrier,
      objectLiteralConstruction: Object.freeze({ kind: "struct-default" }),
    }),
    Object.freeze({
      exportId: interfaceId,
      sourceGenericParameters: Object.freeze([]),
      targetType: readlineInterfaceCarrier,
    }),
  ]);
}

export function readlineOperations(): readonly MojoProviderOperationDefinition[] {
  const optionalWritable = Object.freeze({ kind: "optional" as const, value: writableCarrier });
  const optionalBool = Object.freeze({ kind: "optional" as const, value: boolCarrier });
  const optionalString = Object.freeze({ kind: "optional" as const, value: nativeString });
  return Object.freeze([
    ...option("input", readableCarrier),
    ...option("output", optionalWritable),
    ...option("terminal", optionalBool),
    ...option("prompt", optionalString),
    functionCall(
      `${moduleSpecifier}::createInterface`,
      `${moduleSpecifier}::createInterface(options)`,
      "readline",
      "create_interface",
      [readlineOptionsCarrier],
      readlineInterfaceCarrier,
    ),
    call("question", "question", [nativeString, readlineQuestionCallbackCarrier], unitCarrier, true),
    call("write", "write", [nativeString], unitCarrier, true),
    call("pause", "pause", [], readlineInterfaceCarrier),
    call("resume", "resume", [], readlineInterfaceCarrier),
    call("isPaused", "is_paused", [], boolCarrier),
    call("close", "close", [], unitCarrier),
    call("setPrompt", "set_prompt", [nativeString], unitCarrier),
    call("getPrompt", "get_prompt", [], nativeString),
    call("prompt", "prompt", [], unitCarrier, true),
    propertyRead(interfaceId, `${interfaceId}.line`, "line", readlineInterfaceCarrier, nativeString, "method"),
    propertyRead(interfaceId, `${interfaceId}.cursor`, "cursor", readlineInterfaceCarrier, float64Carrier, "method"),
    propertyRead(interfaceId, `${interfaceId}.terminal`, "terminal", readlineInterfaceCarrier, boolCarrier, "method"),
  ]);
}

function option(name: string, type: MojoTargetTypeRef): readonly MojoProviderOperationDefinition[] {
  return Object.freeze([
    Object.freeze({
      exportId: optionsId,
      memberId: `${optionsId}.${name}`,
      operationKind: "property",
      target: Object.freeze({
        kind: "property-read",
        access: Object.freeze({ kind: "member", name }),
        receiver: "imm",
      }),
      receiverType: readlineOptionsCarrier,
      resultType: type,
    }),
    Object.freeze({
      exportId: optionsId,
      memberId: `${optionsId}.${name}`,
      operationKind: "property-set",
      target: Object.freeze({
        kind: "property-write",
        access: Object.freeze({ kind: "member", name }),
        receiver: "mut",
        value: Object.freeze({
          convention: "imm",
          position: "positional-or-keyword",
        }),
      }),
      receiverType: readlineOptionsCarrier,
      parameterTypes: Object.freeze([type]),
      resultType: unitCarrier,
    }),
  ]);
}

function call(
  member: string,
  name: string,
  parameters: readonly MojoTargetTypeRef[],
  result: MojoTargetTypeRef,
  raises = false,
): MojoProviderOperationDefinition {
  return Object.freeze({
    exportId: interfaceId,
    memberId: `${interfaceId}.${member}`,
    operationKind: "call",
    target: Object.freeze({
      kind: "instance-call",
      name,
      receiver: "mut",
      arguments: Object.freeze(parameters.map(() => Object.freeze({
        convention: "imm" as const,
        position: "positional-or-keyword" as const,
      }))),
    }),
    receiverType: readlineInterfaceCarrier,
    parameterTypes: Object.freeze([...parameters]),
    resultType: result,
    ...(raises ? { raises: true } : {}),
  });
}
