import type {
  MojoProviderModuleDefinition,
  MojoProviderOperationDefinition,
  MojoProviderTypeDefinition,
  MojoTargetTypeRef,
} from "@tsonic/target-mojo/provider";
import { mojoOptionalTargetType } from "@tsonic/target-mojo/provider";
import {
  boolCarrier,
  booleanType,
  constructorMember,
  emptyCallbackCarrier,
  float64Carrier,
  functionCall,
  functionValue,
  instanceCall,
  jsValueCarrier,
  messageChannelCarrier,
  messagePortCarrier,
  methodMember,
  nativeString,
  numberType,
  oneValueCallbackCarrier,
  optionalStringCarrier,
  propertyMember,
  propertyRead,
  propertyWrite,
  providerCallbackType,
  providerRef,
  stringListCarrier,
  stringArrayType,
  stringType,
  undefinedType,
  unitCarrier,
  valueExport,
  voidType,
  workerCarrier,
  workerOptionsCarrier,
} from "../model.js";

const moduleSpecifier = "node:worker_threads";
const workerId = `${moduleSpecifier}::Worker`;
const workerOptionsId = `${moduleSpecifier}::WorkerOptions`;
const messagePortId = `${moduleSpecifier}::MessagePort`;
const messageChannelId = `${moduleSpecifier}::MessageChannel`;
const anyType = Object.freeze({ kind: "any" as const });
const eventNameType = Object.freeze({
  kind: "union" as const,
  types: Object.freeze([
    stringType,
    Object.freeze({ kind: "source-global" as const, name: "Symbol" }),
  ]),
});
const optionalUnknownType = Object.freeze({
  kind: "union" as const,
  types: Object.freeze([anyType, undefinedType]),
});
const optionalPortType = Object.freeze({
  kind: "union" as const,
  types: Object.freeze([providerRef(moduleSpecifier, "MessagePort"), undefinedType]),
});

export function workerThreadsModule(): MojoProviderModuleDefinition {
  return Object.freeze({
    moduleSpecifier,
    providerModuleId: "tsonic.mojo.node.worker-threads",
    exports: Object.freeze([
      Object.freeze({
        id: workerId,
        name: "Worker",
        kind: "class",
        members: Object.freeze([
          Object.freeze({
            id: `${workerId}.constructor`,
            name: "constructor",
            kind: "constructor",
            signatures: Object.freeze([
              Object.freeze({
                id: `${workerId}.constructor(modulePath)`,
                name: "constructor",
                parameters: Object.freeze([{ name: "modulePath", type: stringType }]),
                returnType: voidType,
              }),
              Object.freeze({
                id: `${workerId}.constructor(modulePath,options)`,
                name: "constructor",
                parameters: Object.freeze([
                  { name: "modulePath", type: stringType },
                  { name: "options", type: providerRef(moduleSpecifier, "WorkerOptions") },
                ]),
                returnType: voidType,
              }),
            ]),
          }),
          methodMember(workerId, "postMessage", [{ name: "value", type: anyType }], voidType),
          methodMember(workerId, "terminate", [], Object.freeze({
            kind: "source-global" as const,
            name: "Promise",
            typeArguments: Object.freeze([numberType]),
          })),
          methodMember(workerId, "ref", [], providerRef(moduleSpecifier, "Worker")),
          methodMember(workerId, "unref", [], providerRef(moduleSpecifier, "Worker")),
          ...eventMembers(workerId, "Worker"),
          propertyMember(workerId, "threadId", numberType),
        ]),
      }),
      Object.freeze({
        id: workerOptionsId,
        name: "WorkerOptions",
        kind: "interface",
        members: Object.freeze([
          propertyMember(workerOptionsId, "name", stringType, { readonly: false, optional: true }),
          propertyMember(workerOptionsId, "argv", stringArrayType, { readonly: false, optional: true }),
          propertyMember(workerOptionsId, "env", anyType, { readonly: false, optional: true }),
          propertyMember(workerOptionsId, "workerData", anyType, { readonly: false, optional: true }),
        ]),
      }),
      Object.freeze({
        id: messagePortId,
        name: "MessagePort",
        kind: "class",
        members: Object.freeze([
          methodMember(messagePortId, "postMessage", [{ name: "value", type: anyType }], voidType),
          methodMember(messagePortId, "start", [], voidType),
          methodMember(messagePortId, "close", [], voidType),
          methodMember(messagePortId, "ref", [], providerRef(moduleSpecifier, "MessagePort")),
          methodMember(messagePortId, "unref", [], providerRef(moduleSpecifier, "MessagePort")),
          methodMember(messagePortId, "hasRef", [], booleanType),
          ...eventMembers(messagePortId, "MessagePort"),
        ]),
      }),
      Object.freeze({
        id: messageChannelId,
        name: "MessageChannel",
        kind: "class",
        members: Object.freeze([
          constructorMember(messageChannelId, []),
          propertyMember(messageChannelId, "port1", providerRef(moduleSpecifier, "MessagePort")),
          propertyMember(messageChannelId, "port2", providerRef(moduleSpecifier, "MessagePort")),
        ]),
      }),
      functionExport("receiveMessageOnPort", [
        { name: "port", type: providerRef(moduleSpecifier, "MessagePort") },
      ], optionalUnknownType),
      functionExport("getEnvironmentData", [{ name: "key", type: stringType }], optionalUnknownType),
      functionExport("setEnvironmentData", [
        { name: "key", type: stringType },
        { name: "value", type: anyType },
      ], voidType),
      functionExport("markAsUntransferable", [{ name: "value", type: anyType }], voidType),
      functionExport("isMarkedAsUntransferable", [{ name: "value", type: anyType }], booleanType),
      valueExport(moduleSpecifier, "isMainThread", booleanType),
      valueExport(moduleSpecifier, "threadId", numberType),
      valueExport(moduleSpecifier, "workerData", anyType),
      valueExport(moduleSpecifier, "parentPort", optionalPortType),
    ]),
  });
}

export function workerThreadsTypes(): readonly MojoProviderTypeDefinition[] {
  return Object.freeze([
    providerType(workerId, workerCarrier),
    Object.freeze({
      exportId: workerOptionsId,
      sourceGenericParameters: Object.freeze([]),
      targetType: workerOptionsCarrier,
      objectLiteralConstruction: Object.freeze({ kind: "struct-default" }),
    }),
    providerType(messagePortId, messagePortCarrier),
    providerType(messageChannelId, messageChannelCarrier),
  ]);
}

export function workerThreadsOperations(): readonly MojoProviderOperationDefinition[] {
  return Object.freeze([
    unsupportedWorkerConstructor(`${workerId}.constructor(modulePath)`, [nativeString]),
    unsupportedWorkerConstructor(`${workerId}.constructor(modulePath,options)`, [nativeString, workerOptionsCarrier]),
    Object.freeze({
      exportId: messageChannelId,
      memberId: `${messageChannelId}.constructor`,
      signatureId: `${messageChannelId}.constructor()`,
      operationKind: "constructor",
      target: Object.freeze({
        kind: "function-call",
        modulePath: Object.freeze(["tsonic_node", "worker_threads"]),
        name: "message_channel_new",
        arguments: Object.freeze([]),
      }),
      parameterTypes: Object.freeze([]),
      resultType: messageChannelCarrier,
    }),
    instanceCall(messagePortId, `${messagePortId}.postMessage`, `${messagePortId}.postMessage(value)`, "post_message", messagePortCarrier, [jsValueCarrier], unitCarrier, true, "mut"),
    instanceCall(messagePortId, `${messagePortId}.start`, `${messagePortId}.start()`, "start", messagePortCarrier, [], unitCarrier, false, "mut"),
    instanceCall(messagePortId, `${messagePortId}.close`, `${messagePortId}.close()`, "close", messagePortCarrier, [], unitCarrier, false, "mut"),
    instanceCall(messagePortId, `${messagePortId}.ref`, `${messagePortId}.ref()`, "ref_chain", messagePortCarrier, [], messagePortCarrier, false, "mut"),
    instanceCall(messagePortId, `${messagePortId}.unref`, `${messagePortId}.unref()`, "unref_chain", messagePortCarrier, [], messagePortCarrier, false, "mut"),
    instanceCall(messagePortId, `${messagePortId}.hasRef`, `${messagePortId}.hasRef()`, "has_ref", messagePortCarrier, [], boolCarrier),
    ...eventOperations(messagePortId, messagePortCarrier),
    propertyRead(messageChannelId, `${messageChannelId}.port1`, "port1", messageChannelCarrier, messagePortCarrier),
    propertyRead(messageChannelId, `${messageChannelId}.port2`, "port2", messageChannelCarrier, messagePortCarrier),
    functionCall(`${moduleSpecifier}::receiveMessageOnPort`, `${moduleSpecifier}::receiveMessageOnPort(port)`, "worker_threads", "receive_message_on_port", [messagePortCarrier], jsValueCarrier, true),
    functionCall(`${moduleSpecifier}::getEnvironmentData`, `${moduleSpecifier}::getEnvironmentData(key)`, "worker_threads", "get_environment_data", [nativeString], jsValueCarrier, true),
    functionCall(`${moduleSpecifier}::setEnvironmentData`, `${moduleSpecifier}::setEnvironmentData(key,value)`, "worker_threads", "set_environment_data", [nativeString, jsValueCarrier], unitCarrier, true),
    functionCall(`${moduleSpecifier}::markAsUntransferable`, `${moduleSpecifier}::markAsUntransferable(value)`, "worker_threads", "mark_as_untransferable", [jsValueCarrier], unitCarrier, true),
    functionCall(`${moduleSpecifier}::isMarkedAsUntransferable`, `${moduleSpecifier}::isMarkedAsUntransferable(value)`, "worker_threads", "is_marked_as_untransferable", [jsValueCarrier], boolCarrier, true),
    functionValue(`${moduleSpecifier}::isMainThread`, "worker_threads", "is_main_thread", boolCarrier),
    functionValue(`${moduleSpecifier}::threadId`, "worker_threads", "thread_id", float64Carrier),
    functionValue(`${moduleSpecifier}::workerData`, "worker_threads", "worker_data", jsValueCarrier),
    functionValue(`${moduleSpecifier}::parentPort`, "worker_threads", "parent_port", mojoOptionalTargetType(messagePortCarrier)),
    ...optionOperations(),
  ]);
}

function unsupportedWorkerConstructor(
  signatureId: string,
  parameterTypes: readonly MojoTargetTypeRef[],
): MojoProviderOperationDefinition {
  return Object.freeze({
    exportId: workerId,
    memberId: `${workerId}.constructor`,
    signatureId,
    operationKind: "constructor",
    target: Object.freeze({
      kind: "unsupported",
      code: "MOJO_NODE_WORKER_SOURCE_MODULE_CONSTRUCTION_UNAVAILABLE",
      reason: "Worker construction requires an exact generated source-module entry and closed executable dispatch, which the current Mojo target does not provide.",
    }),
    parameterTypes: Object.freeze([...parameterTypes]),
    resultType: workerCarrier,
  });
}

function eventMembers(ownerId: string, ownerName: string) {
  return (["on", "once", "off"] as const).map((name) => Object.freeze({
    id: `${ownerId}.${name}`,
    name,
    kind: "method" as const,
    signatures: Object.freeze([0, 1].map((arity) => Object.freeze({
      id: `${ownerId}.${name}(${arity})`,
      name,
      parameters: Object.freeze([
        { name: "eventName", type: eventNameType },
        {
          name: "listener",
          type: providerCallbackType(`${ownerId}.${name}(${arity})`, "listener", Array.from(
            { length: arity },
            (_, index) => ({ name: `value${index}`, type: anyType }),
          )),
        },
      ]),
      returnType: providerRef(moduleSpecifier, ownerName),
    }))),
  }));
}

function eventOperations(
  ownerId: string,
  receiverType: MojoTargetTypeRef,
): readonly MojoProviderOperationDefinition[] {
  return Object.freeze((["on", "once", "off"] as const).flatMap((name) => [
    instanceCall(ownerId, `${ownerId}.${name}`, `${ownerId}.${name}(0)`, `${name}_callable`, receiverType, [jsValueCarrier, emptyCallbackCarrier], receiverType, true, "mut"),
    instanceCall(ownerId, `${ownerId}.${name}`, `${ownerId}.${name}(1)`, `${name}_callable1`, receiverType, [jsValueCarrier, oneValueCallbackCarrier], receiverType, true, "mut"),
  ]));
}

function optionOperations(): readonly MojoProviderOperationDefinition[] {
  return Object.freeze([
    ...optionProperty("name", "name", optionalStringCarrier),
    ...optionProperty("argv", "argv", mojoOptionalTargetType(stringListCarrier)),
    ...optionProperty("env", "env", jsValueCarrier),
    ...optionProperty("workerData", "worker_data", jsValueCarrier),
  ]);
}

function optionProperty(
  sourceName: string,
  targetName: string,
  type: MojoTargetTypeRef,
): readonly MojoProviderOperationDefinition[] {
  return Object.freeze([
    propertyRead(workerOptionsId, `${workerOptionsId}.${sourceName}`, targetName, workerOptionsCarrier, type),
    propertyWrite(workerOptionsId, `${workerOptionsId}.${sourceName}`, targetName, workerOptionsCarrier, type),
  ]);
}

function providerType(
  exportId: string,
  targetType: MojoTargetTypeRef,
): MojoProviderTypeDefinition {
  return Object.freeze({
    exportId,
    sourceGenericParameters: Object.freeze([]),
    targetType,
  });
}

function functionExport(
  name: string,
  parameters: readonly { readonly name: string; readonly type: typeof anyType | ReturnType<typeof providerRef> | typeof stringType }[],
  returnType: typeof anyType | typeof optionalUnknownType | typeof booleanType | typeof voidType,
) {
  return Object.freeze({
    id: `${moduleSpecifier}::${name}`,
    name,
    kind: "function" as const,
    signatures: Object.freeze([Object.freeze({
      id: `${moduleSpecifier}::${name}(${parameters.map((parameter) => parameter.name).join(",")})`,
      name,
      parameters: Object.freeze(parameters.map((parameter) => Object.freeze({ ...parameter }))),
      returnType,
    })]),
  });
}
