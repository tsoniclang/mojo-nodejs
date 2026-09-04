import type {
  MojoProviderModuleDefinition,
  MojoProviderOperationDefinition,
  MojoProviderTypeDefinition,
} from "@tsonic/target-mojo/provider";
import {
  boolCarrier,
  emptyCallbackCarrier,
  fnExport,
  instanceCall,
  int32Carrier,
  int32Type,
  methodMember,
  nodeProviderType,
  providerCallbackType,
  providerRef,
  timeoutCarrier,
  unitCarrier,
  voidType,
} from "../model.js";

const moduleSpecifier = "node:timers";
const timeoutId = `${moduleSpecifier}::Timeout`;

export function timersModule(): MojoProviderModuleDefinition {
  const timeoutCallback = providerCallbackType(
    `${moduleSpecifier}::setTimeout(callback,delay)`,
    "callback",
    [],
  );
  const intervalCallback = providerCallbackType(
    `${moduleSpecifier}::setInterval(callback,delay)`,
    "callback",
    [],
  );
  return Object.freeze({
    moduleSpecifier,
    providerModuleId: "tsonic.mojo.node.timers",
    exports: Object.freeze([
      Object.freeze({
        id: timeoutId,
        name: "Timeout",
        kind: "class",
        members: Object.freeze([
          methodMember(timeoutId, "hasRef", [], Object.freeze({ kind: "boolean" })),
          methodMember(timeoutId, "ref", [], providerRef(moduleSpecifier, "Timeout")),
          methodMember(timeoutId, "unref", [], providerRef(moduleSpecifier, "Timeout")),
          methodMember(timeoutId, "refresh", [], providerRef(moduleSpecifier, "Timeout")),
          methodMember(timeoutId, "close", [], providerRef(moduleSpecifier, "Timeout")),
        ]),
      }),
      fnExport(moduleSpecifier, "setTimeout", [
        { name: "callback", type: timeoutCallback },
        { name: "delay", type: int32Type },
      ], providerRef(moduleSpecifier, "Timeout")),
      fnExport(moduleSpecifier, "setInterval", [
        { name: "callback", type: intervalCallback },
        { name: "delay", type: int32Type },
      ], providerRef(moduleSpecifier, "Timeout")),
      fnExport(moduleSpecifier, "clearTimeout", [
        { name: "timeout", type: providerRef(moduleSpecifier, "Timeout") },
      ], voidType),
      fnExport(moduleSpecifier, "clearInterval", [
        { name: "timeout", type: providerRef(moduleSpecifier, "Timeout") },
      ], voidType),
    ]),
  });
}

export function timersTypes(): readonly MojoProviderTypeDefinition[] {
  return Object.freeze([
    nodeProviderType(timeoutId, timeoutCarrier, "implicitly-copyable"),
  ]);
}

export function timersOperations(): readonly MojoProviderOperationDefinition[] {
  const functionOperation = (
    name: "setTimeout" | "setInterval",
    targetName: "set_timeout" | "set_interval",
  ): MojoProviderOperationDefinition => Object.freeze({
    exportId: `${moduleSpecifier}::${name}`,
    signatureId: `${moduleSpecifier}::${name}(callback,delay)`,
    operationKind: "call",
    target: Object.freeze({
      kind: "function-call",
      modulePath: Object.freeze(["tsonic_node", "timers"]),
      name: targetName,
      arguments: Object.freeze([
        Object.freeze({ convention: "imm", position: "positional-or-keyword" }),
        Object.freeze({ convention: "imm", position: "positional-or-keyword" }),
      ]),
    }),
    parameterTypes: Object.freeze([emptyCallbackCarrier, int32Carrier]),
    resultType: timeoutCarrier,
    raises: true,
  });
  const clearOperation = (
    name: "clearTimeout" | "clearInterval",
    targetName: "clear_timeout" | "clear_interval",
  ): MojoProviderOperationDefinition => Object.freeze({
    exportId: `${moduleSpecifier}::${name}`,
    signatureId: `${moduleSpecifier}::${name}(timeout)`,
    operationKind: "call",
    target: Object.freeze({
      kind: "function-call",
      modulePath: Object.freeze(["tsonic_node", "timers"]),
      name: targetName,
      arguments: Object.freeze([
        Object.freeze({ convention: "imm", position: "positional-or-keyword" }),
      ]),
    }),
    parameterTypes: Object.freeze([timeoutCarrier]),
    resultType: unitCarrier,
  });
  return Object.freeze([
    functionOperation("setTimeout", "set_timeout"),
    functionOperation("setInterval", "set_interval"),
    clearOperation("clearTimeout", "clear_timeout"),
    clearOperation("clearInterval", "clear_interval"),
    instanceCall(timeoutId, `${timeoutId}.hasRef`, `${timeoutId}.hasRef()`, "has_ref", timeoutCarrier, [], boolCarrier),
    instanceCall(timeoutId, `${timeoutId}.ref`, `${timeoutId}.ref()`, "ref", timeoutCarrier, [], timeoutCarrier),
    instanceCall(timeoutId, `${timeoutId}.unref`, `${timeoutId}.unref()`, "unref", timeoutCarrier, [], timeoutCarrier),
    instanceCall(timeoutId, `${timeoutId}.refresh`, `${timeoutId}.refresh()`, "refresh", timeoutCarrier, [], timeoutCarrier),
    instanceCall(timeoutId, `${timeoutId}.close`, `${timeoutId}.close()`, "close", timeoutCarrier, [], timeoutCarrier),
  ]);
}
