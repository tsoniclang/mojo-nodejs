import type {
  MojoProviderModuleDefinition,
  MojoProviderOperationDefinition,
  MojoProviderTypeDefinition,
  MojoTargetTypeRef,
} from "@tsonic/target-mojo/provider";
import {
  booleanType,
  boolCarrier,
  constructorMember,
  emptyCallbackCarrier,
  eventEmitterCarrier,
  float64Carrier,
  fnExport,
  jsValueCarrier,
  methodMember,
  nodeProviderType,
  numberType,
  oneValueCallbackCarrier,
  providerRef,
  threeValueCallbackCarrier,
  twoValueCallbackCarrier,
  voidType,
} from "../model.js";
import { mojoListTargetType } from "@tsonic/target-mojo/provider";

const moduleSpecifier = "node:events";
const emitterId = `${moduleSpecifier}::EventEmitter`;
const anyType = Object.freeze({ kind: "any" as const });
const symbolType = Object.freeze({ kind: "source-global" as const, name: "Symbol" });
const eventNameType = Object.freeze({
  kind: "union" as const,
  types: Object.freeze([Object.freeze({ kind: "string" as const }), symbolType]),
});
const eventNameArrayType = Object.freeze({ kind: "array" as const, elementType: eventNameType });
const eventNameListCarrier = mojoListTargetType(jsValueCarrier);

export function eventsModule(): MojoProviderModuleDefinition {
  return Object.freeze({
    moduleSpecifier,
    providerModuleId: "tsonic.mojo.node.events",
    exports: Object.freeze([
      Object.freeze({
        id: emitterId,
        name: "EventEmitter",
        kind: "class",
        members: Object.freeze([
          constructorMember(emitterId, []),
          ...(["addListener", "on", "once", "off", "prependListener", "prependOnceListener", "removeListener"] as const)
            .map(listenerMember),
          emitMember(),
          methodMember(emitterId, "eventNames", [], eventNameArrayType),
          methodMember(emitterId, "getMaxListeners", [], numberType),
          methodMember(emitterId, "listenerCount", [{ name: "eventName", type: eventNameType }], numberType),
          Object.freeze({
            id: `${emitterId}.removeAllListeners`,
            name: "removeAllListeners",
            kind: "method",
            signatures: Object.freeze([
              Object.freeze({ id: `${emitterId}.removeAllListeners()`, name: "removeAllListeners", parameters: Object.freeze([]), returnType: providerRef(moduleSpecifier, "EventEmitter") }),
              Object.freeze({ id: `${emitterId}.removeAllListeners(eventName)`, name: "removeAllListeners", parameters: Object.freeze([{ name: "eventName", type: eventNameType }]), returnType: providerRef(moduleSpecifier, "EventEmitter") }),
            ]),
          }),
          methodMember(emitterId, "setMaxListeners", [{ name: "count", type: numberType }], providerRef(moduleSpecifier, "EventEmitter")),
        ]),
      }),
      fnExport(moduleSpecifier, "listenerCount", [
        { name: "emitter", type: providerRef(moduleSpecifier, "EventEmitter") },
        { name: "eventName", type: eventNameType },
      ], numberType),
    ]),
  });
}

export function eventsTypes(): readonly MojoProviderTypeDefinition[] {
  return Object.freeze([
    nodeProviderType(emitterId, eventEmitterCarrier, "implicitly-copyable"),
  ]);
}

export function eventsOperations(): readonly MojoProviderOperationDefinition[] {
  const callbackCarriers = [emptyCallbackCarrier, oneValueCallbackCarrier, twoValueCallbackCarrier, threeValueCallbackCarrier] as const;
  const rows: MojoProviderOperationDefinition[] = [Object.freeze({
    exportId: emitterId,
    memberId: `${emitterId}.constructor`,
    signatureId: `${emitterId}.constructor()`,
    operationKind: "constructor",
    target: Object.freeze({ kind: "function-call", modulePath: Object.freeze(["tsonic_node", "events"]), name: "event_emitter_new", arguments: Object.freeze([]) }),
    parameterTypes: Object.freeze([]),
    resultType: eventEmitterCarrier,
  })];
  for (const member of ["addListener", "on", "once", "off", "prependListener", "prependOnceListener", "removeListener"] as const) {
    const target = member === "once" ? "once" : member === "prependListener" ? "prepend" : member === "prependOnceListener" ? "prepend_once" : member === "off" || member === "removeListener" ? "off" : "on";
    for (let arity = 0; arity < callbackCarriers.length; arity += 1) {
      rows.push(instance(member, `${target}_callable${arity === 0 ? "" : arity}`, `${emitterId}.${member}(${arity})`, [jsValueCarrier, callbackCarriers[arity]!], eventEmitterCarrier, true, true));
    }
  }
  for (let arity = 0; arity < callbackCarriers.length; arity += 1) {
    rows.push(instance("emit", `emit_callable${arity === 0 ? "" : arity}`, `${emitterId}.emit(${arity})`, [jsValueCarrier, ...Array.from({ length: arity }, () => jsValueCarrier)], boolCarrier, true, true));
  }
  rows.push(
    instance("listenerCount", "listener_count", `${emitterId}.listenerCount(eventName)`, [jsValueCarrier], float64Carrier, false, true),
    instance("removeAllListeners", "remove_all_listeners", `${emitterId}.removeAllListeners()`, [], eventEmitterCarrier, true),
    instance("removeAllListeners", "remove_all_listeners_for", `${emitterId}.removeAllListeners(eventName)`, [jsValueCarrier], eventEmitterCarrier, true, true),
    instance("eventNames", "event_names", `${emitterId}.eventNames()`, [], eventNameListCarrier),
    instance("getMaxListeners", "get_max_listeners", `${emitterId}.getMaxListeners()`, [], float64Carrier),
    instance("setMaxListeners", "set_max_listeners", `${emitterId}.setMaxListeners(count)`, [float64Carrier], eventEmitterCarrier, true, true),
    Object.freeze({
      exportId: `${moduleSpecifier}::listenerCount`,
      signatureId: `${moduleSpecifier}::listenerCount(emitter,eventName)`,
      operationKind: "call",
      target: Object.freeze({
        kind: "function-call",
        modulePath: Object.freeze(["tsonic_node", "events"]),
        name: "listener_count",
        arguments: Object.freeze([
          Object.freeze({ convention: "imm", position: "positional-or-keyword" }),
          Object.freeze({ convention: "imm", position: "positional-or-keyword" }),
        ]),
      }),
      parameterTypes: Object.freeze([eventEmitterCarrier, jsValueCarrier]),
      resultType: float64Carrier,
      raises: true,
    }),
  );
  return Object.freeze(rows);
}

function listenerMember(name: string) {
  return Object.freeze({
    id: `${emitterId}.${name}`,
    name,
    kind: "method" as const,
    signatures: Object.freeze(Array.from({ length: 4 }, (_, arity) => Object.freeze({
      id: `${emitterId}.${name}(${arity})`,
      name,
      parameters: Object.freeze([
        Object.freeze({ name: "eventName", type: eventNameType }),
        Object.freeze({
          name: "listener",
          type: Object.freeze({
            kind: "function" as const,
            id: `${emitterId}.${name}.Listener${arity}`,
            parameters: Object.freeze(Array.from({ length: arity }, (__, index) => Object.freeze({ name: `value${index}`, type: anyType }))),
            returnType: voidType,
          }),
        }),
      ]),
      returnType: providerRef(moduleSpecifier, "EventEmitter"),
    }))),
  });
}

function emitMember() {
  return Object.freeze({
    id: `${emitterId}.emit`,
    name: "emit",
    kind: "method" as const,
    signatures: Object.freeze(Array.from({ length: 4 }, (_, arity) => Object.freeze({
      id: `${emitterId}.emit(${arity})`,
      name: "emit",
      parameters: Object.freeze([
        Object.freeze({ name: "eventName", type: eventNameType }),
        ...Array.from({ length: arity }, (__, index) => Object.freeze({ name: `value${index}`, type: anyType })),
      ]),
      returnType: booleanType,
    }))),
  });
}

function instance(
  member: string,
  name: string,
  signatureId: string | undefined,
  parameterTypes: readonly MojoTargetTypeRef[],
  resultType: MojoTargetTypeRef,
  mutating = false,
  raises = false,
): MojoProviderOperationDefinition {
  return Object.freeze({
    exportId: emitterId,
    memberId: `${emitterId}.${member}`,
    ...(signatureId === undefined ? {} : { signatureId }),
    operationKind: "call",
    target: Object.freeze({
      kind: "instance-call",
      name,
      receiver: mutating ? "mut" : "imm",
      arguments: Object.freeze(parameterTypes.map(() => Object.freeze({ convention: "imm" as const, position: "positional-or-keyword" as const }))),
    }),
    receiverType: eventEmitterCarrier,
    parameterTypes: Object.freeze([...parameterTypes]),
    resultType,
    ...(raises ? { raises: true } : {}),
  });
}
